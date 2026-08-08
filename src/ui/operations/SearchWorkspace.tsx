'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useOperationsStore } from '@/operations/useOperationsStore';
import { authorizationHeaders } from '@/operations/auth';
import type { EvidenceObject, GemstoneAsset, IntakeBatch, ReviewCase } from '@/operations/types';

interface SearchResults { assets: GemstoneAsset[]; batches: IntakeBatch[]; evidence: EvidenceObject[]; reviews: ReviewCase[] }

export function SearchWorkspace() {
  const { dataset, sessionId } = useOperationsStore();
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState('');
  const [results, setResults] = useState<SearchResults>({ assets: [], batches: [], evidence: [], reviews: [] });
  const [message, setMessage] = useState('Search by asset ID, serial, batch, supplier, laboratory report, credential, source, or status.');
  const search = async () => {
    setMessage('Searching tenant-scoped operational records.');
    const params = new URLSearchParams({ q: query, limit: '100' });
    if (status) params.set('status', status);
    const response = await fetch(`/api/v1/operations/search?${params}`, { headers: authorizationHeaders(dataset.sessions.find((item) => item.id === sessionId)!) });
    const body = await response.json();
    if (!response.ok) return setMessage(body.error?.message ?? 'Search failed.');
    setResults(body.data);
    setMessage(`${body.data.assets.length} units, ${body.data.batches.length} batches, ${body.data.evidence.length} evidence objects, and ${body.data.reviews.length} review cases matched.`);
  };
  return <section className="ops-panel ops-search-workspace">
    <header><div><span>Tenant-scoped search</span><h2>Operational records</h2></div></header>
    <div className="ops-search-controls"><label>Search<input value={query} onChange={(event) => setQuery(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') void search(); }} placeholder="Serial, asset ID, report, supplier, credential…" /></label><label>Status<select value={status} onChange={(event) => setStatus(event.target.value)}><option value="">All</option><option value="draft">Draft</option><option value="submitted">Submitted</option><option value="in-review">In review</option><option value="issued">Issued</option><option value="blocked">Blocked</option></select></label><button className="button button-primary" onClick={() => void search()}>Search</button></div>
    <p role="status">{message}</p>
    <div className="ops-search-results"><article><h3>Units</h3>{results.assets.map((asset) => <Link key={asset.id} href={`/app/batches/${asset.batchId}`}><strong>{asset.serial}</strong><span>{asset.material} · {asset.status}</span><small>{asset.id}</small></Link>)}</article><article><h3>Batches</h3>{results.batches.map((batch) => <Link key={batch.id} href={`/app/batches/${batch.id}`}><strong>{batch.reference}</strong><span>{batch.name} · {batch.status}</span><small>{batch.assetIds.length} units</small></Link>)}</article><article><h3>Evidence</h3>{results.evidence.map((item) => <div key={item.id}><strong>{item.label}</strong><span>{item.sourceOrganization} · {item.status}</span><small>{item.integrityHash}</small></div>)}</article><article><h3>Review and credential</h3>{results.reviews.map((item) => <Link key={item.id} href="/app/review"><strong>{item.credential?.publicId ?? item.id}</strong><span>{item.status}</span><small>{item.assetId}</small></Link>)}</article></div>
  </section>;
}
