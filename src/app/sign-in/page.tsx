import type { Metadata } from 'next';
import { RouteShell } from '@/ui/RouteShell';
import { SignInAccess } from '@/ui/SignInAccess';
import { AuthoritySignInAccess } from '@/ui/AuthoritySignInAccess';
import { publicEnvironment } from '@/authority/config';

export const metadata: Metadata = { title: 'Operational access' };

export default function Page() {
  const environment = publicEnvironment();
  if (environment === 'sandbox') {
    return (
      <RouteShell eyebrow="OPERATOR ACCESS / TEST MODE" title="Enter the authenticated website through an explicit authority context." lede="Select a deterministic organization role to inspect permissions, intake, evidence, review, issuance, registry publication, labels, exceptions, and audit behavior.">
        <SignInAccess />
      </RouteShell>
    );
  }
  return (
    <RouteShell eyebrow={`OPERATOR ACCESS / ${environment.toUpperCase()}`} title="Authenticate into the governed organization workspace." lede="Identity, MFA, active tenant membership, role, session, and device context are verified before any operational data or consequential command is available.">
      <AuthoritySignInAccess environment={environment} />
    </RouteShell>
  );
}
