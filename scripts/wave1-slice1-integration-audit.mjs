import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import childProcess from 'node:child_process';
import { createRequire } from 'node:module';

const BASE = '10d95ebbd90f1e489efd859987cfaeafb3a5a6fc';
const A1 = '79204ec9733062725aaf0e0d6cdfe560cb4a9444';
const A5 = 'd22e88df68ad3564f25ce2a080fa60e84b76b793';
const A4 = 'c339916317c1153968d9d223b4798b76155d5810';
const LOCK = 'c313eedd8a9695b27f2bfff37c0834b64fd32263e653fbf073b1900f112053da';
const evidenceDir = 'evidence/wave1-slice1-integration';
const results = [];
const text = (file) => fs.readFileSync(file, 'utf8');
const hash = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run = (command, args, options = {}) => childProcess.execFileSync(command, args, { encoding: 'utf8', ...options }).trim();
const git = (...args) => run('git', args);
const commandPass = (command, args) => { try { childProcess.execFileSync(command, args, { stdio: 'pipe' }); return true; } catch { return false; } };
const check = (id, pass, detail) => { results.push({ id, pass: Boolean(pass), detail: String(detail) }); console.log(`${pass ? 'PASS' : 'FAIL'} ${id} ${detail}`); };

check('BASE_COMMIT', commandPass('git', ['cat-file', '-e', `${BASE}^{commit}`]), BASE);
check('A1_OBJECT', commandPass('git', ['cat-file', '-e', `${A1}^{commit}`]), A1);
check('A5_OBJECT', commandPass('git', ['cat-file', '-e', `${A5}^{commit}`]), A5);
check('A4_OBJECT', commandPass('git', ['cat-file', '-e', `${A4}^{commit}`]), A4);
check('INTEGRATION_BRANCH', ['integration/wave1-slice1','integration/wave1-slice1-r1'].includes(git('branch', '--show-current')), git('branch', '--show-current'));
check('LOCKFILE_HASH', hash('package-lock.json') === LOCK, hash('package-lock.json'));
check('NO_LOCKFILE_DIFF', !git('diff', '--name-only', BASE, '--').split('\n').includes('package-lock.json'), 'package-lock.json');

const changed = git('diff', '--name-only', BASE, '--').split('\n').filter(Boolean);
check('A1_MIGRATION_003_5', fs.existsSync('database/003_5_wave1_tenant_context_bootstrap.sql'), 'present');
check('A1_MIGRATION_012', fs.existsSync('database/012_wave1_slice1_tenant_safe_foundation.sql'), 'present');
check('MIRROR_003_5', fs.readFileSync('database/003_5_wave1_tenant_context_bootstrap.sql').equals(fs.readFileSync('supabase/migrations/20260722035000_wave1_tenant_context_bootstrap.sql')), 'byte-identical');
check('MIRROR_012', fs.readFileSync('database/012_wave1_slice1_tenant_safe_foundation.sql').equals(fs.readFileSync('supabase/migrations/20260725050000_wave1_slice1_tenant_safe_foundation.sql')), 'byte-identical');
check('GENERATED_TYPES', fs.existsSync('database/generated/wave1-slice1-database.types.ts'), 'present');

const migration = text('database/012_wave1_slice1_tenant_safe_foundation.sql');
for (const rpc of ['resolve_actor_identity','derive_tenant_context','authorize_and_audit','claim_idempotency_key','complete_idempotency_key']) {
  check(`RPC_${rpc.toUpperCase()}`, migration.includes(`function provenance_api.${rpc}`), rpc);
}
check('RLS_ENABLED', (migration.match(/enable row level security/gi) || []).length >= 8, 'protected tables');
check('RLS_FORCED', (migration.match(/force row level security/gi) || []).length >= 8, 'protected tables');
check('NO_PERMISSIVE_RLS', !/using\s*\(\s*true\s*\)|with check\s*\(\s*true\s*\)/i.test(migration), 'no true policy');
check('AUDIT_APPEND_ONLY', migration.includes('pv_authorization_audit_events') && migration.includes('reject_immutable_authority_change') && /truncate/i.test(migration), 'update/delete/truncate blocked');
check('DURABLE_IDEMPOTENCY', migration.includes('create table if not exists public.pv_idempotency_keys') && migration.includes('PV_IDEMPOTENCY_FINGERPRINT_CONFLICT'), 'database persisted');
check('PURCHASER_SEPARATION', migration.includes('pv_purchaser_relationships') && !/purchaser[^\n]*authority_role/i.test(migration), 'non-authorizing relation');

const adapter = text('src/authority/a1-wave1-rpc-adapter.ts');
check('A5_A1_ADAPTER_COMMIT', adapter.includes(A1), A1);
check('A5_A1_NAMESPACE', adapter.includes("A1_WAVE1_RPC_NAMESPACE = 'provenance_api'"), 'provenance_api');
const http = text('src/operations/http.ts');
const data = text('src/authority/supabase-data.ts');
const serverContracts = text('src/authority/wave1-contracts.ts');
const authRoute = text('src/app/api/v1/auth/session/route.ts');
const opsRoute = text('src/app/api/v1/operations/session/route.ts');
check('SERVER_VERIFIED_SESSION', http.includes('verifyAuthenticatedSession'), 'server only');
check('SERVER_DERIVED_ACTOR', http.includes('resolveActorIdentity'), 'A1 RPC');
check('SERVER_DERIVED_TENANT', http.includes('deriveTenantContext'), 'A1 RPC');
check('TYPED_TENANT_AMBIGUITY', serverContracts.includes('Wave1TenantSelectionRequired') && serverContracts.includes("code: 'DENY_TENANT_AMBIGUOUS'") && http.includes('listEligibleWave1Tenants'), '409 selection envelope');
check('NO_FIRST_TENANT_FALLBACK', !/(memberships|eligibleTenants)\s*\[\s*0\s*\]/.test(http + authRoute + opsRoute), 'explicit selection only');
check('CANONICAL_SESSION_PROJECTION', http.includes('projectWave1AuthorityContext') && ['actor:','tenant:','membership:','authorization:','session:','eligibleTenants','correlationId'].every((marker) => http.includes(marker)), 'one response shape');
check('AUTH_ROUTE_PROJECTION', authRoute.includes('projectWave1AuthorityContext'), 'canonical');
check('OPS_ROUTE_PROJECTION', opsRoute.includes('projectWave1AuthorityContext'), 'canonical');
check('RLS_FINAL_READ', data.includes('/rest/v1/pv_tenants?') && data.includes('Bearer ${accessToken}'), 'user JWT');
check('MANDATORY_AUDIT', http.includes('authorizeAndAudit') && data.includes('authorizeAndAuditRpc'), 'fail closed');
check('IDEMPOTENCY_ORCHESTRATION', http.includes('claimIdempotency') && http.includes('completeIdempotency') && !/idempotency[^\n]{0,80}new Map/i.test(http), 'durable');
check('SERVICE_ROLE_SCOPED', !authRoute.includes('SERVICE_ROLE') && !opsRoute.includes('SERVICE_ROLE') && (data.match(/callServiceRoleRpc</g) || []).length === 2, 'quota only');

const mfaRoutes = ['enroll','challenge','verify'].map((name) => text(`src/app/api/v1/auth/mfa/${name}/route.ts`)).join('\n');
const signIn = text('src/ui/AuthoritySignInAccess.tsx');
check('MFA_ENROLLMENT', signIn.includes('/api/v1/auth/mfa/enroll') && signIn.includes('mfaEnrollmentRequired'), 'restored');
check('MFA_CHALLENGE', signIn.includes('/api/v1/auth/mfa/challenge'), 'restored');
check('MFA_VERIFY', signIn.includes('/api/v1/auth/mfa/verify'), 'restored');
check('MFA_SAFE_ERRORS', !/message\s*:\s*(message|error\.message)/.test(mfaRoutes) && (mfaRoutes.match(/wave1ErrorResponse/g) || []).length >= 3, 'sanitized');
check('BOUNDED_CLIENT_TIMEOUT', signIn.includes('AbortController') && signIn.includes('9000'), '9 seconds');
check('DUPLICATE_SUBMISSION_GUARD', (signIn.match(/if \(busy\) return/g) || []).length >= 3, 'sign-in/MFA/tenant');
check('SERVER_TENANT_REVALIDATION', signIn.includes("tenantSelectionSource === 'sign-in'") && signIn.includes('authenticate(tenantId)') && text('src/ui/authenticated/authority-client.ts').includes("'x-provenance-tenant'"), 'no client authority');

const clientContracts = text('src/ui/authenticated/authority-contracts.ts');
const client = text('src/ui/authenticated/authority-client.ts');
const shell = text('src/ui/authenticated/AuthenticatedProductShell.tsx');
const css = text('src/ui/authenticated/AuthorityExperience.module.css');
check('CLIENT_CANONICAL_PARSER', clientContracts.includes("membershipStatus !== 'active'") && clientContracts.includes("decision !== 'ALLOW'"), 'fail closed');
check('CROSS_ENDPOINT_BINDING', client.includes('authContext.actor.actorId!==opsContext.actor.actorId') && client.includes('authContext.authorization.authorityVersion!==opsContext.authorization.authorityVersion'), 'actor tenant role version');
check('MALFORMED_200_DENIED', client.includes('DENY_MALFORMED_RESPONSE'), 'both endpoints');
check('PROTECTED_FLASH_PREVENTED', shell.includes('Private content withheld') && /state\.status\s*===\s*['"]AUTHENTICATED['"]/.test(shell), 'withheld until allow');
check('SESSION_EXPIRATION', shell.includes('DENY_SESSION_EXPIRED') && shell.includes('setTimeout'), 'bounded timer');
check('LOGOUT_STATE_CLEAR', shell.includes('clearNonAuthoritativeClientState') && shell.includes('terminateAuthoritySession'), 'client and server');
check('AUTHORIZED_EMPTY_STATE', shell.includes('AUTHORIZED EMPTY FOUNDATION') && shell.includes('No lots, evidence, claims'), 'future slices closed');
check('RESPONSIVE_UI', css.includes('@media(max-width') && css.includes('grid-template-columns'), 'responsive');
check('REDUCED_MOTION', css.includes('prefers-reduced-motion'), 'accessibility');
check('FOCUS_AND_LIVE_REGIONS', signIn.includes('errorRef.current?.focus') && signIn.includes('aria-live') && shell.includes('tabIndex={-1}'), 'accessible states');
check('NO_W1_C10', !changed.filter((file) => file.startsWith('src/') && /\.(ts|tsx)$/.test(file)).some((file) => text(file).includes('W1-C10')), 'provisional absent from implementation');
check('NO_DEFAULT_AUTHORITY', !/(defaultTenant|defaultAdmin|firstMembership|staticActor)/.test(http + signIn + shell), 'no fallback');

const tsFiles = changed.filter((file) => /\.(ts|tsx)$/.test(file) && !file.endsWith('.d.ts'));
let syntaxDiagnostics = [];
try {
  const require = createRequire(import.meta.url);
  const ts = require('typescript');
  for (const file of tsFiles) {
    const output = ts.transpileModule(text(file), {
      compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext, jsx: ts.JsxEmit.ReactJSX },
      fileName: file,
      reportDiagnostics: true,
    });
    for (const diagnostic of output.diagnostics ?? []) {
      if (diagnostic.category === ts.DiagnosticCategory.Error) syntaxDiagnostics.push({ file, code: diagnostic.code });
    }
  }
} catch (error) {
  syntaxDiagnostics = [{ file: 'typescript', code: String(error) }];
}
check('CHANGED_TS_SYNTAX', syntaxDiagnostics.length === 0, syntaxDiagnostics.length ? JSON.stringify(syntaxDiagnostics) : `${tsFiles.length} files`);

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'pv-wave1-a4-'));
let harnessOutput = '';
let harnessPass = false;
try {
  childProcess.execFileSync('node_modules/.bin/tsc', [
    'src/ui/authenticated/authority-contracts.ts',
    'src/ui/authenticated/authority-state.ts',
    '--target', 'ES2022', '--module', 'commonjs', '--strict', '--skipLibCheck', '--outDir', temp,
  ], { stdio: 'pipe' });
  harnessOutput = run('node', ['tests/a0/wave1-slice1-integration-harness.cjs', temp]);
  harnessPass = /"failed": 0/.test(harnessOutput) && /"passed": 20/.test(harnessOutput);
} catch (error) {
  harnessOutput = String(error);
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
check('DEPENDENCY_FREE_CONTRACT_HARNESS', harnessPass, harnessPass ? '20/20' : harnessOutput.slice(0, 500));

const a1Tests = text('database/tests/012_wave1_slice1_foundation.sql');
const a5Tests = text('tests/wave1/slice1-server-authorization.test.ts');
const a4Tests = text('tests/a4/authority-kernel-harness.cjs');
const uniqueCount = (source, expression) => new Set(source.match(expression) ?? []).size;
const counts = {
  a1Acceptance: uniqueCount(a1Tests, /S1-AT-\d{3}/g),
  a1Negative: uniqueCount(a1Tests, /S1-NT-\d{3}/g),
  a5Acceptance: uniqueCount(a5Tests, /S1-A5-AT-\d{3}/g),
  a5Negative: uniqueCount(a5Tests, /S1-A5-NT-\d{3}/g),
  a4Kernel: (a4Tests.match(/t\('/g) || []).length,
  integrationHarness: 20,
};
check('TEST_DEFINITIONS_PRESENT', counts.a1Acceptance >= 8 && counts.a1Negative >= 16 && counts.a5Acceptance >= 8 && counts.a5Negative >= 20 && counts.a4Kernel >= 25, JSON.stringify(counts));
check('DIFF_HYGIENE', commandPass('git', ['diff', '--check']), 'git diff --check');
check('GIT_FSCK', commandPass('git', ['fsck', '--full', '--no-dangling']), 'git fsck');

const failures = results.filter((item) => !item.pass);
const report = {
  generatedAt: new Date().toISOString(),
  baseCommit: BASE,
  componentObjects: { A1, A5, A4 },
  integrationHead: git('rev-parse', 'HEAD'),
  changedFiles: changed.length,
  checks: results.length,
  passed: results.length - failures.length,
  failed: failures.length,
  testDefinitions: counts,
  dependencyInstallAttempts: 0,
  runtimeTests: 'BLOCKED_PENDING_A6',
  databaseTests: 'BLOCKED_PENDING_A6',
  results,
};
fs.mkdirSync(evidenceDir, { recursive: true });
fs.writeFileSync(path.join(evidenceDir, 'STATIC_RESULTS.json'), `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(path.join(evidenceDir, 'STATIC_RESULTS.txt'), results.map((item) => `${item.pass ? 'PASS' : 'FAIL'} ${item.id} ${item.detail}`).join('\n') + '\n');
fs.writeFileSync(path.join(evidenceDir, 'CONTRACT_HARNESS.txt'), `${harnessOutput}\n`);
if (failures.length) process.exit(1);
