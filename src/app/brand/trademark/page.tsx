import type { Metadata } from 'next'; import { PolicyDocument } from '@/ui/RouteShell';
export const metadata: Metadata = { title: 'Trademark and identity' };
export default function Page() { return <PolicyDocument title="Trademark and identity" summary="Role separation, approved material language, and prohibited uses for the PROVENANCE VERIFIED™ corporate identity and Provenance Verified™ certification seals." sections={[
  { heading: 'Corporate master mark', body: 'The corporate mark uses the approved octagonal DNA, machined silver, smoked evidence glass, deep carbon, and controlled cyan. It identifies the platform and never changes into a certification-tier metal.' },
  { heading: 'Certification-tier seals', body: 'Tier 1 — Self-Reported uses graphite and controlled cyan. Tier 2 — Bronze uses bronze. Tier 3 — Silver uses silver. Tier 4 — Gold uses gold. Ring count and material are driven only by the certification result.' },
  { heading: 'Wordmark', body: 'Use the approved PROVENANCE VERIFIED™ wordmark direction. Do not imitate Resend or another company’s letterforms, layout, footer composition, lighting, spacing, or trade dress.' },
  { heading: 'Prohibited use', body: 'Do not present fixture seals as production credentials, recolor the corporate mark by tier, remove required disclosures, or imply unsupported compliance, customer, performance, or certification claims.' }
]} />; }
