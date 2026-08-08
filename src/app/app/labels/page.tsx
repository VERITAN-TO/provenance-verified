import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { LabelWorkspace } from '@/ui/operations/LabelWorkspace';
export const metadata: Metadata = { title: 'Controlled labels' };
export default function LabelsPage() { return <OperationsShell eyebrow="CONTROLLED PROJECTION" title="Labels and QR"><LabelWorkspace /></OperationsShell>; }
