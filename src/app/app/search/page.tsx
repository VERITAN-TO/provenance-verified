import type { Metadata } from 'next';
import { OperationsShell } from '@/ui/operations/OperationsShell';
import { SearchWorkspace } from '@/ui/operations/SearchWorkspace';
export const metadata: Metadata = { title: 'Operational search' };
export default function SearchPage() { return <OperationsShell eyebrow="OPERATIONS INDEX" title="Search records"><SearchWorkspace /></OperationsShell>; }
