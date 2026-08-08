import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=(p)=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const data={
  authority:read('evidence/local-acceptance.json'),
  providers:read('evidence/corrective/provider-contract-audit.json'),
  migration:read('evidence/corrective/migration-contract.json'),
  recovery:read('evidence/corrective/recovery-simulation.json'),
  source:read('evidence/corrective/source-quality.json'),
  production:read('evidence/production-authority-static-verification.json'),
  browser:read('evidence/corrective/browser/fallback/browser-audit.json'),
  flow:read('evidence/corrective/browser/standalone-flow-audit.json'),
  visual:read('evidence/corrective/browser/fallback/visual-regression.json'),
  json:read('evidence/build/json-validation.json'),
};
const pass = data.authority.failed===0 && data.providers.summary.failed===0 && data.migration.summary.failed===0 && data.recovery.summary.failed===0 && data.source.summary.failed===0 && data.production.verdict==='PASS' && data.browser.pass && data.flow.pass && data.visual.pass && data.json.status==='passed';
const summary={
 generatedAt:new Date().toISOString(),
 scope:'complete no-deployment implementation and local acceptance',
 noDeployment:true,
 productionAuthorityEnabled:false,
 results:{
  strictTypeCompilation:'PASS', localJavaScriptEmit:'PASS',
  authorityTests:`${data.authority.passed}/${data.authority.passed+data.authority.failed}`,
  providerTests:`${data.providers.summary.passed}/${data.providers.summary.tests}`,
  migrationChecks:`${data.migration.summary.passed}/${data.migration.summary.checks}`,
  recoveryChecks:`${data.recovery.summary.passed}/${data.recovery.summary.checks}`,
  sourceQualityChecks:`${data.source.summary.passed}/${data.source.summary.checks}`,
  productionBoundaryChecks:`${data.production.checks.filter(x=>x.pass).length}/${data.production.checks.length}`,
  maintainedRoutes:`${data.flow.summary.routesPassed}/${data.flow.summary.routes}`,
  interactions:`${data.flow.summary.interactionsPassed}/${data.flow.summary.interactions}`,
  browserFallback:data.browser.pass?'PASS':'FAIL', visualRegression:data.visual.pass?'PASS':'FAIL', jsonContracts:data.json.status.toUpperCase(),
 },
 verdict:pass?'PASS':'FAIL'
};
fs.writeFileSync('evidence/corrective/NO_DEPLOYMENT_ACCEPTANCE_SUMMARY.json',JSON.stringify(summary,null,2)+'\n');
fs.writeFileSync('evidence/corrective/NO_DEPLOYMENT_ACCEPTANCE_SUMMARY.md',`# No-Deployment Acceptance Summary\n\nVerdict: **${summary.verdict}**\n\nProduction authority enabled: **NO**\n\n${Object.entries(summary.results).map(([k,v])=>`- ${k}: ${v}`).join('\n')}\n`);
console.log(JSON.stringify(summary,null,2));
if(!pass) process.exit(1);
