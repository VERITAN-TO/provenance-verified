import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { AuditLog } from '@/ui/operations/AuditLog';
export const metadata: Metadata = { title: 'Operational audit' };
export default function AuditPage() { return <OperationsShell eyebrow="IMMUTABLE ACTIVITY" title="Operational audit"><AuditLog /></OperationsShell>; }
