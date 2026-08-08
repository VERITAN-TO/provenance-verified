import { stableHash } from '@/domain/hash';
import type { AuthorityInput, ReviewerApproval } from '@/domain/types';
import type {
  EvidenceObject,
  GemstoneAsset,
  IntakeBatch,
  InventoryLot,
  OperationalAuditEvent,
  OperationalDataset,
  OperationalSession,
  OrganizationLocation,
  OrganizationTenant,
  ReviewCase,
  StructuredAttestation,
  SyncOperation,
} from './types';

const now = '2026-07-20T03:00:00Z';

function makeChainEvent(type: 'transfer' | 'custody', assetId: string, sequence: number, actorId: string, actorOrganization: string, action: string, occurredAt: string, location: string, previousEventHash: string, historyComplete: boolean) {
  const eventHash = `sha256:${stableHash(`${type}:${assetId}:${sequence}:${actorId}:${actorOrganization}:${action}:${occurredAt}:${location}:${previousEventHash}`)}`;
  return { sequence, actorId, actorOrganization, action, occurredAt, location, previousEventHash, eventHash, historyComplete };
}

function makeEventReceipt(type: 'attestation.recorded' | 'review.primary-recorded', targetId: string, actorId: string, sequence: number, at: string, previousEventHash: string) {
  const eventHash = `sha256:${stableHash(`${type}:${targetId}:${actorId}:${sequence}:${at}:${previousEventHash}`)}`;
  return { id: `op_evt_${stableHash(`${targetId}:${type}:${sequence}`)}`, type, targetId, actorId, sequence, at, previousEventHash, eventHash, signature: `ed25519:test-event:${stableHash(eventHash)}` };
}
const tenant: OrganizationTenant = {
  id: 'tenant_northstar',
  legalName: 'Northstar Jewelry Group LLC',
  displayName: 'Northstar Jewelers',
  status: 'active',
  createdAt: now,
  settings: { defaultCurrency: 'USD', timezone: 'America/Phoenix', retentionDays: 2555, maxBatchSize: 5000 },
};
const secondTenant: OrganizationTenant = {
  id: 'tenant_meridian',
  legalName: 'Meridian Gem House LLC',
  displayName: 'Meridian Gem House',
  status: 'active',
  createdAt: now,
  settings: { defaultCurrency: 'USD', timezone: 'America/New_York', retentionDays: 2555, maxBatchSize: 5000 },
};
const locations: OrganizationLocation[] = [
  { id: 'loc_phx_01', tenantId: tenant.id, name: 'Phoenix Intake Lab', code: 'PHX', timezone: 'America/Phoenix', address: 'Phoenix, Arizona', active: true },
  { id: 'loc_nyc_01', tenantId: secondTenant.id, name: 'New York Operations', code: 'NYC', timezone: 'America/New_York', address: 'New York, New York', active: true },
];
const sessions: OperationalSession[] = [
  { id: 'session_intake', tenantId: tenant.id, userId: 'user_intake_01', displayName: 'Avery Intake', role: 'intake-operator', locationIds: ['loc_phx_01'], deviceId: 'device_pwa_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_inventory', tenantId: tenant.id, userId: 'user_inventory_01', displayName: 'Taylor Inventory', role: 'inventory-manager', locationIds: ['loc_phx_01'], deviceId: 'device_inventory_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_attestor', tenantId: tenant.id, userId: 'user_attestor_01', displayName: 'Morgan Attestor', role: 'authorized-attestor', locationIds: ['loc_phx_01'], deviceId: 'device_desktop_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_reviewer', tenantId: tenant.id, userId: 'reviewer_primary_01', displayName: 'Riley Reviewer', role: 'reviewer', locationIds: ['loc_phx_01'], deviceId: 'device_review_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_reviewer_secondary', tenantId: tenant.id, userId: 'reviewer_secondary_02', displayName: 'Jordan Reviewer', role: 'reviewer', locationIds: ['loc_phx_01'], deviceId: 'device_review_02', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_compliance', tenantId: tenant.id, userId: 'compliance_01', displayName: 'Casey Compliance', role: 'compliance-officer', locationIds: ['loc_phx_01'], deviceId: 'device_compliance_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
  { id: 'session_other_tenant', tenantId: secondTenant.id, userId: 'user_other_01', displayName: 'Other Tenant User', role: 'administrator', locationIds: ['loc_nyc_01'], deviceId: 'device_other_01', authenticatedAt: now, expiresAt: '2099-12-31T23:59:59Z', testMode: true },
];
const lots: InventoryLot[] = [
  { id: 'lot_phx_2026_0719', tenantId: tenant.id, locationId: 'loc_phx_01', supplierReference: 'SUP-0719-A', description: 'Mixed blue sapphire parcel', declaredQuantity: 120, identifiedUnitCount: 24, status: 'partially-serialized', receivedAt: '2026-07-19T16:00:00Z', notes: 'Quantity remains a lot count until each physical unit receives a real fingerprint.' },
  { id: 'lot_nyc_2026_0701', tenantId: secondTenant.id, locationId: 'loc_nyc_01', supplierReference: 'SUP-NYC-0701', description: 'Independent tenant fixture', declaredQuantity: 10, identifiedUnitCount: 1, status: 'partially-serialized', receivedAt: '2026-07-01T14:00:00Z', notes: 'Used to prove tenant isolation.' },
];

const batch: IntakeBatch = {
  id: 'batch_phx_2026_0720_a', tenantId: tenant.id, locationId: 'loc_phx_01', name: 'July sapphire intake A', reference: 'PHX-0720-A', status: 'ready', assetIds: [], lotIds: [lots[0].id], validationErrors: [], createdAt: now, updatedAt: now, createdBy: 'user_intake_01', version: 1,
};
const secondBatch: IntakeBatch = {
  id: 'batch_nyc_private', tenantId: secondTenant.id, locationId: 'loc_nyc_01', name: 'Private tenant batch', reference: 'NYC-PRIVATE', status: 'draft', assetIds: [], lotIds: [lots[1].id], validationErrors: [], createdAt: now, updatedAt: now, createdBy: 'user_other_01', version: 1,
};

function makeAsset(index: number, targetBatch = batch, targetTenant = tenant.id): GemstoneAsset {
  const serial = `${targetBatch.reference}-${String(index).padStart(4, '0')}`;
  const id = `asset_${stableHash(`${targetTenant}:${serial}`)}`;
  return {
    id,
    tenantId: targetTenant,
    locationId: targetBatch.locationId,
    batchId: targetBatch.id,
    lotId: targetBatch.lotIds[0],
    serial,
    status: 'ready',
    material: 'Natural sapphire',
    shape: index % 3 === 0 ? 'Oval' : index % 3 === 1 ? 'Cushion' : 'Round',
    cut: 'Faceted',
    colorDescription: index % 2 ? 'Medium deep blue' : 'Royal blue',
    clarityDescription: 'Eye-clean with identifiable inclusions',
    treatmentDisclosure: index === 7 ? 'Unknown / not declared' : 'Heat treatment disclosed',
    originClaim: 'Cambodia — supplier claim pending independent corroboration',
    measurements: { weightCarats: Number((0.75 + index * 0.06).toFixed(2)), lengthMm: 5.1 + index * 0.03, widthMm: 4.2 + index * 0.02, depthMm: 2.9 + index * 0.01 },
    identifyingFeatures: [`inclusion-map-${index}`, `girdle-profile-${index}`],
    supplierReference: lots[0].supplierReference,
    laboratoryReportReference: index <= 4 ? `LAB-2026-${String(index).padStart(4, '0')}` : '',
    evidenceIds: [],
    version: 1,
    createdAt: now,
    updatedAt: now,
    createdBy: 'user_intake_01',
  };
}

const assets = Array.from({ length: 24 }, (_, index) => makeAsset(index + 1));
const privateAsset = makeAsset(1, secondBatch, secondTenant.id);
privateAsset.id = 'asset_private_tenant';
privateAsset.serial = 'NYC-PRIVATE-0001';
privateAsset.supplierReference = lots[1].supplierReference;

const evidence: EvidenceObject[] = [];
for (const [index, asset] of assets.entries()) {
  const photo: EvidenceObject = {
    id: `ev_photo_${asset.id}`,
    tenantId: asset.tenantId,
    assetId: asset.id,
    type: 'photo',
    label: `Controlled intake photograph ${asset.serial}`,
    sourceOrganization: tenant.displayName,
    sourceType: 'operator',
    acquisitionMethod: 'camera',
    issueDate: now,
    claimIds: ['claim_identity'],
    independent: false,
    qualified: true,
    integrityHash: `sha256:${stableHash(`${asset.id}:photo`)}`,
    storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/photo-01.jpg`,
    visibility: 'reviewer',
    status: 'active',
    createdAt: now,
    createdBy: 'user_intake_01',
  };
  const measurement: EvidenceObject = {
    ...photo,
    id: `ev_measure_${asset.id}`,
    type: 'measurement',
    label: `Measurement capture ${asset.serial}`,
    acquisitionMethod: 'manual',
    claimIds: ['claim_identity', 'claim_measurements'],
    integrityHash: `sha256:${stableHash(`${asset.id}:measurement`)}`,
    storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/measurement.json`,
  };
  evidence.push(photo, measurement);
  asset.evidenceIds.push(photo.id, measurement.id);
  if (index < 4) {
    const lab: EvidenceObject = {
      ...photo,
      id: `ev_lab_${asset.id}`,
      type: 'laboratory',
      label: `Independent laboratory report ${asset.serial}`,
      sourceOrganization: 'Independent Gem Laboratory',
      sourceType: 'laboratory',
      acquisitionMethod: 'upload',
      claimIds: ['claim_origin', 'claim_treatment'],
      independent: true,
      qualified: true,
      integrityHash: `sha256:${stableHash(`${asset.id}:lab`)}`,
      storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/lab-report.pdf`,
      visibility: 'public-summary',
    };
    evidence.push(lab);
    asset.evidenceIds.push(lab.id);
  }
  if (index < 4) {
    const supplier: EvidenceObject = {
      ...photo,
      id: `ev_source_${asset.id}`,
      type: 'document',
      label: `Independent source declaration ${asset.serial}`,
      sourceOrganization: 'Qualified Source Registry',
      sourceType: 'registry',
      acquisitionMethod: 'api',
      claimIds: ['claim_origin'],
      independent: true,
      qualified: true,
      integrityHash: `sha256:${stableHash(`${asset.id}:source`)}`,
      storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/source-record.json`,
      visibility: 'public-summary',
    };
    evidence.push(supplier);
    asset.evidenceIds.push(supplier.id);

    const transferEvent = makeChainEvent('transfer', asset.id, 1, 'supplier_custodian_01', 'Qualified Supplier Custodian', 'Released gemstone to bonded carrier', '2026-07-19T18:00:00Z', 'Supplier secure vault', 'genesis:operational-chain', true);
    const transfer: EvidenceObject = {
      ...photo,
      id: `ev_transfer_${asset.id}`,
      type: 'transfer',
      label: `Qualified transfer record ${asset.serial}`,
      sourceOrganization: 'Qualified Supplier Custodian',
      sourceType: 'custodian',
      acquisitionMethod: 'api',
      issueDate: transferEvent.occurredAt,
      createdAt: transferEvent.occurredAt,
      claimIds: ['claim_transfer'],
      independent: true,
      qualified: true,
      integrityHash: `sha256:${stableHash(`${asset.id}:transfer`)}`,
      storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/transfer-event.json`,
      visibility: 'public-summary',
      chainEvent: transferEvent,
    };
    const custodyEvent1 = makeChainEvent('custody', asset.id, 1, 'carrier_01', 'Bonded Gem Carrier', 'Accepted sealed gemstone container', '2026-07-19T18:15:00Z', 'Supplier secure vault', 'genesis:operational-chain', false);
    const custody1: EvidenceObject = {
      ...photo,
      id: `ev_custody_1_${asset.id}`,
      type: 'custody',
      label: `Bonded-carrier custody event ${asset.serial}`,
      sourceOrganization: 'Bonded Gem Carrier',
      sourceType: 'custodian',
      acquisitionMethod: 'api',
      issueDate: custodyEvent1.occurredAt,
      createdAt: custodyEvent1.occurredAt,
      claimIds: ['claim_custody'],
      independent: true,
      qualified: true,
      integrityHash: `sha256:${stableHash(`${asset.id}:custody:1`)}`,
      storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/custody-01.json`,
      visibility: 'public-summary',
      chainEvent: custodyEvent1,
    };
    const custodyEvent2 = makeChainEvent('custody', asset.id, 2, 'user_intake_01', tenant.displayName, 'Received sealed gemstone container', '2026-07-20T02:30:00Z', 'Phoenix Intake Lab', custodyEvent1.eventHash, true);
    const custody2: EvidenceObject = {
      ...photo,
      id: `ev_custody_2_${asset.id}`,
      type: 'custody',
      label: `Jeweler receipt custody event ${asset.serial}`,
      sourceOrganization: tenant.displayName,
      sourceType: 'custodian',
      acquisitionMethod: 'scan',
      issueDate: custodyEvent2.occurredAt,
      createdAt: custodyEvent2.occurredAt,
      claimIds: ['claim_custody'],
      independent: false,
      qualified: true,
      integrityHash: `sha256:${stableHash(`${asset.id}:custody:2`)}`,
      storageKey: `tenants/${asset.tenantId}/assets/${asset.id}/custody-02.json`,
      visibility: 'public-summary',
      chainEvent: custodyEvent2,
    };
    evidence.push(transfer, custody1, custody2);
    asset.evidenceIds.push(transfer.id, custody1.id, custody2.id);
  }
}

batch.assetIds = assets.map((asset) => asset.id);
secondBatch.assetIds = [privateAsset.id];

const attestationBase: StructuredAttestation = {
  id: 'att_fixture_batch_phx',
  tenantId: tenant.id,
  batchId: batch.id,
  signerId: 'user_attestor_01',
  signerRole: 'authorized-attestor',
  organizationName: tenant.legalName,
  assetIds: batch.assetIds,
  claimSummary: 'Supplier origin claims, treatment disclosures, measurements, physical fingerprints, transfers, and custody events submitted for review.',
  evidenceSummary: 'Controlled photographs and measurements exist for every unit; four units include qualifying laboratory, registry, transfer, and custody evidence.',
  limitations: ['Phone photographs are supporting fingerprint evidence and are not laboratory authentication.', 'Most origin claims remain uncorroborated.'],
  declaration: 'I attest that the submitted claims and evidence are complete to the best of my authorized knowledge.',
  version: 1,
  signedAt: '2026-07-20T03:15:00Z',
  signature: '',
  immutable: true,
};
const attestationPayload = `${attestationBase.tenantId}:${attestationBase.batchId}:${[...attestationBase.assetIds].sort().join(',')}:${attestationBase.claimSummary}:${attestationBase.evidenceSummary}:${attestationBase.limitations.join('|')}:${attestationBase.version}:${attestationBase.signedAt}`;
const attestation: StructuredAttestation = { ...attestationBase, signature: `ed25519:test-attestation:${stableHash(attestationPayload)}` };

const approvals: ReviewerApproval[] = [
  { id: 'approval_primary_asset1', reviewerId: 'reviewer_primary_01', role: 'primary', independent: true, conflictFree: true, decision: 'approve', decidedAt: '2026-07-20T03:20:00Z', reasonCodes: ['PV_REVIEW_APPROVED'] },
];
const defaultAuthority: AuthorityInput = {
  reviewerApprovals: approvals,
  conflictClearance: 'clear',
  custosVerdict: { status: 'pending', reasonCodes: ['PV_CUSTOS_REQUIRED'] },
  signingKeyStatus: 'pending',
  registryStatus: 'pending',
  revocationCapability: false,
  markAuthorization: 'pending',
};
function makeReview(asset: GemstoneAsset, index: number): ReviewCase {
  const registryId = `PV-OPS-${stableHash(asset.id).slice(0, 8).toUpperCase()}`;
  const attestationReceipt = makeEventReceipt('attestation.recorded', attestation.id, attestation.signerId, 1, attestation.signedAt, 'genesis:operational-events');
  const receipts = index === 0
    ? [attestationReceipt, makeEventReceipt('review.primary-recorded', `review_${asset.id}`, 'reviewer_primary_01', 2, '2026-07-20T03:20:00Z', attestationReceipt.eventHash)]
    : [attestationReceipt];
  return {
    id: `review_${asset.id}`,
    tenantId: asset.tenantId,
    batchId: asset.batchId,
    assetId: asset.id,
    attestationId: attestation.id,
    registryId,
    eventReceipts: receipts,
    status: index === 0 ? 'secondary-required' : 'unassigned',
    assignedReviewerIds: index === 0 ? ['reviewer_primary_01'] : [],
    approvals: index === 0 ? defaultAuthority.reviewerApprovals : [],
    conflictClearance: index === 0 ? 'clear' : 'pending',
    custosVerdict: index === 0 ? defaultAuthority.custosVerdict : { status: 'pending', reasonCodes: [] },
    signingKeyStatus: 'pending',
    registryStatus: 'pending',
    revocationCapability: false,
    markAuthorization: 'pending',
    corrections: [],
    credentialLifecycle: 'active',
    lifecycleEvents: [],
    openedAt: now,
    updatedAt: now,
    serviceLevelDueAt: '2026-07-22T03:00:00Z',
  };
}
const reviewCases = assets.map(makeReview);

const syncOperations: SyncOperation[] = [
  { id: 'sync_queued_01', tenantId: tenant.id, deviceId: 'device_pwa_01', entityType: 'asset', entityId: assets[6].id, operation: 'update', expectedVersion: 1, payload: { treatmentDisclosure: 'Unknown / not declared' }, status: 'queued', attempts: 0, createdAt: '2026-07-20T03:40:00Z' },
];
const auditEvents: OperationalAuditEvent[] = [
  { id: 'audit_001', tenantId: tenant.id, actorId: 'user_intake_01', actorRole: 'intake-operator', action: 'batch.created', targetType: 'batch', targetId: batch.id, resultingState: { status: batch.status, assetCount: batch.assetIds.length }, requestId: 'req_phase4_seed_001', at: now },
  { id: 'audit_002', tenantId: tenant.id, actorId: 'user_attestor_01', actorRole: 'authorized-attestor', action: 'attestation.signed', targetType: 'attestation', targetId: attestation.id, resultingState: { batchId: batch.id, version: 1 }, requestId: 'req_phase4_seed_002', at: attestation.signedAt },
];

export const operationalDataset: OperationalDataset = {
  tenants: [tenant, secondTenant],
  locations,
  sessions,
  lots,
  batches: [batch, secondBatch],
  assets: [...assets, privateAsset],
  evidence,
  attestations: [attestation],
  reviewCases,
  syncOperations,
  auditEvents,
};

export const defaultOperationalSession = sessions.find((item) => item.id === 'session_intake')!;
export const inventorySession = sessions.find((item) => item.id === 'session_inventory')!;
export const attestorSession = sessions.find((item) => item.id === 'session_attestor')!;
export const reviewerSession = sessions.find((item) => item.id === 'session_reviewer')!;
export const secondaryReviewerSession = sessions.find((item) => item.id === 'session_reviewer_secondary')!;
export const complianceSession = sessions.find((item) => item.id === 'session_compliance')!;
export const otherTenantSession = sessions.find((item) => item.id === 'session_other_tenant')!;
