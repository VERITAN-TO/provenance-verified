import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const excluded = new Set(['node_modules', '.git', '.next', 'test-results']);
const files = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory() && excluded.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.json')) files.push(full);
  }
}
walk(root);
const errors = [];
for (const file of files) {
  try { JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (error) { errors.push({ file: path.relative(root, file), error: String(error) }); }
}
for (const file of ['evidence/browsers/system-chromium/webgl-probe.jsonl', 'evidence/webgl/system-webgl-probe.jsonl']) {
  if (!fs.existsSync(file)) continue;
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean);
  lines.forEach((line, index) => {
    try { JSON.parse(line); }
    catch (error) { errors.push({ file, line: index + 1, error: String(error) }); }
  });
}
const submission = JSON.parse(fs.readFileSync('SUBMISSION.json', 'utf8'));
const required = ['name','version','commit','build','workOrders','tests','browsers','identity','artifacts','knownLimitations','sha256'];
for (const key of required) if (!(key in submission)) errors.push({ file: 'SUBMISSION.json', error: `Missing required property ${key}` });
if (submission.name !== 'PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_BUILD_R2_NO_DEPLOYMENT_COMPLETE') errors.push({ file: 'SUBMISSION.json', error: 'name const mismatch' });
if (!['passed','failed'].includes(submission.build?.status)) errors.push({ file: 'SUBMISSION.json', error: 'invalid build.status' });
if (!Array.isArray(submission.workOrders) || submission.workOrders.length < 28) errors.push({ file: 'SUBMISSION.json', error: 'workOrders must have at least 28 items' });
for (const item of submission.workOrders ?? []) {
  if (!item.id || !['passed','failed','blocked'].includes(item.status) || !Array.isArray(item.evidence)) {
    errors.push({ file: 'SUBMISSION.json', error: `invalid work order entry ${JSON.stringify(item)}` });
  }
}
const report = {
  generatedAt: new Date().toISOString(),
  strategy: 'JSON.parse for all submitted JSON/JSONL plus direct enforcement of 10_SUBMISSION_PROTOCOL/03_SUBMISSION.schema.json required fields, const, enums, and minimum work-order count',
  filesValidated: files.length,
  submissionWorkOrders: submission.workOrders?.length ?? 0,
  errors,
  status: errors.length === 0 ? 'passed' : 'failed',
};
fs.mkdirSync('evidence/build', { recursive: true });
fs.writeFileSync('evidence/build/json-validation.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
if (errors.length) process.exit(1);
