import type { Metadata } from 'next';
import Link from 'next/link';
import { RouteShell } from '@/ui/RouteShell';
import { DeveloperWorkbench } from '@/ui/DeveloperWorkbench';

export const metadata: Metadata = { title: 'Developers' };

export default function Page() {
  return (
    <RouteShell eyebrow="DEVELOPER INTEGRATION" title="One contract from evidence intake to public consequence." lede="Consume deterministic verification, registry, event, webhook, SDK, and lifecycle contracts without recreating eligibility or issuer authority in client code.">
      <div className="developer-route-grid">
        <article><span>01</span><h2>Verify</h2><p>Receive either an issued credential or a fail-closed eligibility case with explicit blockers.</p><Link href="/docs/api">API reference →</Link></article>
        <article><span>02</span><h2>Resolve</h2><p>Open the same canonical record through the public registry with field-level response parity.</p><Link href="/registry">Registry →</Link></article>
        <article><span>03</span><h2>Observe</h2><p>Consume signed event chains and inspect webhook attempts, retry, replay, and lineage.</p><Link href="/docs/webhooks">Webhook guide →</Link></article>
        <article><span>04</span><h2>Control</h2><p>Preserve resolvability through suspension, supersession, revocation, expiration, and successors.</p><Link href="/docs/events">Event guide →</Link></article>
      </div>
      <DeveloperWorkbench />
    </RouteShell>
  );
}
