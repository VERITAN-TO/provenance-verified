// detector: safe-sign-out
export async function signOut(){await terminateAuthoritySession();await clearAllOfflineData();await purgeServiceWorkerCaches();try{}catch{restoreSession();}}
