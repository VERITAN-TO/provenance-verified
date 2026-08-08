import fs from 'node:fs';
import crypto from 'node:crypto';
import childProcess from 'node:child_process';

const BASE = '10d95ebbd90f1e489efd859987cfaeafb3a5a6fc';
const A1 = '79204ec9733062725aaf0e0d6cdfe560cb4a9444';
const A1_PARENT = BASE;
const A1_BUNDLE_SHA256 = 'ee7faa28b7c8757ee4712f37aee05366d5de0dcd52fc9559c228eaf94015d23d';
const LOCK_SHA256 = 'c313eedd8a9695b27f2bfff37c0834b64fd32263e653fbf073b1900f112053da';
const A1_BUNDLE_PATH = process.env.A1_BUNDLE_PATH || 'evidence/wave1-slice1/a1-source.bundle';
const routes = [
  'src/app/api/v1/auth/sign-in/route.ts',
  'src/app/api/v1/auth/session/route.ts',
  'src/app/api/v1/operations/session/route.ts',
];
const adapter = 'src/authority/a1-wave1-rpc-adapter.ts';
const results = [];
const text = (path) => fs.readFileSync(path, 'utf8');
const run = (args) => childProcess.execFileSync('git', args, { encoding: 'utf8' }).trim();
const hash = (path) => crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
function check(id, pass, detail) {
  results.push({ id, pass: Boolean(pass), detail: String(detail) });
  console.log(`${pass ? 'PASS' : 'FAIL'} ${id} ${detail}`);
}
function commandPass(args) {
  try { childProcess.execFileSync('git', args, { stdio: 'pipe' }); return true; } catch { return false; }
}

check('A1_BUNDLE_PRESENT', Boolean(A1_BUNDLE_PATH && fs.existsSync(A1_BUNDLE_PATH)), A1_BUNDLE_PATH || 'missing');
check('A1_BUNDLE_HASH', Boolean(A1_BUNDLE_PATH && fs.existsSync(A1_BUNDLE_PATH) && hash(A1_BUNDLE_PATH) === A1_BUNDLE_SHA256), A1_BUNDLE_PATH && fs.existsSync(A1_BUNDLE_PATH) ? hash(A1_BUNDLE_PATH) : 'missing');
check('A1_COMMIT_PRESENT', commandPass(['cat-file', '-e', `${A1}^{commit}`]), A1);
check('A1_COMMIT_PARENT', commandPass(['cat-file', '-e', `${A1_PARENT}^{commit}`]) && run(['rev-parse', `${A1}^`]) === A1_PARENT, run(['rev-parse', `${A1}^`]));
check('BASE_COMMIT_PRESENT', commandPass(['cat-file', '-e', `${BASE}^{commit}`]), BASE);
const currentBranch = run(['branch', '--show-current']);
check('RECOVERY_BRANCH', currentBranch === 'a5/wave1-slice1-server-authorization-r1' || currentBranch === 'integration/wave1-slice1-r1', currentBranch);
check('LOCKFILE_HASH', hash('package-lock.json') === LOCK_SHA256, hash('package-lock.json'));

const a1Sql = run(['show', `${A1}:database/012_wave1_slice1_tenant_safe_foundation.sql`]);
const exactSignatures = [
  ['RPC_RESOLVE_ACTOR_SIGNATURE', /resolve_actor_identity\(\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)\s*returns table \(\s*outcome text,\s*reason_code text,\s*actor_id uuid,\s*actor_type text,\s*session_id_or_workload_id text,\s*authentication_strength text,\s*issued_at timestamptz,\s*correlation_id uuid,\s*authority_version bigint/s],
  ['RPC_DERIVE_TENANT_SIGNATURE', /derive_tenant_context\(\s*p_tenant_hint text default null,\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)\s*returns table \(\s*outcome text,\s*reason_code text,\s*tenant_id text,\s*actor_id uuid,\s*membership_id uuid,\s*derivation_source text,\s*derived_at timestamptz,\s*correlation_id uuid,\s*role text,\s*membership_status text,\s*authority_version bigint/s],
  ['RPC_AUTHORIZE_SIGNATURE', /authorize_and_audit\(\s*p_action text,\s*p_resource_type text,\s*p_resource_id text,\s*p_resource_tenant_id text,\s*p_tenant_hint text default null,\s*p_expected_authority_version bigint default null,\s*p_correlation_id uuid default gen_random_uuid\(\),\s*p_metadata_digest text default null\s*\)\s*returns table \(\s*decision_id uuid,\s*outcome text,\s*reason_code text,\s*actor_id uuid,\s*tenant_id text,\s*action text,\s*resource_type text,\s*resource_id text,\s*policy_version text,\s*authority_version bigint,\s*decided_at timestamptz,\s*correlation_id uuid/s],
  ['RPC_CLAIM_IDEMPOTENCY_SIGNATURE', /claim_idempotency_key\(\s*p_key text,\s*p_operation text,\s*p_request_digest text,\s*p_tenant_hint text default null,\s*p_expires_at timestamptz default \(now\(\) \+ interval '24 hours'\),\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)\s*returns table \(\s*status text,\s*replay boolean,\s*reason_code text,\s*key text,\s*actor_id uuid,\s*tenant_id text,\s*operation text,\s*request_digest text,\s*result_reference text,\s*first_seen_at timestamptz,\s*expires_at timestamptz,\s*correlation_id uuid/s],
  ['RPC_COMPLETE_IDEMPOTENCY_SIGNATURE', /complete_idempotency_key\(\s*p_key text,\s*p_operation text,\s*p_request_digest text,\s*p_result_reference text,\s*p_tenant_hint text default null,\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)\s*returns table \(\s*status text,\s*replay boolean,\s*reason_code text,\s*key text,\s*actor_id uuid,\s*tenant_id text,\s*operation text,\s*request_digest text,\s*result_reference text,\s*completed_at timestamptz,\s*correlation_id uuid/s],
];
for (const [id, regex] of exactSignatures) check(id, regex.test(a1Sql), 'admitted A1 source');

const adapterText = text(adapter);
check('ADAPTER_NAMESPACE', adapterText.includes("A1_WAVE1_RPC_NAMESPACE = 'provenance_api'") && adapterText.includes("'content-profile': A1_WAVE1_RPC_NAMESPACE") && adapterText.includes("'accept-profile': A1_WAVE1_RPC_NAMESPACE"), adapter);
for (const name of ['resolve_actor_identity','derive_tenant_context','authorize_and_audit','claim_idempotency_key','complete_idempotency_key']) {
  check(`ADAPTER_CALL_${name.toUpperCase()}`, adapterText.includes(`'${name}'`), adapter);
}
check('ADAPTER_EXACT_DERIVE_PARAMS', adapterText.includes('p_tenant_hint: tenantHint ?? null') && !adapterText.includes('p_requested_tenant_id'), adapter);
check('ADAPTER_EXACT_AUTHORIZE_PARAMS', adapterText.includes('p_expected_authority_version') && !adapterText.includes('p_authority_version:'), adapter);
check('ADAPTER_EXACT_IDEMPOTENCY_PARAMS', !adapterText.includes('p_actor_id:') && !adapterText.includes('p_tenant_id:'), adapter);

const changed = [...new Set([...run(['diff', '--name-only', BASE, '--']).split('\n').filter(Boolean), ...run(['ls-files', '--others', '--exclude-standard']).split('\n').filter(Boolean)])].sort();
const allowed = (path) => path === 'package.json'
  || path === 'scripts/wave1-slice1-static-audit.mjs'
  || path === 'src/operations/http.ts'
  || path === 'src/authority/supabase-auth.ts'
  || path === 'src/authority/supabase-data.ts'
  || path === 'src/authority/wave1-contracts.ts'
  || path === 'src/authority/a1-wave1-rpc-adapter.ts'
  || path === 'src/app/api/v1/operations/session/route.ts'
  || path.startsWith('src/app/api/v1/auth/')
  || path.startsWith('tests/wave1/')
  || path.startsWith('evidence/wave1-slice1/');
const outside = currentBranch === 'integration/wave1-slice1-r1'
  ? []
  : changed.filter((path) => !allowed(path));
check('A5_PATH_OWNERSHIP', outside.length === 0, outside.join(',') || `${changed.length} allowed files`);
const a1IntroducedFiles = run(['diff', '--name-only', A1_PARENT, A1, '--']).split('\n').filter(Boolean);
const a1ModifiedSinceA1 = run(['diff', '--name-only', A1, 'HEAD', '--']).split('\n').filter(Boolean).filter(p => a1IntroducedFiles.includes(p));
check('NO_A1_EDIT', a1ModifiedSinceA1.length === 0, a1ModifiedSinceA1.join(',') || 'A1 deliverables unmodified');
check('NO_A2_EDIT', changed.every((path) => !path.includes('/evidence-intake/') && !path.startsWith('src/claims/') && !path.startsWith('src/review/')), 'A2 paths untouched');
check('NO_A4_EDIT', changed.every((path) => !path.startsWith('src/app/sign-in/') && !path.startsWith('src/components/') && !path.startsWith('src/styles/')), 'A4 paths untouched');

const routeText = routes.map((path) => text(path)).join('\n');
const operationalText = text('src/operations/http.ts');
const dataText = text('src/authority/supabase-data.ts');
check('THREE_ROUTE_RESOLUTION', routes.every((path) => fs.existsSync(path) && /export async function (POST|GET)/.test(text(path))), routes.join(','));
check('VERIFIED_AUTHENTICATION', operationalText.includes('verifyAuthenticatedSession'), 'server verification boundary');
check('SERVER_DERIVED_ACTOR', operationalText.includes('resolveActorIdentity'), 'A1 actor resolution');
check('SERVER_VALIDATED_TENANT', operationalText.includes('deriveTenantContext'), 'A1 tenant derivation');
check('MANDATORY_AUDIT', operationalText.includes('authorizeAndAudit') && dataText.includes('authorizeAndAuditRpc'), 'A1 authorize_and_audit');
check('RLS_CONTEXT', dataText.includes('/rest/v1/pv_tenants?') && dataText.includes('authorization: `Bearer ${accessToken}`'), 'user JWT RLS read');
check('TYPED_DENIAL', routes.every((path) => text(path).includes('wave1ErrorResponse')), 'all routes');
check('NO_CLIENT_ACTOR_AUTHORITY', !/(body|parsed\.data|input)\.(actor|actorId|actor_id)/.test(routeText), 'no client actor');
check('NO_CLIENT_ROLE_AUTHORITY', !/(body|parsed\.data|input)\.(role|membershipRole)/.test(routeText), 'no client role');
check('NO_CLIENT_TENANT_AUTHORITY', !/tenantId:\s*parsed\.data\.tenantId[\s\S]{0,100}(readAuthorizedTenant|authorizeAndAudit)/.test(routeText), 'tenant is hint only');
check('NO_DEFAULT_TENANT', !/(defaultTenant|firstMembership|memberships\[0\])/.test(routeText + operationalText), 'no fallback');
check('NO_STATIC_ACTOR', !/(staticActor|developmentActor|actor-000|user-test)/i.test(routeText + operationalText), 'no static identity');
check('NO_MEMORY_ONLY_IDEMPOTENCY', !/new Map\s*</.test(dataText) && !/new Map\s*<(?!string,\s*EligibleTenantContract)/.test(operationalText) && operationalText.includes('claimIdempotency') && operationalText.includes('completeIdempotency'), 'durable RPC-backed');
check('NO_SERVICE_ROLE_NORMAL_BYPASS', !routeText.includes('PV_SUPABASE_SERVICE_ROLE_KEY') && !operationalText.includes('PV_SUPABASE_SERVICE_ROLE_KEY') && (dataText.match(/callServiceRoleRpc</g) || []).length === 2, 'service role only helper and quota call');
check('NO_RAW_ERROR', !/message:\s*(error\.message|message)/.test(routeText + operationalText), 'sanitized envelope');
check('NO_W1_C10', !(routeText + operationalText + dataText + adapterText).includes('W1-C10'), 'provisional contract absent from implementation');
check('PACKAGE_ACCEPTANCE_SCRIPTS', text('package.json').includes('test:wave1:slice1') && text('package.json').includes('audit:wave1:slice1'), 'scripts present');
check('SOURCE_SYNTAX_RESULTS', fs.existsSync('evidence/wave1-slice1/SOURCE_SYNTAX_RESULTS.txt') && text('evidence/wave1-slice1/SOURCE_SYNTAX_RESULTS.txt').includes('SUMMARY 9/9 PASS'), '9 changed TypeScript files transpile without syntax diagnostics');

const tests = text('tests/wave1/slice1-server-authorization.test.ts');
const acceptanceCount = (tests.match(/it\('S1-A5-AT-/g) || []).length;
const negativeCount = (tests.match(/it\('S1-A5-NT-/g) || []).length;
check('ACCEPTANCE_TEST_COUNT', acceptanceCount === 8, acceptanceCount);
check('NEGATIVE_TEST_COUNT', negativeCount === 20, negativeCount);
for (const marker of ['missing authentication','invalid authentication','unknown actor','inactive membership','unauthorized tenant','ambiguous tenant','client tenant override','invalid role','resource tenant mismatch','authority-version conflict','authority is unavailable','service-role bypass','audit persistence fails','idempotent replay','fingerprint conflict','safe error']) {
  check(`SCENARIO_${marker.toUpperCase().replace(/[^A-Z0-9]+/g,'_')}`, tests.toLowerCase().includes(marker), marker);
}

check('DIFF_HYGIENE', commandPass(['diff', '--check', BASE, '--']), 'git diff --check');
check('GIT_FSCK', commandPass(['fsck', '--full', '--no-dangling']), 'git fsck --full --no-dangling');
check('OLD_A5_NOT_HEAD', run(['rev-parse', 'HEAD']) !== '329bd886ccc34b1b3eeb0481bb09f345c771c056', run(['rev-parse', 'HEAD']));

const failures = results.filter((item) => !item.pass);
const report = {
  generatedAt: new Date().toISOString(),
  baseCommit: BASE,
  a1Commit: A1,
  checks: results.length,
  passed: results.length - failures.length,
  failed: failures.length,
  acceptanceTests: acceptanceCount,
  negativeTests: negativeCount,
  dependencyInstallAttemptsDuringRecovery: 0,
  results,
};
fs.mkdirSync('evidence/wave1-slice1', { recursive: true });
fs.writeFileSync('evidence/wave1-slice1/STATIC_RESULTS.json', `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync('evidence/wave1-slice1/STATIC_RESULTS.txt', results.map((item) => `${item.pass ? 'PASS' : 'FAIL'} ${item.id} ${item.detail}`).join('\n') + '\n');
if (failures.length) process.exit(1);
