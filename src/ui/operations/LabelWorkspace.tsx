'use client';

import Image from 'next/image';
import { useMemo, useState } from 'react';
import { useOperationsStore } from '@/operations/useOperationsStore';
import { authorizationHeaders } from '@/operations/auth';

interface GeneratedLabel { labelId: string; assetId: string; serial: string; credentialId: string; publicId: string; tier: number; sealAsset: string; verificationUrl: string; qrSvg: string }

export function LabelWorkspace() {
  const { dataset, sessionId } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const tenantAssets = dataset.assets.filter((item) => item.tenantId === session.tenantId);
  const [selected, setSelected] = useState<string[]>([]);
  const [labels, setLabels] = useState<GeneratedLabel[]>([]);
  const [message, setMessage] = useState('Only issued credentials with authorized mark use can generate physical projections.');
  const candidates = useMemo(() => tenantAssets.map((asset) => ({ asset, review: dataset.reviewCases.find((item) => item.assetId === asset.id) })).filter((item) => item.review?.credential?.status === 'issued'), [tenantAssets, dataset.reviewCases]);
  const generate = async () => {
    if (!selected.length) return setMessage('Select at least one issued unit.');
    const response = await fetch('/api/v1/operations/labels', { method: 'POST', headers: authorizationHeaders(session, 'application/json'), body: JSON.stringify({ assetIds: selected, format: 'svg' }) });
    const body = await response.json();
    setLabels(body.data ?? []);
    setMessage(response.ok ? `${body.meta.generated} controlled labels generated.` : `${body.blocked?.length ?? 0} labels blocked because issuance or mark authorization is incomplete.`);
  };
  return <div className="ops-label-layout"><section className="ops-panel"><header><div><span>Controlled carrier generation</span><h2>Labels and QR</h2></div><button className="button button-primary" onClick={() => void generate()}>Generate selected</button></header><p role="status">{message}</p><div className="ops-label-candidates">{candidates.length ? candidates.map(({ asset, review }) => <label key={asset.id}><input type="checkbox" checked={selected.includes(asset.id)} onChange={(event) => setSelected((current) => event.target.checked ? [...current, asset.id] : current.filter((id) => id !== asset.id))} /><span><strong>{asset.serial}</strong><small>{review?.credential?.publicId} · mark {review?.credential?.sealAuthorization.status}</small></span></label>) : <p>No issued credentials are currently available in the active tenant. Complete review, signing, registry readiness, and mark authorization first.</p>}</div></section><section className="ops-label-preview">{labels.map((label) => <article key={label.labelId}><Image src={label.sealAsset} alt={`Provenance Verified Tier ${label.tier}`} width={72} height={72} unoptimized /><div><span>PROVENANCE VERIFIED™</span><strong>{label.serial}</strong><small>{label.publicId}</small><small>{label.credentialId}</small></div><div className="ops-qr" aria-label={`QR verification carrier for ${label.publicId}`} dangerouslySetInnerHTML={{ __html: label.qrSvg }} /><footer>Scan resolves the canonical registry. This physical carrier is not the authority.</footer></article>)}</section></div>;
}
