import { chromium } from '@playwright/test';
import fs from 'node:fs';
const out='evidence/phase3/browser';
fs.mkdirSync(out,{recursive:true});
const result={browser:'chromium',executablePath:'/usr/bin/chromium',url:'http://127.0.0.1:3413/',pass:false};
let browser;
try {
  browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const consoleErrors=[]; const pageErrors=[]; const failedRequests=[];
  page.on('console',m=>{if(m.type()==='error') consoleErrors.push(m.text())});
  page.on('pageerror',e=>pageErrors.push(String(e)));
  page.on('requestfailed',r=>failedRequests.push({url:r.url(),error:r.failure()?.errorText}));
  const response=await page.goto(result.url,{waitUntil:'networkidle',timeout:45000});
  result.status=response?.status() ?? null;
  result.title=await page.title();
  result.bodyText=(await page.locator('body').innerText()).slice(0,1000);
  result.consoleErrors=consoleErrors;
  result.pageErrors=pageErrors;
  result.failedRequests=failedRequests;
  result.viewport=await page.viewportSize();
  result.hasHero=await page.getByText('Trust, made verifiable.').count().catch(()=>0);
  result.hasTierChapter=await page.getByText('PROVENANCE VERIFIED™').count().catch(()=>0);
  await page.screenshot({path:`${out}/desktop-home.png`,fullPage:true});
  const mobile=await browser.newPage({viewport:{width:390,height:844},isMobile:true});
  await mobile.goto(result.url,{waitUntil:'networkidle',timeout:45000});
  await mobile.screenshot({path:`${out}/mobile-home.png`,fullPage:true});
  result.mobileScrollWidth=await mobile.evaluate(()=>({scrollWidth:document.documentElement.scrollWidth,clientWidth:document.documentElement.clientWidth}));
  result.pass=result.status===200 && result.pageErrors.length===0 && result.mobileScrollWidth.scrollWidth<=result.mobileScrollWidth.clientWidth;
} catch(e) {
  result.error=String(e?.stack||e);
} finally {
  if(browser) await browser.close();
}
fs.writeFileSync(`${out}/PLAYWRIGHT_SMOKE.json`,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
process.exit(result.pass?0:1);
