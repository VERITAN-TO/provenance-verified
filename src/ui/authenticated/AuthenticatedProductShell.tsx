'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { usePathname } from 'next/navigation';
import { clearAllOfflineData, purgeServiceWorkerCaches } from '@/operations/offline/indexedDb';
import {
  clearNonAuthoritativeClientState,
  resolveAuthoritativeContext,
  terminateAuthoritySession,
} from './authority-client';
import { safeDenial, type EligibleTenant } from './authority-contracts';
import {
  executeAuthenticatedSignOut,
  retrySignedOutCleanup,
  type SignOutDependencies,
} from './sign-out-controller';
import {
  canRetryState,
  initialAuthorityState,
  stateForDenial,
  transitionAuthorityState,
  type AuthorityViewState,
} from './authority-state';
import styles from './AuthorityExperience.module.css';

const signOutDependencies: SignOutDependencies = {
  terminateAuthoritySession,
  clearAllOfflineData,
  purgeServiceWorkerCaches,
  clearNonAuthoritativeClientState,
};

export function AuthenticatedProductShell({
  environment,
  children,
}: {
  environment: 'pilot' | 'production';
  children: ReactNode;
}) {
  const pathname = usePathname();
  const [state, setState] = useState<AuthorityViewState>(initialAuthorityState);
  const [tenantBusy, setTenantBusy] = useState(false);
  const [signOutBusy, setSignOutBusy] = useState(false);
  const [signOutFailure, setSignOutFailure] = useState<'server' | 'cleanup' | null>(null);
  const focusRef = useRef<HTMLHeadingElement>(null);
  const move = useCallback((next: AuthorityViewState) => setState((current) => transitionAuthorityState(current, next)), []);

  const resolve = useCallback(async (tenantId?: string, tenants?: EligibleTenant[]) => {
    if (!tenantId) move({ status: 'RESOLVING_SESSION' });
    const result = await resolveAuthoritativeContext(tenantId);
    if (result.kind === 'tenant-selection') {
      move({
        status: 'CHANGING_TENANT',
        eligibleTenants: result.tenants,
        denial: safeDenial('DENY_TENANT_AMBIGUOUS', result.correlationId),
      });
      return;
    }
    if (result.kind === 'deny') {
      move(stateForDenial(result.denial));
      return;
    }
    if (Date.parse(result.context.session.expiresAt) <= Date.now()) {
      move({ status: 'EXPIRED', denial: safeDenial('DENY_SESSION_EXPIRED') });
      return;
    }
    move({
      status: 'AUTHENTICATED',
      context: result.context,
      eligibleTenants: tenants ?? result.context.eligibleTenants,
    });
  }, [move]);

  useEffect(() => { void resolve(); }, [resolve]);
  useEffect(() => {
    if (state.status === 'AUTHENTICATED' && state.context) {
      const milliseconds = Date.parse(state.context.session.expiresAt) - Date.now();
      const timer = setTimeout(
        () => move({ status: 'EXPIRED', denial: safeDenial('DENY_SESSION_EXPIRED') }),
        Math.max(0, Math.min(milliseconds, 2_147_000_000)),
      );
      return () => clearTimeout(timer);
    }
    return undefined;
  }, [state.status, state.context, move]);
  useEffect(() => {
    if (['DENIED','EXPIRED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE','CHANGING_TENANT','SIGNED_OUT_CLEANUP_REQUIRED'].includes(state.status)) {
      focusRef.current?.focus();
    }
  }, [state.status]);

  async function chooseTenant(id: string) {
    if (tenantBusy) return;
    setTenantBusy(true);
    try { await resolve(id, state.eligibleTenants); } finally { setTenantBusy(false); }
  }

  async function finishSuccessfulSignOut() {
    move({ status: 'UNAUTHENTICATED' });
    location.replace('/sign-in?reason=signed-out');
  }

  async function signOut() {
    if (signOutBusy) return;
    setSignOutBusy(true);
    setSignOutFailure(null);
    move({ status: 'SIGNING_OUT' });
    try {
      const outcome = await executeAuthenticatedSignOut(signOutDependencies);
      if (outcome.status === 'SIGNED_OUT') {
        await finishSuccessfulSignOut();
        return;
      }
      const localCleanupFailure = outcome.status === 'LOCAL_CLEANUP_FAILED';
      setSignOutFailure(localCleanupFailure ? 'cleanup' : 'server');
      move({
        status: 'SIGNED_OUT_CLEANUP_REQUIRED',
        message: localCleanupFailure
          ? 'Your server session is signed out, but protected browser data could not be fully removed. Retry cleanup before continuing.'
          : 'Protected access is disabled, but server sign-out could not be confirmed. Retry sign-out before continuing.',
      });
    } finally {
      setSignOutBusy(false);
    }
  }

  async function retryCleanup() {
    if (signOutBusy) return;
    setSignOutBusy(true);
    move({ status: 'SIGNING_OUT' });
    try {
      const outcome = signOutFailure === 'server'
        ? await executeAuthenticatedSignOut(signOutDependencies)
        : await retrySignedOutCleanup(signOutDependencies);
      if (outcome.status === 'SIGNED_OUT') {
        await finishSuccessfulSignOut();
        return;
      }
      setSignOutFailure(outcome.status === 'LOCAL_CLEANUP_FAILED' ? 'cleanup' : 'server');
      move({
        status: 'SIGNED_OUT_CLEANUP_REQUIRED',
        message: outcome.status === 'LOCAL_CLEANUP_FAILED'
          ? 'Protected browser data is still being withheld until cleanup completes. Retry cleanup.'
          : 'Server sign-out is still unconfirmed. Protected access remains disabled. Retry sign-out.',
      });
    } finally {
      setSignOutBusy(false);
    }
  }

  const context = state.context;
  const settingsAuthorized = context?.navigation.settings === true;
  const isSettingsRoute = pathname === '/app/settings';
  const activeLink = (href: string) => pathname === href ? 'page' as const : undefined;

  return (
    <main className={styles.shell} id="main-content" data-environment={environment}>
      <div className={styles.grid}>
        <aside className={styles.side} aria-label="Protected navigation">
          <Link className={styles.brand} href="/app">
            <Image src="/r5/lockups/provenance-lockup-horizontal.svg" alt="PROVENANCE VERIFIED™" width={202} height={38} />
          </Link>
          <div className={styles.context}>
            <span>Authority context</span>
            <strong>{context ? context.tenant.displayName : 'Private content withheld'}</strong>
            <small>{context ? context.membership.role : state.status}</small>
          </div>
          <nav className={styles.nav} aria-label="Authenticated product">
            <Link href="/app" aria-current={activeLink('/app')}>Foundation</Link>
            {settingsAuthorized ? <Link href="/app/settings" aria-current={activeLink('/app/settings')}>Settings</Link> : null}
            <Link href="/docs">Documentation</Link>
            <Link href="/">Public authority</Link>
          </nav>
        </aside>
        <section className={styles.main}>
          <header className={styles.top}>
            <div>
              <span className={styles.kicker}>SLICE 1 / AUTHENTICATED FOUNDATION</span>
              <h1>{context ? context.tenant.displayName : 'Resolving authority'}</h1>
            </div>
            <div>
              <span className={styles.status}>{state.status}</span>
              {context ? <button className={styles.button} disabled={signOutBusy} onClick={() => void signOut()}>Sign out</button> : null}
            </div>
          </header>
          <div className={styles.content}>
            <section className={styles.boundary}>
              <div><span>Cookie admission</span><strong>Preliminary only</strong></div>
              <div><span>Actor and tenant</span><strong>Server derived</strong></div>
              <div><span>Role and decision</span><strong>Server controlled</strong></div>
              <div><span>Future-slice data</span><strong>Not loaded</strong></div>
            </section>

            {state.status === 'AUTHENTICATED' && context ? (
              pathname === '/app' ? (
                <section className={styles.card}>
                  <span className={styles.kicker}>AUTHORIZED EMPTY FOUNDATION</span>
                  <h2>The protected product shell is open. Later-slice operations remain closed.</h2>
                  <p>No lots, evidence, claims, reviews, credentials, marks, physical media, fulfillment, or shipping data is loaded in this slice.</p>
                  <div className={styles.proof}>
                    <div><span>Actor</span><strong>{context.actor.displayName ?? context.actor.actorId}</strong></div>
                    <div><span>Role</span><strong>{context.membership.role}</strong></div>
                    <div><span>Authority version</span><strong>{context.authorization.authorityVersion}</strong></div>
                    <div><span>Session</span><strong>{context.session.sessionId}</strong></div>
                    <div><span>Expires</span><strong>{new Date(context.session.expiresAt).toLocaleString()}</strong></div>
                    <div><span>Correlation</span><strong>{context.correlationId}</strong></div>
                  </div>
                  {context.eligibleTenants.length > 1 ? (
                    <div className={styles.actions}>
                      <button className={styles.button} onClick={() => move({ status: 'CHANGING_TENANT', eligibleTenants: context.eligibleTenants })}>Change organization</button>
                    </div>
                  ) : null}
                </section>
              ) : isSettingsRoute && settingsAuthorized ? (
                <section aria-label="Organization settings">{children}</section>
              ) : isSettingsRoute ? (
                <section className={styles.card} role="alert">
                  <span className={styles.kicker}>DENY_ACTION</span>
                  <h2 ref={focusRef} tabIndex={-1}>Settings authority is required.</h2>
                  <p>The server-authorized navigation projection did not permit this settings route.</p>
                  <Link className={`${styles.button} ${styles.primary}`} href="/app">Return to foundation</Link>
                </section>
              ) : (
                <section className={styles.card}>
                  <span className={styles.kicker}>ROUTE HELD FOR LATER SLICE</span>
                  <h2>This route is not available in the Slice 1 production foundation.</h2>
                  <p>Legacy fixture-backed operational surfaces are not production authority.</p>
                  <Link className={`${styles.button} ${styles.primary}`} href="/app">Return to foundation</Link>
                </section>
              )
            ) : null}

            {state.status === 'CHANGING_TENANT' ? (
              <section className={styles.card}>
                <span className={styles.kicker}>SERVER-RETURNED ELIGIBLE ORGANIZATIONS</span>
                <h2 ref={focusRef} tabIndex={-1}>Choose an organization for server revalidation.</h2>
                <p>No tenant is selected by default.</p>
                <div className={styles.tenants}>
                  {state.eligibleTenants?.map((tenant) => (
                    <button className={styles.tenant} disabled={tenantBusy} key={`${tenant.tenantId}:${tenant.role}`} onClick={() => void chooseTenant(tenant.tenantId)}>
                      <strong>{tenant.displayName}</strong><small>{tenant.role}</small>
                    </button>
                  ))}
                </div>
              </section>
            ) : null}

            {['BOOTING','RESOLVING_SESSION','SIGNING_OUT'].includes(state.status) ? (
              <section className={styles.card} aria-busy="true" aria-live="polite">
                <div className={styles.spinner} />
                <h2>{state.status === 'SIGNING_OUT' ? 'Removing protected session data.' : 'Resolving the authoritative session.'}</h2>
                <p>Private content remains withheld while the protected boundary is resolved.</p>
              </section>
            ) : null}

            {state.status === 'SIGNED_OUT_CLEANUP_REQUIRED' ? (
              <section className={styles.card} role="alert" aria-live="assertive">
                <span className={styles.kicker}>SIGNED OUT / CLEANUP REQUIRED</span>
                <h2 ref={focusRef} tabIndex={-1}>Protected access remains disabled.</h2>
                <p>{state.message}</p>
                <div className={styles.actions}>
                  <button className={`${styles.button} ${styles.primary}`} disabled={signOutBusy} onClick={() => void retryCleanup()}>
                    {signOutFailure === 'server' ? 'Retry sign-out' : 'Retry cleanup'}
                  </button>
                </div>
              </section>
            ) : null}

            {['UNAUTHENTICATED','DENIED','EXPIRED','AUTHORITY_UNAVAILABLE','NETWORK_FAILURE'].includes(state.status) ? (
              <section className={styles.card} role="alert">
                <span className={styles.kicker}>{state.denial?.code ?? state.status}</span>
                <h2 ref={focusRef} tabIndex={-1}>{state.denial?.title ?? 'Protected session unavailable'}</h2>
                <p>{state.denial?.message}</p>
                {state.denial?.correlationId ? <div className={styles.correlation}>Reference: {state.denial.correlationId}</div> : null}
                <div className={styles.actions}>
                  {canRetryState(state) ? <button className={`${styles.button} ${styles.primary}`} onClick={() => void resolve()}>Retry authority check</button> : null}
                  <Link className={styles.button} href="/sign-in">Sign in again</Link>
                  <Link className={styles.button} href="/">Return to public surface</Link>
                </div>
              </section>
            ) : null}
          </div>
        </section>
      </div>
    </main>
  );
}
