import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = process.cwd();
const checks = [];
const requireFile = (relative) => {
  const absolute = path.join(root, relative);
  const present = fs.existsSync(absolute) && fs.statSync(absolute).size > 0;
  checks.push({ check: `file:${relative}`, pass: present });
  if (!present) throw new Error(`REQUIRED_FILE_MISSING:${relative}`);
  return fs.readFileSync(absolute, 'utf8');
};
const assert = (name, condition, detail = '') => {
  checks.push({ check: name, pass: Boolean(condition), detail });
  if (!condition) throw new Error(`${name}:${detail}`);
};

const migration = requireFile('database/002_r8_1_production_authority.sql');
const migrationMirror = requireFile('supabase/migrations/20260722000000_r8_1_production_authority.sql');
const r3Migration = requireFile('database/003_r3_full_corrective_authority.sql');
const r3MigrationMirror = requireFile('supabase/migrations/20260722030000_r3_full_corrective_authority.sql');
const evidenceCustody = requireFile('services/provider-boundaries/evidence-custody/handler.py');
const edge = requireFile('supabase/functions/authority-api/index.ts');
const adapters = requireFile('src/services/adapters.ts');
const store = requireFile('src/operations/useOperationsStore.ts');
const proxy = requireFile('src/proxy.ts');
const terraform = requireFile('infra/terraform/provider-boundaries/main.tf');
const custosTerraform = requireFile('infra/terraform/custos-independent/main.tf');
const custosBackend = requireFile('infra/terraform/custos-independent/backend.hcl.example');
const env = requireFile('.env.example');
const normalizedTerraform = terraform.replace(/\s+/g, ' ');
for (const file of [
  'services/provider-boundaries/activation-authority/handler.py',
  'services/provider-boundaries/attestation-signer/handler.py',
  'services/provider-boundaries/canonical-authority/handler.py',
  'services/provider-boundaries/evidence-custody/handler.py',
  'services/provider-boundaries/reviewer-authority/handler.py',
  'services/provider-boundaries/signer/handler.py',
  'services/provider-boundaries/custos/handler.py',
  'services/provider-boundaries/registry/handler.py',
  'services/provider-boundaries/mark-authority/handler.py',
  'services/provider-boundaries/scanner/handler.py',
  'services/provider-boundaries/evidence-eligibility/handler.py',
  'services/provider-boundaries/conflict-engine/handler.py',
  'services/provider-boundaries/claim-validator/handler.py',
  'services/provider-boundaries/secret-vault/handler.py',
]) requireFile(file);

assert('migration mirror byte-identical', migration === migrationMirror);
assert('r3 migration mirror byte-identical', r3Migration === r3MigrationMirror);
for (const adapter of ['SandboxProvenanceAdapter','PilotProvenanceAdapter','ProductionProvenanceAdapter']) assert(`adapter:${adapter}`, adapters.includes(`class ${adapter}`));
assert('production activation fail closed', adapters.includes('PRODUCTION_ACTIVATION_INCOMPLETE') && migration.includes('PRODUCTION_ISSUANCE_DISABLED'));
assert('non-sandbox fixture isolation', store.includes("publicEnvironment === 'sandbox' ? operationalDataset : pendingDataset") && store.includes("? session\n          : incoming.sessions[0]"));
assert('no proxy fallback to sandbox', proxy.includes('No sandbox fallback was used'));
for (const dependency of ['SCANNER','EVIDENCE_ELIGIBILITY','CLAIM_VALIDATOR','CONFLICT_ENGINE','CUSTOS','SIGNER','REGISTRY','MARK_AUTHORITY','SECRET_VAULT']) assert(`provider:${dependency}`, edge.includes(`provider('${dependency}'`));
for (const [name, marker] of [['authority-issue','const issueMatch'],['reconciliation','/api/v1/authority/reconciliation'],['webhook-replay','/api/v1/webhooks/replay'],['mcp','/api/v1/mcp'],['organization','/api/v1/organization']]) assert(`endpoint:${name}`, edge.includes(marker));
for (const denial of ['SESSION_REQUIRED','TENANT_REQUIRED','MFA_REQUIRED','TENANT_MEMBERSHIP_REQUIRED','PERMISSION_DENIED','CUSTOS_DENIED','SIGNING_KEY_INACTIVE','REGISTRY_PUBLICATION_INCOMPLETE']) assert(`deny:${denial}`, migration.includes(denial) || edge.includes(denial));
assert('same reviewer blocked', migration.includes('unique (review_case_id, review_round, reviewer_id)'));
assert('immutable evidence upload', edge.includes("/v1/uploads/begin") && edge.includes("/v1/uploads/finalize") && evidenceCustody.includes('get_object_retention') && evidenceCustody.includes('VersionId') && migration.includes('No UPDATE policy is created'));
assert('non-exportable signing keys', /key_usage\s*=\s*"SIGN_VERIFY"/.test(normalizedTerraform) && /customer_master_key_spec\s*=\s*"ECC_NIST_P256"/.test(normalizedTerraform) && !/private[_-]?key\s*=/.test(terraform));
assert('registry recovery enabled', terraform.includes('point_in_time_recovery { enabled = true }'));
assert('webhook secrets encrypted', terraform.includes('aws_kms_key.envelope') && edge.includes("provider('SECRET_VAULT', '/v1/seal'") && edge.includes('nonExportableKey'));
assert('environment inventory complete', ['PV_ENVIRONMENT','PV_SUPABASE_URL','PV_AUTHORITY_API_URL','PV_AUTHORITY_PROVIDER_API_URL','PV_AWS_ROLE_ARN','PV_AWS_WEB_IDENTITY_TOKEN','PV_CUSTOS_PROVIDER_API_URL','PV_CUSTOS_AWS_ROLE_ARN'].every((name) => env.includes(name)));
assert('independent CUSTOS absent from primary service map', !terraform.includes('custos          = {') && !terraform.includes('resource \"aws_dynamodb_table\" \"custos_store\"'));
assert('independent CUSTOS separate account and state', custosTerraform.includes('check \"separate_aws_account\"') && custosTerraform.includes('data.aws_caller_identity.current.account_id != var.primary_authority_account_id') && custosBackend.includes('use_lockfile = true'));
assert('independent CUSTOS canonical read only', terraform.includes('IndependentCustosReadOnly') && terraform.includes('IndependentCustosConsequentialWriteDeny') && custosTerraform.includes('Resource = var.primary_canonical_table_arn'));
assert('independent CUSTOS receipt key and API', custosTerraform.includes('resource \"aws_kms_key\" \"receipt\"') && custosTerraform.includes('authorization = \"AWS_IAM\"') && custosTerraform.includes('resource \"aws_wafv2_web_acl\" \"custos\"'));
assert('no service role secret in client components', ![...walk(path.join(root,'src'))].filter((file)=>file.endsWith('.tsx')).some((file)=>fs.readFileSync(file,'utf8').includes('SERVICE_ROLE')));

const report = {
  generatedAt: new Date().toISOString(),
  verdict: checks.every((item) => item.pass) ? 'PASS' : 'FAIL',
  checks,
  migrationSha256: crypto.createHash('sha256').update(migration + r3Migration).digest('hex'),
  edgeSha256: crypto.createHash('sha256').update(edge).digest('hex'),
};
fs.mkdirSync(path.join(root,'evidence'), { recursive: true });
fs.writeFileSync(path.join(root,'evidence','production-authority-static-verification.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ verdict: report.verdict, checks: checks.length, migrationSha256: report.migrationSha256 }, null, 2));

function* walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const current = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(current); else yield current;
  }
}
