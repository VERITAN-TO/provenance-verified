'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { operationalDataset } from '@/operations/fixtures';

export function SignInAccess() {
  const router = useRouter();
  const [sessionId, setSessionId] = useState('session_intake');
  const session = operationalDataset.sessions.find((item) => item.id === sessionId)!;
  const tenant = operationalDataset.tenants.find((item) => item.id === session.tenantId)!;

  function enterTestMode() {
    localStorage.setItem('pv-test-session-id', sessionId);
    localStorage.setItem('pv-test-session-selected-at', new Date().toISOString());
    router.push('/app');
  }

  return (
    <div className="signin-access-grid">
      <section className="access-console">
        <div className="access-console-head"><span>TEST MODE IDENTITY</span><strong>NON-PRODUCTION</strong></div>
        <label htmlFor="test-session">Operational role</label>
        <select id="test-session" value={sessionId} onChange={(event) => setSessionId(event.target.value)}>
          {operationalDataset.sessions.filter((item) => item.tenantId === 'tenant_northstar').map((item) => (
            <option key={item.id} value={item.id}>{item.displayName} — {item.role}</option>
          ))}
        </select>
        <dl>
          <div><dt>Organization</dt><dd>{tenant.displayName}</dd></div>
          <div><dt>Role</dt><dd>{session.role}</dd></div>
          <div><dt>Device</dt><dd>{session.deviceId}</dd></div>
          <div><dt>Locations</dt><dd>{session.locationIds.join(', ')}</dd></div>
        </dl>
        <button className="button button-primary" type="button" onClick={enterTestMode}>Enter operational Test Mode</button>
        <p>This selects a deterministic fixture session. It does not create an account, authenticate a production identity, or grant external authority.</p>
      </section>
      <aside className="signin-boundary">
        <span>PRODUCTION ACCESS BOUNDARY</span>
        <h2>Identity is an authority control, not a decorative login screen.</h2>
        <p>A live deployment requires enterprise identity, MFA, tenant provisioning, session revocation, device controls, recovery, risk evaluation, least-privilege authorization, and immutable audit evidence.</p>
        <ul>
          <li>Tenant and location scope enforced server-side</li>
          <li>Reviewer identity bound to the authenticated session</li>
          <li>Tier 4 approvals require distinct authorized people</li>
          <li>CUSTOS, signing, publication, revocation, and mark control remain separate</li>
        </ul>
      </aside>
    </div>
  );
}
