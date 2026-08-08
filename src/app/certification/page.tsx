import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';

export const metadata: Metadata = {
  title: 'Certification',
  alternates: { canonical: '/certification' },
};

export default function Page() {
  return (
    <RouteShell
      eyebrow="CERTIFICATION"
      title="Evidence-bounded provenance credentials with defined scope and lifecycle accountability."
      lede="A PROVENANCE VERIFIED™ credential certifies what the evidence supports — no more, no less. Scope, limitations, and the distinction between publication and authorised use are stated here."
    >
      <div className="certification-route-grid">
        <section>
          <h2>What certification means</h2>
          <p>
            A credential issued by PROVENANCE VERIFIED™ asserts that a defined set of evidence,
            reviewed under the Certification Policy, supports a provenance claim at a specified tier.
            The credential is scoped strictly to the evidence presented. It does not assert facts
            beyond the evidentiary record and does not imply endorsement of the stone, seller, or
            any downstream representation.
          </p>
        </section>
        <section>
          <h2>Scope and limitations</h2>
          <p>
            Every credential carries an explicit evidence scope. Claims outside that scope are not
            certified. In particular, certification at one tier does not imply or upgrade claims
            characteristic of a higher tier. A Tier 2 documentation-substantiated credential makes
            no representations about laboratory-verified origin.
          </p>
          <p>
            Certification does not constitute valuation, grading, or appraisal. PROVENANCE
            VERIFIED™ is an independent provenance certification body, not a gemological
            laboratory or trading platform.
          </p>
        </section>
        <section>
          <h2>Credential status</h2>
          <p>
            Credentials exist in one of the following lifecycle states: active, suspended,
            superseded, revoked, or expired. Only active credentials are currently valid for
            third-party verification. All status transitions are recorded in the public registry
            and remain historically resolvable. A revoked credential is not deleted; its
            revocation record and reason are published.
          </p>
        </section>
        <section>
          <h2>Publication vs. authorised certification use</h2>
          <p>
            Appearance of the PROVENANCE VERIFIED™ name, mark, or credential identifier on this
            website constitutes publication of registry data only. Authorised use of PROVENANCE
            VERIFIED™ marks in commercial contexts — including labelling, marketing, sales
            materials, and third-party platforms — is governed separately by the Certification
            Policy and requires explicit authorisation. Displaying a credential identifier does not
            by itself constitute authorised commercial mark use.
          </p>
        </section>
        <section>
          <h2>Submitting for certification</h2>
          <p>
            Certification intake is conducted through the authorised submission process. Evidence
            requirements, acceptable document classes, independence criteria, and processing
            timelines are defined in the Certification Policy and Evidence Policy. Contact the
            support team to begin an intake discussion.
          </p>
        </section>
      </div>
    </RouteShell>
  );
}
