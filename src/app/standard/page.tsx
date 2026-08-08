import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';

export const metadata: Metadata = {
  title: 'Standard',
  alternates: { canonical: '/standard' },
};

export default function Page() {
  return (
    <RouteShell
      eyebrow="STANDARD"
      title="The PV Protocol — a structured framework for gemstone provenance certification."
      lede="PROVENANCE VERIFIED™ defines a four-tier certification hierarchy anchored to evidence quality, source independence, and lifecycle accountability."
    >
      <div className="standard-route-grid">
        <section>
          <h2>Four-tier certification hierarchy</h2>
          <p>
            The PV Protocol organises claims into four tiers based on the independence, depth, and
            verifiability of the underlying evidence. Tier 1 reflects self-reported origin
            declarations; Tier 2 requires documentation substantiation; Tier 3 requires independent
            laboratory evidence; Tier 4 requires multi-source, independently corroborated evidence
            across the full supply chain with lifecycle audit capability.
          </p>
          <p>
            Each tier defines a scope boundary. A credential issued at a given tier makes no claims
            beyond what its evidence tier supports. Tier assignment is permanent for the evidence set
            presented at issuance. New evidence initiates a new credential.
          </p>
        </section>
        <section>
          <h2>Evidence requirements</h2>
          <p>
            Evidence must be submitted through the authorised intake process and reviewed against
            the Evidence Policy before a certification tier is assigned. Acceptable evidence classes
            include laboratory reports, chain-of-custody documentation, government origin
            certificates, and independent professional assessments.
          </p>
          <p>
            Evidence sources must meet source-independence criteria defined in the Certification
            Policy. Self-referential or internally produced evidence does not satisfy independence
            requirements above Tier 1.
          </p>
        </section>
        <section>
          <h2>Credential lifecycle</h2>
          <p>
            Every credential issued under the PV Protocol carries a validity period, a public
            verification key reference, and a lifecycle status. Credentials may be suspended,
            superseded, revoked, or corrected. All lifecycle events are recorded in an append-only
            registry. Historical records remain resolvable after expiry or revocation.
          </p>
        </section>
        <section>
          <h2>Registry and verification</h2>
          <p>
            Issued credentials are published to the PROVENANCE VERIFIED™ public registry.
            Third-party verification is supported via the public verification API without requiring
            an account. Registry entries expose the credential tier, evidence scope, issuer
            identity, and lifecycle status.
          </p>
        </section>
      </div>
    </RouteShell>
  );
}
