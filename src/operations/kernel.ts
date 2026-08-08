import { stableHash } from '@/domain/hash';
import { evaluateCertification } from '@/domain/kernel';
import { buildCredential } from '@/domain/projectors';
import type { ClaimRecord, CustodyEvent, EvidenceItem, FixtureRecord, PolicyInput, SourceRecord } from '@/domain/types';
import type {
  BatchValidationIssue,
  EvidenceObject,
  GemstoneAsset,
  IntakeBatch,
  OperationalAuthorityProjection,
  OperationalEventReceipt,
  OperationalSession,
  ReviewCase,
  StructuredAttestation,
  SyncOperation,
} from './types';
import { can } from './permissions';

const SHA256_PATTERN = /^sha256:[a-f0-9]{8,}$/i;
const REGISTRY_ID_PATTERN = /^PV-OPS-[A-Z0-9]{6,}$/;

export function assertTenantScope(session: OperationalSession, tenantId: string): void {
  if (session.tenantId !== tenantId) throw new Error('TENANT_SCOPE_VIOLATION');
}

export function assertPermission(session: OperationalSession, permission: Parameters<typeof can>[1]): void {
  if (!can(session.role, permission)) throw new Error(`PERMISSION_DENIED:${permission}`);
}

export function createAssetId(tenantId: string, serial: string): string {
  return `asset_${stableHash(`${tenantId}:${serial.toUpperCase()}`)}`;
}

export function validateBatch(batch: IntakeBatch, assets: GemstoneAsset[], evidence: EvidenceObject[]): BatchValidationIssue[] {
  const issues: BatchValidationIssue[] = [];
  const batchAssets = assets.filter((asset) => asset.batchId === batch.id);
  const serials = new Map<string, string[]>();

  if (batchAssets.length === 0) {
    issues.push({ code: 'PV_BATCH_EMPTY', severity: 'error', message: 'The batch has no individually identified gemstone units.' });
  }

  for (const asset of batchAssets) {
    const normalized = asset.serial.trim().toUpperCase();
    serials.set(normalized, [...(serials.get(normalized) ?? []), asset.id]);
    if (!asset.material.trim()) issues.push({ code: 'PV_ASSET_MATERIAL_REQUIRED', severity: 'error', assetId: asset.id, field: 'material', message: 'Material is required.' });
    if (!asset.shape.trim()) issues.push({ code: 'PV_ASSET_SHAPE_REQUIRED', severity: 'error', assetId: asset.id, field: 'shape', message: 'Shape is required.' });
    if (!asset.measurements.weightCarats) issues.push({ code: 'PV_ASSET_WEIGHT_REQUIRED', severity: 'error', assetId: asset.id, field: 'measurements.weightCarats', message: 'Weight is required.' });
    if (!asset.measurements.lengthMm || !asset.measurements.widthMm || !asset.measurements.depthMm) {
      issues.push({ code: 'PV_ASSET_DIMENSIONS_REQUIRED', severity: 'error', assetId: asset.id, field: 'measurements', message: 'Length, width, and depth are required.' });
    }
    const assetEvidence = evidence.filter((item) => item.assetId === asset.id && item.status === 'active');
    if (!assetEvidence.some((item) => item.type === 'photo')) issues.push({ code: 'PV_ASSET_PHOTO_REQUIRED', severity: 'error', assetId: asset.id, field: 'evidence', message: 'At least one active photograph is required.' });
    if (!assetEvidence.some((item) => item.type === 'measurement')) issues.push({ code: 'PV_ASSET_MEASUREMENT_EVIDENCE_REQUIRED', severity: 'error', assetId: asset.id, field: 'evidence', message: 'Measurement evidence is required.' });
    if (asset.treatmentDisclosure.toLowerCase().includes('unknown')) issues.push({ code: 'PV_TREATMENT_DISCLOSURE_UNKNOWN', severity: 'warning', assetId: asset.id, field: 'treatmentDisclosure', message: 'Treatment remains unknown and must be disclosed.' });
  }

  for (const [serial, ids] of serials.entries()) {
    if (ids.length > 1) ids.forEach((assetId) => issues.push({ code: 'PV_DUPLICATE_SERIAL', severity: 'error', assetId, field: 'serial', message: `Serial ${serial} appears more than once in this batch.` }));
  }

  return issues;
}

export function isBatchSubmittable(issues: BatchValidationIssue[]): boolean {
  return !issues.some((issue) => issue.severity === 'error');
}

function attestationPayload(attestation: StructuredAttestation): string {
  return `${attestation.tenantId}:${attestation.batchId}:${[...attestation.assetIds].sort().join(',')}:${attestation.claimSummary}:${attestation.evidenceSummary}:${attestation.limitations.join('|')}:${attestation.version}:${attestation.signedAt}`;
}

export function validateStructuredAttestation(attestation: StructuredAttestation | undefined, asset: GemstoneAsset, review: ReviewCase): boolean {
  if (!attestation) return false;
  if (review.attestationId !== attestation.id) return false;
  if (attestation.tenantId !== asset.tenantId || attestation.batchId !== asset.batchId) return false;
  if (!attestation.assetIds.includes(asset.id) || attestation.signerRole !== 'authorized-attestor' || !attestation.immutable) return false;
  if (!attestation.organizationName.trim() || !attestation.signerId.trim() || !attestation.declaration.trim() || attestation.version < 1) return false;
  if (!isIsoTimestamp(attestation.signedAt)) return false;
  return attestation.signature === `ed25519:test-attestation:${stableHash(attestationPayload(attestation))}`;
}

export function signAttestation(session: OperationalSession, batch: IntakeBatch, assets: GemstoneAsset[], claimSummary: string, evidenceSummary: string, limitations: string[], prior?: StructuredAttestation): StructuredAttestation {
  assertTenantScope(session, batch.tenantId);
  assertPermission(session, 'attestation.sign');
  const assetIds = assets.filter((asset) => asset.batchId === batch.id).map((asset) => asset.id).sort();
  const version = (prior?.version ?? 0) + 1;
  const signedAt = '2026-07-20T04:00:00Z';
  const attestation: StructuredAttestation = {
    id: '',
    tenantId: batch.tenantId,
    batchId: batch.id,
    signerId: session.userId,
    signerRole: session.role,
    organizationName: 'PROVENANCE participant organization',
    assetIds,
    claimSummary,
    evidenceSummary,
    limitations,
    declaration: 'I attest that the submitted claims and evidence are complete to the best of my authorized knowledge and that disclosed limitations remain visible.',
    version,
    signedAt,
    signature: '',
    supersedesId: prior?.id,
    immutable: true,
  };
  const payload = attestationPayload(attestation);
  return {
    ...attestation,
    id: `att_${stableHash(payload)}`,
    signature: `ed25519:test-attestation:${stableHash(payload)}`,
  };
}

export function applySyncOperation<T extends { id: string; version: number }>(operation: SyncOperation, current: T | undefined): { operation: SyncOperation; entity?: T } {
  if (!current && operation.operation !== 'create') return { operation: { ...operation, status: 'failed', attempts: operation.attempts + 1, error: 'ENTITY_NOT_FOUND' } };
  if (current && current.version !== operation.expectedVersion) return { operation: { ...operation, status: 'conflict', attempts: operation.attempts + 1, error: `VERSION_CONFLICT:${current.version}` }, entity: current };
  const merged = { ...(current ?? { id: operation.entityId, version: 0 }), ...operation.payload, id: operation.entityId, version: (current?.version ?? 0) + 1 } as T;
  return { operation: { ...operation, status: 'applied', attempts: operation.attempts + 1, lastAttemptAt: '2026-07-20T04:02:00Z', error: undefined }, entity: merged };
}

function claim(id: string, label: string, value: string, evidenceIds: string[], status: ClaimRecord['status'], material = true): ClaimRecord {
  return { id, label, value, status, evidenceIds, material, scopeNote: status === 'verified' ? 'Supported by qualifying evidence.' : 'Limited to submitted evidence and review state.' };
}

function isIsoTimestamp(value: string): boolean {
  return Number.isFinite(Date.parse(value));
}

function isIntegrityHash(value: string): boolean {
  return SHA256_PATTERN.test(value);
}

function isActiveEvidence(item: EvidenceObject): boolean {
  if (item.status !== 'active' || !isIsoTimestamp(item.issueDate) || !isIsoTimestamp(item.createdAt) || !isIntegrityHash(item.integrityHash)) return false;
  if (item.expiresAt && (!isIsoTimestamp(item.expiresAt) || Date.parse(item.expiresAt) <= Date.parse(item.issueDate))) return false;
  return true;
}

function evidenceEventHash(item: EvidenceObject): string | null {
  const event = item.chainEvent;
  if (!event) return null;
  return `sha256:${stableHash(`${item.type}:${item.assetId}:${event.sequence}:${event.actorId}:${event.actorOrganization}:${event.action}:${event.occurredAt}:${event.location}:${event.previousEventHash}`)}`;
}

function completeEvidenceChain(items: EvidenceObject[], type: 'transfer' | 'custody'): boolean {
  const chain = items
    .filter((item) => item.type === type && item.qualified && isActiveEvidence(item) && item.chainEvent)
    .sort((a, b) => a.chainEvent!.sequence - b.chainEvent!.sequence);
  if (!chain.length) return false;
  let previous = 'genesis:operational-chain';
  for (let index = 0; index < chain.length; index += 1) {
    const event = chain[index].chainEvent!;
    if (event.sequence !== index + 1 || event.previousEventHash !== previous || !isIsoTimestamp(event.occurredAt)) return false;
    const expected = evidenceEventHash(chain[index]);
    if (!expected || event.eventHash !== expected || !isIntegrityHash(event.eventHash)) return false;
    previous = event.eventHash;
  }
  return chain[chain.length - 1].chainEvent!.historyComplete;
}

function toEvidenceItem(item: EvidenceObject): EvidenceItem {
  return {
    id: item.id,
    type: item.type === 'video' || item.type === 'document' ? 'identity' : item.type,
    label: item.label,
    sourceId: `source_${stableHash(item.sourceOrganization)}`,
    hash: item.integrityHash,
    capturedAt: item.createdAt,
    qualified: item.qualified,
    independent: item.independent,
    claimIds: item.claimIds,
  };
}

function operationalReceiptHash(receipt: Omit<OperationalEventReceipt, 'id' | 'eventHash' | 'signature'>): string {
  return `sha256:${stableHash(`${receipt.type}:${receipt.targetId}:${receipt.actorId}:${receipt.sequence}:${receipt.at}:${receipt.previousEventHash}`)}`;
}

export function createOperationalEventReceipt(existing: OperationalEventReceipt[], type: OperationalEventReceipt['type'], targetId: string, actorId: string, at: string): OperationalEventReceipt {
  const previousEventHash = existing.length ? existing[existing.length - 1].eventHash : 'genesis:operational-events';
  const base = { type, targetId, actorId, sequence: existing.length + 1, at, previousEventHash };
  const eventHash = operationalReceiptHash(base);
  return {
    ...base,
    id: `op_evt_${stableHash(`${targetId}:${type}:${base.sequence}`)}`,
    eventHash,
    signature: `ed25519:test-event:${stableHash(eventHash)}`,
  };
}

export function validateOperationalEventChain(receipts: OperationalEventReceipt[]): boolean {
  if (!receipts.length) return false;
  let previous = 'genesis:operational-events';
  const ordered = [...receipts].sort((a, b) => a.sequence - b.sequence);
  for (let index = 0; index < ordered.length; index += 1) {
    const receipt = ordered[index];
    if (receipt.sequence !== index + 1 || receipt.previousEventHash !== previous || !isIsoTimestamp(receipt.at)) return false;
    const expectedHash = operationalReceiptHash({ type: receipt.type, targetId: receipt.targetId, actorId: receipt.actorId, sequence: receipt.sequence, at: receipt.at, previousEventHash: receipt.previousEventHash });
    if (receipt.eventHash !== expectedHash || receipt.signature !== `ed25519:test-event:${stableHash(receipt.eventHash)}`) return false;
    previous = receipt.eventHash;
  }
  return true;
}

function validRegistryPublication(review: ReviewCase): boolean {
  const publication = review.registryPublication;
  if (!publication || publication.publicId !== review.registryId || !isIsoTimestamp(publication.publishedAt) || !isIntegrityHash(publication.integrityHash)) return false;
  return review.eventReceipts.some((receipt) => receipt.id === publication.receiptId && receipt.type === 'registry.published');
}

function custodyProjection(items: EvidenceObject[]): CustodyEvent[] {
  return items
    .filter((item) => (item.type === 'transfer' || item.type === 'custody') && item.chainEvent && item.qualified && isActiveEvidence(item))
    .sort((a, b) => (a.chainEvent!.occurredAt.localeCompare(b.chainEvent!.occurredAt)))
    .map((item) => ({
      id: item.id,
      actor: item.chainEvent!.actorOrganization,
      action: item.chainEvent!.action,
      at: item.chainEvent!.occurredAt,
      location: item.chainEvent!.location,
      hash: item.chainEvent!.eventHash,
    }));
}

export function projectAssetToAuthority(asset: GemstoneAsset, evidence: EvidenceObject[], review: ReviewCase, attestation?: StructuredAttestation): OperationalAuthorityProjection {
  const activeEvidence = evidence.filter((item) => item.assetId === asset.id && isActiveEvidence(item));
  const evidenceItems = activeEvidence.map(toEvidenceItem);
  const qualifyingIndependentEvidence = activeEvidence.filter((item) => item.independent && item.qualified && item.claimIds.length > 0);
  const independentSources = new Set(qualifyingIndependentEvidence.map((item) => item.sourceOrganization));
  const photoIds = activeEvidence.filter((item) => item.type === 'photo').map((item) => item.id);
  const measurementIds = activeEvidence.filter((item) => item.type === 'measurement').map((item) => item.id);
  const labEvidence = activeEvidence.filter((item) => item.type === 'laboratory' && item.qualified && item.independent);
  const labIds = labEvidence.map((item) => item.id);
  const originEvidence = qualifyingIndependentEvidence.filter((item) => item.claimIds.includes('claim_origin'));
  const originIds = originEvidence.map((item) => item.id);
  const originSources = new Set(originEvidence.map((item) => item.sourceOrganization));
  const transferIds = activeEvidence.filter((item) => item.type === 'transfer').map((item) => item.id);
  const custodyIds = activeEvidence.filter((item) => item.type === 'custody').map((item) => item.id);
  const transferComplete = completeEvidenceChain(activeEvidence, 'transfer');
  const custodyComplete = completeEvidenceChain(activeEvidence, 'custody');
  const attestationValid = validateStructuredAttestation(attestation, asset, review);
  const eventChainValid = validateOperationalEventChain(review.eventReceipts);
  const attestationReceiptPresent = Boolean(attestation && review.eventReceipts.some((receipt) => receipt.type === 'attestation.recorded' && receipt.targetId === attestation.id));
  const registryIdValid = REGISTRY_ID_PATTERN.test(review.registryId);
  const claims: ClaimRecord[] = [
    claim('claim_identity', 'Physical identity', asset.serial, [...photoIds, ...measurementIds], photoIds.length && measurementIds.length ? 'corroborated' : 'self-attested'),
    claim('claim_origin', 'Origin', asset.originClaim, originIds, originSources.size >= 2 ? 'verified' : originIds.length ? 'corroborated' : 'self-attested'),
    claim('claim_treatment', 'Treatment disclosure', asset.treatmentDisclosure, labIds, labIds.length ? 'verified' : 'self-attested'),
    claim('claim_measurements', 'Measurements', `${asset.measurements.weightCarats ?? '—'} ct`, measurementIds, measurementIds.length ? 'corroborated' : 'unknown'),
    claim('claim_transfer', 'Transfer history', transferComplete ? 'Complete applicable transfer history' : 'Transfer history incomplete', transferIds, transferComplete ? 'verified' : 'unknown'),
    claim('claim_custody', 'Custody history', custodyComplete ? 'Complete applicable custody history' : 'Custody history incomplete', custodyIds, custodyComplete ? 'verified' : 'unknown'),
  ];
  const correspondence = activeEvidence.every((item) => item.claimIds.length > 0)
    && claims.every((item) => item.evidenceIds.every((evidenceId) => activeEvidence.some((evidenceItem) => evidenceItem.id === evidenceId)));
  const policy: PolicyInput = {
    submitterIdentity: Boolean(asset.createdBy.trim()),
    selfDeclaredOrigin: Boolean(asset.originClaim.trim() && asset.originClaim !== 'Not claimed'),
    photographs: photoIds.length > 0,
    measurements: measurementIds.length > 0 && Boolean(asset.measurements.weightCarats && asset.measurements.lengthMm && asset.measurements.widthMm && asset.measurements.depthMm),
    timestamp: isIsoTimestamp(asset.createdAt) && isIsoTimestamp(asset.updatedAt) && activeEvidence.every((item) => isIsoTimestamp(item.createdAt)),
    registryId: registryIdValid,
    signedAttestation: attestationValid,
    identifiedAttestingParty: attestationValid && Boolean(attestation?.signerId && attestation.organizationName),
    legalDeclaration: attestationValid && Boolean(attestation?.declaration.trim()),
    signatureValid: attestationValid,
    signatureTimestamp: attestationValid && Boolean(attestation && isIsoTimestamp(attestation.signedAt)),
    attestationVersion: attestationValid && Boolean(attestation && attestation.version >= 1),
    appendOnlyEvent: eventChainValid && attestationReceiptPresent,
    integrityHash: activeEvidence.length > 0 && activeEvidence.every((item) => isIntegrityHash(item.integrityHash)) && eventChainValid,
    qualifyingIndependentSources: independentSources.size,
    claimLevelCorrespondence: correspondence,
    verifiedOrigin: originSources.size >= 2,
    physicalFingerprint: photoIds.length > 0 && measurementIds.length > 0 && asset.identifyingFeatures.length > 0,
    qualifyingLaboratoryEvidence: labEvidence.length > 0,
    completeTransferHistory: transferComplete,
    completeCustodyTransfers: custodyComplete,
  };
  const registryReady = review.registryStatus === 'ready' && validRegistryPublication(review);
  const signingReady = review.signingKeyStatus === 'active' && review.eventReceipts.some((receipt) => receipt.type === 'signing.authorized');
  const revocationReady = review.revocationCapability && review.eventReceipts.some((receipt) => receipt.type === 'revocation-control.enabled');
  const custosReady = review.custosVerdict.status === 'pass' && review.eventReceipts.some((receipt) => receipt.type === 'custos.recorded');
  const authority = {
    reviewerApprovals: review.approvals,
    conflictClearance: review.conflictClearance,
    custosVerdict: review.custosVerdict.status === 'pass' && !custosReady ? { status: 'pending' as const, reasonCodes: ['PV_CUSTOS_RECEIPT_REQUIRED'] } : review.custosVerdict,
    signingKeyStatus: review.signingKeyStatus === 'active' && !signingReady ? 'pending' as const : review.signingKeyStatus,
    registryStatus: review.registryStatus === 'ready' && !registryReady ? 'pending' as const : review.registryStatus,
    revocationCapability: revocationReady,
    markAuthorization: review.markAuthorization,
  };
  const sourcesById = new Map<string, SourceRecord>();
  for (const item of activeEvidence) {
    const id = `source_${stableHash(item.sourceOrganization)}`;
    sourcesById.set(id, {
      id,
      name: item.sourceOrganization,
      category: item.sourceType === 'operator' ? 'submitter' : item.sourceType === 'supplier' ? 'attestor' : item.sourceType,
      independent: item.independent,
      qualified: item.qualified,
      jurisdiction: 'Declared by source',
    });
  }
  const publicId = review.registryId;
  const fixture: FixtureRecord = {
    key: `ops_${asset.id}`,
    name: `Operational case ${asset.serial}`,
    description: 'Operational projection from the authenticated PROVENANCE jeweler system.',
    policy,
    authority,
    claims,
    evidence: evidenceItems,
    sources: [...sourcesById.values()],
    custody: custodyProjection(activeEvidence),
    lifecycle: review.credentialLifecycle,
    expectedTier: evaluateCertification(policy, claims).tier,
    expectedIssuanceStatus: 'review-required',
    expectedIssued: false,
    publicId,
  };
  const credential = buildCredential(fixture);
  fixture.expectedIssuanceStatus = credential.authorization.status;
  fixture.expectedIssued = credential.status === 'issued';
  return { policy, authority, fixture };
}

export function credentialForOperationalAsset(asset: GemstoneAsset, evidence: EvidenceObject[], review: ReviewCase, attestation?: StructuredAttestation) {
  const credential = buildCredential(projectAssetToAuthority(asset, evidence, review, attestation).fixture);
  return review.successorId ? { ...credential, successorId: review.successorId } : credential;
}


export function buildAssetIndex(assets: GemstoneAsset[]): Map<string, GemstoneAsset> {
  const index = new Map<string, GemstoneAsset>();
  for (const asset of assets) {
    index.set(asset.id, asset);
    index.set(`${asset.tenantId}:${asset.serial.toUpperCase()}`, asset);
  }
  return index;
}
