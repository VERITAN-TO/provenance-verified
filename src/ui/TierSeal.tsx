import Image from 'next/image';
import type { CertificationTier } from '@/domain/types';
import { certificationSealAssets } from '@/identity/assets';
import { CorporateMark } from '@/identity/CorporateIdentity';

const tierLabels: Record<CertificationTier, string> = { 1: 'Self-Reported', 2: 'Bronze', 3: 'Silver', 4: 'Gold' };

export function TierSeal({ tier, compact = false, authorized = true }: { tier: CertificationTier; compact?: boolean; authorized?: boolean }) {
  if (!authorized) {
    return <figure className={`tier-eligibility tier-eligibility-${tier} ${compact ? 'compact' : ''}`} aria-label={`Eligible Tier ${tier} — ${tierLabels[tier]}; credential or certification mark not authorized`}>
      <div className="tier-eligibility-authority"><CorporateMark className="tier-eligibility-master-mark" /></div>
      {!compact && <figcaption className="tier-seal-copy"><small>CERTIFICATION MARK WITHHELD</small><strong>TIER {tier} ELIGIBILITY</strong><em>{tierLabels[tier]}</em></figcaption>}
    </figure>;
  }
  const asset = certificationSealAssets[tier];
  return <figure className={`tier-seal tier-seal-${tier} ${compact ? 'compact' : ''}`} aria-label={`Provenance Verified Tier ${tier} — ${tierLabels[tier]}`}><Image className="tier-seal-asset" src={compact ? asset.compact : asset.display} alt={`Provenance Verified™ ${asset.label} certification seal`} width={compact ? 128 : 640} height={compact ? 128 : 640} unoptimized /></figure>;
}
