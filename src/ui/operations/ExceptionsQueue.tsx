'use client';
import { useOperationsStore } from '@/operations/useOperationsStore';
export function ExceptionsQueue() {
  const { dataset, sessionId } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const sync = dataset.syncOperations.filter((item) => item.tenantId === session.tenantId && item.status !== 'applied');
  const issues = dataset.batches.filter((item) => item.tenantId === session.tenantId).flatMap((batch) => batch.validationErrors.map((issue) => ({ ...issue, batchId: batch.id })));
  const authority = dataset.reviewCases.filter((item) => item.tenantId === session.tenantId && !['issued'].includes(item.status));
  return <div className="ops-dashboard-grid"><article className="ops-panel"><span className="ops-kicker">Synchronization</span><h2>{sync.length} open</h2><ul className="ops-issue-list">{sync.map((item) => <li key={item.id} data-severity={item.status === 'failed' ? 'error' : 'warning'}><strong>{item.status}</strong>{item.entityType} · {item.entityId}{item.error ? ` · ${item.error}` : ''}</li>)}</ul></article><article className="ops-panel"><span className="ops-kicker">Validation</span><h2>{issues.length} open</h2><ul className="ops-issue-list">{issues.slice(0, 40).map((item, index) => <li key={`${item.code}-${index}`} data-severity={item.severity}><strong>{item.code}</strong>{item.message}</li>)}</ul></article><article className="ops-panel ops-wide"><span className="ops-kicker">Authority blockers</span><h2>{authority.length} cases not issued</h2><div className="ops-table"><div className="ops-table-head"><span>Case</span><span>Status</span><span>Approvals</span><span>Credential</span></div>{authority.slice(0, 100).map((item) => <div key={item.id}><span><strong>{item.id}</strong><small>{item.assetId}</small></span><em data-state={item.status}>{item.status}</em><span>{item.approvals.length}</span><span>{item.credential?.authorization.status ?? 'not evaluated'}</span></div>)}</div></article></div>;
}
