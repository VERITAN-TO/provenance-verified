import fs from 'node:fs';
import path from 'node:path';
import childProcess from 'node:child_process';

const START = '7c2f94aeb00abc5f7b92adf7bffd30f5ceeb3e60';
const LOCK_SHA256 = 'c313eedd8a9695b27f2bfff37c0834b64fd32263e653fbf073b1900f112053da';
const checks = [];
const check = (id, pass, detail = '') => checks.push({ id, pass: Boolean(pass), detail: String(detail) });
const text = (file) => fs.readFileSync(file, 'utf8');
const git = (...args) => childProcess.execFileSync('git', args, { encoding: 'utf8' }).trim();
const sha = (file) => childProcess.execFileSync('sha256sum', [file], { encoding: 'utf8' }).split(/\s+/)[0];
function walk(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  });
}

const changed = git('diff', '--name-only', START, '--').split('\n').filter(Boolean);
const untracked = git('ls-files', '--others', '--exclude-standard').split('\n').filter(Boolean);
const allChanged = [...new Set([...changed, ...untracked])].sort();
const a1Changes = allChanged.filter((file) => file.startsWith('database/') || file.startsWith('supabase/'));
const prohibited = allChanged.filter((file) => file === 'package-lock.json' || file.startsWith('database/') || file.startsWith('supabase/'));
check('EXACT_START_ANCESTRY', git('merge-base', '--is-ancestor', START, 'HEAD') === '', START);
check('CORRECTION_BRANCH', git('branch', '--show-current') === 'integration/wave1-slice1-r1', git('branch', '--show-current'));
check('LOCKFILE_HASH', sha('package-lock.json') === LOCK_SHA256, sha('package-lock.json'));
check('NO_A1_MODIFICATION', a1Changes.length === 0, a1Changes.join(','));
check('NO_PROHIBITED_SOURCE_CHANGE', prohibited.length === 0, prohibited.join(','));

const controller = text('src/ui/authenticated/sign-out-controller.ts');
const shell = text('src/ui/authenticated/AuthenticatedProductShell.tsx');
const offline = text('src/operations/offline/indexedDb.ts');
const serviceWorker = text('public/sw.js');
const signOutRoute = text('src/app/api/v1/auth/sign-out/route.ts');
check('SIGNOUT_SERVER_INVALIDATION_AWAITED', /await\s+dependencies\.terminateAuthoritySession\(\)/.test(controller));
check('SIGNOUT_OFFLINE_PURGE_AWAITED', /Promise\.allSettled\([\s\S]*clearAllOfflineData/.test(controller));
check('SIGNOUT_CACHE_PURGE_AWAITED', /Promise\.allSettled\([\s\S]*purgeServiceWorkerCaches/.test(controller));
check('SIGNOUT_MARKER_PURGE_ATTEMPTED', /clearNonAuthoritativeClientState\(\)/.test(controller));
check('SIGNOUT_FAILURE_FAILS_CLOSED', /SIGNED_OUT_CLEANUP_REQUIRED/.test(shell) && /Protected access remains disabled/.test(shell));
check('SIGNOUT_NO_SESSION_RESTORE', !/restore(?:Authority|Authenticated|Session)/i.test(`${controller}\n${shell}`));
check('SIGNOUT_RETRY_AVAILABLE', /retrySignedOutCleanup/.test(shell) && /Retry cleanup|Retry sign-out/.test(shell));
check('SIGNOUT_PROVIDER_FAILURE_NOT_200', /catch \(error\)[\s\S]*status: mapped\.status/.test(signOutRoute));
check('SIGNOUT_COOKIES_CLEARED_ON_FAILURE', /return clearAuthorityCookies\(NextResponse\.json\(mapped\.public/.test(signOutRoute));
check('INDEXEDDB_ALL_STORES_PURGED', /clear\(SNAPSHOTS\).*clear\(MEDIA\).*clear\(KEYS\).*clear\(META\)/s.test(offline));
check('CACHE_STORAGE_DIRECT_PURGE', /globalThis\.caches\.keys/.test(offline) && /globalThis\.caches\.delete/.test(offline));
check('SERVICE_WORKER_ACK_REQUIRED', /PURGE_COMPLETE/.test(offline) && /PURGE_FAILED/.test(offline) && /PURGE_COMPLETE/.test(serviceWorker));

const mapper = text('src/operations/public-error-mapper.ts');
const changedApiFiles = allChanged.filter((file) => /^src\/app\/api\/.*\/route\.ts$/.test(file));
const changedApi = changedApiFiles.map((file) => text(file)).join('\n');
check('PUBLIC_ERROR_MAPPER_PRESENT', /mapPublicAuthorityError/.test(mapper) && /SAFE_MESSAGES/.test(mapper));
const publicEnvelopeBlock = mapper.match(/const publicEnvelope:[\s\S]*?= \{([\s\S]*?)\n  \};/)?.[1] ?? '';
check('PUBLIC_ERROR_APPROVED_FIELDS_ONLY', !/fieldErrors|field_errors/.test(mapper) && !/status\s*:/.test(publicEnvelopeBlock));
check('PUBLIC_ERROR_CORRELATION_ID', /correlation_id:\s*input\.correlationId/.test(mapper));
check('PUBLIC_ERROR_HTTP_STATUS_SEPARATE', /status:\s*STATUS\[code\]/.test(mapper.split('return {')[1] ?? mapper));
check('SERVER_DIAGNOSTIC_SANITIZED_SHAPE', /internalErrorClass/.test(mapper) && /category: diagnosticCategory/.test(mapper) && !/message:\s*(?:record\(error\)|error)/.test(mapper));
check('NO_RAW_ERROR_MESSAGE_RESPONSE', !/message\s*:\s*(?:error|exception)\.(?:message|toString\(\))/.test(changedApi));
check('NO_STACK_RESPONSE', !/stack\s*:\s*(?:error|exception)\.stack/.test(changedApi));
check('NO_SQL_DETAIL_RESPONSE', !/(detail|hint|constraint)\s*:\s*(?:error|exception)/.test(changedApi));

const settings = text('src/app/app/settings/page.tsx');
check('SETTINGS_LINK_SERVER_PROJECTED', /context\?\.navigation\.settings === true/.test(shell));
check('SETTINGS_LINK_ACCESSIBLE', /<Link href="\/app\/settings" aria-current=/.test(shell) && />Settings<\/Link>/.test(shell));
check('SETTINGS_ROUTE_SERVER_GUARD', /authorizeWave1Request\s*\(/.test(settings) && /action:\s*'membership\/manage'/.test(settings));
check('SETTINGS_ROUTE_FAILS_CLOSED', /redirect\('\/app\?denied=settings'\)/.test(settings));

const maintainedFiles = [...walk('src'), ...walk('public'), ...walk('scripts')]
  .filter((file) => fs.statSync(file).isFile())
  .filter((file) => !file.includes('tests/fixtures'));
const secretPatterns = [
  /BEGIN (?:RSA|EC|OPENSSH) PRIVATE KEY/,
  /sk_live_[A-Za-z0-9]{8,}/,
  /AKIA[0-9A-Z]{16}/,
  /(?:password|service[_-]?role[_-]?key)\s*[:=]\s*['"][^'"]{4,}['"]/i,
  /[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/,
];
const secretHits = maintainedFiles.flatMap((file) => {
  const source = text(file);
  return secretPatterns.some((pattern) => pattern.test(source)) ? [file] : [];
});
check('SOURCE_SECRET_SCAN', secretHits.length === 0, secretHits.join(','));
check('DIFF_HYGIENE', childProcess.spawnSync('git', ['diff', '--check']).status === 0);
check('GIT_FSCK', childProcess.spawnSync('git', ['fsck', '--full', '--no-dangling']).status === 0);

const failed = checks.filter((item) => !item.pass);
console.log(JSON.stringify({ checks: checks.length, passed: checks.length - failed.length, failed: failed.length, changedFiles: allChanged.length, results: checks }, null, 2));
if (failed.length) process.exit(1);
