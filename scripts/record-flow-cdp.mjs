import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const framesDir = '/tmp/prov-screencast';
const browser = await chromium.launch({
  executablePath: '/usr/bin/chromium',
  headless: true,
  args: ['--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--disable-software-rasterizer','--disable-crash-reporter','--disable-breakpad','--no-first-run','--no-default-browser-check'],
});
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage();
const cdp = await context.newCDPSession(page);
let frame = 0;
let recording = true;
cdp.on('Page.screencastFrame', async ({ data, sessionId }) => {
  if (recording) {
    const name = String(frame++).padStart(6, '0') + '.jpg';
    fs.writeFileSync(path.join(framesDir, name), Buffer.from(data, 'base64'));
  }
  await cdp.send('Page.screencastFrameAck', { sessionId });
});
await page.goto('http://127.0.0.1:3100', { waitUntil: 'networkidle', timeout: 60000 });
await page.getByRole('heading', { level: 1, name: 'Trust infrastructure for AI.' }).waitFor();
await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 75, maxWidth: 1280, maxHeight: 720, everyNthFrame: 1 });
const pause = (ms=700) => page.waitForTimeout(ms);
await pause(1200);
await page.getByRole('button', { name: /Run verification/i }).click();
await page.locator('[data-testid="accessible-status"]').filter({ hasText: /Verification completed/ }).waitFor({ timeout: 10000 }).catch(()=>{});
await pause(1800);
await page.getByRole('heading', { name: 'Certification is a deterministic policy result.' }).scrollIntoViewIfNeeded();
await pause(1000);
await page.getByRole('button', { name: /Tier 3/i }).first().click();
await pause(1000);
await page.getByRole('heading', { name: 'Every claim remains inspectable.' }).scrollIntoViewIfNeeded();
await pause(1000);
await page.getByRole('heading', { name: 'Publication has signed, observable consequences.' }).scrollIntoViewIfNeeded();
await pause(1000);
const failedCard = page.locator('.webhook-inspector article').filter({ hasText: 'wh_01' });
await failedCard.getByRole('button', { name: 'Retry' }).click();
await pause(500);
await failedCard.getByRole('button', { name: 'Manual replay' }).click();
await pause(1000);
await page.getByRole('heading', { name: 'Trust remains governable after issuance.' }).scrollIntoViewIfNeeded();
await page.locator('.lifecycle-orbit > button', { hasText: 'suspended' }).click();
await pause(1200);
await page.getByRole('heading', { name: 'Authority and boundaries are public.' }).scrollIntoViewIfNeeded();
await pause(1000);
await page.goto('http://127.0.0.1:3100/registry/PV-TEST-T4D004', { waitUntil: 'networkidle' });
await pause(1400);
recording = false;
await cdp.send('Page.stopScreencast');
await browser.close();
fs.writeFileSync('evidence/recordings/cdp-recording-metadata.json', JSON.stringify({ frameCount: frame, viewport: { width: 1280, height: 720 }, browser: 'System Chromium 144', mode: 'TEST MODE / NON-AUTHORITATIVE / NOT A PRODUCTION CREDENTIAL', flow: ['hero','verification','tier change','claim resolution','webhook retry','manual replay','lifecycle change','registry record'] }, null, 2));
console.log(frame);
