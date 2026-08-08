import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const htmlPath = process.argv[2] ? path.resolve(process.argv[2]) : path.join(root, 'review', 'PROVENANCE_CX_R8_PRODUCTION_CAMPAIGN_REVIEW_STANDALONE.html');
const mode = process.env.FORCE_NO_WEBGL === 'false' ? 'webgl' : 'fallback';
const port = Number(process.env.CDP_PORT || '9222');
const outDir = path.join(root, 'evidence', 'corrective', 'browser', mode);
fs.mkdirSync(outDir, { recursive: true });

const version = await fetch(`http://127.0.0.1:${port}/json/version`).then((r) => r.json());
const ws = new WebSocket(version.webSocketDebuggerUrl);
let seq = 0;
const pending = new Map();
const listeners = new Map();
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(`${msg.error.code}:${msg.error.message}`)); else resolve(msg.result);
  }
  if (msg.method) for (const fn of listeners.get(msg.method) ?? []) fn(msg.params ?? {});
};
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
function send(method, params = {}, sessionId) {
  const id = ++seq;
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}
function on(method, fn) { listeners.set(method, [...(listeners.get(method) ?? []), fn]); }
const target = await send('Target.createTarget', { url: 'about:blank', newWindow: false, background: false });
const attached = await send('Target.attachToTarget', { targetId: target.targetId, flatten: true });
const sessionId = attached.sessionId;
const consoleErrors = [];
const exceptions = [];
const externalRequests = [];
on('Runtime.consoleAPICalled', (p) => { if (p.type === 'error') consoleErrors.push(p.args.map((a) => a.value ?? a.description ?? '').join(' ')); });
on('Runtime.exceptionThrown', (p) => exceptions.push(p.exceptionDetails?.exception?.description ?? p.exceptionDetails?.text ?? 'unknown exception'));
on('Network.requestWillBeSent', (p) => { if (/^https?:/i.test(p.request.url)) externalRequests.push(p.request.url); });
await send('Runtime.enable', {}, sessionId);
await send('Page.enable', {}, sessionId);
await send('Network.enable', {}, sessionId);
await send('Accessibility.enable', {}, sessionId);
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false }, sessionId);
const url = pathToFileURL(htmlPath).href;
let html = fs.readFileSync(htmlPath, 'utf8');
if (mode === 'fallback') html = html.replace('<head>', '<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>');
const frameTree = await send('Page.getFrameTree', {}, sessionId);
await send('Page.setDocumentContent', { frameId: frameTree.frameTree.frame.id, html }, sessionId);
await new Promise((r) => setTimeout(r, 5000));
async function evaluate(expression) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, sessionId);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
  return r.result?.value;
}
const desktop = await evaluate(`(() => {
  const duplicateIds = [...document.querySelectorAll('[id]')].map(e=>e.id).filter((id,i,a)=>a.indexOf(id)!==i);
  const interactive=[...document.querySelectorAll('a[href],button,input,select,textarea,[role="button"],[tabindex]')];
  const unnamed=interactive.filter(e=>{ const wrapped=e.closest('label')?.textContent?.trim(); const explicit=e.id?document.querySelector('label[for=\"'+CSS.escape(e.id)+'\"]')?.textContent?.trim():''; return !(e.getAttribute('aria-label')||e.getAttribute('aria-labelledby')||e.textContent?.trim()||e.getAttribute('title')||e.getAttribute('placeholder')||wrapped||explicit); }).map(e=>e.outerHTML.slice(0,180));
  const anchors=[...document.querySelectorAll('a[href]')].map(a=>a.getAttribute('href'));
  const placeholders=anchors.filter(h=>!h||h==='#'||/^javascript:/i.test(h));
  const images=[...document.images].map(img=>({src:img.currentSrc||img.src,alt:img.alt,complete:img.complete,naturalWidth:img.naturalWidth}));
  const brokenImages=images.filter(i=>!i.complete||i.naturalWidth===0);
  const forms=[...document.forms].map(f=>({id:f.id,inputs:f.querySelectorAll('input,select,textarea').length,buttons:f.querySelectorAll('button').length}));
  return {
    title:document.title,
    h1:[...document.querySelectorAll('h1')].map(e=>e.textContent.replace(/\\s+/g,' ').trim()),
    headings:[...document.querySelectorAll('h1,h2,h3')].length,
    links:anchors.length,buttons:document.querySelectorAll('button').length,forms,
    duplicateIds,unnamed,placeholders,brokenImages,
    horizontalOverflow:Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth),
    bodyHeight:document.body.scrollHeight,
    canvases:document.querySelectorAll('canvas').length,
    fallbackVisible:[...document.querySelectorAll('[class*="fallback"]')].some(e=>getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden'),
    testModeText:/test mode/i.test(document.body.innerText),
    pilotText:/pilot/i.test(document.body.innerText),
    productionAuthorityClaim:/production authority (active|enabled|live)/i.test(document.body.innerText),
    readyState:document.readyState,
    textLength:document.body.innerText.length
  };
})()`);
const ax = await send('Accessibility.getFullAXTree', {}, sessionId);
const interactiveRoles = new Set(['button','link','textbox','combobox','checkbox','radio','switch','menuitem','tab']);
const axUnnamed = (ax.nodes ?? []).filter((n) => interactiveRoles.has(n.role?.value) && !(n.name?.value ?? '').trim()).map((n) => ({ role:n.role?.value, nodeId:n.nodeId })).slice(0,100);

await evaluate("document.documentElement.style.scrollBehavior='auto'; scrollTo(0,0)");
await new Promise((r)=>setTimeout(r,250));
const desktopShot = await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,fromSurface:true},sessionId);
fs.writeFileSync(path.join(outDir,'desktop.png'),Buffer.from(desktopShot.data,'base64'));

const tabs=[];
for(let i=0;i<30;i++){
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9,nativeVirtualKeyCode:9},sessionId);
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9,nativeVirtualKeyCode:9},sessionId);
  tabs.push(await evaluate(`(() => {const e=document.activeElement; return {tag:e?.tagName||'',text:(e?.getAttribute('aria-label')||e?.textContent||e?.getAttribute('placeholder')||'').replace(/\\s+/g,' ').trim().slice(0,100),href:e?.getAttribute?.('href')||null};})()`));
}
await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]},sessionId);
await new Promise((r)=>setTimeout(r,500));
const reducedMotion = await evaluate(`(() => ({
  activeAnimations:document.getAnimations().filter(a=>a.playState==='running').length,
  reduced:matchMedia('(prefers-reduced-motion: reduce)').matches
}))()`);
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true,screenWidth:390,screenHeight:844},sessionId);
await send('Emulation.setUserAgentOverride',{userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36'},sessionId);
await new Promise((r)=>setTimeout(r,700));
const mobile = await evaluate(`(() => ({
  width:document.documentElement.clientWidth,
  horizontalOverflow:Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth),
  bodyHeight:document.body.scrollHeight,
  menuButtons:[...document.querySelectorAll('button')].filter(e=>/menu/i.test(e.getAttribute('aria-label')||e.textContent||'')).map(e=>({text:e.textContent?.trim(),display:getComputedStyle(e).display})),
  h1FontSize:document.querySelector('h1')?getComputedStyle(document.querySelector('h1')).fontSize:null,
  viewportMeta:document.querySelector('meta[name="viewport"]')?.content||null
}))()`);
const mobileShot = await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,fromSurface:true},sessionId);
fs.writeFileSync(path.join(outDir,'mobile.png'),Buffer.from(mobileShot.data,'base64'));

await send('Emulation.setDeviceMetricsOverride',{width:768,height:1024,deviceScaleFactor:1,mobile:false},sessionId);
await new Promise((r)=>setTimeout(r,500));
const tablet = await evaluate(`(() => ({width:document.documentElement.clientWidth,horizontalOverflow:Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth),bodyHeight:document.body.scrollHeight}))()`);
const tabletShot = await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,fromSurface:true},sessionId);
fs.writeFileSync(path.join(outDir,'tablet.png'),Buffer.from(tabletShot.data,'base64'));

const report={generatedAt:new Date().toISOString(),mode,browser:version.Browser,protocol:version['Protocol-Version'],htmlPath,url,desktop,mobile,tablet,reducedMotion,tabs,accessibility:{nodes:(ax.nodes??[]).length,unnamedInteractive:axUnnamed},consoleErrors,exceptions,externalRequests:[...new Set(externalRequests)]};
report.pass = desktop.readyState==='complete' && desktop.title.includes('PROVENANCE VERIFIED') && desktop.textLength>10000 && desktop.links>20 && desktop.buttons>5 && desktop.h1.length>=1 && desktop.duplicateIds.length===0 && desktop.unnamed.length===0 && desktop.placeholders.length===0 && desktop.brokenImages.length===0 && desktop.horizontalOverflow===0 && mobile.horizontalOverflow===0 && tablet.horizontalOverflow===0 && axUnnamed.length===0 && consoleErrors.length===0 && exceptions.length===0 && externalRequests.length===0 && !desktop.productionAuthorityClaim && (mode==='fallback' ? desktop.fallbackVisible && desktop.canvases===0 : desktop.canvases>=1);
fs.writeFileSync(path.join(outDir,'browser-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
ws.close();
process.exit(report.pass?0:1);
