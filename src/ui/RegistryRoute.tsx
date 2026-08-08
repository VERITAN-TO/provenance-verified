'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { RouteShell } from './RouteShell';
import { TierSeal } from './TierSeal';
import type { CertificationTier } from '@/domain/types';

type RegistrySummary = {
  publicId: string;
  lifecycle: string;
  tier: CertificationTier;
  tierName: string;
  description: string;
  claimCount: number;
  evidenceCount: number;
  markAuthorized: boolean;
  authoritative: boolean;
};

type Envelope = { data?: Array<Record<string, unknown>>; error?: { message?: string; code?: string }; meta?: Record<string, unknown> };

function tierOf(record: Record<string, unknown>): CertificationTier {
  const value = Number(record.tier ?? (record.certification as Record<string, unknown> | undefined)?.tier ?? 1);
  return ([1,2,3,4].includes(value) ? value : 1) as CertificationTier;
}

function normalize(record: Record<string, unknown>): RegistrySummary {
  const certification = record.certification as Record<string, unknown> | undefined;
  const claims = record.claimScope ?? record.claims;
  const evidence = record.evidenceSummary as Record<string, unknown> | undefined;
  const seal = record.sealAuthorization as Record<string, unknown> | undefined;
  return {
    publicId: String(record.publicId ?? record.public_id ?? ''),
    lifecycle: String(record.lifecycle ?? 'unknown'),
    tier: tierOf(record),
    tierName: String(record.tierName ?? certification?.name ?? `Tier ${tierOf(record)}`),
    description: String(record.description ?? certification?.disclosure ?? record.disclosure ?? 'Published provenance credential.'),
    claimCount: Number(record.claimCount ?? (Array.isArray(claims) ? claims.length : 0)),
    evidenceCount: Number(record.evidenceCount ?? evidence?.count ?? 0),
    markAuthorized: Boolean(record.markAuthorized ?? seal?.status === 'authorized' ?? false),
    authoritative: record.authoritative === true,
  };
}

export function RegistryRoute({ environment = 'sandbox' }: { environment?: 'sandbox' | 'pilot' | 'production' }) {
  const [query, setQuery] = useState('');
  const [records, setRecords] = useState<RegistrySummary[]>([]);
  const [message, setMessage] = useState('Loading append-only registry…');

  useEffect(() => {
    const controller = new AbortController();
    if (environment !== 'sandbox' && query.trim().length < 8) { setRecords([]); setMessage('Enter at least 8 characters from a public registry ID. Broad registry enumeration is disabled.'); return () => controller.abort(); }
    const timer = window.setTimeout(async () => {
      try {
        setMessage('Resolving current registry projection…');
        const response = await fetch(`/api/v1/registry?q=${encodeURIComponent(query)}`, { cache: 'no-store', signal: controller.signal });
        const body = await response.json().catch(() => ({})) as Envelope;
        if (!response.ok) throw new Error(body.error?.message ?? body.error?.code ?? `REGISTRY_${response.status}`);
        setRecords((body.data ?? []).map(normalize).filter((record) => record.publicId));
        setMessage(`${(body.data ?? []).length} append-only registry record(s) resolved.`);
      } catch (error) {
        if ((error as Error).name !== 'AbortError') setMessage(error instanceof Error ? error.message : 'Registry unavailable.');
      }
    }, 180);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [query, environment]);

  return (
    <RouteShell eyebrow="PUBLIC REGISTRY" title="Resolve issued credentials without hiding lifecycle or claim scope." lede="Only issuer-authorized credentials enter this registry. Evidence-eligible cases that have not passed review, conflict clearance, CUSTOS, signing, registry, revocation, and other required gates are not published.">
      <div className="registry-index p3-registry-index">
        <div className="p3-registry-toolbar">
          <div><label htmlFor="registry-filter">Search current and historical authority</label><input id="registry-filter" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={environment === 'sandbox' ? 'Public ID, tier, lifecycle, or credential' : 'Public ID prefix (8+ characters)'} /></div>
          <div className="p3-registry-count"><strong>{records.length}</strong><span>published records</span></div>
        </div>
        <p className="sr-only" role="status">{message}</p>
        <div className="p3-registry-legend"><span><i className="active" /> Active</span><span><i className="limited" /> Suspended / expired</span><span><i className="invalid" /> Revoked / superseded</span><span>Append-only history retained</span></div>
        {records.length ? (
          <div className="registry-record-list p3-registry-record-list">
            {records.map((record) => <Link key={record.publicId} href={`/registry/${record.publicId}`}>
              <TierSeal tier={record.tier} compact authorized={record.markAuthorized} />
              <span><strong>{record.publicId}</strong><small>Tier {record.tier} · {record.tierName} · {record.lifecycle}</small><p>{record.description}</p></span>
              <span className="p3-record-list-meta"><b>{record.claimCount}</b><small>claim states</small><b>{record.evidenceCount}</b><small>evidence objects</small></span>
              <em>Resolve →</em>
            </Link>)}
          </div>
        ) : <div className="empty-state"><p>{message}</p>{query ? <button type="button" className="button button-secondary" onClick={() => setQuery('')}>Clear search</button> : null}</div>}
      </div>
    </RouteShell>
  );
}
