import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { OperationsDashboard } from '@/ui/operations/OperationsDashboard';
export const metadata: Metadata = { title: 'Operations command' };
export default function OperationsPage() { return <OperationsShell eyebrow="PROVENANCE OPERATIONS" title="Jeweler command center"><OperationsDashboard /></OperationsShell>; }
