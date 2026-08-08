'use client';

import Link from 'next/link';
import { apiProjection, projectionParity, registryProjection } from '@/adapters/projections';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { TierSeal } from '@/ui/TierSeal';
import { CodeSurface, Metric, ProofChapterHeader, StatePill } from './Shared';

export function CredentialRegistryProjection() {
  const decision = useProvenanceStore((state) => state.decision);
  const credential = useProvenanceStore((state) => state.credential);
  const registry = registryProjection(credential);
  const api = apiProjection(credential);
  const parity = projectionParity(credential);
  const issued = credential.status === 'issued';
  const markAuthorized = issued && credential.sealAuthorization.status === 'authorized';
  const parityRows = Object.entries(parity);
  const allAligned = parityRows.every(([, value]) => value);

  return (
    <section className="p3-chapter p3-projection" aria-labelledby="p3-projection-title">
      <ProofChapterHeader
        index="04"
        eyebrow="ONE CREDENTIAL · EXACT PROJECTIONS"
        title="Publish once. Resolve the same authority state everywhere."
        description="The human record, registry API, QR destination, event stream, and future MCP tools must not calculate separate answers. They project one credential and preserve negative states."
        aside={<StatePill tone={allAligned ? 'good' : 'danger'}>{allAligned ? 'PARITY ALIGNED' : 'PARITY FAILURE'}</StatePill>}
      />

      <div className="p3-projection-grid">
        <article className="p3-public-record-card">
          <div className="p3-record-topline"><span>PUBLIC RECORD</span><strong>{credential.publicId}</strong></div>
          <div className="p3-record-identity">
            <TierSeal tier={decision.tier} authorized={markAuthorized} />
            <div>
              <StatePill tone={issued ? 'good' : 'warn'}>{issued ? credential.lifecycle.toUpperCase() : 'NOT PUBLISHED'}</StatePill>
              <h3>{issued ? `Tier ${credential.tier} · ${credential.tierName}` : `Eligible Tier ${decision.tier} · ${decision.tierName}`}</h3>
              <p>{issued ? credential.disclosure : 'Evidence eligibility exists, but no issuer-authorized credential or public registry record exists.'}</p>
            </div>
          </div>
          <div className="p3-record-metrics">
            <Metric label="Issuer" value={credential.issuer} />
            <Metric label="Credential" value={credential.status} />
            <Metric label="Signature" value={credential.signature.status} />
            <Metric label="Mark" value={credential.sealAuthorization.status} />
          </div>
          <div className="p3-record-actions">
            {issued ? <Link href={`/registry/${credential.publicId}`} className="button button-primary">Open public record</Link> : <span className="button button-secondary" aria-disabled="true">No registry record</span>}
            <Link href="/registry" className="button button-secondary">Browse issued registry</Link>
          </div>
        </article>

        <div className="p3-machine-projection">
          <CodeSurface title="CANONICAL API PROJECTION" value={JSON.stringify(api, null, 2)} label="Copy JSON" />
        </div>

        <aside className="p3-parity-panel">
          <div className="p3-panel-head"><span>PROJECTION PARITY</span><strong>{parityRows.filter(([, value]) => value).length}/{parityRows.length}</strong></div>
          {parityRows.map(([field, aligned]) => <div key={field}><i className={aligned ? 'aligned' : 'failed'} /> <span>{field}</span><strong>{aligned ? 'Aligned' : 'Mismatch'}</strong></div>)}
          <p>Registry publication is {registry.published ? 'enabled' : 'withheld'} for this case. The integrity digest remains <code>{credential.integrityHash}</code>.</p>
        </aside>
      </div>
    </section>
  );
}
