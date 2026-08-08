'use client';

import { useRef, useState } from 'react';
import { useOperationsStore } from '@/operations/useOperationsStore';

function numberOrNull(value: string) { return value === '' ? null : Number(value); }

export function BatchIntakeConsole() {
  const {
    dataset, sessionId, selectedBatchId, selectedAssetId, selectBatch, selectAsset, createBatch, addAsset, addBulkAssets,
    updateSelectedAsset, addEvidence, addEvidenceFile, importCsvFile, validateSelectedBatch, submitSelectedBatch, online, flushSyncQueue, syncState,
  } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const batches = dataset.batches.filter((item) => item.tenantId === session.tenantId);
  const batch = batches.find((item) => item.id === selectedBatchId) ?? batches[0];
  const assets = dataset.assets.filter((item) => item.batchId === batch?.id);
  const selected = assets.find((item) => item.id === selectedAssetId) ?? assets[0] ?? null;
  const selectedEvidence = dataset.evidence.filter((item) => item.assetId === selected?.id);
  const [serial, setSerial] = useState('');
  const [bulkCount, setBulkCount] = useState(100);
  const cameraInput = useRef<HTMLInputElement>(null);
  const csvInput = useRef<HTMLInputElement>(null);
  const add = () => {
    if (!serial.trim()) return;
    addAsset({ serial: serial.trim(), material: 'Natural gemstone', shape: 'Unspecified', cut: '', colorDescription: '', clarityDescription: '', treatmentDisclosure: 'Unknown / not declared', originClaim: 'Not claimed', measurements: { weightCarats: null, lengthMm: null, widthMm: null, depthMm: null }, identifyingFeatures: [], supplierReference: '', laboratoryReportReference: '' });
    setSerial('');
  };
  return <div className="ops-intake-layout">
    <aside className="ops-panel ops-intake-control">
      <span className="ops-kicker">Batch context</span>
      <label>Active batch<select value={batch?.id ?? ''} onChange={(event) => selectBatch(event.target.value)}>{batches.map((item) => <option key={item.id} value={item.id}>{item.reference} — {item.status}</option>)}</select></label>
      <button onClick={() => createBatch(`New intake ${batches.length + 1}`, `INTAKE-${String(batches.length + 1).padStart(3, '0')}`)}>Create batch</button>
      <div className="ops-divider" />
      <label>Unit serial<input value={serial} onChange={(event) => setSerial(event.target.value)} placeholder="Physical unit identifier" /></label>
      <button className="button button-primary" onClick={add}>Create identified unit</button>
      <div className="ops-divider" />
      <label>Bulk draft count<input type="number" min="1" max="1000" value={bulkCount} onChange={(event) => setBulkCount(Number(event.target.value))} /></label>
      <button onClick={() => addBulkAssets(bulkCount)}>Create individual draft records</button>
      <small>Bulk creation produces explicit unit records only. It never expands a lot quantity automatically.</small>
      <div className="ops-divider" />
      <input ref={csvInput} className="ops-file-input" type="file" accept=".csv,text/csv" onChange={async (event) => { const file = event.target.files?.[0]; if (file) await importCsvFile(file); event.currentTarget.value = ''; }} />
      <button onClick={() => csvInput.current?.click()}>Import gemstone CSV</button>
      <small>CSV imports create explicit unit identities. Invalid rows and tenant duplicate serials fail closed.</small>
    </aside>
    <section className="ops-intake-main">
      <section className="ops-panel ops-intake-stage">
        <header><div><span>Guided intake</span><h2>{batch?.reference ?? 'No batch selected'}</h2></div><div className="ops-button-row"><button onClick={validateSelectedBatch}>Validate</button><button onClick={submitSelectedBatch}>Attest & submit</button><button disabled={!online || syncState === 'syncing'} onClick={flushSyncQueue}>Sync queue</button></div></header>
        <div className="ops-intake-summary"><div><span>Units</span><strong>{assets.length}</strong></div><div><span>Ready</span><strong>{assets.filter((item) => item.status === 'ready').length}</strong></div><div><span>Draft</span><strong>{assets.filter((item) => item.status === 'draft').length}</strong></div><div><span>Errors</span><strong>{batch?.validationErrors.filter((item) => item.severity === 'error').length ?? 0}</strong></div></div>
        <div className="ops-table ops-intake-table"><div className="ops-table-head"><span>Unit</span><span>Material</span><span>Measurements</span><span>Evidence</span><span>Status</span></div>{assets.slice(0, 250).map((asset) => <button type="button" className={asset.id === selected?.id ? 'ops-intake-row is-selected' : 'ops-intake-row'} key={asset.id} onClick={() => selectAsset(asset.id)}><span><strong>{asset.serial}</strong><small>{asset.id}</small></span><span>{asset.material}<small>{asset.shape}</small></span><span>{asset.measurements.weightCarats ?? '—'} ct<small>{asset.measurements.lengthMm ?? '—'} × {asset.measurements.widthMm ?? '—'} × {asset.measurements.depthMm ?? '—'} mm</small></span><span>{asset.evidenceIds.length}<small>{asset.laboratoryReportReference || 'No lab reference'}</small></span><em data-state={asset.status}>{asset.status}</em></button>)}</div>
        {assets.length > 250 && <p className="ops-pagination-note">Showing the first 250 of {assets.length.toLocaleString()} units. Production pagination is server-driven.</p>}
      </section>
      {selected && <section className="ops-panel ops-unit-inspector">
        <header><div><span>Unit inspector</span><h2>{selected.serial}</h2></div><em data-state={selected.status}>{selected.status}</em></header>
        <div className="ops-unit-form">
          <label>Material<input value={selected.material} onChange={(event) => updateSelectedAsset({ material: event.target.value })} /></label>
          <label>Shape<input value={selected.shape} onChange={(event) => updateSelectedAsset({ shape: event.target.value })} /></label>
          <label>Cut<input value={selected.cut} onChange={(event) => updateSelectedAsset({ cut: event.target.value })} /></label>
          <label>Weight (ct)<input type="number" step="0.01" value={selected.measurements.weightCarats ?? ''} onChange={(event) => updateSelectedAsset({ measurements: { ...selected.measurements, weightCarats: numberOrNull(event.target.value) } })} /></label>
          <label>Length (mm)<input type="number" step="0.01" value={selected.measurements.lengthMm ?? ''} onChange={(event) => updateSelectedAsset({ measurements: { ...selected.measurements, lengthMm: numberOrNull(event.target.value) } })} /></label>
          <label>Width (mm)<input type="number" step="0.01" value={selected.measurements.widthMm ?? ''} onChange={(event) => updateSelectedAsset({ measurements: { ...selected.measurements, widthMm: numberOrNull(event.target.value) } })} /></label>
          <label>Depth (mm)<input type="number" step="0.01" value={selected.measurements.depthMm ?? ''} onChange={(event) => updateSelectedAsset({ measurements: { ...selected.measurements, depthMm: numberOrNull(event.target.value) } })} /></label>
          <label>Origin claim<input value={selected.originClaim} onChange={(event) => updateSelectedAsset({ originClaim: event.target.value })} /></label>
          <label className="ops-form-wide">Treatment disclosure<input value={selected.treatmentDisclosure} onChange={(event) => updateSelectedAsset({ treatmentDisclosure: event.target.value })} /></label>
          <label className="ops-form-wide">Identifying features<input value={selected.identifyingFeatures.join(', ')} onChange={(event) => updateSelectedAsset({ identifyingFeatures: event.target.value.split(',').map((item) => item.trim()).filter(Boolean) })} /></label>
        </div>
        <div className="ops-evidence-capture"><div><span className="ops-kicker">Evidence capture</span><p>Phone images support the physical fingerprint. They do not perform laboratory authentication.</p></div><div className="ops-button-row"><input ref={cameraInput} className="ops-file-input" type="file" accept="image/jpeg,image/png,image/webp" capture="environment" onChange={async (event) => { const file = event.target.files?.[0]; if (file) await addEvidenceFile(file); event.currentTarget.value = ''; }} /><button onClick={() => cameraInput.current?.click()}>Capture / choose photo</button><button onClick={() => addEvidence('measurement')}>Attach measurement</button><button onClick={() => addEvidence('laboratory', true)}>Attach independent lab report</button><button onClick={() => addEvidence('document', true)}>Attach source record</button></div></div>
        <ul className="ops-evidence-list">{selectedEvidence.map((item) => <li key={item.id}><span><strong>{item.label}</strong><small>{item.integrityHash}</small></span><em>{item.independent ? 'independent' : 'submitted'} · {item.status}</em></li>)}</ul>
      </section>}
    </section>
  </div>;
}
