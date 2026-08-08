'use client';

import { useState } from 'react';
import Link from 'next/link';
import { fixtureList } from '@/domain/fixtures';
import { STAGES } from '@/domain/constants';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { Metric, ProofChapterHeader, StatePill } from './Shared';

export function VerificationTransaction() {
  const fixture = useProvenanceStore((state) => state.fixture);
  const decision = useProvenanceStore((state) => state.decision);
  const credential = useProvenanceStore((state) => state.credential);
  const stageIndex = useProvenanceStore((state) => state.stageIndex);
  const runState = useProvenanceStore((state) => state.runState);
  const events = useProvenanceStore((state) => state.events);
  const webhooks = useProvenanceStore((state) => state.webhooks);
  const selectFixture = useProvenanceStore((state) => state.selectFixture);
  const setStage = useProvenanceStore((state) => state.setStage);
  const runVerification = useProvenanceStore((state) => state.runVerification);
  const [publicId, setPublicId] = useState(fixture.publicId);
  const [error, setError] = useState('');

  const issued = credential.status === 'issued';
  const registryPublished = issued && credential.authorization.status === 'authorized';
  const markAuthorized = issued && credential.sealAuthorization.status === 'authorized';
  const delivered = webhooks.filter((attempt) => attempt.status === 'delivered').length;

  const resolve = async () => {
    const match = fixtureList.find((item) => item.publicId === publicId.trim().toUpperCase());
    if (!match) {
      setError('No deterministic fixture exists for this public ID.');
      return;
    }
    setError('');
    selectFixture(match.key);
    await runVerification();
  };

  return (
    <section className="p3-chapter p3-transaction" id="verification" aria-labelledby="p3-transaction-title">
      <ProofChapterHeader
        index="02"
        eyebrow="ONE REQUEST · EVERY CONSEQUENCE"
        title="Run one verification. Watch the entire proof system respond."
        description="The same deterministic input drives evidence evaluation, authority gates, credential state, registry publication, signed events, webhook attempts, lifecycle controls, and machine output. No chapter calculates its own truth."
        aside={<StatePill tone={runState === 'complete' ? 'good' : runState === 'error' ? 'warn' : 'cyan'}>{runState.toUpperCase()}</StatePill>}
      />

      <div className="p3-transaction-grid">
        <div className="p3-run-console">
          <div className="p3-console-head"><span>VERIFICATION INPUT</span><strong>POST /api/v1/verify</strong></div>
          <label htmlFor="p3-public-id">Public ID</label>
          <div className="p3-input-row">
            <input id="p3-public-id" value={publicId} onChange={(event) => setPublicId(event.target.value.toUpperCase())} />
            <button type="button" className="button button-primary" onClick={() => void resolve()} disabled={runState === 'running'}>{runState === 'running' ? 'Resolving…' : 'Run verification'}</button>
          </div>
          {error ? <p className="form-error" role="alert">{error}</p> : null}
          <label htmlFor="p3-fixture">Deterministic scenario</label>
          <select id="p3-fixture" value={fixture.key} onChange={(event) => {
            const next = fixtureList.find((item) => item.key === event.target.value);
            selectFixture(event.target.value);
            if (next) setPublicId(next.publicId);
          }}>
            {fixtureList.map((item) => <option key={item.key} value={item.key}>{item.name} · {item.publicId}</option>)}
          </select>
          <p>{fixture.description}</p>
          <div className="p3-console-actions"><Link href="/verify">Open dedicated verifier</Link><Link href={issued ? `/registry/${credential.publicId}` : '/registry'}>{issued ? 'Open public record' : 'View issued registry'}</Link></div>
        </div>

        <div className="p3-stage-machine">
          <div className="p3-stage-rail" role="list" aria-label="Canonical verification stages">
            {STAGES.map((stage, index) => {
              const state = index < stageIndex ? 'complete' : index === stageIndex ? 'active' : 'pending';
              return (
                <button key={stage.id} type="button" role="listitem" className={state} onClick={() => setStage(index)} aria-current={state === 'active' ? 'step' : undefined}>
                  <span>{String(index + 1).padStart(2, '0')}</span><strong>{stage.label}</strong><small>{stage.detail}</small>
                </button>
              );
            })}
          </div>
        </div>

        <div className="p3-consequence-board">
          <div className="p3-consequence-head"><span>CANONICAL CONSEQUENCES</span><strong>{credential.publicId}</strong></div>
          <div className="p3-consequence-grid">
            <Metric label="Evidence eligibility" value={`Tier ${decision.tier}`} detail={decision.tierName} />
            <Metric label="Issuer authority" value={credential.authorization.status} detail={`${credential.authorization.acceptedApprovalCount}/${credential.authorization.requiredApprovalCount} approvals`} />
            <Metric label="Credential" value={issued ? `Issued Tier ${credential.tier}` : 'Not issued'} detail={credential.signature.status} />
            <Metric label="Registry" value={registryPublished ? 'Published' : 'Not published'} detail={credential.lifecycle} />
            <Metric label="Certification mark" value={markAuthorized ? 'Authorized' : 'Withheld'} detail={credential.sealAuthorization.status} />
            <Metric label="Signed consequences" value={events.length} detail={`${delivered} delivered webhook attempt${delivered === 1 ? '' : 's'}`} />
          </div>
          {credential.authorization.blockers.length ? <div className="p3-blocker-list"><strong>FAIL-CLOSED BLOCKERS</strong>{credential.authorization.blockers.map((blocker) => <span key={blocker}>{blocker}</span>)}</div> : <div className="p3-authorized-line"><i />All required authority gates are closed for this deterministic fixture.</div>}
        </div>
      </div>
    </section>
  );
}
