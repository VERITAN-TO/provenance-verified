import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const htmlPath = path.join(root, 'review', 'PROVENANCE_CX_UNIFIED_FOUR_LAYER_R6_LIVING_STANDALONE.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const evidence = path.join(root, 'evidence', 'r6');
fs.mkdirSync(evidence, { recursive: true });
const browser = await chromium.connectOverCDP('http://127.0.0.1:9333');
const context = browser.contexts()[0];
const page = await context.newPage();
const consoleErrors = []; const pageErrors = [];
page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()); });
page.on('pageerror', (error) => pageErrors.push(String(error)));
await page.setViewportSize({ width: 1512, height: 982 });
await page.setContent(html, { waitUntil: 'load' });
await page.waitForTimeout(1200);

const webgl = await page.evaluate(() => {
  const canvas = document.querySelector('.spatial-host canvas');
  if (!(canvas instanceof HTMLCanvasElement)) return { canvas: false, context: null, fallback: !!document.querySelector('.spatial-static-base') };
  const context = canvas.getContext('webgl2') || canvas.getContext('webgl');
  return { canvas: true, context: context ? (context instanceof WebGL2RenderingContext ? 'webgl2' : 'webgl') : null, fallback: !!document.querySelector('.spatial-static-base') && getComputedStyle(document.querySelector('.spatial-static-base')).display !== 'none' };
});

await page.screenshot({ path: path.join(evidence, 'R6_DESKTOP_FULL.png'), fullPage: true });

// Exercise every homepage tab/button family.
const buttonGroups = [
  '.pv2-stage-rail button',
  '.pv2-evidence-list button',
  '.pv2-lifecycle-nav button',
  '.pv2-credibility-grid button',
  '.pv2-code-window [role="tab"]',
];
const groupResults = {};
for (const selector of buttonGroups) {
  const count = await page.locator(selector).count();
  let clicked = 0;
  for (let i = 0; i < count; i++) {
    const item = page.locator(selector).nth(i);
    await item.scrollIntoViewIfNeeded();
    await item.click();
    await page.waitForTimeout(110);
    clicked++;
  }
  groupResults[selector] = { count, clicked };
}

await page.locator('#credibility').scrollIntoViewIfNeeded();
await page.waitForTimeout(1400);
const credibility = await page.evaluate(() => ({
  cards: document.querySelectorAll('.pv2-credibility-grid button').length,
  active: document.querySelectorAll('.pv2-credibility-grid button.is-active').length,
  receipt: document.querySelector('.pv2-control-receipt code')?.textContent?.trim().slice(0, 160) || '',
  receiptComplete: document.querySelector('.pv2-control-receipt .pv-live-code')?.classList.contains('is-complete') || false,
}));
await page.screenshot({ path: path.join(evidence, 'R6_CREDIBILITY_CONTROL.png') });

await page.locator('.pv2-developer').scrollIntoViewIfNeeded();
await page.waitForTimeout(1600);
const developer = await page.evaluate(() => ({
  activeTab: document.querySelector('.pv2-code-window [role="tab"][aria-selected="true"]')?.textContent,
  codeLength: document.querySelector('.pv2-code-window code')?.textContent?.length || 0,
  complete: document.querySelector('.pv2-code-window .pv-live-code')?.classList.contains('is-complete') || false,
}));
await page.screenshot({ path: path.join(evidence, 'R6_DEVELOPER_LIVE_CODE.png') });

const runtimeConsole = await page.evaluate(() => ({
  exists: !!document.querySelector('.pv-runtime-console'),
  active: document.querySelector('.pv-runtime-console')?.classList.contains('is-active') || false,
  text: document.querySelector('.pv-runtime-console')?.textContent?.replace(/\s+/g, ' ').trim().slice(0, 200),
}));

const routes = [...new Set(await page.locator('a[href^="#/"]').evaluateAll((links) => links.map((link) => link.getAttribute('href')).filter(Boolean)))];
const routeResults = [];
for (const hash of routes) {
  await page.evaluate((value) => { window.location.hash = value.slice(1); window.dispatchEvent(new Event('pv:navigate')); }, hash);
  await page.waitForTimeout(120);
  const result = await page.evaluate(() => ({ h1: document.querySelector('h1')?.textContent?.replace(/\s+/g, ' ').trim() || '', notFound: document.body.textContent?.includes('Review route not found.') || false }));
  routeResults.push({ hash, ...result });
}

// Restore home and accessibility audit.
await page.evaluate(() => { window.location.hash = '/'; window.dispatchEvent(new Event('pv:navigate')); });
await page.waitForTimeout(500);
const axe = await new AxeBuilder({ page }).analyze();
const desktop = await page.evaluate(() => ({
  title: document.title,
  h1: document.querySelector('h1')?.textContent?.replace(/\s+/g, ' ').trim(),
  horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  sectionHardRules: [...document.querySelectorAll('.pv2-section')].filter((section) => parseFloat(getComputedStyle(section).borderBottomWidth) > 0).length,
  internalLinks: document.querySelectorAll('a[href^="#/"]').length,
  buttons: document.querySelectorAll('button').length,
  externalResources: performance.getEntriesByType('resource').filter((entry) => /^https?:/.test(entry.name)).map((entry) => entry.name),
}));

await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(400);
await page.screenshot({ path: path.join(evidence, 'R6_MOBILE_FULL.png'), fullPage: true });
const mobile = await page.evaluate(() => ({
  horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  menuVisible: getComputedStyle(document.querySelector('.pv2-menu-button')).display !== 'none',
  credibilityColumns: getComputedStyle(document.querySelector('.pv2-credibility-grid')).gridTemplateColumns,
  bodyHeight: document.body.scrollHeight,
}));

await page.emulateMedia({ reducedMotion: 'reduce' });
await page.reload({ waitUntil: 'load' }).catch(() => {});
// setContent after reload because this is a data document.
await page.setContent(html, { waitUntil: 'load' });
await page.waitForTimeout(250);
const reducedMotion = await page.evaluate(() => ({
  animatedElements: [...document.querySelectorAll('*')].filter((element) => {
    const style = getComputedStyle(element); return style.animationName !== 'none' && parseFloat(style.animationDuration) > 0.02;
  }).length,
  heroBeam: getComputedStyle(document.querySelector('.pv2-hero-beam')).display,
}));

const report = {
  generatedAt: new Date().toISOString(), htmlPath, webgl, groupResults, credibility, developer, runtimeConsole,
  routes: { count: routeResults.length, failures: routeResults.filter((route) => route.notFound), results: routeResults },
  axe: { count: axe.violations.length, violations: axe.violations.map((item) => ({ id: item.id, impact: item.impact, nodes: item.nodes.length, help: item.help })) },
  desktop, mobile, reducedMotion, consoleErrors, pageErrors,
};
fs.writeFileSync(path.join(evidence, 'R6_VISUAL_FUNCTIONAL_AUDIT.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
await page.close();
await browser.close();
