// detector: safe-sign-out
export async function signOut(){await terminateAuthoritySession();location.replace('/sign-in');}
