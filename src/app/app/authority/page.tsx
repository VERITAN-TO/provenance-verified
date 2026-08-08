import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { AuthorityControlCenter } from '@/ui/operations/AuthorityControlCenter';
import { OperationalGovernancePanel } from '@/ui/operations/OperationalGovernancePanel';
import { CommercialAuthorityPanel } from '@/ui/operations/CommercialAuthorityPanel';

export const metadata: Metadata = { title: 'Launch authority' };

export default function AuthorityPage() {
  return <OperationsShell eyebrow="ORIGINAL CAMPAIGN AUTHORITY" title="Launch-to-operate control"><><AuthorityControlCenter /><OperationalGovernancePanel /><CommercialAuthorityPanel /></></OperationsShell>;
}
