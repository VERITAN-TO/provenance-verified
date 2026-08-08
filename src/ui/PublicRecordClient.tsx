'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import type { CertificationTier } from '@/domain/types';
import { RouteShell } from './RouteShell';
import { TierSeal } from './TierSeal';
import { CodeSurface, StatePill } from './phase3/Shared';

type Envelope<T> = { data?: T; error?: { code?: string; message?: string }; meta?: Record<string, unknown> };
type History = { publicId: string; versions: Array<Record<string, unknown>>; events: Array<Record<string, unknown>>; independentlyRebuildable: boolean };

function tierOf(record: Record<string, unknown>): CertificationTier {
  const certification = record.certification as Record<string, unknown> | undefined;
  const value = Number(record.tier ?? certification?.tier ?? 1);
  return ([1,2,3,4].includes(value) ? value : 1) as CertificationTier;
}

function array(value: unknown): Array<Record<string, unknown>> { return Array.isArray(value) ? value.filter((item): item is Record<string, unknown> => Boolean(item && typeof item === 'object')) : []; }

export function PublicRecordClient({ publicId }: { publicId: string }) {
  const [record, setRecord] = useState<Record<string, unknown> | null>(null);
  const [history, setHistory] = useState<History | null>(null);
  const [message, setMessage] = useState('Resolving canonical registry record…');

  useEffect(() => {
    const controller = new AbortController();
    void Promise.all([
      fetch(`/api/v1/registry/${encodeURIComponent(publicId)}`, { cache: 'no-store', signal: controller.signal }),
      fetch(`/api/v1/registry/${encodeURIComponent(publicId)}/history`, { cache: 'no-store', signal: controller.signal }),
    ]).then(async ([recordResponse, historyResponse]) => {
      const recordBody = await recordResponse.json().catch(() => ({})) as Envelope<Record<string, unknown>>;
      if (!recordResponse.ok || !recordBody.data) throw new Error(recordBody.error?.message ?? recordBody.error?.code ?? `REGISTRY_${recordResponse.status}`);
      const historyBody = await historyResponse.json().catch(() => ({})) as Envelope<History>;
      if (!historyResponse.ok || !historyBody.data) throw new Error(historyBody.error?.message ?? historyBody.error?.code ?? `REGISTRY_HISTORY_${historyResponse.status}`);
      setRecord(recordBody.data); setHistory(historyBody.data); setMessage('Canonical current state and append-only history resolved.');
    }).catch((error) => { if ((error as Error).name !== 'AbortError') setMessage(error instanceof Error ? error.message : 'Registry unavailable.'); });
    return () => controller.abort();
  }, [publicId]);

  const view = useMemo(() => {
    if (!record) return null;
    const certification = record.certification as Record<string, unknown> | undefined;
    const signature = record.signature as Record<string, unknown> | undefined;
    const seal = record.sealAuthorization as Record<string, unknown> | undefined;
    const claims = array(record.claimScope ?? record.claims);
    const evidenceSummary = record.evidenceSummary as Record<string, unknown> | undefined;
    return {
      tier: tierOf(record), tierName: String(record.tierName ?? certification?.name ?? `Tier ${tierOf(record)}`),
      disclosure: String(certification?.disclosure ?? record.disclosure ?? 'Published provenance credential.'),
      lifecycle: String(record.lifecycle ?? 'unknown'), version: Number(record.version ?? history?.versions.at(-1)?.version ?? 1),
      issuer: String(record.issuer ?? 'PROVENANCE VERIFIED™'), program: String(record.program ?? 'PROVENANCE Verified'),
      issuedAt: String(record.issuedAt ?? record.publishedAt ?? ''), integrityHash: String(record.integrityHash ?? record.credentialDigest ?? ''),
      signatureStatus: String(signature?.status ?? (signature?.valid === true ? 'valid' : 'unverified')),
      signatureKey: String(signature?.keyId ?? history?.versions.at(-1)?.signingKeyId ?? ''),
      markAuthorized: seal?.status === 'authorized' || record.markAuthorized === true,
      markStatus: String(seal?.status ?? (record.markAuthorized === true ? 'authorized' : 'withheld')),
      claims, evidenceCount: Number(evidenceSummary?.count ?? record.evidenceCount ?? 0),
      successorId: record.successorId ? String(record.successorId) : null,
    };
  }, [history, record]);

  if (!record || !view || !history) return <RouteShell eyebrow="PUBLIC REGISTRY" title={record ? publicId : 'Resolving registry record.'} lede={message}><div className="empty-state"><p role="status">{message}</p><Link className="button button-secondary" href="/registry">Return to registry</Link></div></RouteShell>;

  return <RouteShell eyebrow="PUBLIC REGISTRY RECORD" title={publicId} lede={view.disclosure} aside={<TierSeal tier={view.tier} compact authorized={view.markAuthorized} />}>
    <div className="public-record-page p3-public-record-page">
      <div className="p3-record-statusbar"><StatePill tone={view.lifecycle.toLowerCase() === 'active' ? 'good' : view.lifecycle.toLowerCase() === 'revoked' ? 'danger' : 'warn'}>{view.lifecycle}</StatePill><span>Version {view.version}</span><span>{view.signatureStatus}</span><span>Mark {view.markStatus}</span></div>
      <section className="p3-route-record-summary" aria-labelledby="record-summary-title"><div className="p3-route-record-seal"><TierSeal tier={view.tier} authorized={view.markAuthorized} /></div><div><span className="eyebrow"><span />ISSUED CREDENTIAL</span><h2 id="record-summary-title">Tier {view.tier} · {view.tierName}</h2><p>{view.disclosure}</p><dl className="record-grid"><div><dt>Issuer</dt><dd>{view.issuer}</dd></div><div><dt>Program</dt><dd>{view.program}</dd></div><div><dt>Issued</dt><dd>{view.issuedAt}</dd></div><div><dt>Signature key</dt><dd>{view.signatureKey}</dd></div><div><dt>Integrity hash</dt><dd>{view.integrityHash}</dd></div><div><dt>Certification mark</dt><dd>{view.markStatus}</dd></div></dl></div></section>
      <section className="p3-route-section" aria-labelledby="record-claims-title"><div className="p3-route-section-head"><div><span>CLAIM SCOPE</span><h2 id="record-claims-title">One credential. Exact claim outcomes.</h2></div><strong>{view.claims.length} determinations</strong></div><div className="record-claims p3-record-claims">{view.claims.map((claim, index) => <article key={String(claim.id ?? index)}><span className={`claim-status ${String(claim.status ?? 'unknown')}`}>{String(claim.status ?? 'unknown')}</span><h3>{String(claim.label ?? claim.claimType ?? `Claim ${index + 1}`)}</h3><strong>{String(claim.value ?? claim.decision ?? '')}</strong><p>{String(claim.scopeNote ?? claim.reason ?? '')}</p></article>)}</div></section>
      <section className="p3-route-section" aria-labelledby="record-evidence-title"><div className="p3-route-section-head"><div><span>EVIDENCE + CUSTODY</span><h2 id="record-evidence-title">Private evidence remains protected; public counts remain attributable.</h2></div><strong>{view.evidenceCount} objects</strong></div><p>Every published version remains digest-bound to immutable custody and the credential signature.</p></section>
      <section className="p3-route-section" aria-labelledby="record-history-title"><div className="p3-route-section-head"><div><span>SIGNED HISTORY</span><h2 id="record-history-title">No prior public authority is erased.</h2></div><strong>{history.events.length} events · {history.versions.length} versions</strong></div><ol className="p3-route-event-list">{history.events.map((event, index) => <li key={String(event.eventHash ?? event.id ?? index)}><b>{String(event.sequence ?? index + 1).padStart(2,'0')}</b><div><strong>{String(event.eventType ?? event.type ?? 'registry.event')}</strong><span>{String(event.occurredAt ?? event.at ?? '')}</span><code>{String(event.eventHash ?? '')}</code><small>{String(event.fromState ?? '')} → {String(event.toState ?? event.lifecycle ?? '')}</small></div></li>)}</ol></section>
      <section className="p3-route-section p3-route-machine" aria-labelledby="record-machine-title"><div className="p3-route-section-head"><div><span>MACHINE PROJECTION</span><h2 id="record-machine-title">Current state and history resolve through the same API.</h2></div><Link href={`/api/v1/registry/${publicId}`}>Open JSON endpoint →</Link></div><CodeSurface title="PUBLIC REGISTRY JSON" value={JSON.stringify({ current: record, history }, null, 2)} label="Copy record" /></section>
      {view.successorId ? <p className="successor-link">This record is superseded. <Link href={`/registry/${view.successorId}`}>Open successor {view.successorId}</Link>.</p> : null}
      {!view.markAuthorized ? <div className="test-record-warning"><strong>MARK NOT AUTHORIZED</strong><span>The credential may exist, but the certification seal is suppressed by current mark authority.</span></div> : null}
    </div>
  </RouteShell>;
}
