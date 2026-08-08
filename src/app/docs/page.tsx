import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';
import { DocsIndex } from '@/ui/DocsIndex';

export const metadata: Metadata = { title: 'Documentation' };

export default function Page() {
  return (
    <RouteShell eyebrow="DEVELOPER DOCUMENTATION" title="Build against the same canonical proof transaction." lede="Documentation for deterministic verification, registry resolution, signed events, webhooks, SDKs, MCP contracts, lifecycle control, and Test Mode boundaries.">
      <DocsIndex />
    </RouteShell>
  );
}
