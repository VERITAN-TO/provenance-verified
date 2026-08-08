import fs from 'node:fs';
const proxy=fs.readFileSync('src/proxy.ts','utf8');
const cookies=fs.readFileSync('src/authority/cookies.ts','utf8');
const policy=fs.readFileSync('governance/BROWSER_COMMAND_SECURITY_POLICY.md','utf8');
const checks=[
  ['cross-site Fetch Metadata denied',proxy.includes("fetchSite==='cross-site'")],
  ['origin mismatch denied',proxy.includes('origin!==request.nextUrl.origin')],
  ['cookie command requires origin',proxy.includes('cookieAuthenticated && !origin')],
  ['safe methods exempt',proxy.includes("['GET','HEAD','OPTIONS']")],
  ['machine bearer remains separate',policy.includes('scoped bearer credentials')],
  ['Pilot Production secure cookies',cookies.includes("['pilot','production'].includes")],
  ['HttpOnly cookies',cookies.includes('httpOnly: true')],
  ['SameSite defense',cookies.includes("sameSite: 'lax'")],
  ['fail closed 403',proxy.includes('browser_command_origin_denied')&&proxy.includes('{ status: 403 }')],
];
const report={generatedAt:new Date().toISOString(),total:checks.length,passed:checks.filter(([,v])=>v).length,failed:checks.filter(([,v])=>!v).map(([n])=>n),checks:checks.map(([name,passed])=>({name,passed}))};
fs.mkdirSync('evidence/r3',{recursive:true});fs.writeFileSync('evidence/r3/browser-command-security-audit.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));if(report.failed.length)process.exit(1);
