import { chromium } from '@playwright/test';
const browser=await chromium.connectOverCDP('http://127.0.0.1:9223');
const page=await browser.contexts()[0].newPage();
await page.setContent('<!doctype html><html><body><canvas id="c"></canvas></body></html>');
const result=await page.evaluate(()=>{
  const c=document.getElementById('c');
  const gl2=c.getContext('webgl2');
  const gl=gl2||c.getContext('webgl')||c.getContext('experimental-webgl');
  if(!gl) return {available:false};
  const dbg=gl.getExtension('WEBGL_debug_renderer_info');
  return {available:true,version:gl.getParameter(gl.VERSION),renderer:dbg?gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),vendor:dbg?gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL):gl.getParameter(gl.VENDOR)};
});
console.log(JSON.stringify(result,null,2));
await page.close(); await browser.close();
