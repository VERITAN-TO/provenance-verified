import type { Metadata } from 'next';
import Link from 'next/link';
import { RouteShell } from '@/ui/RouteShell';

export const metadata: Metadata = {
  title: 'Support',
  alternates: { canonical: '/support' },
};

export default function Page() {
  return (
    <RouteShell
      eyebrow="SUPPORT"
      title="Help with certification, verification, registry, and integration."
      lede="Route your inquiry to the right channel. For certification intake, developer integration, verification questions, or policy clarification — start here."
    >
      <div className="support-route-grid">
        <section>
          <h2>Certification and evidence</h2>
          <p>
            Questions about the certification process, evidence requirements, tier eligibility,
            intake timelines, or credential scope. Include the stone type, available evidence
            sources, and the tier you are targeting in your inquiry.
          </p>
        </section>
        <section>
          <h2>Verification and registry</h2>
          <p>
            Questions about verifying a credential, interpreting registry data, understanding
            lifecycle status, or resolving a credential identifier. The public verification
            endpoint at <Link href="/verify">/verify</Link> accepts credential identifiers
            without an account.
          </p>
        </section>
        <section>
          <h2>Developer and API integration</h2>
          <p>
            Questions about the verification API, webhook integration, SDK usage, or MCP
            connectivity. Documentation is available at <Link href="/developers">Developers</Link>{' '}
            and <Link href="/docs">Docs</Link>. Include the integration type and target environment
            in your inquiry.
          </p>
        </section>
        <section>
          <h2>Policy and legal</h2>
          <p>
            Questions about the Certification Policy, Evidence Policy, Revocation Policy,
            authorised mark use, or Privacy Policy. Review the <Link href="/legal/certification-policy">Certification Policy</Link> and{' '}
            <Link href="/legal/evidence-policy">Evidence Policy</Link> before submitting a
            policy inquiry.
          </p>
        </section>
        <section>
          <h2>Contact</h2>
          <p>
            All public inquiries are handled through the <Link href="/contact">contact form</Link>.
            Route your message using the inquiry type guidance above. Security disclosures
            should be submitted via the <Link href="/security/report">security report page</Link>.
          </p>
        </section>
      </div>
    </RouteShell>
  );
}
