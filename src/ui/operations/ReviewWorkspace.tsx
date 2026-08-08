'use client';

import { useState } from 'react';
import { evaluateCertification } from '@/domain/kernel';
import { can } from '@/operations/permissions';
import { projectAssetToAuthority } from '@/operations/kernel';
import { useOperationsStore } from '@/operations/useOperationsStore';

const policyLabels = {
  submitterIdentity: 'Submitter identity',
  selfDeclaredOrigin: 'Origin declared',
  photographs: 'Controlled photographs',
  measurements: 'Weight and dimensions',
  timestamp: 'Trusted timestamps',
  registryId: 'Assigned registry ID',
  signedAttestation: 'Immutable attestation',
  identifiedAttestingParty: 'Authorized signer',
  legalDeclaration: 'Legal declaration',
  signatureValid: 'Attestation signature',
  signatureTimestamp: 'Signature timestamp',
  attestationVersion: 'Attestation version',
  appendOnlyEvent: 'Append-only event chain',
  integrityHash: 'Evidence integrity',
  claimLevelCorrespondence: 'Claim correspondence',
  verifiedOrigin: 'Verified origin',
  physicalFingerprint: 'Physical fingerprint',
  qualifyingLaboratoryEvidence: 'Qualified laboratory evidence',
  completeTransferHistory: 'Transfer history',
  completeCustodyTransfers: 'Custody history',
} as const;

export function ReviewWorkspace() {
  const { dataset, sessionId, selectedReviewCaseId, selectReviewCase, reviewAction, lifecycleAction, requestCorrection, resolveCorrection, rejectCorrection } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const reviews = dataset.reviewCases.filter((item) => item.tenantId === session.tenantId);
  const review = reviews.find((item) => item.id === selectedReviewCaseId) ?? reviews[0];
  const asset = dataset.assets.find((item) => item.id === review?.assetId);
  const evidence = dataset.evidence.filter((item) => item.assetId === asset?.id);
  const attestation = dataset.attestations.find((item) => item.id === review?.attestationId);
  const projection = review && asset ? projectAssetToAuthority(asset, evidence, review, attestation) : null;
  const decision = projection ? evaluateCertification(projection.policy, projection.fixture.claims) : null;
  const independentSources = new Set(evidence.filter((item) => item.independent && item.qualified && item.status === 'active').map((item) => item.sourceOrganization)).size;
  const canReview = can(session.role, 'review.decide');
  const canTier4 = can(session.role, 'review.approve-tier4');
  const canCustos = can(session.role, 'custos.decide');
  const canIssue = can(session.role, 'credential.issue');
  const canMark = can(session.role, 'mark.authorize');
  const canLifecycle = can(session.role, 'credential.lifecycle');
  const canRequestCorrection = can(session.role, 'correction.request');
  const canResolveCorrection = can(session.role, 'correction.resolve');
  const [lifecycleReason, setLifecycleReason] = useState('Compliance-controlled lifecycle action recorded through the canonical authority service.');
  const [successorId, setSuccessorId] = useState('');
  const [correctionReason, setCorrectionReason] = useState('Evidence or claim data requires correction before authority can continue.');
  const [correctionFields, setCorrectionFields] = useState('originClaim,evidence');
  const [resolution, setResolution] = useState('Corrected records verified and resubmitted with a new immutable attestation version.');
  const openCorrection = review?.corrections?.find((item) => item.status === 'open');

  return (
    <div className="ops-review-layout">
      <section className="ops-panel ops-review-queue" aria-label="Review queue">
        <div className="ops-panel-heading">
          <span className="ops-kicker">Review queue</span>
          <strong>{reviews.length}</strong>
        </div>
        {reviews.slice(0, 120).map((item) => {
          const target = dataset.assets.find((assetItem) => assetItem.id === item.assetId);
          return (
            <button key={item.id} className={item.id === review?.id ? 'is-selected' : ''} onClick={() => selectReviewCase(item.id)}>
              <span><strong>{target?.serial}</strong><small>{item.status}</small></span>
              <em>{item.approvals.filter((approval) => approval.decision === 'approve').length}</em>
            </button>
          );
        })}
      </section>

      <section className="ops-panel ops-review-stage">
        {review && asset && projection && decision ? (
          <>
            <header>
              <div><span>Canonical authority case</span><h2>{asset.serial}</h2><small>{review.registryId}</small></div>
              <em data-state={review.status}>{review.status}</em>
            </header>

            <div className="ops-review-summary">
              <div><span>Evidence</span><strong>{evidence.length}</strong></div>
              <div><span>Independent sources</span><strong>{independentSources}</strong></div>
              <div><span>Authority receipts</span><strong>{review.eventReceipts.length}</strong></div>
              <div><span>Eligible tier</span><strong>{decision.tier}</strong></div>
            </div>

            <div className="ops-truth-banner" data-ready={decision.tier === 4 && projection.policy.completeTransferHistory && projection.policy.completeCustodyTransfers}>
              <span>Projection law</span>
              <strong>{decision.tier === 4 ? 'Tier 4 evidence profile is record-derived.' : 'Tier 4 remains blocked by missing canonical records.'}</strong>
              <small>No workflow status, user selection, or UI action can manufacture evidence eligibility.</small>
            </div>

            <div className="ops-review-columns">
              <article>
                <span className="ops-kicker">Asset and controlled evidence</span>
                <dl>
                  <div><dt>Material</dt><dd>{asset.material}</dd></div>
                  <div><dt>Origin claim</dt><dd>{asset.originClaim}</dd></div>
                  <div><dt>Treatment</dt><dd>{asset.treatmentDisclosure}</dd></div>
                  <div><dt>Attestation</dt><dd>{attestation ? `v${attestation.version} · ${attestation.signerRole}` : 'missing'}</dd></div>
                </dl>
                <ul className="ops-evidence-list">
                  {evidence.map((item) => (
                    <li key={item.id}>
                      <span><strong>{item.label}</strong><small>{item.sourceOrganization}</small></span>
                      <em>{item.status} · {item.qualified ? 'qualified' : 'unqualified'} · {item.independent ? 'independent' : 'submitted'}</em>
                    </li>
                  ))}
                </ul>
              </article>

              <article>
                <span className="ops-kicker">Evidence eligibility gates</span>
                <div className="ops-policy-grid">
                  {Object.entries(policyLabels).map(([key, label]) => {
                    const value = projection.policy[key as keyof typeof projection.policy];
                    return <div key={key} data-pass={Boolean(value)}><i aria-hidden="true" /><span>{label}</span><strong>{typeof value === 'number' ? value : value ? 'pass' : 'blocked'}</strong></div>;
                  })}
                </div>
                {decision.upgradePath.length > 0 && <div className="ops-blocker-list"><span>Required next records</span>{decision.upgradePath.map((item) => <strong key={item}>{item}</strong>)}</div>}
              </article>
            </div>

            <div className="ops-authority-console">
              <div>
                <span className="ops-kicker">Issuance authority</span>
                <dl>
                  <div><dt>Conflict clearance</dt><dd>{review.conflictClearance}</dd></div>
                  <div><dt>CUSTOS</dt><dd>{review.custosVerdict.status}</dd></div>
                  <div><dt>Signing key</dt><dd>{review.signingKeyStatus}</dd></div>
                  <div><dt>Registry publication</dt><dd>{review.registryPublication ? review.registryPublication.receiptId : review.registryStatus}</dd></div>
                  <div><dt>Revocation control</dt><dd>{review.revocationCapability ? 'enabled' : 'required'}</dd></div>
                  <div><dt>Mark authorization</dt><dd>{review.markAuthorization}</dd></div>
                  <div><dt>Credential</dt><dd>{review.credential?.status ?? 'not evaluated'}</dd></div>
                </dl>
              </div>
              <div className="ops-gate-actions">
                <button disabled={!canReview} onClick={() => reviewAction('primary-approve')}>Primary approval</button>
                <button disabled={!canTier4} onClick={() => reviewAction('secondary-approve')}>Secondary approval</button>
                <button disabled={!canCustos} onClick={() => reviewAction('custos-pass')}>CUSTOS pass</button>
                <button disabled={!canIssue} onClick={() => reviewAction('authorize-signing')}>Authorize signing</button>
                <button disabled={!canIssue} onClick={() => reviewAction('publish-registry')}>Publish registry</button>
                <button disabled={!canIssue} onClick={() => reviewAction('enable-revocation-control')}>Enable revocation control</button>
                <button disabled={!canMark} onClick={() => reviewAction('authorize-mark')}>Authorize mark</button>
                <button disabled={!canReview} className="is-danger" onClick={() => reviewAction('reject')}>Reject</button>
              </div>
            </div>

            <div className="ops-control-grid">
              <section className="ops-panel ops-lifecycle-control" aria-labelledby="lifecycle-control-title">
                <header>
                  <div><span className="ops-kicker">Credential lifecycle</span><h3 id="lifecycle-control-title">Controlled negative states</h3></div>
                  <em data-state={review.credentialLifecycle}>{review.credentialLifecycle}</em>
                </header>
                <p>Lifecycle transitions operate on the issued canonical record. Suspension, revocation, supersession, and expiration suppress certification-mark use immediately. Reactivation never restores the mark without a separate authorization.</p>
                <label>Recorded reason<textarea value={lifecycleReason} onChange={(event) => setLifecycleReason(event.target.value)} rows={3} /></label>
                <label>Successor public ID <input value={successorId} onChange={(event) => setSuccessorId(event.target.value)} placeholder="Required for supersession" /></label>
                <div className="ops-gate-actions ops-lifecycle-actions">
                  <button disabled={!canLifecycle || review.credentialLifecycle !== 'active'} onClick={() => void lifecycleAction('suspend', lifecycleReason)}>Suspend</button>
                  <button disabled={!canLifecycle || review.credentialLifecycle !== 'suspended'} onClick={() => void lifecycleAction('reactivate', lifecycleReason)}>Reactivate</button>
                  <button disabled={!canLifecycle || !['active', 'suspended'].includes(review.credentialLifecycle)} className="is-danger" onClick={() => void lifecycleAction('revoke', lifecycleReason)}>Revoke</button>
                  <button disabled={!canLifecycle || !successorId || !['active', 'suspended'].includes(review.credentialLifecycle)} onClick={() => void lifecycleAction('supersede', lifecycleReason, successorId)}>Supersede</button>
                  <button disabled={!canLifecycle || !['active', 'suspended'].includes(review.credentialLifecycle)} onClick={() => void lifecycleAction('expire', lifecycleReason)}>Expire</button>
                </div>
                <ol className="ops-event-list">
                  {review.lifecycleEvents.length ? review.lifecycleEvents.slice().reverse().map((event) => <li key={event.id}><strong>{event.from} → {event.to}</strong><span>{event.reason}</span><small>{event.actorId} · {event.at}</small></li>) : <li><span>No lifecycle transition has been recorded.</span></li>}
                </ol>
              </section>

              <section className="ops-panel ops-correction-control" aria-labelledby="correction-control-title">
                <header>
                  <div><span className="ops-kicker">Versioned correction</span><h3 id="correction-control-title">Correction and re-review</h3></div>
                  <em data-state={openCorrection ? 'open' : 'clear'}>{openCorrection ? `open v${openCorrection.version}` : 'clear'}</em>
                </header>
                {!openCorrection ? <>
                  <label>Correction reason<textarea value={correctionReason} onChange={(event) => setCorrectionReason(event.target.value)} rows={3} /></label>
                  <label>Affected fields<input value={correctionFields} onChange={(event) => setCorrectionFields(event.target.value)} placeholder="originClaim,evidence" /></label>
                  <button className="button button-primary" disabled={!canRequestCorrection} onClick={() => void requestCorrection(correctionReason, correctionFields.split(',').map((item) => item.trim()).filter(Boolean))}>Request correction</button>
                </> : <>
                  <div className="ops-correction-open"><strong>{openCorrection.reason}</strong><span>{openCorrection.fields.join(' · ')}</span><small>Requested by {openCorrection.requestedBy} · {openCorrection.requestedAt}</small></div>
                  <label>Resolution record<textarea value={resolution} onChange={(event) => setResolution(event.target.value)} rows={4} /></label>
                  <div className="ops-gate-actions">
                    <button className="button button-primary" disabled={!canResolveCorrection} onClick={() => void resolveCorrection(openCorrection.id, resolution)}>Resolve with new attestation</button>
                    <button className="is-danger" disabled={!canResolveCorrection} onClick={() => void rejectCorrection(openCorrection.id, resolution)}>Reject request</button>
                  </div>
                </>}
                <ol className="ops-event-list">
                  {review.corrections.length ? review.corrections.slice().reverse().map((item) => <li key={item.id}><strong>v{item.version} · {item.status}</strong><span>{item.reason}</span><small>{item.replacementAttestationId ? `Replacement ${item.replacementAttestationId}` : item.requestedAt}</small></li>) : <li><span>No correction history exists.</span></li>}
                </ol>
              </section>
            </div>
          </>
        ) : <div className="ops-empty"><h2>No review cases</h2></div>}
      </section>
    </div>
  );
}
