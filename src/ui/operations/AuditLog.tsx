'use client';
import { useOperationsStore } from '@/operations/useOperationsStore';
export function AuditLog() {
  const { dataset, sessionId } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const events = dataset.auditEvents.filter((item) => item.tenantId === session.tenantId).slice().reverse();
  return <div className="ops-panel"><div className="ops-table ops-audit-table"><div className="ops-table-head"><span>Time</span><span>Actor</span><span>Action</span><span>Target</span><span>Request</span></div>{events.map((event) => <div key={event.id}><time>{event.at}</time><span><strong>{event.actorId}</strong><small>{event.actorRole}</small></span><span>{event.action}</span><span><strong>{event.targetType}</strong><small>{event.targetId}</small></span><code>{event.requestId}</code></div>)}</div></div>;
}
