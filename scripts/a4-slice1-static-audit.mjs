import fs from 'node:fs';
import childProcess from 'node:child_process';

const BASE = '10d95ebbd90f1e489efd859987cfaeafb3a5a6fc';
const STARTING_INTEGRATION = '7c2f94aeb00abc5f7b92adf7bffd30f5ceeb3e60';
const LOCK_SHA256 = 'c313eedd8a9695b27f2bfff37c0834b64fd32263e653fbf073b1900f112053da';
const branch = run(['branch', '--show-current']);
const integrationMode = branch === 'integration/wave1-slice1-r1';
const comparison = integrationMode ? STARTING_INTEGRATION : BASE;
const changed = [...new Set([
  ...run(['diff', '--name-only', comparison, '--']).split('\n').filter(Boolean),
  ...run(['ls-files', '--others', '--exclude-standard']).split('\n').filter(Boolean),
])].sort();
const a4SourceFiles = [
  'src/app/app/layout.tsx',
  'src/app/app/settings/page.tsx',
  'src/ui/AuthoritySignInAccess.tsx',
  'src/ui/operations/OperationsShell.tsx',
  'src/ui/authenticated/AuthenticatedProductShell.tsx',
  'src/ui/authenticated/AuthorityExperience.module.css',
  'src/ui/authenticated/authority-client.ts',
  'src/ui/authenticated/authority-contracts.ts',
  'src/ui/authenticated/authority-state.ts',
  'src/ui/authenticated/sign-out-controller.ts',
  'src/operations/offline/indexedDb.ts',
  'public/sw.js',
].filter(fs.existsSync);
const source = a4SourceFiles.map((file) => fs.readFileSync(file, 'utf8')).join('\n');
const shell = fs.readFileSync('src/ui/authenticated/AuthenticatedProductShell.tsx', 'utf8');
const settings = fs.existsSync('src/app/app/settings/page.tsx') ? fs.readFileSync('src/app/app/settings/page.tsx', 'utf8') : '';
const signOutController = fs.existsSync('src/ui/authenticated/sign-out-controller.ts') ? fs.readFileSync('src/ui/authenticated/sign-out-controller.ts', 'utf8') : '';
const offline = fs.readFileSync('src/operations/offline/indexedDb.ts', 'utf8');
const serviceWorker = fs.readFileSync('public/sw.js', 'utf8');
const checks = [];
const check = (name, pass, detail = '') => checks.push({ name, pass: Boolean(pass), detail });

function run(args) {
  return childProcess.execFileSync('git', args, { encoding: 'utf8' }).trim();
}
function sha256(file) {
  return childProcess.execFileSync('sha256sum', [file], { encoding: 'utf8' }).split(/\s+/)[0];
}
function commandPass(command, args) {
  return childProcess.spawnSync(command, args, { encoding: 'utf8' }).status === 0;
}

const componentAllowed = (file) => file.startsWith('src/app/app/')
  || file === 'src/app/sign-in/page.tsx'
  || file.startsWith('src/ui/authenticated/')
  || file === 'src/ui/AuthoritySignInAccess.tsx'
  || file === 'src/ui/operations/OperationsShell.tsx'
  || file.startsWith('tests/a4/')
  || file === 'scripts/a4-slice1-static-audit.mjs'
  || file === 'tsconfig.a4-slice1.json';

check('base-commit-present', commandPass('git', ['cat-file', '-e', `${BASE}^{commit}`]), BASE);
check('expected-branch', integrationMode || branch === 'a4/wave1-slice1-authenticated-shell-r1', branch);
check('a4-component-ownership', integrationMode || changed.every(componentAllowed), integrationMode ? 'integration correction mode' : changed.filter((file) => !componentAllowed(file)).join(','));
check('no-a1-source-modification', run(['diff', '--name-only', STARTING_INTEGRATION, '--', 'database', 'supabase']).length === 0, 'database and supabase unchanged');
check('lockfile-unchanged', sha256('package-lock.json') === LOCK_SHA256, sha256('package-lock.json'));
check('seven-contracts', source.includes("'W1-C07'") && source.includes("'W1-C01'"));
check('no-w1-c10', !source.includes('W1-C10'));
check('no-default-tenant', !source.includes('defaultTenant'));
check('no-default-admin', !source.includes('defaultAdmin'));
check('complete-allow-parser', source.includes("decision !== 'ALLOW'") && source.includes("membershipStatus !== 'active'"));
check('malformed-200-denied', source.includes('DENY_MALFORMED_RESPONSE'));
check('auth-and-operations-session', source.includes('/api/v1/auth/session') && source.includes('/api/v1/operations/session'));
check('sign-in-route', source.includes('/api/v1/auth/sign-in'));
check('bounded-timeout', source.includes('AbortController') && source.includes('9000'));
check('duplicate-prevention', /if\s*\(busy\)\s*return/.test(source));
check('safe-client-errors', source.includes('safeDenial') && !/error\.message|error\.stack/.test(source));
check('correlation-reference', source.includes('correlationId'));
check('no-protected-flash', shell.includes('Private content withheld') && /state\.status\s*===\s*['"]AUTHENTICATED['"]/.test(shell));
check('fixture-absent-production', source.includes("environment!=='sandbox'") && source.includes('return null'));
check('authorized-empty-state', source.includes('AUTHORIZED EMPTY FOUNDATION'));
check('no-future-slice-data', source.includes('No lots, evidence, claims'));
check('tenant-server-revalidation', source.includes("'x-provenance-tenant'") && /resolve\(id\s*,\s*(?:state\.eligibleTenants|tenants)\)/.test(source));
check('no-first-tenant-fallback', !source.includes('eligibleTenants[0]') && !source.includes('memberships[0]'));
check('role-server-presented', source.includes('membership.role'));
check('terminal-retry-bounded', source.includes('canRetryState'));
check('logout-server-invalidation-awaited', /await\s+dependencies\.terminateAuthoritySession\(\)/.test(signOutController));
check('logout-offline-purge-awaited', /Promise\.allSettled\([\s\S]*clearAllOfflineData/.test(signOutController));
check('logout-cache-purge-awaited', /Promise\.allSettled\([\s\S]*purgeServiceWorkerCaches/.test(signOutController));
check('logout-failure-fail-closed', shell.includes('SIGNED_OUT_CLEANUP_REQUIRED') && shell.includes('Protected access remains disabled'));
check('logout-retry-present', shell.includes('retrySignedOutCleanup'));
check('indexeddb-all-stores-cleared', /clear\(SNAPSHOTS\).*clear\(MEDIA\).*clear\(KEYS\).*clear\(META\)/s.test(offline));
check('cache-storage-direct-purge', /globalThis\.caches\.keys/.test(offline) && /globalThis\.caches\.delete/.test(offline));
check('service-worker-purge-acknowledged', /PURGE_COMPLETE/.test(offline) && /PURGE_COMPLETE/.test(serviceWorker));
check('settings-link-authorized', /settingsAuthorized\s*\?\s*<Link href="\/app\/settings"/.test(shell));
check('settings-active-nav', /aria-current=\{activeLink\('\/app\/settings'\)\}/.test(shell));
check('settings-server-guard', /authorizeWave1Request\s*\(/.test(settings) && /action:\s*'membership\/manage'/.test(settings));
check('settings-direct-denial', /redirect\('\/app\?denied=settings'\)/.test(settings));
check('responsive-css', source.includes('@media(max-width'));
check('reduced-motion', source.includes('prefers-reduced-motion'));
check('focus-error', source.includes('focusRef.current?.focus'));
check('live-region', source.includes('aria-live'));
check('diff-hygiene', commandPass('git', ['diff', '--check']));

const failed = checks.filter((item) => !item.pass);
console.log(JSON.stringify({ mode: integrationMode ? 'integrated-correction' : 'component', passed: checks.length - failed.length, failed: failed.length, checks }, null, 2));
if (failed.length) process.exit(1);
