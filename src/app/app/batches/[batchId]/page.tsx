import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { BatchDetail } from '@/ui/operations/BatchDetail';
export const metadata: Metadata = { title: 'Batch record' };
export default async function BatchPage({ params }: { params: Promise<{ batchId: string }> }) { const { batchId } = await params; return <OperationsShell eyebrow="BATCH RECORD" title="Controlled intake record"><BatchDetail batchId={batchId} /></OperationsShell>; }
