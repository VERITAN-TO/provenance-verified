import type { Metadata } from 'next';
import { legalContent } from '@/ui/content';
import { PolicyDocument } from '@/ui/RouteShell';
import { R5IdentityObject } from '@/identity/R5IdentityObject';
import { R5TierDeck } from '@/identity/R5TierDeck';

export const metadata: Metadata = { title: 'Provenance Verified certification standard' };

export default function Page() {
  const doc = legalContent['certification-policy'];
  return <PolicyDocument
    title="Provenance Verified™"
    summary="Four-tier gemstone provenance certification issued by VERITAN, INC. and operated through provenanceverified.org."
    sections={doc.sections}
    aside={<div className="pv2-route-seal-cluster" aria-label="Provenance Verified certification seal system"><R5IdentityObject variant="certification" tier={4} interactive priority label="Live R5 Three.js Provenance Verified Tier 4 Gold certification seal" /><span>Live R5 certification geometry</span></div>}
    lead={<div className="pv2-policy-live-tier-deck"><R5TierDeck /></div>}
  />;
}
