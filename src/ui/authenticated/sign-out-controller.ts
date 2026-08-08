export type SignOutDependencies = {
  terminateAuthoritySession: () => Promise<void>;
  clearAllOfflineData: () => Promise<void>;
  purgeServiceWorkerCaches: () => Promise<void>;
  clearNonAuthoritativeClientState: () => void;
};

export type SignOutOutcome =
  | { status: 'SIGNED_OUT' }
  | { status: 'SERVER_INVALIDATION_FAILED'; cleanupFailures: string[] }
  | { status: 'LOCAL_CLEANUP_FAILED'; cleanupFailures: string[] };

export async function purgeSignedOutBrowserState(dependencies: Omit<SignOutDependencies, 'terminateAuthoritySession'>): Promise<string[]> {
  const settled = await Promise.allSettled([
    Promise.resolve().then(dependencies.clearAllOfflineData),
    Promise.resolve().then(dependencies.purgeServiceWorkerCaches),
  ]);
  const failures: string[] = [];
  if (settled[0].status === 'rejected') failures.push('OFFLINE_DATA_PURGE');
  if (settled[1].status === 'rejected') failures.push('SERVICE_WORKER_CACHE_PURGE');
  try {
    dependencies.clearNonAuthoritativeClientState();
  } catch {
    failures.push('CLIENT_MARKER_PURGE');
  }
  return failures;
}

export async function executeAuthenticatedSignOut(dependencies: SignOutDependencies): Promise<SignOutOutcome> {
  let serverInvalidated = false;
  try {
    await dependencies.terminateAuthoritySession();
    serverInvalidated = true;
  } catch {
    serverInvalidated = false;
  }
  const cleanupFailures = await purgeSignedOutBrowserState(dependencies);
  if (!serverInvalidated) return { status: 'SERVER_INVALIDATION_FAILED', cleanupFailures };
  if (cleanupFailures.length) return { status: 'LOCAL_CLEANUP_FAILED', cleanupFailures };
  return { status: 'SIGNED_OUT' };
}

export async function retrySignedOutCleanup(dependencies: Omit<SignOutDependencies, 'terminateAuthoritySession'>): Promise<SignOutOutcome> {
  const cleanupFailures = await purgeSignedOutBrowserState(dependencies);
  return cleanupFailures.length
    ? { status: 'LOCAL_CLEANUP_FAILED', cleanupFailures }
    : { status: 'SIGNED_OUT' };
}
