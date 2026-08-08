import fs from 'node:fs';
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const html = fs.readFileSync('/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_STANDALONE_R3.html', 'utf8');
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const context = browser.contexts()[0];
const page = await context.newPage();
const consoleErrors=[]; const pageErrors=[];
page.on('console', m => { if(m.type()==='error') consoleErrors.push(m.text()); });
page.on('pageerror', e => pageErrors.push(String(e)));
await page.setViewportSize({ width: 1440, height: 900 });
await page.setContent(html, { waitUntil: 'load' });
await page.waitForTimeout(400);
const axe = await new AxeBuilder({ page }).analyze();
const desktop = await page.evaluate(() => ({
  title: document.title,
  h1: document.querySelector('h1')?.textContent?.replace(/\s+/g,' ').trim(),
  links: document.querySelectorAll('a[href]').length,
  buttons: document.querySelectorAll('button').length,
  duplicateIds: [...document.querySelectorAll('[id]')].map(e=>e.id).filter((id,i,a)=>a.indexOf(id)!==i),
  horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  fallbackVisible: !!document.querySelector('.spatial-static-base') && getComputedStyle(document.querySelector('.spatial-static-base')).display !== 'none',
  canvases: document.querySelectorAll('canvas').length,
  externalRequests: performance.getEntriesByType('resource').filter(r => /^https?:/.test(r.name)).map(r=>r.name),
}));

const tabs=[];
for(let i=0;i<20;i++){
  await page.keyboard.press('Tab');
  tabs.push(await page.evaluate(() => {
    const e=document.activeElement;
    return { tag:e?.tagName, text:(e?.getAttribute('aria-label')||e?.textContent||'').replace(/\s+/g,' ').trim().slice(0,80), href:e?.getAttribute('href')||null };
  }));
}

await page.emulateMedia({ reducedMotion: 'reduce' });
const reduced = await page.evaluate(() => ({
  beamDisplay: getComputedStyle(document.querySelector('.pv2-hero-beam')).display,
  animatedCount: [...document.querySelectorAll('*')].filter(e => {
    const s=getComputedStyle(e); return s.animationName && s.animationName !== 'none' && parseFloat(s.animationDuration)>0;
  }).length,
}));

await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(200);
const mobile = await page.evaluate(() => ({
  horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  menuButtonVisible: (()=>{const e=document.querySelector('.pv2-menu-button'); return e && getComputedStyle(e).display !== 'none';})(),
  h1FontSize: getComputedStyle(document.querySelector('h1')).fontSize,
  bodyHeight: document.body.scrollHeight,
}));

const report={
  generatedAt:new Date().toISOString(),
  axe:{violations:axe.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length,help:v.help})), count:axe.violations.length},
  desktop,mobile,reduced,tabs,consoleErrors,pageErrors
};
fs.writeFileSync('/mnt/data/PROVENANCE_CX_NEWLY_REBUILT_R3_BROWSER_AUDIT.json', JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
await page.close();
await browser.close();
