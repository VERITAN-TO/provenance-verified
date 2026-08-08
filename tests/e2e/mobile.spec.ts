import { test, expect } from '@playwright/test';

test('mobile composition exposes navigation and primary proof task', async ({ page, isMobile }) => {
  test.skip(!isMobile, 'mobile project only');
  await page.goto('/');
  await expect(page.locator('h1#pv2-hero-title')).toBeVisible();
  await page.getByRole('button', { name: 'Menu' }).click();
  await expect(page.getByRole('navigation', { name: 'Primary navigation' })).toBeVisible();
  await page.getByRole('navigation', { name: 'Primary navigation' }).getByRole('link', { name: 'Registry', exact: true }).click();
  await expect(page).toHaveURL('/registry');
  await expect(page.getByRole('heading', { name: /Resolve issued credentials/ })).toBeVisible();
});
