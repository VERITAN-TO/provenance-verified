import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

for (const route of ['/', '/verify', '/registry', '/docs', '/security']) {
  test(`axe critical scan ${route}`, async ({ page }) => {
    await page.goto(route);
    const results = await new AxeBuilder({ page }).withTags(['wcag2a','wcag2aa','wcag21aa','wcag22aa']).analyze();
    const critical = results.violations.filter((v) => v.impact === 'critical' || v.impact === 'serious');
    expect(critical, JSON.stringify(critical, null, 2)).toEqual([]);
  });
}

test('primary journey is keyboard operable', async ({ page, browserName }) => {
  await page.goto('/');
  // WebKit's default Tab order only includes form controls, not plain <a> links —
  // matches real desktop Safari with "Full Keyboard Access" off, where Option+Tab
  // (not Tab) is how links join the keyboard traversal order. Confirmed by direct
  // reproduction: plain Tab lands on the first checkbox; Alt+Tab reaches the skip
  // link. This exercises the real, platform-correct keyboard path for WebKit rather
  // than skipping the assertion.
  await page.keyboard.press(browserName === 'webkit' ? 'Alt+Tab' : 'Tab');
  await expect(page.locator('.skip-link')).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main-content')).toBeInViewport();
  const primaryBtn = page.getByRole('button', { name: /Run the proof transaction/i });
  await primaryBtn.focus();
  await expect(primaryBtn).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/, { timeout: 10_000 });
});
