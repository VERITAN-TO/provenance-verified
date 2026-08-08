'use client';

import { useState } from 'react';
import Link from 'next/link';
import { fixtureList } from '@/domain/fixtures';
import { STAGES } from '@/domain/constants';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { TierSeal } from './TierSeal';
import { RouteShell } from './RouteShell';
import { Metric, StatePill } from './phase3/Shared';

export function VerifyRoute() {
  const fixture = useProvenanceStore((state) => state.fixture);
  const credential = useProvenanceStore((state) => state.credential);
  const decision = useProvenanceStore((state) => state.decision);
  const events = useProvenanceStore((state) => state.events);
  const webhooks = useProvenanceStore((state) => state.webhooks);
  const stageIndex = useProvenanceStore((state) => state.stageIndex);
  const selectFixture = useProvenanceStore((state) => state.selectFixture);
  const setStage = useProvenanceStore((state) => state.setStage);
  const run = useProvenanceStore((state) => state.runVerification);
  const runState = useProvenanceStore((state) => state.runState);
  const [id, setId] = useState(fixture.publicId);
  const [error, setError] = useState('');

  const resolve = async () => {
    const match = fixtureList.find((item) => item.publicId === id.trim().toUpperCase());
    if (!match) {
      setError('Record not found in the deterministic fixture library.');
      return;
    }
    setError('');
    selectFixture(match.key);
    await run();
  };

  const issued = credential.status === 'issued';
  const markAuthorized = issued && credential.sealAuthorization.status === 'authorized';
  const registryPublished = issued && credential.authorization.status === 'authorized';

  return (
    <RouteShell eyebrow="VERIFICATION ENTRY" title="Resolve evidence eligibility and issuance authority without collapsing them." lede="Use a deterministic public ID to inspect evidence depth, reviewer gates, issuer authorization, credential state, registry publication, signed consequences, lifecycle, and certification-mark control." aside={<TierSeal tier={decision.tier} compact authorized={markAuthorized} />}>
      <div className="p3-verify-route">
        <section className="p3-route-verify-input" aria-labelledby="verify-input-title">
          <div className="p3-panel-head"><span id="verify-input-title">VERIFICATION REQUEST</span><strong>TEST MODE</strong></div>
          <label htmlFor="route-verify-id">Public ID</label>
          <div className="p3-input-row"><input id="route-verify-id" value={id} onChange={(event) => setId(event.target.value.toUpperCase())} /><button className="button button-primary" onClick={() => void resolve()} disabled={runState === 'running'}>{runState === 'running' ? 'Resolving…' : 'Resolve record'}</button></div>
          {error ? <p className="form-error" role="alert">{error}</p> : null}
          <label htmlFor="route-fixture">Deterministic scenario</label>
          <select id="route-fixture" aria-label="Select deterministic fixture" value={fixture.key} onChange={(event) => { selectFixture(event.target.value); const next = fixtureList.find((item) => item.key === event.target.value); if (next) setId(next.publicId); }}>{fixtureList.map((item) => <option key={item.key} value={item.key}>{item.name} — {item.publicId}</option>)}</select>
          <p>{fixture.description}</p>
        </section>

        <section className="p3-route-verify-result" aria-labelledby="verify-result-title">
          <div className="p3-panel-head"><span id="verify-result-title">CANONICAL RESULT</span><StatePill tone={runState === 'complete' ? 'good' : runState === 'error' ? 'warn' : 'cyan'}>{runState}</StatePill></div>
          <div className="p3-route-result-identity"><TierSeal tier={decision.tier} authorized={markAuthorized} /><div><span>Evidence eligibility</span><h2>Tier {decision.tier} · {decision.tierName}</h2><p>{decision.disclosure}</p></div></div>
          <div className="p3-route-result-metrics"><Metric label="Credential" value={issued ? `Issued Tier ${credential.tier}` : 'Not issued'} detail={credential.authorization.status} /><Metric label="Registry" value={registryPublished ? 'Published' : 'Not published'} detail={credential.lifecycle} /><Metric label="Signature" value={credential.signature.status} detail={credential.signature.keyId} /><Metric label="Mark" value={credential.sealAuthorization.status} detail={markAuthorized ? 'Controlled seal available' : 'Seal withheld'} /></div>
          {credential.authorization.blockers.length ? <div className="p3-blocker-list"><strong>ISSUANCE BLOCKED</strong>{credential.authorization.blockers.map((blocker) => <span key={blocker}>{blocker}</span>)}</div> : null}
          <div className="p3-route-result-actions">{issued ? <Link href={`/registry/${credential.publicId}`} className="button button-primary">Open registry record</Link> : <span className="button button-secondary" aria-disabled="true">No public registry record</span>}<Link href={`/api/v1/registry/${credential.publicId}`} className="button button-secondary">Open machine response</Link></div>
        </section>

        <section className="p3-route-proof-loop" aria-labelledby="proof-loop-title">
          <div className="p3-route-section-head"><div><span>COMPLETE PROOF LOOP</span><h2 id="proof-loop-title">One request drives every consequence.</h2></div><strong>{events.length} signed events · {webhooks.length} delivery attempts</strong></div>
          <div className="p3-route-stage-grid">{STAGES.map((stage, index) => <button key={stage.id} type="button" className={index === stageIndex ? 'active' : index < stageIndex ? 'complete' : ''} onClick={() => setStage(index)}><b>{String(index + 1).padStart(2,'0')}</b><strong>{stage.label}</strong><span>{stage.detail}</span></button>)}</div>
          <div className="p3-route-consequence-grid"><Metric label="Claim determinations" value={credential.claims.length} detail={`${credential.claims.filter((claim) => claim.status === 'verified').length} verified`} /><Metric label="Evidence objects" value={credential.evidence.length} detail={`${credential.sources.filter((source) => source.independent && source.qualified).length} independent qualified sources`} /><Metric label="Authority approvals" value={`${credential.authorization.acceptedApprovalCount}/${credential.authorization.requiredApprovalCount}`} detail={credential.authorization.status} /><Metric label="Integrity digest" value={credential.integrityHash} detail="Shared by public and machine projections" /></div>
        </section>
      </div>
    </RouteShell>
  );
}
