import fs from 'node:fs';
const sql=fs.readFileSync('database/005_r3_freshness_regression.sql','utf8');
const mirror=fs.readFileSync('supabase/migrations/20260722050000_r3_freshness_regression.sql','utf8');
const worker=fs.readFileSync('supabase/functions/freshness-worker/index.ts','utf8');
const cron=fs.readFileSync('DEPLOYMENT/SUPABASE_FRESHNESS_CRON.sql.template','utf8');
const checks=[
 ['migration mirrored byte-identical',sql===mirror],
 ['append-only evaluations',sql.includes('pv_freshness_findings_immutable')],
 ['runtime claim expiry',sql.includes('CLAIM_OR_EVIDENCE_NOT_CURRENT')],
 ['waiver expiry',sql.includes('WAIVER_EXPIRED')],
 ['key expiry',sql.includes('AUTHORITY_KEY_NOT_ELIGIBLE')],
 ['access review expiry',sql.includes('ACCESS_REVIEW_OVERDUE')],
 ['public claim expiry',sql.includes('PUBLIC_CLAIM_EXPIRED')],
 ['knowledge freshness',sql.includes('KNOWLEDGE_REVIEW_OR_EXPIRY_DUE')],
 ['contract expiry',sql.includes('CONTRACT_AUTHORITY_EXPIRED')],
 ['break-glass expiry',sql.includes('BREAK_GLASS_LEASE_EXPIRED')],
 ['resolution events retained',sql.includes("'FRESHNESS_RESTORED','resolved'")],
 ['launch hard-block trigger',sql.includes('PV_LAUNCH_BLOCKED_BY_STALE_EVIDENCE')],
 ['scheduled worker authenticated',worker.includes('workload_identity_required') && worker.includes('SUPABASE_SERVICE_ROLE_KEY')],
 ['timestamp and nonce checked',worker.includes('schedule_timestamp_invalid') && worker.includes('x-pv-nonce')],
 ['five-minute schedule',cron.includes("'*/5 * * * *'")],
 ['vault-managed schedule secrets',cron.includes('vault.decrypted_secrets')],
];
const report={generatedAt:new Date().toISOString(),total:checks.length,passed:checks.filter(([,v])=>v).length,failed:checks.filter(([,v])=>!v).map(([n])=>n),checks:checks.map(([name,passed])=>({name,passed}))};
fs.mkdirSync('evidence/r3',{recursive:true});fs.writeFileSync('evidence/r3/freshness-regression-audit.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));if(report.failed.length)process.exit(1);
