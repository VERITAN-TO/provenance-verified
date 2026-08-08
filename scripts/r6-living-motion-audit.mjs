import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '@playwright/test';

const root=path.resolve(path.dirname(new URL(import.meta.url).pathname),'..');
const htmlPath=path.join(root,'review','PROVENANCE_CX_UNIFIED_FOUR_LAYER_R6_LIVING_STANDALONE.html');
const html=fs.readFileSync(htmlPath,'utf8').replace('<script>','<script>window.__PV_FORCE_NO_WEBGL__=true;</script><script>');
const browser=await chromium.connectOverCDP('http://127.0.0.1:9334');
const page=await browser.contexts()[0].newPage();
const errors=[]; const pageErrors=[];
page.on('console',m=>{if(m.type()==='error') errors.push(m.text())});
page.on('pageerror',e=>pageErrors.push(String(e)));
await page.setViewportSize({width:1440,height:900});
await page.setContent(html,{waitUntil:'load'});
await page.waitForTimeout(250);
const initial=await page.evaluate(()=>({
  pageProgress:getComputedStyle(document.documentElement).getPropertyValue('--pv-page-progress').trim(),
  developerVisible:document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-running')||false,
  developerLength:document.querySelector('.pv2-code-window code')?.textContent?.length||0,
  hardSectionRules:[...document.querySelectorAll('.pv2-section')].filter(e=>parseFloat(getComputedStyle(e).borderBottomWidth)>0).length,
  placeholderLinks:[...document.querySelectorAll('a[href]')].map(a=>a.getAttribute('href')).filter(h=>!h||h==='#'||h?.startsWith('javascript:')),
}));
await page.evaluate(()=>{document.documentElement.style.scrollBehavior='auto';const el=document.querySelector('.pv2-code-window');el?.scrollIntoView({block:'center'});});
await page.waitForTimeout(220);
const during=await page.evaluate(()=>({
  pageProgress:getComputedStyle(document.documentElement).getPropertyValue('--pv-page-progress').trim(),
  developerRunning:document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-running')||false,
  developerComplete:document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-complete')||false,
  developerLength:document.querySelector('.pv2-code-window code')?.textContent?.length||0,
  localProgress:getComputedStyle(document.querySelector('.pv2-developer')).getPropertyValue('--pv-local-progress').trim(),
}));
await page.waitForTimeout(1400);
const complete=await page.evaluate(()=>({
  developerComplete:document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-complete')||false,
  developerLength:document.querySelector('.pv2-code-window code')?.textContent?.length||0,
  meta:document.querySelector('.pv2-code-window .pv-live-code-meta')?.textContent||'',
}));
await page.evaluate(()=>{const el=document.querySelector('#credibility');el?.scrollIntoView({block:'center'});});
await page.waitForTimeout(250);
await page.locator('.pv2-credibility-grid button').nth(1).click();
await page.waitForTimeout(20);
const queued=await page.locator('.pv-runtime-console').textContent();
await page.waitForTimeout(130);
const executing=await page.locator('.pv-runtime-console').textContent();
await page.waitForTimeout(480);
const resolved=await page.locator('.pv-runtime-console').textContent();
const keyboard=[];
await page.evaluate(()=>scrollTo(0,0)); await page.waitForTimeout(100);
for(let i=0;i<12;i++){await page.keyboard.press('Tab');keyboard.push(await page.evaluate(()=>({tag:document.activeElement?.tagName||'',text:(document.activeElement?.textContent||'').replace(/\s+/g,' ').trim().slice(0,70),href:document.activeElement instanceof HTMLAnchorElement?document.activeElement.getAttribute('href'):null})));}
const report={generatedAt:new Date().toISOString(),initial,during,complete,runtime:{queued:queued?.replace(/\s+/g,' ').trim(),executing:executing?.replace(/\s+/g,' ').trim(),resolved:resolved?.replace(/\s+/g,' ').trim()},keyboard,errors,pageErrors,pass:initial.hardSectionRules===0&&initial.placeholderLinks.length===0&&during.developerRunning&&complete.developerComplete&&complete.developerLength>during.developerLength&&String(queued).includes('QUEUED')&&String(executing).includes('EXECUTING')&&String(resolved).includes('RESOLVED')&&errors.length===0&&pageErrors.length===0};
fs.writeFileSync(path.join(root,'evidence','r6-final','R6_LIVING_MOTION_AUDIT.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
await page.close(); await browser.close();
if(!report.pass) process.exitCode=1;
