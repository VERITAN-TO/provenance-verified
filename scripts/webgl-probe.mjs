import { chromium } from '@playwright/test';
const variants = [
  {name:'swiftshader-angle', args:['--no-sandbox','--disable-dev-shm-usage','--ignore-gpu-blocklist','--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']},
  {name:'swiftshader-gl', args:['--no-sandbox','--disable-dev-shm-usage','--ignore-gpu-blocklist','--enable-webgl','--use-gl=swiftshader','--enable-unsafe-swiftshader']},
  {name:'default-gpu', args:['--no-sandbox','--disable-dev-shm-usage','--ignore-gpu-blocklist','--enable-webgl']}
];
for (const v of variants) {
  let browser;
  try {
    browser = await chromium.launch({executablePath:'/usr/bin/chromium', headless:true, args:v.args});
    const page = await browser.newPage({viewport:{width:1440,height:1000}});
    const consoleErrors=[]; page.on('console', m=>{if(m.type()==='error') consoleErrors.push(m.text())});
    await page.goto('http://127.0.0.1:3100',{waitUntil:'networkidle'});
    await page.waitForTimeout(1500);
    const result = await page.evaluate(() => {
      const c = document.createElement('canvas');
      const gl2 = c.getContext('webgl2');
      const gl = gl2 || c.getContext('webgl');
      const dbg = gl?.getExtension('WEBGL_debug_renderer_info');
      return {
        webgl: Boolean(gl),
        webgl2: Boolean(gl2),
        renderer: gl && dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null,
        vendor: gl && dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : null,
        sceneCanvas: Boolean(document.querySelector('[data-testid="spatial-canvas"]')),
        fallback: Boolean(document.querySelector('[data-testid="spatial-fallback"]')),
      };
    });
    console.log(JSON.stringify({variant:v.name,...result,consoleErrors}));
    if (result.sceneCanvas) await page.screenshot({path:`evidence/browsers/system-chromium/webgl-${v.name}.png`,fullPage:false});
  } catch (e) {
    console.log(JSON.stringify({variant:v.name,error:String(e)}));
  } finally { if (browser) await browser.close(); }
}
