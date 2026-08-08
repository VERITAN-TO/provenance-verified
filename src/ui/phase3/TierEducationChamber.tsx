'use client';

import { useState } from 'react';
import type { CertificationTier } from '@/domain/types';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { TierSeal } from '@/ui/TierSeal';
import { tierEducation } from './content';
import { BoundaryNote, Metric, ProofChapterHeader, StatePill } from './Shared';

export function TierEducationChamber() {
  const [selectedTier, setSelectedTier] = useState<CertificationTier>(4);
  const decision = useProvenanceStore((state) => state.decision);
  const credential = useProvenanceStore((state) => state.credential);
  const selected = tierEducation[selectedTier];
  const issued = credential.status === 'issued';
  const markAuthorized = issued && credential.sealAuthorization.status === 'authorized';

  return (
    <section className="p3-chapter p3-tier" id="provenance-verified" aria-labelledby="p3-tier-title">
      <ProofChapterHeader
        index="01"
        eyebrow="PROVENANCE VERIFIED™"
        title="Certification depth is earned by evidence. Issuance is earned by authority."
        description="The four tiers communicate evidence depth. They do not let a user select, purchase, or visually promote a credential. The active case keeps eligibility, issuance, lifecycle, and mark control separate."
        aside={<StatePill tone={issued ? 'good' : 'warn'}>{issued ? `Issued Tier ${credential.tier}` : `Eligible Tier ${decision.tier}`}</StatePill>}
      />

      <div className="p3-tier-layout">
        <div className="p3-tier-selector" role="tablist" aria-label="Certification tier education">
          {(Object.keys(tierEducation).map(Number) as CertificationTier[]).map((tier) => {
            const item = tierEducation[tier];
            const active = tier === selectedTier;
            return (
              <button
                key={tier}
                type="button"
                role="tab"
                aria-selected={active}
                className={active ? 'active' : ''}
                onClick={() => setSelectedTier(tier)}
              >
                <span className="p3-tier-number">{tier}</span>
                <span><strong>{item.label}</strong><small>{item.eyebrow}</small></span>
                <i aria-hidden="true" />
              </button>
            );
          })}
        </div>

        <article className="p3-tier-detail" aria-live="polite">
          <div className="p3-tier-education-mark" aria-label={`Educational Tier ${selectedTier} diagram; not a credential`}>
            {Array.from({ length: selectedTier }, (_, index) => <i key={index} style={{ inset: `${index * 13}px` }} />)}
            <span>{selectedTier}</span>
          </div>
          <div className="p3-tier-copy">
            <StatePill tone="neutral">EDUCATION ONLY · NOT ISSUANCE</StatePill>
            <h3>Tier {selectedTier} · {selected.label}</h3>
            <p className="p3-tier-disclosure">{selected.disclosure}</p>
            <ul>{selected.requirements.map((requirement) => <li key={requirement}>{requirement}</li>)}</ul>
            <BoundaryNote title="Boundary">{selected.boundary}</BoundaryNote>
          </div>
        </article>

        <aside className="p3-live-case">
          <div className="p3-live-case-head"><span>ACTIVE DETERMINISTIC CASE</span><strong>{credential.publicId}</strong></div>
          <div className="p3-live-case-seal"><TierSeal tier={decision.tier} authorized={markAuthorized} compact={false} /></div>
          <div className="p3-live-case-grid">
            <Metric label="Evidence result" value={`Tier ${decision.tier} · ${decision.tierName}`} />
            <Metric label="Credential" value={issued ? `Tier ${credential.tier} · ${credential.tierName}` : 'Not issued'} />
            <Metric label="Authority" value={credential.authorization.status} />
            <Metric label="Mark control" value={credential.sealAuthorization.status} />
          </div>
          {!markAuthorized ? <p className="p3-live-case-warning">The tier diagram above represents eligibility only. No certification seal is authorized for this state.</p> : null}
        </aside>
      </div>
    </section>
  );
}
