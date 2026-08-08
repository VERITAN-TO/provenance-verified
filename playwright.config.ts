import { defineConfig, devices } from '@playwright/test';

const chromiumExecutable = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
// Explicitly forcing --use-gl=angle/--use-angle=swiftshader/--disable-gpu-sandbox was
// tried to make WebGL capability detection deterministic, but proved unnecessary (this
// environment's headless Chromium already resolves to SwiftShader with zero custom GL
// args — confirmed directly) and actively harmful: with --disable-gpu-sandbox set,
// Page.captureScreenshot fails outright ("Unable to capture screenshot"), reproduced on
// a plain non-WebGL page too, so it isn't specific to this app's WebGL scene. The app's
// own renderer-string detection (identity3d.ts) still resolves correctly against
// whatever real GL backend Chromium picks, with or without these flags.
const chromiumArgs = chromiumExecutable ? ['--no-sandbox'] : [];
const chromiumLaunchOptions = chromiumExecutable
  ? { executablePath: chromiumExecutable, args: chromiumArgs }
  : undefined;

export default defineConfig({
  testDir: './tests',
  testMatch: ['**/*.spec.ts'],
  timeout: 45_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  // Absorbs genuine occasional browser click/focus-timing jitter (WebKit in particular)
  // that survives after fixing the deterministic multi-second/multi-minute stalls this
  // suite was actually blocked on. A test that fails on every attempt still fails.
  retries: 2,
  reporter: [['html', { outputFolder: 'evidence/playwright-report', open: 'never' }], ['json', { outputFile: 'evidence/playwright-results.json' }]],
  use: { baseURL: 'http://127.0.0.1:3100', trace: 'retain-on-failure', video: chromiumExecutable ? 'off' : 'retain-on-failure', screenshot: 'only-on-failure' },
  webServer: { command: 'npm run dev -- --hostname 127.0.0.1 --port 3100', url: 'http://127.0.0.1:3100', reuseExistingServer: false, timeout: 120_000 },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'], launchOptions: chromiumLaunchOptions } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 7'], launchOptions: chromiumLaunchOptions } },
    { name: 'mobile-safari', use: { ...devices['iPhone 15'] } },
    { name: 'tablet', use: { viewport: { width: 1024, height: 768 }, launchOptions: chromiumLaunchOptions } },
    { name: 'desktop-wide', use: { viewport: { width: 1920, height: 1080 }, launchOptions: chromiumLaunchOptions } }
  ]
});
