// detector: safe-sign-out
export async function signOut() {
  await terminateAuthoritySession();
  const settled = await Promise.allSettled([clearAllOfflineData(), purgeServiceWorkerCaches()]);
  if (settled.some((entry) => entry.status === 'rejected')) return { status: 'SIGNED_OUT_CLEANUP_REQUIRED' };
  return { status: 'SIGNED_OUT' };
}
