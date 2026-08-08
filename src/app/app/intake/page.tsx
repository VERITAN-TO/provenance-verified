import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { BatchIntakeConsole } from '@/ui/operations/BatchIntakeConsole';
export const metadata: Metadata = { title: 'Gemstone intake' };
export default function IntakePage() { return <OperationsShell eyebrow="FIELD PWA" title="Gemstone intake"><BatchIntakeConsole /></OperationsShell>; }
