import { test, expect, type Page } from '@playwright/test';

// The dev server's HMR client can lose a race with rapid cross-route navigation
// (its own chunk reconnect request collides with the browser's navigation and gets
// cancelled — NS_BINDING_ABORTED in Firefox), aborting the navigation itself. This is
// dev-tooling network noise, not an application defect: retry the navigation once.
async function gotoResilient(page: Page, route: string) {
  try {
    return await page.goto(route, { waitUntil: 'domcontentloaded' });
  } catch (error) {
    if (error instanceof Error && /NS_BINDING_ABORTED|frame was detached/i.test(error.message)) {
      return await page.goto(route, { waitUntil: 'domcontentloaded' });
    }
    throw error;
  }
}

test('CaliberHomepage hero renders and proof transaction runs', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1#pv2-hero-title')).toBeVisible();
  await expect(page.getByText('TEST MODE').first()).toBeVisible();
  await page.getByRole('button', { name: /Run the proof transaction/i }).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/, { timeout: 10_000 });
});

test('verification stage rail updates accessible status on selection', async ({ page }, testInfo) => {
  await page.goto('/');
  await page.getByRole('button', { name: /Run the proof transaction/i }).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/, { timeout: 10_000 });
  // .pv2-stage-rail is intentionally display:none below 620px
  // (caliber-r2.css @media(max-width:620px)) — real responsive behavior, not a bug.
  // There is no mobile-viewport equivalent for manually re-selecting a stage.
  const viewportWidth = page.viewportSize()?.width ?? testInfo.project.use.viewport?.width ?? 1280;
  if (viewportWidth <= 620) return;
  const stageRail = page.getByRole('tablist', { name: 'Verification stages' });
  await expect(stageRail).toBeVisible();
  await stageRail.getByRole('tab').nth(1).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Stage 2 of 7/, { timeout: 5_000 });
});

test('evidence objects list is present and interactive', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: /Run the proof transaction/i }).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/, { timeout: 10_000 });
  const evidenceList = page.getByRole('listbox', { name: 'Evidence objects' });
  await expect(evidenceList).toBeVisible();
  await expect(evidenceList.getByRole('option').first()).toBeVisible();
});

test('lifecycle record examples update public record state', async ({ page }) => {
  await page.goto('/');
  const lifecycleNav = page.getByRole('tablist', { name: 'Lifecycle record examples' });
  await expect(lifecycleNav).toBeVisible();
  await lifecycleNav.getByRole('tab', { name: /suspended/i }).click();
  await expect(page.locator('[data-testid="accessible-status"]')).toContainText(/Verification completed/, { timeout: 8_000 });
});

test('verification and public registry deep link remain inspectable', async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('/verify');
  // Root-caused directly (instrumented the store's selectFixture to log its argument):
  // locator.fill() sets the DOM value and dispatches one 'input' event; on WebKit this can
  // resolve *before* React's synthetic value-tracking wrapper has committed the resulting
  // setId() state update, so a click issued immediately after can still run the click
  // handler's *previous* render's closure — resolve() then reads the stale (default) id and
  // silently re-selects the already-active fixture instead of the one just typed. Verified
  // by direct A/B: with .fill() this reproduced in 20/20 fresh WebKit contexts; switching to
  // real per-character key events (pressSequentially, which is how an actual user types)
  // reproduced in 0/20. Type it for real instead of racing the programmatic value setter.
  const idField = page.locator('#route-verify-id');
  await idField.click();
  await idField.selectText();
  await idField.pressSequentially('PV-TEST-RV1004', { delay: 5 });
  await page.getByRole('button', { name: 'Resolve record' }).click();
  const registryLink = page.getByRole('link', { name: 'Open registry record' });
  await expect(registryLink).toHaveAttribute('href', '/registry/PV-TEST-RV1004', { timeout: 30_000 });
  // WebKit specifically can lose a click issued right as React finishes a state update
  // (the anchor node gets replaced mid-click, so the click lands but nothing navigates).
  // Waiting for the URL and the click together, rather than sequentially, avoids the race.
  await Promise.all([
    page.waitForURL(/\/registry\/PV-TEST-RV1004/, { timeout: 30_000 }),
    registryLink.click(),
  ]);
  await expect(page.locator('.p3-record-statusbar').getByText('revoked')).toBeVisible({ timeout: 45_000 });
  await expect(page.locator('h1').first()).toContainText('PV-TEST-RV1004');
});

test('code examples and canonical machine response are rendered', async ({ page }, testInfo) => {
  await page.goto('/');
  await expect(page.getByRole('tablist', { name: 'Code examples' })).toBeVisible();
  // .pv2-object-response (the inline JSON preview) is intentionally display:none below
  // 1200px (caliber-r2.css @media(max-width:1200px)) — real responsive behavior, not a
  // bug. The same canonical record it previews is always reachable via "Open full
  // record", which is in a different, never-hidden section (.pv2-public-record-*) —
  // verify that equivalent access exists rather than just skipping the assertion.
  const viewportWidth = page.viewportSize()?.width ?? testInfo.project.use.viewport?.width ?? 1280;
  if (viewportWidth > 1200) {
    await expect(page.locator('[aria-label="Canonical machine response"]')).toBeVisible();
  } else {
    await expect(page.locator('[aria-label="Canonical machine response"]')).toBeHidden();
    await expect(page.getByRole('link', { name: /Open full record/i })).toBeVisible();
  }
});

test('credibility controls group is accessible', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('group', { name: 'Implemented credibility controls' })).toBeVisible();
});

test('all principal routes resolve without placeholder navigation', async ({ page }) => {
  test.setTimeout(600_000);
  for (const route of ['/verify','/registry','/provenance-verified','/developers','/docs','/docs/quickstart','/docs/api','/docs/sdk','/docs/mcp','/docs/webhooks','/docs/events','/docs/test-mode','/security','/trust','/status','/changelog','/access','/company','/contact','/sign-in','/legal/privacy','/legal/terms','/legal/certification-policy','/legal/evidence-policy','/legal/revocation-policy','/brand/trademark']) {
    const response = await gotoResilient(page, route);
    expect(response?.status(), route).toBeLessThan(400);
    await expect(page.locator('h1').first()).toBeVisible();
  }
});
