'use client';
import Link from 'next/link';
import { useMemo, useState } from 'react';
import { STAGES, TEST_MODE_LABELS } from '@/domain/constants';
import { fixtureList } from '@/domain/fixtures';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { SpatialEnvironment } from '@/spatial/SpatialEnvironment';
import { TierSeal } from './TierSeal';

function statusCode(runState: 'idle' | 'running' | 'complete' | 'error', issued: boolean) {
  if (runState === 'running') return '202 RUNNING';
  if (runState === 'error') return issued ? '422 ERROR' : '409 BLOCKED';
  if (runState === 'complete') return issued ? '200 ACTIVE' : '409 BLOCKED';
  return 'READY';
}

export function CoreHero() {
  const fixtureKey = useProvenanceStore((s) => s.fixtureKey);
  const decision = useProvenanceStore((s) => s.decision);
  const credential = useProvenanceStore((s) => s.credential);
  const stageIndex = useProvenanceStore((s) => s.stageIndex);
  const runState = useProvenanceStore((s) => s.runState);
  const events = useProvenanceStore((s) => s.events);
  const selectFixture = useProvenanceStore((s) => s.selectFixture);
  const setStage = useProvenanceStore((s) => s.setStage);
  const runVerification = useProvenanceStore((s) => s.runVerification);
  const [paused, setPaused] = useState(false);
  const issued = credential.status === 'issued';
  const markAuthorized = issued && credential.sealAuthorization.status === 'authorized';
  const displayTier = credential.tier ?? decision.tier;
  const displayTierName = credential.tierName ?? decision.tierName;
  const stage = STAGES[stageIndex];
  const machineProjection = useMemo(() => ({ public_id: credential.publicId, eligible_tier: decision.tier, issued_tier: credential.tier, credential_status: credential.status, issuance_status: credential.authorization.status, lifecycle: credential.lifecycle, stage: stage.id, registry: issued && stageIndex >= 5 ? 'published' : 'not_published', mark_authorization: credential.sealAuthorization.status }), [credential, decision.tier, issued, stage.id, stageIndex]);

  return <section className="core-hero" id="product" aria-labelledby="hero-title">
    <div className="core-hero-light-ray" aria-hidden="true" />
    <div className="core-hero-shell"><div className="core-hero-grid">
      <div className="core-hero-copy">
        <div className="core-hero-eyebrow">PV PROTOCOL / PROGRAMMABLE PROVENANCE</div>
        <h1 id="hero-title">Trust<br />infrastructure<br />for <em>AI.</em></h1>
        <p className="core-hero-lede">Verify physical assets with signed evidence, public registry status, and machine-readable provenance—through one API.</p>
        <div className="core-hero-actions"><button className="button button-primary core-primary" aria-label="Run verification" onClick={() => void runVerification()} disabled={runState === 'running'}>{runState === 'running' ? 'Running proof sequence…' : 'Get started'} <span aria-hidden="true">→</span></button><Link className="button button-secondary core-secondary" href="/verify">Verify an asset <span aria-hidden="true">⌕</span></Link><Link className="core-text-link" href="/docs">Documentation <span aria-hidden="true">→</span></Link></div>
        <div className="core-proofline" aria-label="Platform capabilities"><span><i />Signed evidence</span><span><i />Public registry</span><span><i />API + MCP contract</span></div>
      </div>
      <div className="core-stage-wrap">
        <div className="core-stage-topline" aria-hidden="true"><span>LIVE PROOF OBJECT</span><span>TEST RECORD / {credential.publicId}</span></div>
        <div className="core-stage" aria-label="Interactive R5 authority object"><SpatialEnvironment paused={paused} /><button aria-label={paused ? 'Resume verification object motion' : 'Pause verification object motion'} className="core-play" onClick={() => setPaused((v) => !v)} type="button">{paused ? '▶' : 'Ⅱ'}</button></div>
        <div className="core-stage-label" aria-live="polite"><b>{stage.label.toUpperCase()} / {stage.detail.toUpperCase()}</b><span>{String(stageIndex + 1).padStart(2, '0')} / 07</span><em>{stage.detail}</em></div>
        <div className="core-proof-rail"><div className="core-steps" role="tablist" aria-label="Verification stages">{STAGES.map((item, index) => <button key={item.id} type="button" role="tab" aria-selected={stageIndex === index} className={stageIndex === index ? 'core-step active' : index < stageIndex ? 'core-step complete' : 'core-step'} onClick={() => setStage(index)}><b>{String(index + 1).padStart(2, '0')}</b><span>{item.label}</span></button>)}</div></div>
        <div className="core-stage-foot" aria-hidden="true"><span>PHYSICAL ASSET</span><i /><span>EVIDENCE</span><i /><span>SIGNATURE</span><i /><span>PUBLIC STATE</span><i /><span>MACHINE RESPONSE</span></div>
      </div>
      <aside className="core-status-stack" aria-live="polite" aria-label="Operational proof state">
        <div className="core-status-card core-status-primary"><div className="core-status-card-head"><small>TEST MODE / ASSET STATUS</small><span className={runState === 'error' ? 'blocked' : 'ok'}>{statusCode(runState, issued)}</span></div><div className="core-status-main hero-tier-readout"><TierSeal tier={displayTier} compact authorized={markAuthorized} /><span><small>{issued ? 'ISSUED CREDENTIAL' : 'ELIGIBILITY RESULT'}</small>{`Tier ${displayTier} — ${displayTierName}`}<em>{issued ? credential.authorization.status : credential.authorization.status}</em></span></div><label className="core-fixture-label" htmlFor="hero-fixture">Deterministic record</label><select id="hero-fixture" className="core-fixture" value={fixtureKey} onChange={(e) => selectFixture(e.target.value)}>{fixtureList.map((item) => <option key={item.key} value={item.key}>{item.name}</option>)}</select><div className="core-field"><label>Credential ID</label><div className="core-field-row"><span>{issued ? credential.id : 'Not issued'}</span></div></div><Link className="core-record-link" href={issued ? `/registry/${credential.publicId}` : '/verify'}><span>{issued ? `${credential.lifecycle.toUpperCase()} public record` : credential.authorization.status}</span><span>→</span></Link></div>
        <div className="core-status-card core-status-api"><div className="core-machine-head"><small>MACHINE RESPONSE</small><strong>{events[Math.min(stageIndex, Math.max(0, events.length - 1))]?.type ?? 'verification.ready'}</strong></div><pre tabIndex={0} aria-label="Current machine response JSON">{JSON.stringify(machineProjection, null, 2)}</pre></div>
      </aside>
    </div></div>
    <div className="core-boundary" role="note">{TEST_MODE_LABELS.map((label) => <span key={label}>{label}</span>)}</div>
  </section>;
}
