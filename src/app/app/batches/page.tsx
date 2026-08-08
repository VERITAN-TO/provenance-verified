import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { BatchList } from '@/ui/operations/BatchList';
export const metadata: Metadata = { title: 'Batches' };
export default function BatchesPage() { return <OperationsShell eyebrow="INVENTORY OPERATIONS" title="Batches"><BatchList /></OperationsShell>; }
