import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
const root=path.resolve(path.dirname(new URL(import.meta.url).pathname),'..');
const htmlPath=path.join(root,'review','PROVENANCE_CX_UNIFIED_FOUR_LAYER_R6_LIVING_STANDALONE.html');
const html=fs.readFileSync(htmlPath,'utf8');
const evidence=path.join(root,'evidence','r6-final'); fs.mkdirSync(evidence,{recursive:true});
const browser=await chromium.connectOverCDP('http://127.0.0.1:9334');
const context=browser.contexts()[0];
const errors=[]; const pageErrors=[];

// Live WebGL is audited in a separate headed Chromium session.
const webglPath=path.join(evidence,'R6_WEBGL_AUDIT.json');
const webgl=fs.existsSync(webglPath)?JSON.parse(fs.readFileSync(webglPath,'utf8')):{status:'NOT_RUN'};

// Stable fallback page for full interaction and visual audit.
const page=await context.newPage();
page.on('console',m=>{if(m.type()==='error') errors.push(m.text())}); page.on('pageerror',e=>pageErrors.push(String(e)));
await page.setViewportSize({width:1440,height:900});
const fallbackHtml=html.replace('<script>','<script>window.__PV_FORCE_NO_WEBGL__=true;</script><script>');
await page.setContent(fallbackHtml,{waitUntil:'load'}); await page.waitForTimeout(500);
const groups={};
for(const selector of ['.pv2-stage-rail button','.pv2-evidence-list button','.pv2-lifecycle-nav button','.pv2-credibility-grid button','.pv2-code-window [role="tab"]']){
 const count=await page.locator(selector).count(); let clicked=0;
 for(let i=0;i<count;i++){const el=page.locator(selector).nth(i); await el.scrollIntoViewIfNeeded(); await el.click(); await page.waitForTimeout(50); clicked++;}
 groups[selector]={count,clicked};
}
await page.evaluate(() => { const el=document.querySelector('#credibility'); if(el) window.scrollTo(0, Math.max(0, el.getBoundingClientRect().top + window.scrollY - 96)); }); await page.waitForTimeout(1500);
const credibility=await page.evaluate(()=>({cards:document.querySelectorAll('.pv2-credibility-grid button').length,active:document.querySelectorAll('.pv2-credibility-grid button.is-active').length,receiptComplete:document.querySelector('.pv2-control-receipt .pv-live-code')?.classList.contains('is-complete')||false,receiptText:document.querySelector('.pv2-control-receipt code')?.textContent?.slice(0,160)||''}));
await page.locator('#credibility').screenshot({path:path.join(evidence,'R6_CREDIBILITY.png')});
await page.evaluate(() => { const el=document.querySelector('.pv2-developer'); if(el) window.scrollTo(0, Math.max(0, el.getBoundingClientRect().top + window.scrollY - 96)); }); await page.waitForTimeout(1400);
const developer=await page.evaluate(()=>({tab:document.querySelector('.pv2-code-window [aria-selected="true"]')?.textContent,complete:document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-complete')||false,length:document.querySelector('.pv2-code-window code')?.textContent?.length||0}));
await page.locator('.pv2-developer').screenshot({path:path.join(evidence,'R6_DEVELOPER.png')});
await page.locator('.pv2-code-window [role="tab"]').first().click(); await page.waitForTimeout(140);
const runtime=await page.evaluate(()=>({exists:!!document.querySelector('.pv-runtime-console'),active:document.querySelector('.pv-runtime-console')?.classList.contains('is-active')||false,text:document.querySelector('.pv-runtime-console')?.textContent?.replace(/\s+/g,' ').trim().slice(0,180)||''}));
const routes=['/','/verify','/registry','/developers','/docs','/docs/quickstart','/docs/api','/docs/sdk','/docs/mcp','/docs/webhooks','/trust','/security','/company','/contact','/access','/sign-in','/status','/changelog','/brand/trademark','/provenance-verified','/legal/privacy','/legal/terms','/legal/certification-policy','/legal/evidence-policy','/legal/revocation-policy','/app','/app/lots','/app/intake','/app/batches','/app/search','/app/review','/app/labels','/app/exceptions','/app/audit'];
const routeResults=[];
for(const route of routes){await page.evaluate(r=>{window.location.hash=r;window.dispatchEvent(new Event('pv:navigate'));},route); await page.waitForTimeout(70); routeResults.push(await page.evaluate(r=>({route:r,h1:document.querySelector('h1')?.textContent?.replace(/\s+/g,' ').trim()||'',notFound:(document.querySelector('h1')?.textContent||'').includes('Review route not found')}),route));}
await page.evaluate(()=>{window.location.hash='/';window.dispatchEvent(new Event('pv:navigate'));}); await page.waitForTimeout(900);
const axe=await new AxeBuilder({page}).analyze();
const desktop=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth-document.documentElement.clientWidth,hardSectionRules:[...document.querySelectorAll('.pv2-section')].filter(e=>parseFloat(getComputedStyle(e).borderBottomWidth)>0).length,buttons:document.querySelectorAll('button').length,links:document.querySelectorAll('a[href]').length,externalResources:performance.getEntriesByType('resource').filter(e=>/^https?:/.test(e.name)).map(e=>e.name)}));
await page.screenshot({path:path.join(evidence,'R6_DESKTOP_FULL.png'),fullPage:true});
await page.setViewportSize({width:390,height:844}); await page.waitForTimeout(250);
const mobile=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth-document.documentElement.clientWidth,menuVisible:getComputedStyle(document.querySelector('.pv2-menu-button')).display!=='none',credibilityColumns:getComputedStyle(document.querySelector('.pv2-credibility-grid')).gridTemplateColumns}));
await page.screenshot({path:path.join(evidence,'R6_MOBILE_FULL.png'),fullPage:true});
const report={generatedAt:new Date().toISOString(),webgl,groups,credibility,developer,runtime,routes:{count:routeResults.length,failures:routeResults.filter(r=>r.notFound),results:routeResults},axe:{count:axe.violations.length,violations:axe.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length,help:v.help,details:v.nodes.map(n=>({target:n.target,html:n.html,failureSummary:n.failureSummary}))}))},desktop,mobile,errors,pageErrors};
fs.writeFileSync(path.join(evidence,'R6_BROWSER_AUDIT.json'),JSON.stringify(report,null,2)+'\n'); console.log(JSON.stringify(report,null,2));
await page.close(); await browser.close();
