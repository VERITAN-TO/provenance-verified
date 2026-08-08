import type { AuthorityContext, EligibleTenant, SafeDenial } from './authority-contracts';
export type AuthorityStatus = 'BOOTING'|'UNAUTHENTICATED'|'AUTHENTICATING'|'RESOLVING_SESSION'|'AUTHENTICATED'|'CHANGING_TENANT'|'DENIED'|'EXPIRED'|'AUTHORITY_UNAVAILABLE'|'NETWORK_FAILURE'|'SIGNING_OUT'|'SIGNED_OUT_CLEANUP_REQUIRED';
export type AuthorityViewState = { status: AuthorityStatus; context?: AuthorityContext; denial?: SafeDenial; eligibleTenants?: EligibleTenant[]; message?: string };
export const initialAuthorityState: AuthorityViewState = { status:'BOOTING' };
const transitions: Record<AuthorityStatus, AuthorityStatus[]> = {
  BOOTING:['RESOLVING_SESSION','UNAUTHENTICATED','DENIED','EXPIRED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE'],
  UNAUTHENTICATED:['AUTHENTICATING','RESOLVING_SESSION'], AUTHENTICATING:['RESOLVING_SESSION','UNAUTHENTICATED','DENIED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE'],
  RESOLVING_SESSION:['AUTHENTICATED','CHANGING_TENANT','UNAUTHENTICATED','DENIED','EXPIRED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE'],
  AUTHENTICATED:['CHANGING_TENANT','EXPIRED','SIGNING_OUT','DENIED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE'],
  CHANGING_TENANT:['AUTHENTICATED','CHANGING_TENANT','DENIED','EXPIRED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE','SIGNING_OUT'],
  DENIED:['RESOLVING_SESSION','AUTHENTICATING','SIGNING_OUT'], EXPIRED:['AUTHENTICATING','SIGNING_OUT'],
  AUTHORITY_UNAVAILABLE:['RESOLVING_SESSION','AUTHENTICATING','SIGNING_OUT'], NETWORK_FAILURE:['RESOLVING_SESSION','AUTHENTICATING','SIGNING_OUT'],
  SIGNING_OUT:['UNAUTHENTICATED','SIGNED_OUT_CLEANUP_REQUIRED'],
  SIGNED_OUT_CLEANUP_REQUIRED:['SIGNING_OUT','UNAUTHENTICATED'],
};
export function transitionAuthorityState(current: AuthorityViewState, next: AuthorityViewState): AuthorityViewState {
  if (!transitions[current.status].includes(next.status)) return current;
  if (next.status === 'AUTHENTICATED' && !next.context) return current;
  return next;
}
export function stateForDenial(denial: SafeDenial): AuthorityViewState {
  if (denial.code === 'DENY_UNAUTHENTICATED') return {status:'UNAUTHENTICATED',denial};
  if (denial.code === 'DENY_SESSION_EXPIRED') return {status:'EXPIRED',denial};
  if (denial.code === 'DENY_AUTHORITY_UNAVAILABLE') return {status:'AUTHORITY_UNAVAILABLE',denial};
  if (denial.code === 'DENY_NETWORK_FAILURE') return {status:'NETWORK_FAILURE',denial};
  return {status:'DENIED',denial};
}
export function canRetryState(state: AuthorityViewState): boolean { return Boolean(state.denial?.retryable && (state.status === 'AUTHORITY_UNAVAILABLE' || state.status === 'NETWORK_FAILURE')); }
