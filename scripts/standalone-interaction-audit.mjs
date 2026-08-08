import fs from 'node:fs';
import { chromium } from '@playwright/test';
const html=fs.readFileSync('/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_STANDALONE_R3.html','utf8');
const browser=await chromium.connectOverCDP('http://127.0.0.1:9222');
const page=await browser.contexts()[0].newPage();
const consoleErrors=[]; const pageErrors=[];
page.on('console',m=>{if(m.type()==='error')consoleErrors.push(m.text())});
page.on('pageerror',e=>pageErrors.push(String(e)));
await page.setViewportSize({width:1440,height:900});
await page.setContent(html,{waitUntil:'load'});
await page.waitForTimeout(250);
await page.screenshot({path:'/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_R3_DESKTOP_FINAL.png',fullPage:true});

const run=page.getByRole('button',{name:/Run the proof transaction/});
await run.click();
await page.waitForTimeout(3900);
const proof=await page.evaluate(()=>({
  stage:document.querySelector('.pv2-object-state strong')?.textContent?.trim(),
  response:document.querySelector('.pv2-object-response pre')?.textContent,
  buttonDisabled:document.querySelector('.pv2-hero-actions .pv2-button-primary')?.disabled||false
}));

const evidenceButtons=page.locator('.pv2-evidence-list button');
await evidenceButtons.nth(3).click();
const evidence=await page.evaluate(()=>({
  selected:document.querySelector('.pv2-evidence-list .is-selected small')?.textContent?.trim(),
  title:document.querySelector('.pv2-evidence-detail h3')?.textContent?.trim(),
  independent:[...document.querySelectorAll('.pv2-evidence-detail dl div')].find(d=>d.querySelector('dt')?.textContent==='Independent')?.querySelector('dd')?.textContent?.trim()
}));

const revoked=page.locator('.pv2-lifecycle-nav button').filter({hasText:'revoked'});
await revoked.click();
const lifecycle=await page.evaluate(()=>({
  state:document.querySelector('.pv2-public-record header em')?.textContent?.trim(),
  id:document.querySelector('.pv2-public-record header strong')?.textContent?.trim(),
  mark:document.querySelector('.pv2-public-record-grid div:nth-child(4) strong')?.textContent?.trim(),
  suppressed:document.querySelector('.pv2-public-record')?.classList.contains('is-mark-suppressed')||false,
  neutralVisible:getComputedStyle(document.querySelector('.pv2-neutral-mark')).display
}));

await page.locator('#offline-public-id').fill('PV-TEST-SP1003');
await page.locator('#offline-resolver').getByRole('button',{name:/Resolve record/}).click();
const resolver=await page.locator('#offline-resolver-status').textContent();

await page.locator('.pv2-code-window button').filter({hasText:'MCP'}).click();
const developer=await page.evaluate(()=>({
  mode:document.querySelector('.pv2-code-window header>span')?.textContent?.trim(),
  code:document.querySelector('.pv2-code-window code')?.textContent?.trim()
}));

const reviewNav=page.locator('.pv2-ops-sidebar>span[role=button]').filter({hasText:'Review'});
await reviewNav.click();
const operations=await page.evaluate(()=>({
  active:document.querySelector('.pv2-ops-sidebar>span.is-active')?.textContent?.trim(),
  lots:document.querySelector('.pv2-ops-metrics article:nth-child(1) strong')?.textContent?.trim(),
  units:document.querySelector('.pv2-ops-metrics article:nth-child(2) strong')?.textContent?.trim()
}));

await page.setContent(html,{waitUntil:'load'});
await page.setViewportSize({width:390,height:844});
await page.waitForTimeout(200);
await page.locator('.pv2-menu-button').click();
const mobile=await page.evaluate(()=>({
  menuExpanded:document.querySelector('.pv2-menu-button')?.getAttribute('aria-expanded'),
  navOpen:document.querySelector('.pv2-primary-nav')?.classList.contains('is-open')||false,
  overflow:document.documentElement.scrollWidth-document.documentElement.clientWidth
}));
await page.screenshot({path:'/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_R3_MOBILE_FINAL.png',fullPage:true});

const report={generatedAt:new Date().toISOString(),proof,evidence,lifecycle,resolver,developer,operations,mobile,consoleErrors,pageErrors,passed:proof.stage==='Control'&&evidence.independent==='Yes'&&lifecycle.suppressed&&developer.mode==='CONTRACT ONLY'&&mobile.navOpen&&consoleErrors.length===0&&pageErrors.length===0};
fs.writeFileSync('/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_R3_INTERACTION_AUDIT.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
await page.close(); await browser.close();
