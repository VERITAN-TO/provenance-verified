import type { CertificationDecision, Credential, FixtureRecord, LifecycleState, PolicyInput } from '@/domain/types';
import type {
  EvidenceObject,
  GemstoneAsset,
  OperationalDataset,
  OperationalSession,
  ReviewCase,
} from '@/operations/types';

export type ProvenanceServiceMode = 'test' | 'pilot' | 'production';

export interface AssetIdentityQuery {
  publicId?: string;
  assetId?: string;
  serial?: string;
  tenantId?: string;
}

export interface EvidenceValidation {
  valid: boolean;
  eligible: boolean;
  blockers: string[];
  warnings: string[];
  integrity: 'verified' | 'invalid' | 'missing';
}

export interface TierAssessment {
  decision: CertificationDecision;
  fixture: FixtureRecord;
}

export interface VerificationResult {
  status: number;
  body: Record<string, unknown>;
}

export interface RegistryLookupResult {
  record: Record<string, unknown> | null;
  canonicalDigest?: string;
}

export interface ContinuityState {
  publicId: string;
  lifecycle: LifecycleState;
  successorId?: string;
  eventCount: number;
  markPermitted: boolean;
}

export interface CollectionState {
  tenantId: string;
  lots: number;
  declaredUnits: number;
  identifiedAssets: number;
  batches: number;
  evidenceObjects: number;
  openReviews: number;
  issuedCredentials: number;
}

export interface LifecycleTransitionCommand {
  session: OperationalSession;
  reviewCaseId: string;
  action: 'suspend' | 'reactivate' | 'revoke' | 'supersede' | 'expire';
  reason: string;
  successorId?: string;
}

export interface ApiOperation {
  name: 'verify' | 'registry.lookup' | 'events.list' | 'operations.collection';
  input: Record<string, unknown>;
}

export interface McpOperation {
  name: 'provenance_verify' | 'provenance_registry_lookup' | 'provenance_collection_state';
  arguments: Record<string, unknown>;
}

export interface ProvenanceService {
  readonly mode: ProvenanceServiceMode;
  readonly authoritative: boolean;
  identifyAsset(query: AssetIdentityQuery, session?: OperationalSession): Promise<GemstoneAsset | FixtureRecord | null>;
  submitEvidence(session: OperationalSession, evidence: EvidenceObject): Promise<EvidenceObject>;
  validateEvidence(evidence: EvidenceObject[]): Promise<EvidenceValidation>;
  assessTier(policy: PolicyInput, fixture: FixtureRecord): Promise<TierAssessment>;
  issueCredential(session: OperationalSession, reviewCaseId: string): Promise<Credential>;
  verify(publicId: string, fixtureKey?: string): Promise<VerificationResult>;
  transitionLifecycle(command: LifecycleTransitionCommand): Promise<ReviewCase>;
  lookupRegistry(publicId: string): Promise<RegistryLookupResult>;
  evaluatePolicy(policy: PolicyInput, fixture: FixtureRecord): Promise<CertificationDecision>;
  continuity(publicId: string): Promise<ContinuityState | null>;
  collectionState(session: OperationalSession): Promise<CollectionState>;
  dataset(session: OperationalSession): Promise<OperationalDataset>;
  executeApi(operation: ApiOperation): Promise<Record<string, unknown>>;
  invokeMcp(operation: McpOperation): Promise<Record<string, unknown>>;
}
