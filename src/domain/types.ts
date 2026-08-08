export type CertificationTier = 1 | 2 | 3 | 4;
export type TierName = 'Self-Reported' | 'Bronze' | 'Silver' | 'Gold';
export type LifecycleState = 'draft' | 'active' | 'suspended' | 'superseded' | 'revoked' | 'expired' | 'not-found';
export type ClaimStatus = 'verified' | 'corroborated' | 'self-attested' | 'unknown' | 'not-claimed' | 'conflicting';
export type VerificationStage = 'identify' | 'bind' | 'resolve' | 'corroborate' | 'sign' | 'publish' | 'control';
export type CredentialStatus = 'not-issued' | 'issued';
export type IssuanceStatus =
  | 'not-eligible'
  | 'review-required'
  | 'review-rejected'
  | 'independent-review-required'
  | 'second-approval-required'
  | 'reviewer-conflict'
  | 'conflict-clearance-required'
  | 'custos-required'
  | 'signing-key-required'
  | 'registry-required'
  | 'revocation-control-required'
  | 'authorized';

export interface EvidenceItem {
  id: string;
  type: 'photo' | 'measurement' | 'attestation' | 'laboratory' | 'transfer' | 'custody' | 'identity';
  label: string;
  sourceId: string;
  hash: string;
  capturedAt: string;
  qualified: boolean;
  independent: boolean;
  claimIds: string[];
}

export interface SourceRecord {
  id: string;
  name: string;
  category: 'submitter' | 'attestor' | 'laboratory' | 'registry' | 'custodian';
  independent: boolean;
  qualified: boolean;
  jurisdiction: string;
}

export interface ClaimRecord {
  id: string;
  label: string;
  value: string;
  status: ClaimStatus;
  evidenceIds: string[];
  material: boolean;
  scopeNote: string;
}

export interface CustodyEvent {
  id: string;
  actor: string;
  action: string;
  at: string;
  location: string;
  hash: string;
}

/** Evidence and protocol inputs only. Issuance authority is evaluated separately. */
export interface PolicyInput {
  submitterIdentity: boolean;
  selfDeclaredOrigin: boolean;
  photographs: boolean;
  measurements: boolean;
  timestamp: boolean;
  registryId: boolean;
  signedAttestation: boolean;
  identifiedAttestingParty: boolean;
  legalDeclaration: boolean;
  signatureValid: boolean;
  signatureTimestamp: boolean;
  attestationVersion: boolean;
  appendOnlyEvent: boolean;
  integrityHash: boolean;
  qualifyingIndependentSources: number;
  claimLevelCorrespondence: boolean;
  verifiedOrigin: boolean;
  physicalFingerprint: boolean;
  qualifyingLaboratoryEvidence: boolean;
  completeTransferHistory: boolean;
  completeCustodyTransfers: boolean;
}

export interface CertificationDecision {
  policyVersion: string;
  tier: CertificationTier;
  tierName: TierName;
  ringCount: number;
  disclosure: string;
  basis: string[];
  failedRequirements: string[];
  upgradePath: string[];
  claimScope: Record<ClaimStatus, number>;
  eligible: boolean;
  reasonCodes: string[];
}

export interface ReviewerApproval {
  id: string;
  reviewerId: string;
  role: 'primary' | 'secondary';
  independent: boolean;
  conflictFree: boolean;
  decision: 'approve' | 'reject' | 'pending';
  decidedAt?: string;
  reasonCodes: string[];
}

export interface CustosVerdict {
  status: 'pending' | 'pass' | 'fail';
  verdictId?: string;
  evaluatedAt?: string;
  reasonCodes: string[];
}

export interface AuthorityInput {
  reviewerApprovals: ReviewerApproval[];
  conflictClearance: 'pending' | 'clear' | 'conflict';
  custosVerdict: CustosVerdict;
  signingKeyStatus: 'pending' | 'active' | 'unavailable' | 'revoked';
  registryStatus: 'pending' | 'ready' | 'unavailable';
  revocationCapability: boolean;
  markAuthorization: 'pending' | 'authorized' | 'denied';
}

export interface IssuanceDecision {
  eligibleTier: CertificationTier;
  status: IssuanceStatus;
  credentialAuthorized: boolean;
  sealAuthorized: boolean;
  requiredApprovalCount: number;
  acceptedApprovalCount: number;
  blockers: string[];
  reasonCodes: string[];
}

export interface SealAuthorization {
  status: 'not-authorized' | 'authorized';
  tier: CertificationTier | null;
  reasonCodes: string[];
}

export interface Credential {
  id: string;
  publicId: string;
  issuer: 'VERITAN, INC.';
  platform: 'PROVENANCE VERIFIED';
  program: 'Provenance Verified™';
  subject: { assetType: string; assetId: string; description: string };
  status: CredentialStatus;
  eligibleTier: CertificationTier;
  eligibleTierName: TierName;
  tier: CertificationTier | null;
  tierName: TierName | null;
  disclosure: string;
  authorization: IssuanceDecision;
  sealAuthorization: SealAuthorization;
  claims: ClaimRecord[];
  evidence: EvidenceItem[];
  sources: SourceRecord[];
  custody: CustodyEvent[];
  lifecycle: LifecycleState;
  issuedAt?: string;
  expiresAt?: string;
  version: number;
  signature: {
    algorithm: 'Ed25519';
    keyId: string;
    value: string;
    valid: boolean;
    status: 'not-issued' | 'valid' | 'invalid' | 'key-unavailable' | 'revoked-key';
  };
  integrityHash: string;
  successorId?: string;
  warnings: string[];
  testMode: true;
}

export interface SignedEvent {
  id: string;
  type:
    | 'verification.started'
    | 'evidence.bound'
    | 'claims.resolved'
    | 'review.completed'
    | 'approval.completed'
    | 'custos.completed'
    | 'credential.authorization.blocked'
    | 'credential.issued'
    | 'registry.published'
    | 'seal.authorized'
    | 'webhook.attempted'
    | 'webhook.delivered'
    | 'webhook.failed'
    | 'webhook.replayed'
    | 'credential.lifecycle.changed';
  at: string;
  recordId: string;
  sequence: number;
  payload: Record<string, unknown>;
  signature: string;
  previousEventHash: string;
  eventHash: string;
}

export interface WebhookAttempt {
  id: string;
  eventId: string;
  endpoint: string;
  attempt: number;
  status: 'waiting' | 'delivered' | 'failed';
  responseCode?: number;
  scheduledAt: string;
  completedAt?: string;
  signature: string;
  replayOf?: string;
}

export interface FixtureRecord {
  key: string;
  name: string;
  description: string;
  policy: PolicyInput;
  authority: AuthorityInput;
  claims: ClaimRecord[];
  evidence: EvidenceItem[];
  sources: SourceRecord[];
  custody: CustodyEvent[];
  lifecycle: LifecycleState;
  expectedTier: CertificationTier;
  expectedIssuanceStatus: IssuanceStatus;
  expectedIssued: boolean;
  publicId: string;
}
