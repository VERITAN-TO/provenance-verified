import fs from 'node:fs';
const proxy = fs.readFileSync('src/proxy.ts','utf8');
const config = fs.readFileSync('next.config.ts','utf8');
const exception = fs.readFileSync('governance/CSP_CONTROLLED_EXCEPTION.md','utf8');
const checks = [
  ['production script nonce', /script-src 'self' 'nonce-\$\{nonce\}' 'strict-dynamic'/.test(proxy)],
  ['unsafe eval sandbox-only', /mode === 'sandbox' \? " 'unsafe-eval'" : ''/.test(proxy)],
  ['no static unsafe eval CSP', !/script-src[^\n]*unsafe-eval/.test(config)],
  ['object denied', /object-src 'none'/.test(proxy)],
  ['frame ancestors denied', /frame-ancestors 'none'/.test(proxy)],
  ['base and form bounded', /base-uri 'self'/.test(proxy) && /form-action 'self'/.test(proxy)],
  ['HSTS', /Strict-Transport-Security/.test(config)],
  ['COOP', /Cross-Origin-Opener-Policy/.test(config)],
  ['CORP', /Cross-Origin-Resource-Policy/.test(config)],
  ['no DNS prefetch', /X-DNS-Prefetch-Control/.test(config)],
  ['controlled style exception recorded', exception.includes('three render-protected dynamic geometry attributes')],
  ['nonce forwarded to Next rendering', /requestHeaders\.set\('x-nonce', nonce\)/.test(proxy)],
  ['unknown environment rejected', /PV_ENVIRONMENT_INVALID/.test(proxy)],
];
const report={generatedAt:new Date().toISOString(),total:checks.length,passed:checks.filter(([,v])=>v).length,failed:checks.filter(([,v])=>!v).map(([name])=>name),checks:checks.map(([name,passed])=>({name,passed}))};
fs.mkdirSync('evidence/r3',{recursive:true});
fs.writeFileSync('evidence/r3/security-header-audit.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
if(report.failed.length) process.exit(1);
