import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { ReviewWorkspace } from '@/ui/operations/ReviewWorkspace';
export const metadata: Metadata = { title: 'Review workspace' };
export default function ReviewPage() { return <OperationsShell eyebrow="AUTHORITY OPERATIONS" title="Evidence review"><ReviewWorkspace /></OperationsShell>; }
