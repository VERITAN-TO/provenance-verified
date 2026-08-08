import { OperationsShell } from '@/ui/operations/OperationsShell';
import { LotWorkspace } from '@/ui/operations/LotWorkspace';

export default function LotsPage() {
  return <OperationsShell title="Lots and parcels" eyebrow="Inventory receiving"><LotWorkspace /></OperationsShell>;
}
