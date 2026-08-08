export function hasCanonicalAuthorizationGuard(source) {
  const serverGuard = /\b(?:authorizeWave1Request|authenticateWave1Request)\s*\(/.test(source);
  const safeErrorBoundary = /\b(?:wave1ErrorResponse|mapPublicAuthorityError)\s*\(/.test(source);
  const clientRoleAuthority = /headers?\.get\(['"]x-(?:role|user-role|authority-role)['"]\)|body\.(?:role|tenantId)\s*(?:===|==)/i.test(source);
  const clientTenantAuthority = /headers?\.get\(['"]x-(?:tenant-role|client-tenant)['"]\)|request\.json\(\)[\s\S]*tenantId[\s\S]*(?:authorize|allow)/i.test(source);
  return serverGuard && safeErrorBoundary && !clientRoleAuthority && !clientTenantAuthority;
}

export function hasAwaitedOfflinePurge(source) {
  return /await\s+(?:dependencies\.)?clearAllOfflineData\s*\(/.test(source)
    || /await\s+Promise\.allSettled\([\s\S]*clearAllOfflineData/.test(source);
}

export function hasAwaitedCachePurge(source) {
  return /await\s+(?:dependencies\.)?purgeServiceWorkerCaches\s*\(/.test(source)
    || /await\s+Promise\.allSettled\([\s\S]*purgeServiceWorkerCaches/.test(source);
}

export function hasCanonicalSafeSignOut(source) {
  const implementation = source.match(/(?:export\s+)?async function (?:executeAuthenticatedSignOut|signOut)\b[\s\S]*?(?=\n(?:export\s+)?(?:async\s+)?function|$)/)?.[0] ?? source;
  const server = implementation.indexOf('terminateAuthoritySession');
  const offline = implementation.indexOf('clearAllOfflineData');
  const cache = implementation.indexOf('purgeServiceWorkerCaches');
  const delegatedCleanup = /purgeSignedOutBrowserState\s*\(/.test(implementation) && /await\s+purgeSignedOutBrowserState/.test(implementation);
  const failClosed = /SIGNED_OUT_CLEANUP_REQUIRED|LOCAL_CLEANUP_FAILED/.test(source);
  const noRestore = !/restore(?:Authority|Authenticated|Session)|status:\s*['"]AUTHENTICATED['"][\s\S]*(?:catch|failure)/i.test(source);
  const cleanupPresent = (offline > server && cache > server && hasAwaitedOfflinePurge(implementation) && hasAwaitedCachePurge(implementation)) || delegatedCleanup;
  return server >= 0 && cleanupPresent && failClosed && noRestore;
}

export function hasCanonicalSafeErrorMapping(source) {
  const mapper = /mapPublicAuthorityError|SAFE_MESSAGES/.test(source);
  const correlation = /correlation(?:Id|_id)/.test(source);
  const diagnostics = /recordServerDiagnostic|ServerDiagnosticRecord/.test(source);
  const rawResponse = /Response\.json\([\s\S]{0,240}(?:error|exception)\.(?:message|stack)|message\s*:\s*(?:error|exception)\.(?:message|stack)/.test(source);
  const stackResponse = /stack\s*:\s*(?:error|exception)\.stack/.test(source);
  return mapper && correlation && diagnostics && !rawResponse && !stackResponse;
}

export function hasGuardedSettingsRoute(source) {
  return /authorizeWave1Request\s*\(/.test(source)
    && /action:\s*['"]membership\/manage['"]/.test(source)
    && /resourceType:\s*['"]membership['"]/.test(source)
    && /redirect\(['"]\/app\?denied=settings['"]\)/.test(source);
}

export function inspectFixture(detector, source) {
  switch (detector) {
    case 'authorization-guard': return hasCanonicalAuthorizationGuard(source);
    case 'offline-data-purge': return hasAwaitedOfflinePurge(source);
    case 'service-worker-cache-purge': return hasAwaitedCachePurge(source);
    case 'safe-sign-out': return hasCanonicalSafeSignOut(source);
    case 'safe-api-error-mapping': return hasCanonicalSafeErrorMapping(source);
    case 'settings-route-guard': return hasGuardedSettingsRoute(source);
    default: return false;
  }
}
