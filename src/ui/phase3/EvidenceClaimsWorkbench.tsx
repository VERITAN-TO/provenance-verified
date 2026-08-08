'use client';

import { useProvenanceStore } from '@/store/useProvenanceStore';
import { selectSelectedClaim, selectSelectedEvidence } from '@/store/selectors';
import { ClaimEvidenceGraph } from '@/visualization/ClaimEvidenceGraph';
import { BoundaryNote, ProofChapterHeader, StatePill } from './Shared';

export function EvidenceClaimsWorkbench() {
  const fixture = useProvenanceStore((state) => state.fixture);
  const selectedEvidenceId = useProvenanceStore((state) => state.selectedEvidenceId);
  const selectedClaimId = useProvenanceStore((state) => state.selectedClaimId);
  const selectEvidence = useProvenanceStore((state) => state.selectEvidence);
  const selectClaim = useProvenanceStore((state) => state.selectClaim);
  const selectedEvidence = selectSelectedEvidence(fixture.evidence, selectedEvidenceId);
  const selectedClaim = selectSelectedClaim(fixture.claims, selectedClaimId);
  const selectedSource = selectedEvidence ? fixture.sources.find((source) => source.id === selectedEvidence.sourceId) : null;

  return (
    <section className="p3-chapter p3-evidence" aria-labelledby="p3-evidence-title">
      <ProofChapterHeader
        index="03"
        eyebrow="CLAIM-LEVEL EVIDENCE"
        title="Every claim keeps its own evidence, source, determination, and uncertainty."
        description="Evidence objects remain attached to hashes, timestamps, sources, custody, and exact claim IDs. One supported claim cannot turn an entire asset into a vague green check."
        aside={<StatePill tone="cyan">{fixture.evidence.length} EVIDENCE OBJECTS</StatePill>}
      />

      <div className="p3-workbench">
        <div className="p3-evidence-list" aria-label="Evidence objects">
          <div className="p3-panel-head"><span>EVIDENCE BUNDLE</span><strong>{fixture.publicId}</strong></div>
          {fixture.evidence.map((item) => {
            const source = fixture.sources.find((entry) => entry.id === item.sourceId);
            const active = item.id === selectedEvidenceId;
            return (
              <button key={item.id} type="button" className={active ? 'active' : ''} onClick={() => selectEvidence(item.id)}>
                <span className={`p3-evidence-type ${item.type}`}>{item.type}</span>
                <span><strong>{item.label}</strong><small>{source?.name ?? item.sourceId}</small></span>
                <span className="p3-evidence-flags"><i className={item.qualified ? 'on' : ''}>Q</i><i className={item.independent ? 'on' : ''}>I</i></span>
              </button>
            );
          })}
        </div>

        <div className="p3-graph-panel">
          <div className="p3-panel-head"><span>CORRESPONDENCE GRAPH</span><strong>CLAIM ↔ EVIDENCE</strong></div>
          <ClaimEvidenceGraph />
        </div>

        <aside className="p3-inspector">
          <div className="p3-panel-head"><span>INSPECTOR</span><strong>{selectedEvidence ? 'EVIDENCE' : 'CLAIM'}</strong></div>
          {selectedEvidence ? (
            <div className="p3-inspector-content">
              <StatePill tone={selectedEvidence.independent ? 'good' : 'neutral'}>{selectedEvidence.independent ? 'INDEPENDENT SOURCE' : 'SUBMITTER / ATTESTOR SOURCE'}</StatePill>
              <h3>{selectedEvidence.label}</h3>
              <dl>
                <div><dt>Type</dt><dd>{selectedEvidence.type}</dd></div>
                <div><dt>Source</dt><dd>{selectedSource?.name ?? selectedEvidence.sourceId}</dd></div>
                <div><dt>Jurisdiction</dt><dd>{selectedSource?.jurisdiction ?? 'Not recorded'}</dd></div>
                <div><dt>Qualified</dt><dd>{selectedEvidence.qualified ? 'Yes' : 'No'}</dd></div>
                <div><dt>Captured</dt><dd>{selectedEvidence.capturedAt}</dd></div>
                <div><dt>Hash</dt><dd>{selectedEvidence.hash}</dd></div>
              </dl>
              <strong className="p3-linked-label">Linked claims</strong>
              <div className="p3-linked-chips">{selectedEvidence.claimIds.map((id) => {
                const claim = fixture.claims.find((entry) => entry.id === id);
                return <button key={id} type="button" onClick={() => selectClaim(id)}>{claim?.label ?? id}</button>;
              })}</div>
            </div>
          ) : selectedClaim ? (
            <div className="p3-inspector-content">
              <StatePill tone={selectedClaim.status === 'verified' ? 'good' : selectedClaim.status === 'conflicting' ? 'danger' : 'warn'}>{selectedClaim.status.toUpperCase()}</StatePill>
              <h3>{selectedClaim.label}</h3>
              <p className="p3-claim-value">{selectedClaim.value}</p>
              <p>{selectedClaim.scopeNote}</p>
            </div>
          ) : <p>Select an evidence object or claim.</p>}
          <BoundaryNote title="Evidence boundary">A phone image, measurement, attestation, or AI classification is evidence input. None is represented as laboratory authentication unless a qualifying laboratory source is attached.</BoundaryNote>
        </aside>
      </div>

      <div className="p3-claim-matrix">
        <div className="p3-panel-head"><span>PUBLIC CLAIM SCOPE</span><strong>{fixture.claims.length} DETERMINATIONS</strong></div>
        <div className="p3-claim-rows">
          {fixture.claims.map((claim) => (
            <button key={claim.id} type="button" className={claim.id === selectedClaimId ? 'active' : ''} onClick={() => selectClaim(claim.id)}>
              <span className={`claim-status ${claim.status}`}>{claim.status}</span>
              <span><strong>{claim.label}</strong><small>{claim.value}</small></span>
              <span>{claim.evidenceIds.length} evidence link{claim.evidenceIds.length === 1 ? '' : 's'}</span>
              <p>{claim.scopeNote}</p>
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}
