import fs from 'node:fs';
import { chromium } from '@playwright/test';
const browser=await chromium.connectOverCDP('http://127.0.0.1:9222');
const context=browser.contexts()[0];
const page=await context.newPage();
let navigationError=null;
try{await page.goto('http://127.0.0.1:4175/',{waitUntil:'domcontentloaded',timeout:15000});}catch(e){navigationError=String(e);}
const blockedUrl=page.url();
const blockedText=(await page.locator('body').textContent().catch(()=>''))?.slice(0,1000);
const policy=await context.newPage();
let policyError=null, policyText='';
try{await policy.goto('chrome://policy',{waitUntil:'domcontentloaded',timeout:15000});await policy.waitForTimeout(300);policyText=(await policy.locator('body').textContent().catch(()=>''))||'';}catch(e){policyError=String(e);}
const report={generatedAt:new Date().toISOString(),navigation:{error:navigationError,url:blockedUrl,body:blockedText},policy:{error:policyError,text:policyText.slice(0,20000)}};
fs.writeFileSync('evidence/rebuild-r3/browser-policy-block.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
await page.close(); await policy.close(); await browser.close();
