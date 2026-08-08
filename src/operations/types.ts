import type { AuthorityInput, CertificationDecision, Credential, EvidenceItem, FixtureRecord, PolicyInput, ReviewerApproval } from '@/domain/types';

export type TenantId = string;
export type LocationId = string;
export type UserId = string;
export type BatchId = string;
export type AssetId = string;
export type LotId = string;
export type EvidenceObjectId = string;
export type ReviewCaseId = string;

export type OrganizationRole =
  | 'owner'
  | 'administrator'
  | 'intake-operator'
  | 'evidence-manager'
  | 'inventory-manager'
  | 'authorized-attestor'
  | 'reviewer'
  | 'compliance-officer'
  | 'auditor';

export type OperationalPermission =
  | 'tenant.manage'
  | 'location.manage'
  | 'batch.create'
  | 'batch.edit'
  | 'batch.submit'
  | 'inventory.manage'
  | 'asset.create'
  | 'asset.edit'
  | 'evidence.manage'
  | 'attestation.sign'
  | 'review.assign'
  | 'review.decide'
  | 'review.approve-tier4'
  | 'custos.decide'
  | 'credential.issue'
  | 'credential.lifecycle'
  | 'correction.request'
  | 'correction.resolve'
  | 'mark.authorize'
  | 'label.generate'
  | 'operations.search'
  | 'audit.read';

export interface OrganizationTenant {
  id: TenantId;
  legalName: string;
  displayName: string;
  status: 'active' | 'suspended';
  createdAt: string;
  settings: {
    defaultCurrency: string;
    timezone: string;
    retentionDays: number;
    maxBatchSize: number;
  };
}

export interface OrganizationLocation {
  id: LocationId;
  tenantId: TenantId;
  name: string;
  code: string;
  timezone: string;
  address: string;
  active: boolean;
}

export interface OperationalSession {
  id: string;
  tenantId: TenantId;
  userId: UserId;
  displayName: string;
  role: OrganizationRole;
  locationIds: LocationId[];
  deviceId: string;
  authenticatedAt: string;
  expiresAt: string;
  testMode: boolean;
  environment?: 'sandbox' | 'pilot' | 'production';
  assuranceLevel?: 'aal1' | 'aal2';
}

export interface InventoryLot {
  id: LotId;
  tenantId: TenantId;
  locationId: LocationId;
  supplierReference: string;
  description: string;
  declaredQuantity: number;
  identifiedUnitCount: number;
  status: 'received' | 'in-intake' | 'partially-serialized' | 'serialized' | 'archived';
  receivedAt: string;
  notes: string;
}

export interface GemstoneMeasurements {
  weightCarats: number | null;
  lengthMm: number | null;
  widthMm: number | null;
  depthMm: number | null;
}

export interface GemstoneAsset {
  id: AssetId;
  tenantId: TenantId;
  locationId: LocationId;
  batchId: BatchId;
  lotId?: LotId;
  serial: string;
  status: 'draft' | 'ready' | 'submitted' | 'in-review' | 'issued' | 'blocked' | 'archived';
  material: string;
  shape: string;
  cut: string;
  colorDescription: string;
  clarityDescription: string;
  treatmentDisclosure: string;
  originClaim: string;
  measurements: GemstoneMeasurements;
  identifyingFeatures: string[];
  supplierReference: string;
  laboratoryReportReference: string;
  evidenceIds: EvidenceObjectId[];
  version: number;
  createdAt: string;
  updatedAt: string;
  createdBy: UserId;
}

export interface EvidenceChainEvent {
  sequence: number;
  actorId: string;
  actorOrganization: string;
  action: string;
  occurredAt: string;
  location: string;
  previousEventHash: string;
  eventHash: string;
  historyComplete: boolean;
}

export interface EvidenceObject {
  id: EvidenceObjectId;
  tenantId: TenantId;
  assetId: AssetId;
  type: EvidenceItem['type'] | 'video' | 'document';
  label: string;
  sourceOrganization: string;
  sourceType: 'operator' | 'supplier' | 'laboratory' | 'registry' | 'custodian';
  acquisitionMethod: 'camera' | 'upload' | 'api' | 'scan' | 'manual';
  issueDate: string;
  expiresAt?: string;
  claimIds: string[];
  independent: boolean;
  qualified: boolean;
  integrityHash: string;
  storageKey: string;
  visibility: 'private' | 'reviewer' | 'public-summary';
  status: 'active' | 'expired' | 'withdrawn' | 'superseded' | 'quarantined';
  createdAt: string;
  createdBy: UserId;
  chainEvent?: EvidenceChainEvent;
}

export interface IntakeBatch {
  id: BatchId;
  tenantId: TenantId;
  locationId: LocationId;
  name: string;
  reference: string;
  status: 'draft' | 'validating' | 'ready' | 'submitted' | 'in-review' | 'completed' | 'blocked';
  assetIds: AssetId[];
  lotIds: LotId[];
  validationErrors: BatchValidationIssue[];
  createdAt: string;
  updatedAt: string;
  createdBy: UserId;
  submittedAt?: string;
  attestationId?: string;
  version: number;
}

export interface BatchValidationIssue {
  code: string;
  severity: 'error' | 'warning';
  assetId?: AssetId;
  field?: string;
  message: string;
}

export interface StructuredAttestation {
  id: string;
  tenantId: TenantId;
  batchId: BatchId;
  signerId: UserId;
  signerRole: OrganizationRole;
  organizationName: string;
  assetIds: AssetId[];
  claimSummary: string;
  evidenceSummary: string;
  limitations: string[];
  declaration: string;
  version: number;
  signedAt: string;
  signature: string;
  supersedesId?: string;
  immutable: true;
}

export interface OperationalEventReceipt {
  id: string;
  type:
    | 'attestation.recorded'
    | 'review.primary-recorded'
    | 'review.secondary-recorded'
    | 'custos.recorded'
    | 'signing.authorized'
    | 'registry.published'
    | 'revocation-control.enabled'
    | 'mark.authorized'
    | 'mark.denied'
    | 'credential.suspended'
    | 'credential.reactivated'
    | 'credential.revoked'
    | 'credential.superseded'
    | 'credential.expired'
    | 'correction.requested'
    | 'correction.resolved'
    | 'correction.rejected';
  targetId: string;
  actorId: UserId;
  sequence: number;
  at: string;
  previousEventHash: string;
  eventHash: string;
  signature: string;
}

export interface RegistryPublicationReceipt {
  publicId: string;
  receiptId: string;
  publishedAt: string;
  integrityHash: string;
}


export type CredentialLifecycleAction = 'suspend' | 'reactivate' | 'revoke' | 'supersede' | 'expire';

export interface CredentialLifecycleEvent {
  id: string;
  action: CredentialLifecycleAction;
  from: Credential['lifecycle'];
  to: Credential['lifecycle'];
  reason: string;
  actorId: UserId;
  at: string;
  successorId?: string;
  receiptId: string;
}

export interface CorrectionRequestRecord {
  id: string;
  version: number;
  status: 'open' | 'resolved' | 'rejected';
  requestedBy: UserId;
  requestedAt: string;
  reason: string;
  fields: string[];
  resolution?: string;
  resolvedBy?: UserId;
  resolvedAt?: string;
  supersededAttestationId?: string;
  replacementAttestationId?: string;
}

export interface ReviewCase {
  id: ReviewCaseId;
  tenantId: TenantId;
  batchId: BatchId;
  assetId: AssetId;
  attestationId?: string;
  registryId: string;
  eventReceipts: OperationalEventReceipt[];
  registryPublication?: RegistryPublicationReceipt;
  status:
    | 'unassigned'
    | 'assigned'
    | 'correction-requested'
    | 'primary-approved'
    | 'secondary-required'
    | 'custos-required'
    | 'issuer-required'
    | 'mark-required'
    | 'issued'
    | 'rejected'
    | 'blocked';
  assignedReviewerIds: UserId[];
  approvals: ReviewerApproval[];
  conflictClearance: AuthorityInput['conflictClearance'];
  custosVerdict: AuthorityInput['custosVerdict'];
  signingKeyStatus: AuthorityInput['signingKeyStatus'];
  registryStatus: AuthorityInput['registryStatus'];
  revocationCapability: boolean;
  markAuthorization: AuthorityInput['markAuthorization'];
  correctionRequest?: string;
  corrections: CorrectionRequestRecord[];
  credentialLifecycle: Credential['lifecycle'];
  successorId?: string;
  lifecycleEvents: CredentialLifecycleEvent[];
  decision?: CertificationDecision;
  credential?: Credential;
  openedAt: string;
  updatedAt: string;
  serviceLevelDueAt: string;
}

export interface SyncOperation {
  id: string;
  tenantId: TenantId;
  deviceId: string;
  entityType: 'batch' | 'asset' | 'evidence' | 'attestation';
  entityId: string;
  operation: 'create' | 'update' | 'submit';
  expectedVersion: number;
  payload: Record<string, unknown>;
  status: 'queued' | 'syncing' | 'applied' | 'conflict' | 'failed';
  attempts: number;
  createdAt: string;
  lastAttemptAt?: string;
  error?: string;
}

export interface OperationalAuditEvent {
  id: string;
  tenantId: TenantId;
  actorId: UserId;
  actorRole: OrganizationRole;
  action: string;
  targetType: string;
  targetId: string;
  previousState?: Record<string, unknown>;
  resultingState?: Record<string, unknown>;
  reason?: string;
  requestId: string;
  at: string;
}

export interface OperationalDataset {
  tenants: OrganizationTenant[];
  locations: OrganizationLocation[];
  sessions: OperationalSession[];
  lots: InventoryLot[];
  batches: IntakeBatch[];
  assets: GemstoneAsset[];
  evidence: EvidenceObject[];
  attestations: StructuredAttestation[];
  reviewCases: ReviewCase[];
  syncOperations: SyncOperation[];
  auditEvents: OperationalAuditEvent[];
}

export interface OperationalAuthorityProjection {
  policy: PolicyInput;
  authority: AuthorityInput;
  fixture: FixtureRecord;
}
