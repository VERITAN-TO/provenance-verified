'use client';

import Link from 'next/link';
import { useOperationsStore } from '@/operations/useOperationsStore';

export function OperationsDashboard() {
  const { dataset, sessionId } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const batches = dataset.batches.filter((item) => item.tenantId === session.tenantId);
  const assets = dataset.assets.filter((item) => item.tenantId === session.tenantId);
  const reviews = dataset.reviewCases.filter((item) => item.tenantId === session.tenantId);
  const exceptions = [...batches.flatMap((item) => item.validationErrors), ...dataset.syncOperations.filter((item) => item.tenantId === session.tenantId && ['conflict', 'failed', 'queued'].includes(item.status))];
  const issued = reviews.filter((item) => item.credential?.status === 'issued').length;
  return <>
    <section className="ops-metric-grid">
      <article><span>Active batches</span><strong>{batches.filter((item) => !['completed'].includes(item.status)).length}</strong><small>{batches.length} total in tenant</small></article>
      <article><span>Identified units</span><strong>{assets.length.toLocaleString()}</strong><small>Never inferred from lot quantity</small></article>
      <article><span>Review cases</span><strong>{reviews.length}</strong><small>{reviews.filter((item) => item.status === 'unassigned').length} unassigned</small></article>
      <article><span>Issued credentials</span><strong>{issued}</strong><small>Seal use remains separately controlled</small></article>
    </section>
    <section className="ops-dashboard-grid">
      <article className="ops-panel ops-wide"><header><div><span>Operational flow</span><h2>From intake to registry</h2></div><Link href="/app/intake">Open intake</Link></header><div className="ops-flow">{['Receive', 'Identify unit', 'Capture evidence', 'Attest', 'Review', 'Authorize', 'Publish', 'Control mark'].map((item, index) => <div key={item}><b>{String(index + 1).padStart(2, '0')}</b><span>{item}</span></div>)}</div></article>
      <article className="ops-panel"><header><div><span>Exceptions</span><h2>Action required</h2></div><Link href="/app/exceptions">Inspect</Link></header><strong className="ops-large-number">{exceptions.length}</strong><p>Validation, synchronization, and authority blockers remain visible until resolved.</p></article>
      <article className="ops-panel"><header><div><span>Offline queue</span><h2>Device continuity</h2></div></header><strong className="ops-large-number">{dataset.syncOperations.filter((item) => item.tenantId === session.tenantId && item.status === 'queued').length}</strong><p>Queued work is never presented as submitted or published.</p></article>
      <article className="ops-panel ops-wide"><header><div><span>Recent batches</span><h2>Current production</h2></div><Link href="/app/batches">All batches</Link></header><div className="ops-table"><div className="ops-table-head"><span>Reference</span><span>Status</span><span>Units</span><span>Updated</span></div>{batches.slice(0, 6).map((batch) => <Link href={`/app/batches/${batch.id}`} key={batch.id}><span><strong>{batch.reference}</strong><small>{batch.name}</small></span><em data-state={batch.status}>{batch.status}</em><span>{batch.assetIds.length}</span><time>{batch.updatedAt.slice(0, 10)}</time></Link>)}</div></article>
    </section>
  </>;
}
