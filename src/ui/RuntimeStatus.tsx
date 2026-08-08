'use client';

import { useEffect, useState } from 'react';

type Dependency = { ready: boolean; status: number };
type RuntimeStatusData = {
  environment: 'sandbox' | 'pilot' | 'production';
  operational: boolean;
  productionActivated: boolean;
  authoritativeIssuanceEnabled: boolean;
  certificationMarksEnabled: boolean;
  registryReady: boolean;
  revocationReady: boolean;
  dependencies: Record<string, Dependency>;
  checkedAt: string;
};

export function RuntimeStatus() {
  const [data, setData] = useState<RuntimeStatusData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    fetch('/api/v1/status', { cache: 'no-store' })
      .then(async (response) => {
        const body = await response.json() as { data?: RuntimeStatusData; error?: { message?: string } };
        if (!body.data) throw new Error(body.error?.message ?? `Status unavailable (${response.status})`);
        return body.data;
      })
      .then((next) => { if (active) setData(next); })
      .catch((caught) => { if (active) setError(caught instanceof Error ? caught.message : 'Status unavailable'); });
    return () => { active = false; };
  }, []);

  if (error) return <div className="status-panel"><div className="status-summary"><span className="status-dot" /><div><strong>Authority status unavailable</strong><p>{error}. The platform remains fail closed.</p></div></div></div>;
  if (!data) return <div className="status-panel"><div className="status-summary"><span className="status-dot" /><div><strong>Checking authority dependencies</strong><p>No optimistic status is shown before verification.</p></div></div></div>;

  const headline = data.environment === 'sandbox'
    ? 'Deterministic Test Mode is available'
    : data.environment === 'pilot'
      ? data.operational ? 'Production-connected pilot services are available' : 'Pilot authority dependencies are degraded'
      : data.productionActivated && data.operational ? 'Production authority is active' : 'Production authority is not active';

  return <div className="status-panel">
    <div className="status-summary"><span className={`status-dot ${data.operational ? 'complete' : ''}`} /><div><strong>{headline}</strong><p>Verified {data.checkedAt} · {data.environment.toUpperCase()} · fail closed</p></div></div>
    <div className="status-row"><span>Authoritative credential issuance</span><strong>{data.authoritativeIssuanceEnabled && data.productionActivated ? 'Enabled' : 'Disabled'}</strong></div>
    <div className="status-row"><span>Certification marks</span><strong>{data.certificationMarksEnabled && data.productionActivated ? 'Enabled' : 'Suppressed'}</strong></div>
    <div className="status-row"><span>Registry publication</span><strong>{data.registryReady ? 'Ready' : 'Unavailable'}</strong></div>
    <div className="status-row"><span>Revocation control</span><strong>{data.revocationReady ? 'Ready' : 'Unavailable'}</strong></div>
    {Object.entries(data.dependencies).map(([name, dependency]) => <div className="status-row" key={name}><span>{name.replace(/[A-Z]/g, (letter) => ` ${letter.toLowerCase()}`)}</span><strong>{dependency.ready ? 'Available' : `Unavailable · ${dependency.status}`}</strong></div>)}
    <article className="status-incident"><small>AUTHORITY BOUNDARY</small><h2>{data.environment === 'sandbox' ? 'Test Mode cannot issue production credentials.' : data.productionActivated ? 'Activation record verified.' : 'No production authority is claimed.'}</h2><p>Identity, evidence custody, review independence, CUSTOS, signing, registry, revocation, mark authorization and audit dependencies must all remain available. A missing dependency denies the consequential write.</p></article>
  </div>;
}
