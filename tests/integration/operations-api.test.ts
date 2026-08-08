import { beforeEach, describe, expect, it } from 'vitest';
import { NextRequest } from 'next/server';
import { GET as listBatches, POST as createBatch } from '@/app/api/v1/operations/batches/route';
import { GET as listLots, POST as createLot } from '@/app/api/v1/operations/lots/route';
import { GET as getBatch } from '@/app/api/v1/operations/batches/[batchId]/route';
import { POST as importAssets } from '@/app/api/v1/operations/batches/[batchId]/assets/route';
import { POST as importCsv } from '@/app/api/v1/operations/batches/[batchId]/csv/route';
import { POST as submitBatch } from '@/app/api/v1/operations/batches/[batchId]/submit/route';
import { PATCH as updateAsset } from '@/app/api/v1/operations/assets/[assetId]/route';
import { POST as addEvidence } from '@/app/api/v1/operations/assets/[assetId]/evidence/route';
import { POST as syncOperations } from '@/app/api/v1/operations/sync/route';
import { GET as searchOperations } from '@/app/api/v1/operations/search/route';
import { POST as reviewDecision } from '@/app/api/v1/operations/review/[caseId]/decision/route';
import { POST as generateLabels } from '@/app/api/v1/operations/labels/route';
import { OperationalRepository } from '@/operations/repository';
import { operationalDataset } from '@/operations/fixtures';
import { authorizationHeaders } from '@/operations/auth';

const session = (sessionId: string) => operationalDataset.sessions.find((item) => item.id === sessionId)!;
const headers = (sessionId: string, contentType = 'application/json') => authorizationHeaders(session(sessionId), contentType);

const assetInput = (serial: string) => ({
  serial,
  material: 'Natural sapphire',
  shape: 'Oval',
  cut: 'Faceted',
  colorDescription: 'Blue',
  clarityDescription: 'Eye clean',
  treatmentDisclosure: 'Heat disclosed',
  originClaim: 'Not claimed',
  supplierReference: '',
  laboratoryReportReference: '',
  identifyingFeatures: ['needle inclusion at 2 o’clock'],
  measurements: { weightCarats: 1, lengthMm: 6, widthMm: 4, depthMm: 3 },
});

async function createApiBatch(reference: string) {
  const response = await createBatch(new NextRequest('http://localhost/api/v1/operations/batches', {
    method: 'POST',
    headers: headers('session_intake'),
    body: JSON.stringify({ name: `API intake ${reference}`, reference, locationId: 'loc_phx_01', lotIds: [] }),
  }));
  expect(response.status).toBe(201);
  return (await response.json()).data as { id: string };
}

describe('Phase 4 operations API', () => {
  beforeEach(() => { globalThis.__pvOperationalRepository = new OperationalRepository(operationalDataset); });


  it('receives aggregate lots without manufacturing unit identities', async () => {
    const created = await createLot(new NextRequest('http://localhost/api/v1/operations/lots', {
      method: 'POST', headers: headers('session_intake'), body: JSON.stringify({ locationId: 'loc_phx_01', supplierReference: 'SUP-LOT-900', description: 'Mixed sapphire parcel', declaredQuantity: 1250, notes: 'Unit identification pending.' }),
    }));
    expect(created.status).toBe(403);

    const authorized = await createLot(new NextRequest('http://localhost/api/v1/operations/lots', {
      method: 'POST', headers: headers('session_inventory'), body: JSON.stringify({ locationId: 'loc_phx_01', supplierReference: 'SUP-LOT-900', description: 'Mixed sapphire parcel', declaredQuantity: 1250, notes: 'Unit identification pending.' }),
    }));
    const authorizedBody = await authorized.json();
    expect(authorized.status).toBe(201);
    expect(authorizedBody.data.declaredQuantity).toBe(1250);
    expect(authorizedBody.data.identifiedUnitCount).toBe(0);
    expect(authorizedBody.meta.noArtificialExpansion).toBe(true);

    const listed = await listLots(new NextRequest('http://localhost/api/v1/operations/lots', { headers: headers('session_inventory') }));
    const listBody = await listed.json();
    expect(listBody.data.some((item: { id: string }) => item.id === authorizedBody.data.id)).toBe(true);
    expect(listBody.data.every((item: { tenantId: string }) => item.tenantId === 'tenant_northstar')).toBe(true);
  });

  it('returns only the active tenant batches', async () => {
    const response = await listBatches(new NextRequest('http://localhost/api/v1/operations/batches', { headers: headers('session_intake') }));
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body.data.every((item: { tenantId: string }) => item.tenantId === 'tenant_northstar')).toBe(true);
  });

  it('rejects cross-tenant batch access', async () => {
    const response = await getBatch(new NextRequest('http://localhost/api/v1/operations/batches/batch_nyc_private', { headers: headers('session_intake') }), { params: Promise.resolve({ batchId: 'batch_nyc_private' }) });
    expect(response.status).toBe(403);
  });

  it('creates tenant-scoped batches and bulk unit records without expanding lot quantity', async () => {
    const created = await createApiBatch('API-001');
    const assets = Array.from({ length: 25 }, (_, index) => assetInput(`API-001-${index}`));
    const imported = await importAssets(new NextRequest(`http://localhost/api/v1/operations/batches/${created.id}/assets`, {
      method: 'POST', headers: headers('session_intake'), body: JSON.stringify({ assets }),
    }), { params: Promise.resolve({ batchId: created.id }) });
    const body = await imported.json();
    expect(imported.status).toBe(201);
    expect(body.data).toHaveLength(25);
    expect(body.meta.noArtificialExpansion).toBe(true);
  });


  it('imports validated CSV rows as explicit tenant-scoped unit identities', async () => {
    const created = await createApiBatch('CSV-001');
    const csv = [
      'serial,material,shape,weightCarats,lengthMm,widthMm,depthMm,colorDescription,identifyingFeatures',
      'CSV-UNIT-001,Natural sapphire,Oval,1.2,6,4,3,"Royal, vivid blue","needle|feather"',
      'CSV-UNIT-002,Natural ruby,Cushion,2.1,7,5,4,Red,silk',
    ].join('\n');
    const imported = await importCsv(new NextRequest(`http://localhost/api/v1/operations/batches/${created.id}/csv`, {
      method: 'POST', headers: headers('session_intake', 'text/csv'), body: csv,
    }), { params: Promise.resolve({ batchId: created.id }) });
    const body = await imported.json();
    expect(imported.status).toBe(201);
    expect(body.data).toHaveLength(2);
    expect(body.data[0].colorDescription).toBe('Royal, vivid blue');
    expect(body.meta.noArtificialExpansion).toBe(true);

    const invalid = await importCsv(new NextRequest(`http://localhost/api/v1/operations/batches/${created.id}/csv`, {
      method: 'POST', headers: headers('session_intake', 'text/csv'), body: 'serial,material\nBAD-001,Ruby',
    }), { params: Promise.resolve({ batchId: created.id }) });
    expect(invalid.status).toBe(422);
  });

  it('updates assets and persists evidence with tenant and role enforcement', async () => {
    const assetId = operationalDataset.assets[0].id;
    const updated = await updateAsset(new NextRequest(`http://localhost/api/v1/operations/assets/${assetId}`, {
      method: 'PATCH', headers: headers('session_intake'), body: JSON.stringify({ colorDescription: 'Royal blue', measurements: { weightCarats: 1.24 } }),
    }), { params: Promise.resolve({ assetId }) });
    const updatedBody = await updated.json();
    expect(updated.status).toBe(200);
    expect(updatedBody.data.colorDescription).toBe('Royal blue');
    expect(updatedBody.data.measurements.weightCarats).toBe(1.24);

    const evidence = await addEvidence(new NextRequest(`http://localhost/api/v1/operations/assets/${assetId}/evidence`, {
      method: 'POST',
      headers: headers('session_intake'),
      body: JSON.stringify({
        type: 'document', label: 'Supplier declaration', sourceOrganization: 'Qualified supplier', sourceType: 'supplier', acquisitionMethod: 'upload',
        claimIds: ['claim_origin'], independent: false, qualified: true, integrityHash: 'sha256:api-evidence-0001',
        storageKey: `tenants/tenant_northstar/assets/${assetId}/supplier.pdf`, visibility: 'reviewer',
      }),
    }), { params: Promise.resolve({ assetId }) });
    const evidenceBody = await evidence.json();
    expect(evidence.status).toBe(201);
    expect(evidenceBody.meta.phoneImageIsLaboratoryAuthentication).toBe(false);
    expect(globalThis.__pvOperationalRepository?.listEvidence(operationalDataset.sessions[0], assetId).some((item) => item.id === evidenceBody.data.id)).toBe(true);

    const denied = await updateAsset(new NextRequest(`http://localhost/api/v1/operations/assets/${assetId}`, {
      method: 'PATCH', headers: headers('session_other_tenant'), body: JSON.stringify({ colorDescription: 'Unauthorized edit' }),
    }), { params: Promise.resolve({ assetId }) });
    expect(denied.status).toBe(403);
  });

  it('persists immutable attestation and creates one review case per submitted unit', async () => {
    const response = await submitBatch(new NextRequest('http://localhost/api/v1/operations/batches/batch_phx_2026_0720_a/submit', {
      method: 'POST',
      headers: headers('session_attestor'),
      body: JSON.stringify({
        declarationAccepted: true,
        claimSummary: 'Submitted unit identity, measurements, treatment disclosures, and origin claims for independent review.',
        evidenceSummary: 'Every unit includes active controlled photography and measurement evidence; qualified independent evidence remains linked where present.',
        limitations: ['Phone imagery supports fingerprinting and does not constitute laboratory authentication.'],
      }),
    }), { params: Promise.resolve({ batchId: 'batch_phx_2026_0720_a' }) });
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body.data.attestation.immutable).toBe(true);
    expect(body.data.attestation.version).toBe(2);
    expect(body.data.reviewCaseCount).toBe(24);

    const repository = globalThis.__pvOperationalRepository!;
    const session = operationalDataset.sessions.find((item) => item.id === 'session_attestor')!;
    expect(repository.listAttestations(session, 'batch_phx_2026_0720_a')).toHaveLength(2);
    expect(repository.getBatch(session, 'batch_phx_2026_0720_a')?.status).toBe('submitted');
    expect(repository.listAssets(session, 'batch_phx_2026_0720_a').every((item) => item.status === 'submitted')).toBe(true);
  });

  it('searches only the active tenant operational estate', async () => {
    const response = await searchOperations(new NextRequest('http://localhost/api/v1/operations/search?q=PHX-0720-A-0001&limit=20', { headers: headers('session_intake') }));
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body.data.assets).toHaveLength(1);
    expect(body.data.assets[0].tenantId).toBe('tenant_northstar');
    expect(body.data.assets.some((item: { id: string }) => item.id === 'asset_private_tenant')).toBe(false);
  });

  it('binds reviewer identity to the authenticated session and generates QR labels only after mark authorization', async () => {
    const caseId = `review_${operationalDataset.assets[0].id}`;
    const spoofed = await reviewDecision(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/decision`, {
      method: 'POST', headers: headers('session_reviewer_secondary'), body: JSON.stringify({ reviewerId: 'reviewer_primary_01', role: 'secondary', decision: 'approve', independent: true, conflictFree: true, reasonCodes: ['PV_REVIEW_APPROVED'], action: 'review' }),
    }), { params: Promise.resolve({ caseId }) });
    expect(spoofed.status).toBe(400);

    const blockedLabel = await generateLabels(new NextRequest('http://localhost/api/v1/operations/labels', { method: 'POST', headers: headers('session_attestor'), body: JSON.stringify({ assetIds: [operationalDataset.assets[0].id], format: 'svg' }) }));
    expect(blockedLabel.status).toBe(409);

    const actions = [
      { session: 'session_reviewer_secondary', body: { reviewerId: 'reviewer_secondary_02', role: 'secondary', decision: 'approve', independent: true, conflictFree: true, reasonCodes: ['PV_REVIEW_APPROVED'], action: 'review' } },
      { session: 'session_compliance', body: { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_CUSTOS_PASS'], action: 'custos-pass' } },
      { session: 'session_compliance', body: { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_SIGNING_AUTHORIZED'], action: 'authorize-signing' } },
      { session: 'session_compliance', body: { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_REGISTRY_PUBLISHED'], action: 'publish-registry' } },
      { session: 'session_compliance', body: { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_REVOCATION_CONTROL_ENABLED'], action: 'enable-revocation-control' } },
      { session: 'session_compliance', body: { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_MARK_AUTHORIZED'], action: 'authorize-mark' } },
    ];
    for (const item of actions) {
      const response = await reviewDecision(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/decision`, { method: 'POST', headers: headers(item.session), body: JSON.stringify(item.body) }), { params: Promise.resolve({ caseId }) });
      expect(response.status).toBe(200);
    }

    const label = await generateLabels(new NextRequest('http://localhost/api/v1/operations/labels', { method: 'POST', headers: headers('session_attestor'), body: JSON.stringify({ assetIds: [operationalDataset.assets[0].id], format: 'svg' }) }));
    const body = await label.json();
    expect(label.status).toBe(200);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].qrSvg).toContain('<svg');
    expect(body.data[0].verificationUrl).toContain(body.data[0].publicId);
    expect(body.meta.physicalCarrierIsAuthority).toBe(false);
  });

  it('fails closed on sync version conflicts while applying valid device-scoped operations', async () => {
    const asset = operationalDataset.assets[0];
    const response = await syncOperations(new NextRequest('http://localhost/api/v1/operations/sync', {
      method: 'POST',
      headers: headers('session_intake'),
      body: JSON.stringify({ operations: [
        { id: 'sync-conflict-api', tenantId: asset.tenantId, deviceId: 'device_pwa_01', entityType: 'asset', entityId: asset.id, operation: 'update', expectedVersion: 0, payload: { colorDescription: 'Conflict write' }, status: 'queued', attempts: 0, createdAt: '2026-07-20T05:30:00Z' },
        { id: 'sync-apply-api', tenantId: asset.tenantId, deviceId: 'device_pwa_01', entityType: 'asset', entityId: asset.id, operation: 'update', expectedVersion: 1, payload: { colorDescription: 'Synchronized blue' }, status: 'queued', attempts: 0, createdAt: '2026-07-20T05:31:00Z' },
      ] }),
    }));
    const body = await response.json();
    expect(response.status).toBe(409);
    expect(body.meta.conflicts).toBe(1);
    expect(body.meta.applied).toBe(1);
    expect(body.data[0].operation.status).toBe('conflict');
    expect(body.data[1].operation.status).toBe('applied');
    expect(globalThis.__pvOperationalRepository?.getAsset(operationalDataset.sessions[0], asset.id)?.colorDescription).toBe('Synchronized blue');
  });
});
