'use client';

import Image from 'next/image';
import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { resolveAuthoritativeContext } from './authenticated/authority-client';
import {
  denialFromEnvelope,
  parseEligibleTenants,
  safeDenial,
  type EligibleTenant,
  type SafeDenial,
} from './authenticated/authority-contracts';
import styles from './authenticated/AuthorityExperience.module.css';

type Stage = 'credentials' | 'enroll' | 'mfa' | 'tenant';
type TenantSelectionSource = 'sign-in' | 'session';
type JsonResponse = { response: Response; body: unknown };

const record = (value: unknown): Record<string, unknown> | null =>
  typeof value === 'object' && value !== null ? value as Record<string, unknown> : null;
const text = (value: unknown): string | null => typeof value === 'string' && value.trim() ? value.trim() : null;

async function requestJson(url: string, init: RequestInit, timeoutMs = 9000): Promise<JsonResponse> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      ...init,
      cache: 'no-store',
      credentials: 'same-origin',
      signal: controller.signal,
    });
    let body: unknown = {};
    try { body = await response.json(); } catch { /* malformed bodies fail closed below */ }
    return { response, body };
  } finally {
    clearTimeout(timer);
  }
}

async function postCredentials(email: string, password: string, tenantId?: string): Promise<JsonResponse> {
  return requestJson('/api/v1/auth/sign-in', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, ...(tenantId ? { tenantId } : {}) }),
  });
}

export function AuthoritySignInAccess({ environment }: { environment: 'pilot' | 'production' }) {
  const router = useRouter();
  const [stage, setStage] = useState<Stage>('credentials');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [factorId, setFactorId] = useState('');
  const [challengeId, setChallengeId] = useState('');
  const [code, setCode] = useState('');
  const [qrCode, setQrCode] = useState('');
  const [totpSecret, setTotpSecret] = useState('');
  const [tenants, setTenants] = useState<EligibleTenant[]>([]);
  const [tenantSelectionSource, setTenantSelectionSource] = useState<TenantSelectionSource>('session');
  const [busy, setBusy] = useState(false);
  const [denial, setDenial] = useState<SafeDenial>();
  const [status, setStatus] = useState('Enter your organization credentials.');
  const errorRef = useRef<HTMLDivElement>(null);

  function showDenial(next: SafeDenial) {
    setDenial(next);
    setTimeout(() => errorRef.current?.focus(), 0);
  }

  async function finishContext(tenantId?: string) {
    const result = await resolveAuthoritativeContext(tenantId);
    if (result.kind === 'tenant-selection') {
      setTenants(result.tenants);
      setTenantSelectionSource('session');
      setStage('tenant');
      setStatus('Choose one server-returned eligible organization for revalidation.');
      return;
    }
    if (result.kind === 'deny') {
      showDenial(result.denial);
      return;
    }
    setStatus('Authoritative session confirmed. Opening protected foundation.');
    router.replace('/app');
    router.refresh();
  }

  async function beginMfa(enrollmentRequired: boolean) {
    if (enrollmentRequired) {
      const { response, body } = await requestJson('/api/v1/auth/mfa/enroll', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ friendlyName: `PROVENANCE VERIFIED™ ${environment}` }),
      });
      if (!response.ok) {
        showDenial(denialFromEnvelope(body, response.status));
        return;
      }
      const data = record(record(body)?.data);
      const nextFactorId = text(data?.factorId);
      const secret = text(data?.secret);
      if (!nextFactorId || !secret) {
        showDenial(safeDenial('DENY_MALFORMED_RESPONSE'));
        return;
      }
      setFactorId(nextFactorId);
      setQrCode(text(data?.qrCode) ?? '');
      setTotpSecret(secret);
      setChallengeId('');
      setCode('');
      setStage('enroll');
      setStatus('Enroll an authenticator, then enter the first current code.');
      return;
    }

    const { response, body } = await requestJson('/api/v1/auth/mfa/challenge', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{}',
    });
    if (!response.ok) {
      showDenial(denialFromEnvelope(body, response.status));
      return;
    }
    const data = record(record(body)?.data);
    const nextFactorId = text(data?.factorId);
    const nextChallengeId = text(data?.challengeId);
    if (!nextFactorId || !nextChallengeId) {
      showDenial(safeDenial('DENY_MALFORMED_RESPONSE'));
      return;
    }
    setFactorId(nextFactorId);
    setChallengeId(nextChallengeId);
    setCode('');
    setStage('mfa');
    setStatus('Enter the current code from your enrolled authenticator.');
  }

  async function authenticate(tenantId?: string) {
    const { response, body } = await postCredentials(email.trim(), password, tenantId);
    const root = record(body);
    const data = record(root?.data);

    if (response.status === 409) {
      const eligible = parseEligibleTenants(data?.memberships ?? data?.eligibleTenants);
      if (eligible.length) {
        setTenants(eligible);
        setTenantSelectionSource('sign-in');
        setStage('tenant');
        setStatus('Choose one eligible organization. Credentials will be revalidated with that selection.');
        return;
      }
    }
    if (!response.ok) {
      showDenial(denialFromEnvelope(body, response.status));
      return;
    }
    const mfaRequired = data?.mfaRequired === true;
    if (mfaRequired) {
      await beginMfa(data?.mfaEnrollmentRequired === true);
      return;
    }
    await finishContext();
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setDenial(undefined);
    if (!email.trim() || password.length < 8) {
      showDenial(safeDenial('DENY_UNAUTHENTICATED'));
      return;
    }
    setBusy(true);
    setStatus('Authenticating and resolving server authority.');
    try {
      await authenticate();
    } catch (error) {
      showDenial(safeDenial(error instanceof DOMException && error.name === 'AbortError'
        ? 'DENY_AUTHORITY_UNAVAILABLE'
        : 'DENY_NETWORK_FAILURE'));
    } finally {
      setBusy(false);
    }
  }

  async function verifyMfa(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setDenial(undefined);
    if (!factorId || !/^\d{6,8}$/.test(code)) {
      showDenial(safeDenial('DENY_VALIDATION'));
      return;
    }
    setBusy(true);
    setStatus('Verifying the second factor.');
    try {
      let activeChallengeId = challengeId;
      if (!activeChallengeId) {
        const challenge = await requestJson('/api/v1/auth/mfa/challenge', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ factorId }),
        });
        if (!challenge.response.ok) {
          showDenial(denialFromEnvelope(challenge.body, challenge.response.status));
          return;
        }
        activeChallengeId = text(record(record(challenge.body)?.data)?.challengeId) ?? '';
        if (!activeChallengeId) {
          showDenial(safeDenial('DENY_MALFORMED_RESPONSE'));
          return;
        }
        setChallengeId(activeChallengeId);
      }
      const verified = await requestJson('/api/v1/auth/mfa/verify', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ factorId, challengeId: activeChallengeId, code }),
      });
      if (!verified.response.ok) {
        showDenial(denialFromEnvelope(verified.body, verified.response.status));
        return;
      }
      setStatus('AAL2 identity confirmed. Resolving tenant authority.');
      await finishContext();
    } catch (error) {
      showDenial(safeDenial(error instanceof DOMException && error.name === 'AbortError'
        ? 'DENY_AUTHORITY_UNAVAILABLE'
        : 'DENY_NETWORK_FAILURE'));
    } finally {
      setBusy(false);
    }
  }

  async function chooseTenant(tenantId: string) {
    if (busy) return;
    setBusy(true);
    setDenial(undefined);
    setStatus('Revalidating the selected organization against canonical membership.');
    try {
      if (tenantSelectionSource === 'sign-in') await authenticate(tenantId);
      else await finishContext(tenantId);
    } catch (error) {
      showDenial(safeDenial(error instanceof DOMException && error.name === 'AbortError'
        ? 'DENY_AUTHORITY_UNAVAILABLE'
        : 'DENY_NETWORK_FAILURE'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={styles.signin}>
      <section className={styles.panel}>
        <span className={styles.kicker}>{environment.toUpperCase()} IDENTITY</span>
        <h2>Authenticate into the governed organization workspace.</h2>

        {stage === 'credentials' ? (
          <form className={styles.form} onSubmit={submit} noValidate>
            <label htmlFor="authority-email">Email</label>
            <input className={styles.input} id="authority-email" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} aria-invalid={Boolean(denial)} />
            <label htmlFor="authority-password">Password</label>
            <input className={styles.input} id="authority-password" type="password" autoComplete="current-password" minLength={8} required value={password} onChange={(event) => setPassword(event.target.value)} aria-invalid={Boolean(denial)} />
            <button className={`${styles.button} ${styles.primary}`} disabled={busy} type="submit">{busy ? 'Resolving authority…' : 'Continue securely'}</button>
          </form>
        ) : null}

        {stage === 'enroll' ? (
          <form className={styles.form} onSubmit={verifyMfa}>
            <div className={styles.mfaEnrollment}>
              {qrCode ? <Image className={styles.qr} src={qrCode} alt="Authenticator enrollment QR code" width={220} height={220} unoptimized /> : null}
              <div><strong>Manual setup key</strong><code className={styles.secret}>{totpSecret}</code><small>Store this only in your authenticator. The plaintext key is not retained by the product shell.</small></div>
            </div>
            <label htmlFor="authority-enroll-code">First authenticator code</label>
            <input className={styles.input} id="authority-enroll-code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6,8}" required value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))} />
            <button className={`${styles.button} ${styles.primary}`} disabled={busy} type="submit">{busy ? 'Verifying…' : 'Complete MFA enrollment'}</button>
          </form>
        ) : null}

        {stage === 'mfa' ? (
          <form className={styles.form} onSubmit={verifyMfa}>
            <label htmlFor="authority-mfa-code">Authenticator code</label>
            <input className={styles.input} id="authority-mfa-code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6,8}" required value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))} />
            <button className={`${styles.button} ${styles.primary}`} disabled={busy} type="submit">{busy ? 'Verifying…' : 'Verify second factor'}</button>
          </form>
        ) : null}

        {stage === 'tenant' ? (
          <div className={styles.tenantList} aria-label="Eligible organizations">
            {tenants.map((tenant) => (
              <button className={styles.tenant} disabled={busy} type="button" key={`${tenant.tenantId}:${tenant.role}`} onClick={() => void chooseTenant(tenant.tenantId)}>
                <strong>{tenant.displayName}</strong><small>{tenant.role}</small>
              </button>
            ))}
          </div>
        ) : null}

        <p className={styles.statusLine} role="status" aria-live="polite">{status}</p>
        {denial ? <div className={styles.error} ref={errorRef} tabIndex={-1} role="alert"><strong>{denial.title}</strong><p>{denial.message}</p>{denial.correlationId ? <small>Reference: {denial.correlationId}</small> : null}</div> : null}
      </section>
      <aside className={styles.panel}>
        <span className={styles.kicker}>SERVER-CONTROLLED AUTHORITY</span>
        <h2>Credentials alone never expose private tenant content.</h2>
        <p>The browser waits for verified session custody, AAL2 when required, canonical actor, canonical tenant, active membership, role, ALLOW decision, and current authority version. A successful HTTP status without the complete context is denied.</p>
      </aside>
    </div>
  );
}
