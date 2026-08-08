import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

test('capture desktop visual evidence', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'single canonical capture');
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/');
  await page.screenshot({ path: 'evidence/visual/home-desktop.png', fullPage: true });
  await page.getByRole('button', { name: /Run the proof transaction/i }).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/);
  await page.screenshot({ path: 'evidence/visual/home-desktop-complete.png', fullPage: true });
  await page.goto('/registry/PV-TEST-T4D004');
  await page.screenshot({ path: 'evidence/visual/registry-record.png', fullPage: true });
  expect(fs.existsSync(path.resolve('evidence/visual/home-desktop.png'))).toBe(true);
});

test('capture mobile visual evidence', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'mobile-chrome', 'single canonical mobile capture');
  await page.goto('/');
  await page.screenshot({ path: 'evidence/devices/android-chrome-emulation.png', fullPage: true });
});
