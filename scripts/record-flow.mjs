import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const outDir = path.resolve('evidence/recordings');
fs.mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch({
  executablePath: '/usr/bin/chromium',
  headless: true,
  args: [
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-software-rasterizer',
    '--disable-crash-reporter',
    '--disable-breakpad',
    '--no-first-run',
    '--no-default-browser-check',
  ],
});
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  recordVideo: { dir: outDir, size: { width: 1440, height: 900 } },
});
const page = await context.newPage();
await page.goto('http://127.0.0.1:3100', { waitUntil: 'networkidle' });
await page.getByRole('heading', { level: 1, name: 'Trust infrastructure for AI.' }).waitFor();
await page.waitForTimeout(900);
await page.getByRole('button', { name: /Run verification/i }).click();
await page.locator('[data-testid="accessible-status"]').waitFor();
await page.waitForTimeout(1900);
await page.getByRole('heading', { name: 'Certification is a deterministic policy result.' }).scrollIntoViewIfNeeded();
await page.waitForTimeout(900);
await page.getByRole('button', { name: /Tier 3/i }).first().click();
await page.waitForTimeout(900);
await page.getByRole('heading', { name: 'Every claim remains inspectable.' }).scrollIntoViewIfNeeded();
await page.waitForTimeout(900);
await page.getByRole('heading', { name: 'Publication has signed, observable consequences.' }).scrollIntoViewIfNeeded();
await page.waitForTimeout(900);
const failedCard = page.locator('.webhook-inspector article').filter({ hasText: 'wh_01' });
await failedCard.getByRole('button', { name: 'Retry' }).click();
await failedCard.getByRole('button', { name: 'Manual replay' }).click();
await page.waitForTimeout(900);
await page.getByRole('heading', { name: 'Trust remains governable after issuance.' }).scrollIntoViewIfNeeded();
await page.locator('.lifecycle-orbit > button', { hasText: 'suspended' }).click();
await page.waitForTimeout(900);
await page.getByRole('heading', { name: 'Authority and boundaries are public.' }).scrollIntoViewIfNeeded();
await page.waitForTimeout(900);
await page.goto('http://127.0.0.1:3100/registry/PV-TEST-T4D004', { waitUntil: 'networkidle' });
await page.waitForTimeout(1200);
const video = page.video();
await page.close();
await context.close();
await browser.close();
if (!video) throw new Error('Video recording was not created.');
const recordedPath = await video.path();
const target = path.join(outDir, 'complete-vertical-proof-flow.webm');
fs.copyFileSync(recordedPath, target);
fs.writeFileSync(path.join(outDir, 'recording-metadata.json'), JSON.stringify({
  file: 'complete-vertical-proof-flow.webm',
  browser: 'System Chromium 144',
  viewport: { width: 1440, height: 900 },
  flow: ['hero', 'verification', 'tier change', 'claim resolution', 'webhook retry', 'manual replay', 'lifecycle suspension', 'registry record'],
  mode: 'TEST MODE / NON-AUTHORITATIVE / NOT A PRODUCTION CREDENTIAL',
}, null, 2));
console.log(target);
