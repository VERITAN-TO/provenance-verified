import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { ExceptionsQueue } from '@/ui/operations/ExceptionsQueue';
export const metadata: Metadata = { title: 'Exceptions' };
export default function ExceptionsPage() { return <OperationsShell eyebrow="FAIL-CLOSED OPERATIONS" title="Exceptions"><ExceptionsQueue /></OperationsShell>; }
