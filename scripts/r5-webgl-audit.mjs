import { chromium } from '@playwright/test';
import { readFile, writeFile, mkdir } from 'node:fs/promises';

const html = await readFile('review/PROVENANCE_CX_UNIFIED_FOUR_LAYER_R5_STANDALONE.html', 'utf8');
await mkdir('evidence/r5', { recursive: true });
const result = { pass: false, browser: 'Chromium headed', context: null, frames: null, stateTransition: null, reducedMotion: null, fallbackCount: null, consoleErrors: [], pageErrors: [] };
let browser;
try {
  browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: false, args: ['--no-sandbox','--disable-dev-shm-usage','--ignore-gpu-blocklist','--use-gl=angle','--use-angle=gl','--disable-vulkan','--disable-gpu-shader-disk-cache'] });
  const page = await browser.newPage({ viewport: { width: 1100, height: 760 }, reducedMotion: 'no-preference' });
  page.on('console', message => { if (message.type() === 'error') result.consoleErrors.push(message.text()); });
  page.on('pageerror', error => result.pageErrors.push(error.message));
  await page.setContent(html, { waitUntil: 'domcontentloaded', timeout: 10_000 });
  await page.waitForTimeout(900);
  const payload = await page.evaluate(async () => {
    const canvas = document.querySelector('canvas[data-testid="spatial-canvas"]');
    if (!canvas) return { error: 'live canvas absent' };
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return { error: 'webgl context absent' };
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    const first = Number(canvas.dataset.renderedFrames || 0);
    await new Promise(resolve => setTimeout(resolve, 120));
    const second = Number(canvas.dataset.renderedFrames || 0);
    const environment = document.querySelector('.spatial-environment');
    const initial = environment?.getAttribute('data-state');
    const stageButtons = [...document.querySelectorAll('.pv2-stage-rail button')];
    stageButtons.at(-1)?.click();
    const reduced = [...document.querySelectorAll('label')].find(label => label.textContent?.includes('Reduced motion'))?.querySelector('input[type="checkbox"]');
    if (reduced && !reduced.checked) reduced.click();
    await new Promise(resolve => requestAnimationFrame(() => resolve()));
    return {
      context: {
        version: gl.getParameter(gl.VERSION),
        vendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
        renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
        drawingBuffer: [gl.drawingBufferWidth, gl.drawingBufferHeight],
      },
      frames: { first, second, advanced: second > first },
      stateTransition: { initial, final: environment?.getAttribute('data-state'), passed: initial === 'observe' && environment?.getAttribute('data-state') === 'secure' },
      reducedMotion: document.querySelector('.spatial-host')?.getAttribute('data-reduced-motion'),
      fallbackCount: document.querySelectorAll('[data-testid="spatial-fallback"]').length,
    };
  });
  if (payload.error) throw new Error(payload.error);
  Object.assign(result, payload);
  result.pass = Boolean(result.context && result.frames?.advanced && result.stateTransition?.passed && result.reducedMotion === 'true' && result.fallbackCount === 0 && !result.consoleErrors.length && !result.pageErrors.length);
} catch (error) {
  result.error = error instanceof Error ? error.message : String(error);
} finally {
  try { await browser?.close(); } catch {}
  await writeFile('evidence/r5/webgl-audit.json', `${JSON.stringify(result, null, 2)}\n`);
}
console.log(JSON.stringify(result, null, 2));
if (!result.pass) process.exitCode = 1;
