import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
await mkdir('evidence/phase4/browser', { recursive: true });
const report = { status: 'BLOCKED', url: 'http://127.0.0.1:3000/app', browser: '/usr/bin/chromium', error: null, screenshots: [] };
let browser;
try {
  browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await page.goto(report.url, { waitUntil: 'networkidle', timeout: 20000 });
  await page.screenshot({ path: 'evidence/phase4/browser/operations-desktop.png', fullPage: true });
  const title = await page.locator('h1').first().textContent();
  const links = await page.locator('a').count();
  report.status = title?.includes('Jeweler command center') ? 'PASS' : 'FAIL';
  report.title = title;
  report.links = links;
  report.screenshots.push('operations-desktop.png');
} catch (error) {
  report.error = error instanceof Error ? error.message : String(error);
} finally {
  if (browser) await browser.close();
}
await writeFile('evidence/phase4/browser/BROWSER_SMOKE.json', JSON.stringify(report, null, 2) + '\n');
await writeFile('evidence/phase4/browser/README.md', `# Phase 4 browser gate\n\nStatus: **${report.status}**\n\nTarget: \`${report.url}\`\n\n${report.error ? `The installed managed Chromium blocked or failed before application acceptance:\n\n\`\`\`text\n${report.error}\n\`\`\`\n` : 'The operational command page loaded and a screenshot was captured.'}\n`);
console.log(JSON.stringify(report, null, 2));
process.exit(report.status === 'PASS' ? 0 : 2);
