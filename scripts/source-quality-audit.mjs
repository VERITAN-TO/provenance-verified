import fs from 'node:fs';
import path from 'node:path';
import {
  hasCanonicalAuthorizationGuard,
  hasCanonicalSafeErrorMapping,
  hasCanonicalSafeSignOut,
  hasGuardedSettingsRoute,
  inspectFixture,
} from './lib/source-quality-detector.mjs';

const root = process.cwd();
const checks = [];
const add = (id, pass, detail = '') => checks.push({ id, pass: Boolean(pass), detail });
function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  });
}
const runtimeFiles = [...walk('src'), ...walk('services'), ...walk('supabase/functions'), ...walk('infra'), ...walk('database')]
  .filter((file) => !file.includes('.local-build'));
const texts = new Map(runtimeFiles.map((file) => [file, fs.readFileSync(file, 'utf8')]));
const text = (file) => fs.readFileSync(file, 'utf8');
const hits = (expression, filter = () => true) => [...texts].filter(([file, source]) => filter(file) && expression.test(source)).map(([file]) => file);

const todos = hits(/\b(?:TODO|FIXME|HACK|NOT_IMPLEMENTED)\b/i);
add('no-runtime-todos', todos.length === 0, todos.join(','));
const clientFiles = [...texts].filter(([file, source]) => /\.tsx?$/.test(file) && /^\s*['"]use client['"]/m.test(source));
const clientSecrets = clientFiles.filter(([, source]) => /(SERVICE_ROLE|PRIVATE_KEY|PV_SIGNER_TOKEN|PV_CUSTOS_TOKEN)/.test(source)).map(([file]) => file);
add('no-server-secrets-in-client-components', clientSecrets.length === 0, clientSecrets.join(','));

const localStorageFiles = hits(/\b(?:localStorage|sessionStorage)\b/);
const allowedStorage = new Set([
  'src/standalone/runtime.ts',
  'src/ui/SignInAccess.tsx',
  'src/operations/browserStorage.ts',
  'src/ui/authenticated/authority-client.ts',
]);
const authorityClient = text('src/ui/authenticated/authority-client.ts');
const storageFunction = authorityClient.match(/export function clearNonAuthoritativeClientState\(\):void\s*\{[\s\S]*?\}/)?.[0] ?? '';
const authorityClientWithoutStorageFunction = authorityClient.replace(storageFunction, '');
const authorityStorageCanonical = /sessionStorage\.clear\(\)/.test(storageFunction)
  && /localStorage\.removeItem/.test(storageFunction)
  && !/\b(?:localStorage|sessionStorage)\b/.test(authorityClientWithoutStorageFunction);
add(
  'browser-storage-confined-to-reviewed-helpers',
  localStorageFiles.every((file) => allowedStorage.has(file)) && authorityStorageCanonical,
  localStorageFiles.join(','),
);

const rawKeys = hits(/BEGIN (?:RSA|EC|OPENSSH) PRIVATE KEY|(?:^|\W)PRIVATE_KEY\s*[:=]\s*['"][^-]/m);
add('no-raw-private-keys', rawKeys.length === 0, rawKeys.join(','));
const publicMode = text('src/authority/public-mode.ts');
add('no-silent-production-to-sandbox-fallback', /if \(value === 'production'\) return 'production'/.test(publicMode) && !/if\s*\(value === 'production'\)\s*return 'sandbox'/.test(publicMode));
const apiRoutes = runtimeFiles.filter((file) => /src\/app\/api\/.*\/route\.ts$/.test(file));
add('api-route-inventory', apiRoutes.length >= 20, `${apiRoutes.length} route handlers`);
const productionRoutes = apiRoutes.filter((file) => /authority|operations|organization|webhooks|mcp|auth/.test(file));
const unguarded = productionRoutes.filter((file) => {
  const source = texts.get(file) ?? '';
  if (file.endsWith('auth/session/route.ts') || file.endsWith('operations/session/route.ts')) return !hasCanonicalAuthorizationGuard(source);
  return !/(authenticate|authorizeWave1Request|requireSession|requireAuthority|requireRole|requirePermission|sessionFromRequest|assertPermission|ACCESS_COOKIE|REFRESH_COOKIE|testMode|mode:\s*['"]test['"]|sandbox|public registry|health)/i.test(source);
});
add('consequential-routes-have-authority-guards', unguarded.length === 0, unguarded.join(','));

const signOutSource = `${text('src/ui/authenticated/AuthenticatedProductShell.tsx')}\n${text('src/ui/authenticated/sign-out-controller.ts')}`;
add('canonical-safe-sign-out-recognized', hasCanonicalSafeSignOut(text('src/ui/authenticated/sign-out-controller.ts')) && /SIGNED_OUT_CLEANUP_REQUIRED/.test(text('src/ui/authenticated/AuthenticatedProductShell.tsx')));
add('canonical-safe-api-error-mapper-recognized', hasCanonicalSafeErrorMapping(`${text('src/operations/public-error-mapper.ts')}\n${text('src/operations/http.ts')}`));
add('canonical-settings-route-guard-recognized', hasGuardedSettingsRoute(text('src/app/app/settings/page.tsx')));

const fixtureRoot = 'tests/fixtures/source-quality';
function runFixtures(kind) {
  return walk(path.join(fixtureRoot, kind)).filter((file) => /\.(?:ts|tsx)$/.test(file)).map((file) => {
    const source = text(file);
    const detector = source.match(/detector:\s*([a-z-]+)/)?.[1] ?? '';
    return { file, detector, accepted: inspectFixture(detector, source) };
  });
}
const positiveFixtures = runFixtures('positive');
const negativeFixtures = runFixtures('negative');
add('source-quality-positive-fixtures', positiveFixtures.length === 5 && positiveFixtures.every((fixture) => fixture.accepted), `${positiveFixtures.filter((fixture) => fixture.accepted).length}/${positiveFixtures.length}`);
add('source-quality-negative-fixtures', negativeFixtures.length === 9 && negativeFixtures.every((fixture) => !fixture.accepted), `${negativeFixtures.filter((fixture) => !fixture.accepted).length}/${negativeFixtures.length}`);

const placeholders = hits(/placeholder api|fake signing|fake custos|simulated production|fixture-only production/i);
add('no-production-placeholder-markers', placeholders.length === 0, placeholders.join(','));
const throwTodo = hits(/throw\s+new\s+Error\(['"](?:TODO|NOT_IMPLEMENTED)/i);
add('no-not-implemented-throws', throwTodo.length === 0, throwTodo.join(','));
const providerHandlers = runtimeFiles.filter((file) => /services\/provider-boundaries\/[^/]+\/handler\.py$/.test(file));
const requiredProviderServices = ['activation-authority','attestation-signer','canonical-authority','claim-validator','conflict-engine','custos','evidence-custody','evidence-eligibility','mark-authority','registry','reviewer-authority','scanner','secret-vault','signer'];
const providerNames = new Set(providerHandlers.map((file) => file.split('/').at(-2)));
add('all-independent-provider-handlers-present', requiredProviderServices.every((name) => providerNames.has(name)), requiredProviderServices.filter((name) => !providerNames.has(name)).join(','));
const env = text('.env.example');
const required = ['PV_ENVIRONMENT','PV_SUPABASE_URL','PV_AUTHORITY_API_URL','PV_AUTHORITY_PROVIDER_API_URL','PV_AWS_ROLE_ARN','PV_AWS_WEB_IDENTITY_TOKEN','PV_CUSTOS_PROVIDER_API_URL','PV_CUSTOS_AWS_ROLE_ARN'];
add('required-environment-contract-complete', required.every((key) => env.includes(key)), required.filter((key) => !env.includes(key)).join(','));
const config = text('src/authority/config.ts');
add('production-activation-default-deny', /PRODUCTION_ACTIVATION_INCOMPLETE/.test(config) && /PV_PRODUCTION_AUTHORITY_ENABLED/.test(config));
const proxy = text('src/proxy.ts');
add('proxy-explicitly-denies-sandbox-fallback', /No sandbox fallback was used/.test(proxy));
const packageJson = JSON.parse(text('package.json'));
const lock = JSON.parse(text('package-lock.json'));
add('lockfile-versioned', lock.lockfileVersion === 3);
add('package-lock-root-version-match', lock.packages?.['']?.version === packageJson.version, `${lock.packages?.['']?.version}/${packageJson.version}`);
add('dependency-versions-exact', Object.values(packageJson.dependencies ?? {}).every((value) => /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value)) && Object.values(packageJson.devDependencies ?? {}).every((value) => /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value)));

const failed = checks.filter((item) => !item.pass);
const report = {
  generatedAt: new Date().toISOString(),
  scope: 'offline source quality and production-boundary audit; no deployment',
  fixtureSummary: {
    positive: { total: positiveFixtures.length, passed: positiveFixtures.filter((fixture) => fixture.accepted).length },
    negative: { total: negativeFixtures.length, correctlyRejected: negativeFixtures.filter((fixture) => !fixture.accepted).length },
  },
  summary: { checks: checks.length, passed: checks.length - failed.length, failed: failed.length, verdict: failed.length ? 'FAIL' : 'PASS' },
  checks,
};
fs.mkdirSync('evidence/corrective', { recursive: true });
fs.writeFileSync('evidence/corrective/source-quality.json', `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report.summary, null, 2));
if (failed.length) {
  console.error(JSON.stringify(failed, null, 2));
  process.exit(1);
}
