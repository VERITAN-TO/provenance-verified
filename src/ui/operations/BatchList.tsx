'use client';
import Link from 'next/link';
import { useOperationsStore } from '@/operations/useOperationsStore';
export function BatchList() {
  const { dataset, sessionId } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const batches = dataset.batches.filter((item) => item.tenantId === session.tenantId);
  return <div className="ops-panel"><div className="ops-table ops-batch-list"><div className="ops-table-head"><span>Batch</span><span>Status</span><span>Units</span><span>Errors</span><span>Location</span></div>{batches.map((batch) => <Link key={batch.id} href={`/app/batches/${batch.id}`}><span><strong>{batch.reference}</strong><small>{batch.name}</small></span><em data-state={batch.status}>{batch.status}</em><span>{batch.assetIds.length}</span><span>{batch.validationErrors.filter((item) => item.severity === 'error').length}</span><span>{dataset.locations.find((item) => item.id === batch.locationId)?.code}</span></Link>)}</div></div>;
}
