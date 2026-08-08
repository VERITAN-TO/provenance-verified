'use client';

import { useState } from 'react';
import { useOperationsStore } from '@/operations/useOperationsStore';

export function LotWorkspace() {
  const { dataset, sessionId, createLot } = useOperationsStore();
  const session = dataset.sessions.find((item) => item.id === sessionId)!;
  const lots = dataset.lots.filter((item) => item.tenantId === session.tenantId);
  const [supplierReference, setSupplierReference] = useState('');
  const [description, setDescription] = useState('');
  const [declaredQuantity, setDeclaredQuantity] = useState(1);
  const [notes, setNotes] = useState('');
  return <div className="ops-dashboard-grid">
    <section className="ops-panel">
      <header><div><span>Aggregate receiving</span><h2>Receive a lot or parcel</h2></div></header>
      <div className="ops-unit-form">
        <label>Supplier reference<input value={supplierReference} onChange={(event) => setSupplierReference(event.target.value)} /></label>
        <label>Declared quantity<input type="number" min="1" value={declaredQuantity} onChange={(event) => setDeclaredQuantity(Number(event.target.value))} /></label>
        <label className="ops-form-wide">Description<input value={description} onChange={(event) => setDescription(event.target.value)} /></label>
        <label className="ops-form-wide">Notes<textarea value={notes} onChange={(event) => setNotes(event.target.value)} /></label>
      </div>
      <button className="button button-primary" onClick={() => void createLot({ supplierReference, description, declaredQuantity, notes })}>Receive aggregate lot</button>
      <p>A declared quantity remains aggregate inventory. Unit assets are created only through a real identifier or serialization event.</p>
    </section>
    <section className="ops-panel ops-wide">
      <header><div><span>Inventory reconciliation</span><h2>Lots and identified units</h2></div></header>
      <div className="ops-table"><div className="ops-table-head"><span>Supplier / description</span><span>Status</span><span>Declared</span><span>Identified</span></div>{lots.map((lot) => <div key={lot.id}><span><strong>{lot.supplierReference}</strong><small>{lot.description}</small></span><em data-state={lot.status}>{lot.status}</em><span>{lot.declaredQuantity.toLocaleString()}</span><span>{lot.identifiedUnitCount.toLocaleString()}</span></div>)}</div>
    </section>
  </div>;
}
