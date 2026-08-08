import { mkdir, writeFile } from 'node:fs/promises';
const base = process.env.BASE_URL || 'http://127.0.0.1:3000';
const results = [];

const tokenContext = 'PROVENANCE-VERIFIED:DETERMINISTIC:SESSION:BOUNDARY';
const sessionRecords = {
  session_intake: ['tenant_northstar','user_intake_01','intake-operator'],
  session_inventory: ['tenant_northstar','user_inventory_01','inventory-manager'],
  session_attestor: ['tenant_northstar','user_attestor_01','authorized-attestor'],
  session_reviewer: ['tenant_northstar','reviewer_primary_01','reviewer'],
  session_reviewer_secondary: ['tenant_northstar','reviewer_secondary_02','reviewer'],
  session_compliance: ['tenant_northstar','compliance_01','compliance-officer'],
  session_other_tenant: ['tenant_other','user_other_01','administrator'],
};
function stableHash(input) {
  let h1 = 0xdeadbeef ^ input.length;
  let h2 = 0x41c6ce57 ^ input.length;
  for (let i = 0; i < input.length; i += 1) {
    const ch = input.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return `${(h2 >>> 0).toString(16).padStart(8, '0')}${(h1 >>> 0).toString(16).padStart(8, '0')}`;
}
function tokenFor(sessionId) {
  const [tenantId,userId,role] = sessionRecords[sessionId];
  const signature = stableHash([tokenContext,sessionId,tenantId,userId,role,'2099-12-31T23:59:59Z'].join(':'));
  return `pv_test_v1.${sessionId}.${signature}`;
}
const authHeaders = (sessionId, contentType) => ({ ...(contentType ? { 'content-type': contentType } : {}), authorization: `Bearer ${tokenFor(sessionId)}` });
async function check(name, path, options = {}, expected = 200, predicate = () => true) {
  const response = await fetch(base + path, options);
  const text = await response.text();
  let body; try { body = JSON.parse(text); } catch { body = text; }
  const pass = response.status === expected && predicate(body);
  results.push({ name, method: options.method || 'GET', path, expected, actual: response.status, pass });
  if (!pass) throw new Error(`${name} failed: ${response.status} ${text.slice(0, 500)}`);
  return body;
}
const jsonHeaders = (sessionId) => authHeaders(sessionId, 'application/json');
for (const [name, path, text] of [
  ['operations command page', '/app', 'Jeweler command center'],
  ['lot receiving page', '/app/lots', 'Lots and parcels'],
  ['intake page', '/app/intake', 'Gemstone intake'],
  ['search page', '/app/search', 'Operational search'],
  ['review page', '/app/review', 'Evidence review'],
  ['labels page', '/app/labels', 'Labels and QR'],
]) await check(name, path, {}, 200, (body) => String(body).includes(text));

await check('intake cannot receive aggregate lot', '/api/v1/operations/lots', { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ locationId: 'loc_phx_01', supplierReference: 'HTTP-LOT-DENIED', description: 'Denied parcel', declaredQuantity: 5, notes: '' }) }, 403);
const lot = await check('inventory manager receives aggregate lot', '/api/v1/operations/lots', { method: 'POST', headers: jsonHeaders('session_inventory'), body: JSON.stringify({ locationId: 'loc_phx_01', supplierReference: 'HTTP-LOT-1250', description: 'Sapphire parcel awaiting serialization', declaredQuantity: 1250, notes: 'No unit identities created by receiving.' }) }, 201, (body) => body.data.declaredQuantity === 1250 && body.data.identifiedUnitCount === 0 && body.meta.noArtificialExpansion === true);
await check('tenant lot list', '/api/v1/operations/lots', { headers: authHeaders('session_inventory') }, 200, (body) => body.data.some((item) => item.id === lot.data.id) && body.data.every((item) => item.tenantId === 'tenant_northstar'));

const batches = await check('tenant batch list', '/api/v1/operations/batches', { headers: authHeaders('session_intake') }, 200, (body) => body.data.every((item) => item.tenantId === 'tenant_northstar'));
await check('cross tenant denied', '/api/v1/operations/batches/batch_nyc_private', { headers: authHeaders('session_intake') }, 403);
const created = await check('create operational batch', '/api/v1/operations/batches', { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ name: 'HTTP scale batch', reference: 'HTTP-1000-P4', locationId: 'loc_phx_01', lotIds: [lot.data.id] }) }, 201, (body) => body.data.tenantId === 'tenant_northstar');
const assets = Array.from({ length: 1000 }, (_, index) => ({ serial: `HTTP-1000-P4-${index}`, material: 'Natural sapphire', shape: 'Oval', cut: 'Faceted', colorDescription: 'Blue', clarityDescription: 'Eye clean', treatmentDisclosure: 'Heat disclosed', originClaim: 'Not claimed', supplierReference: '', laboratoryReportReference: '', identifyingFeatures: [`fingerprint-${index}`], measurements: { weightCarats: 1, lengthMm: 6, widthMm: 4, depthMm: 3 } }));
const imported = await check('bulk 1000 explicit units', `/api/v1/operations/batches/${created.data.id}/assets`, { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ assets }) }, 201, (body) => body.data.length === 1000 && body.meta.noArtificialExpansion === true);
const assetId = imported.data[0].id;
await check('partial unit update', `/api/v1/operations/assets/${assetId}`, { method: 'PATCH', headers: jsonHeaders('session_intake'), body: JSON.stringify({ colorDescription: 'HTTP royal blue', measurements: { weightCarats: 1.18 } }) }, 200, (body) => body.data.colorDescription === 'HTTP royal blue' && body.data.measurements.weightCarats === 1.18);
await check('controlled evidence attachment', `/api/v1/operations/assets/${assetId}/evidence`, { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ type: 'photo', label: 'HTTP intake photograph', sourceOrganization: 'Northstar Jewelry Group', sourceType: 'operator', acquisitionMethod: 'camera', claimIds: ['claim_identity'], independent: false, qualified: true, integrityHash: 'sha256:http-evidence-0001', storageKey: `tenants/tenant_northstar/assets/${assetId}/http-photo.jpg`, visibility: 'reviewer' }) }, 201, (body) => body.meta.phoneImageIsLaboratoryAuthentication === false);

const csvBatch = await check('create CSV batch', '/api/v1/operations/batches', { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ name: 'HTTP CSV batch', reference: 'HTTP-CSV-P4', locationId: 'loc_phx_01', lotIds: [] }) }, 201);
const csv = ['serial,material,shape,weightCarats,lengthMm,widthMm,depthMm,colorDescription,identifyingFeatures', 'HTTP-CSV-001,Natural ruby,Cushion,2.1,7,5,4,"Vivid, red",silk', 'HTTP-CSV-002,Natural sapphire,Oval,1.2,6,4,3,Blue,needle'].join('\n');
await check('validated CSV import', `/api/v1/operations/batches/${csvBatch.data.id}/csv`, { method: 'POST', headers: authHeaders('session_intake', 'text/csv'), body: csv }, 201, (body) => body.data.length === 2 && body.meta.noArtificialExpansion === true);
await check('tenant operational search', '/api/v1/operations/search?q=HTTP-CSV-001&limit=20', { headers: authHeaders('session_intake') }, 200, (body) => body.data.assets.length === 1 && body.data.assets[0].tenantId === 'tenant_northstar');

await check('offline conflict is explicit', '/api/v1/operations/sync', { method: 'POST', headers: jsonHeaders('session_intake'), body: JSON.stringify({ operations: [{ id: 'sync-http-conflict', tenantId: 'tenant_northstar', deviceId: 'device_pwa_01', entityType: 'asset', entityId: assetId, operation: 'update', expectedVersion: 1, payload: { colorDescription: 'stale write' }, status: 'queued', attempts: 0, createdAt: '2026-07-20T06:00:00Z' }] }) }, 409, (body) => body.meta.conflicts === 1 && body.data[0].operation.status === 'conflict');
await check('immutable attestation submission', '/api/v1/operations/batches/batch_phx_2026_0720_a/submit', { method: 'POST', headers: jsonHeaders('session_attestor'), body: JSON.stringify({ declarationAccepted: true, claimSummary: 'HTTP submission of identity, measurements, treatment disclosures, and origin claims for independent review.', evidenceSummary: 'Every unit contains active controlled photo and measurement evidence with integrity hashes.', limitations: ['Phone images support fingerprint evidence and do not constitute laboratory authentication.'] }) }, 200, (body) => body.data.attestation.immutable === true && body.data.reviewCaseCount === 24);
await check('intake cannot read review queue', '/api/v1/operations/review', { headers: authHeaders('session_intake') }, 403);
const reviewQueue = await check('reviewer can read review queue', '/api/v1/operations/review', { headers: authHeaders('session_reviewer') }, 200, (body) => Array.isArray(body.data));

const tier4Case = reviewQueue.data.find((item) => item.assetId === 'asset_phx_0001') ?? reviewQueue.data[0];
if (!tier4Case) throw new Error('No Tier 4 review case found after attestation submission.');
const seedAssetId = tier4Case.assetId;
const caseId = tier4Case.id;
await check('reviewer identity spoof rejected', `/api/v1/operations/review/${caseId}/decision`, { method: 'POST', headers: jsonHeaders('session_reviewer_secondary'), body: JSON.stringify({ reviewerId: 'reviewer_primary_01', role: 'secondary', decision: 'approve', independent: true, conflictFree: true, reasonCodes: ['PV_REVIEW_APPROVED'], action: 'review' }) }, 400);
await check('label blocked before authority completion', '/api/v1/operations/labels', { method: 'POST', headers: jsonHeaders('session_attestor'), body: JSON.stringify({ assetIds: [seedAssetId], format: 'svg' }) }, 409);
for (const item of [
  ['primary reviewer approval', 'session_reviewer', { reviewerId: 'reviewer_primary_01', role: 'primary', decision: 'approve', independent: true, conflictFree: true, reasonCodes: ['PV_REVIEW_APPROVED'], action: 'review' }],
  ['secondary reviewer approval', 'session_reviewer_secondary', { reviewerId: 'reviewer_secondary_02', role: 'secondary', decision: 'approve', independent: true, conflictFree: true, reasonCodes: ['PV_REVIEW_APPROVED'], action: 'review' }],
  ['CUSTOS pass', 'session_compliance', { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_CUSTOS_PASS'], action: 'custos-pass' }],
  ['signing authorization', 'session_compliance', { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_SIGNING_AUTHORIZED'], action: 'authorize-signing' }],
  ['registry publication', 'session_compliance', { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_REGISTRY_PUBLISHED'], action: 'publish-registry' }],
  ['revocation control enabled', 'session_compliance', { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_REVOCATION_CONTROL_ENABLED'], action: 'enable-revocation-control' }],
  ['mark authorization', 'session_compliance', { reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_MARK_AUTHORIZED'], action: 'authorize-mark' }],
]) await check(item[0], `/api/v1/operations/review/${caseId}/decision`, { method: 'POST', headers: jsonHeaders(item[1]), body: JSON.stringify(item[2]) }, 200);
await check('real QR label after authority gates', '/api/v1/operations/labels', { method: 'POST', headers: jsonHeaders('session_attestor'), body: JSON.stringify({ assetIds: [seedAssetId], format: 'svg' }) }, 200, (body) => body.data.length === 1 && body.data[0].qrSvg.includes('<svg') && body.meta.physicalCarrierIsAuthority === false);

await check('credential suspension', `/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: jsonHeaders('session_compliance'), body: JSON.stringify({ action: 'suspend', reason: 'HTTP compliance hold with a canonical signed lifecycle receipt.' }) }, 200, (body) => body.data.credentialLifecycle === 'suspended' && body.data.markAuthorization === 'denied');
await check('label suppressed while suspended', '/api/v1/operations/labels', { method: 'POST', headers: jsonHeaders('session_attestor'), body: JSON.stringify({ assetIds: [seedAssetId], format: 'svg' }) }, 409);
await check('credential reactivation', `/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: jsonHeaders('session_compliance'), body: JSON.stringify({ action: 'reactivate', reason: 'HTTP compliance hold resolved through canonical review.' }) }, 200, (body) => body.data.credentialLifecycle === 'active' && body.data.markAuthorization !== 'authorized');
await check('separate mark reauthorization', `/api/v1/operations/review/${caseId}/decision`, { method: 'POST', headers: jsonHeaders('session_compliance'), body: JSON.stringify({ reviewerId: 'compliance_01', role: 'primary', decision: 'pending', independent: true, conflictFree: true, reasonCodes: ['PV_MARK_REAUTHORIZED'], action: 'authorize-mark' }) }, 200, (body) => body.data.markAuthorization === 'authorized');
const correction = await check('versioned correction request', `/api/v1/operations/review/${caseId}/corrections`, { method: 'POST', headers: jsonHeaders('session_reviewer'), body: JSON.stringify({ action: 'request', reason: 'HTTP origin claim and evidence linkage require controlled correction.', fields: ['originClaim','evidence'] }) }, 200, (body) => body.data.corrections.at(-1)?.status === 'open');
const correctionId = correction.data.corrections.at(-1).id;
await check('immutable correction resolution', `/api/v1/operations/review/${caseId}/corrections`, { method: 'POST', headers: jsonHeaders('session_attestor'), body: JSON.stringify({ action: 'resolve', correctionId, resolution: 'Corrected records versioned and submitted for full independent re-review.', claimSummary: 'Corrected origin claim and evidence linkage recorded as a new controlled version.', evidenceSummary: 'Replacement evidence references and integrity records were checked before re-attestation.', limitations: ['The corrected record requires a fresh independent review and authority sequence.'] }) }, 200, (body) => body.data.corrections.at(-1)?.status === 'resolved' && body.data.status === 'unassigned' && body.data.attestationId !== tier4Case.attestationId);
await check('compliance can read audit', '/api/v1/operations/audit', { headers: authHeaders('session_compliance') }, 200, (body) => Array.isArray(body.data) && body.data.some((event) => event.action === 'labels.generated'));

const report = { base, batchCount: batches.data.length, scaleUnits: 1000, checks: results.length, passed: results.every((item) => item.pass), results };
await mkdir('evidence/phase4', { recursive: true });
await writeFile('evidence/phase4/HTTP_SMOKE.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
