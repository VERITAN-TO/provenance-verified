import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';

export const metadata: Metadata = {
  title: 'About',
  alternates: { canonical: '/about' },
};

export default function Page() {
  return (
    <RouteShell
      eyebrow="ABOUT"
      title="PROVENANCE VERIFIED™ is operated by VERITAN, INC."
      lede="An independent gemstone provenance certification platform built on evidence quality, source independence, and public verifiability."
    >
      <div className="about-route-grid">
        <section>
          <h2>Mission</h2>
          <p>
            PROVENANCE VERIFIED™ exists to make gemstone provenance claims independently
            verifiable. The platform converts submitted evidence into scoped, signed,
            lifecycle-aware credentials that any party can verify without relying on the
            seller{"'"}s word alone.
          </p>
          <p>
            The PV Protocol defines the evidentiary standards, tier hierarchy, and lifecycle
            rules that govern every credential issued on the platform. The standard is applied
            consistently regardless of stone type, market segment, or submitting party.
          </p>
        </section>
        <section>
          <h2>Operator</h2>
          <p>
            PROVENANCE VERIFIED™ is designed, operated, and maintained by VERITAN, INC.
            VERITAN is the issuing authority for all credentials produced under the PV Protocol.
            Issuer identity, verification keys, and authority assertions are published at the
            Trust Center and exposed through the public JWKS endpoint.
          </p>
        </section>
        <section>
          <h2>Independence</h2>
          <p>
            The platform accepts evidence from certified third-party sources and applies
            source-independence requirements at each certification tier. VERITAN does not buy
            or sell gemstones and has no financial interest in any stone submitted for
            certification. Independence is structural, not aspirational.
          </p>
        </section>
        <section>
          <h2>Public verifiability</h2>
          <p>
            Every issued credential is published to the public registry and can be verified
            independently via the verification API. No account is required for third-party
            verification. Lifecycle events — including suspension, revocation, and correction —
            are published as they occur.
          </p>
        </section>
      </div>
    </RouteShell>
  );
}
