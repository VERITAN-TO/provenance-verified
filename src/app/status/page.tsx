import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';
import { RuntimeStatus } from '@/ui/RuntimeStatus';
import { getPublicEnvironment } from '@/authority/public-mode';

export const metadata: Metadata = { title: 'Status' };

export default function Page() {
  const environment = getPublicEnvironment();
  const title = environment === 'sandbox'
    ? 'Deterministic demonstration services.'
    : environment === 'pilot'
      ? 'Production-connected pilot status.'
      : 'Production authority status.';
  const lede = environment === 'sandbox'
    ? 'This surface reports isolated Test Mode components and never claims live production authority.'
    : 'This surface resolves current dependency readiness from the separate fail-closed authority plane.';
  return <RouteShell eyebrow={`SERVICE STATUS / ${environment.toUpperCase()}`} title={title} lede={lede}><RuntimeStatus /></RouteShell>;
}
