import type { AuthorityInput, ClaimRecord, CustodyEvent, EvidenceItem, FixtureRecord, PolicyInput, SourceRecord } from './types';

const sources: SourceRecord[] = [
  { id: 'src-owner', name: 'Declared asset owner', category: 'submitter', independent: false, qualified: true, jurisdiction: 'US-AZ' },
  { id: 'src-attestor', name: 'Licensed trade attestor', category: 'attestor', independent: false, qualified: true, jurisdiction: 'US-CA' },
  { id: 'src-lab-a', name: 'Independent Laboratory A', category: 'laboratory', independent: true, qualified: true, jurisdiction: 'US-NY' },
  { id: 'src-lab-b', name: 'Independent Laboratory B', category: 'laboratory', independent: true, qualified: true, jurisdiction: 'CH-GE' },
  { id: 'src-custodian', name: 'Qualified Custodian', category: 'custodian', independent: true, qualified: true, jurisdiction: 'SG' }
];

const claims: ClaimRecord[] = [
  { id: 'claim-origin', label: 'Origin', value: 'Recorded mine lot MX-204', status: 'verified', evidenceIds: ['ev-attest', 'ev-lab-a'], material: true, scopeNote: 'Origin is bound to attestation and independent laboratory correspondence.' },
  { id: 'claim-identity', label: 'Physical identity', value: 'Fingerprint PF-61A9', status: 'verified', evidenceIds: ['ev-photo', 'ev-measure', 'ev-lab-a'], material: true, scopeNote: 'Physical fingerprint and measurements correspond.' },
  { id: 'claim-treatment', label: 'Treatment status', value: 'No treatment detected', status: 'corroborated', evidenceIds: ['ev-lab-a', 'ev-lab-b'], material: true, scopeNote: 'Two independent reports correspond at claim level.' },
  { id: 'claim-custody', label: 'Custody chain', value: 'Four documented custody events', status: 'verified', evidenceIds: ['ev-custody'], material: true, scopeNote: 'All applicable custody transitions are hashed.' },
  { id: 'claim-value', label: 'Market value', value: 'Not claimed', status: 'not-claimed', evidenceIds: [], material: false, scopeNote: 'The credential makes no market-value claim.' }
];

const evidence: EvidenceItem[] = [
  { id: 'ev-photo', type: 'photo', label: 'Macro identity image set', sourceId: 'src-owner', hash: 'sha256:1a4d9f7b0cf1', capturedAt: '2026-07-16T09:00:00Z', qualified: true, independent: false, claimIds: ['claim-identity'] },
  { id: 'ev-measure', type: 'measurement', label: 'Weight and dimension capture', sourceId: 'src-owner', hash: 'sha256:2bf6a80c1ee4', capturedAt: '2026-07-16T09:04:00Z', qualified: true, independent: false, claimIds: ['claim-identity'] },
  { id: 'ev-attest', type: 'attestation', label: 'Signed origin attestation', sourceId: 'src-attestor', hash: 'sha256:35f8b2c4d712', capturedAt: '2026-07-16T09:08:00Z', qualified: true, independent: false, claimIds: ['claim-origin'] },
  { id: 'ev-lab-a', type: 'laboratory', label: 'Laboratory identity and origin report', sourceId: 'src-lab-a', hash: 'sha256:4ca55b8e120f', capturedAt: '2026-07-16T09:20:00Z', qualified: true, independent: true, claimIds: ['claim-origin', 'claim-identity', 'claim-treatment'] },
  { id: 'ev-lab-b', type: 'laboratory', label: 'Independent treatment corroboration', sourceId: 'src-lab-b', hash: 'sha256:580ab28e62ad', capturedAt: '2026-07-16T09:24:00Z', qualified: true, independent: true, claimIds: ['claim-treatment'] },
  { id: 'ev-custody', type: 'custody', label: 'Custody event bundle', sourceId: 'src-custodian', hash: 'sha256:62a9f85f99aa', capturedAt: '2026-07-16T09:32:00Z', qualified: true, independent: true, claimIds: ['claim-custody'] }
];

const custody: CustodyEvent[] = [
  { id: 'cust-1', actor: 'Origin facility', action: 'Released', at: '2026-06-02T08:00:00Z', location: 'MX', hash: 'sha256:c1' },
  { id: 'cust-2', actor: 'Secure carrier', action: 'Accepted', at: '2026-06-02T14:20:00Z', location: 'MX', hash: 'sha256:c2' },
  { id: 'cust-3', actor: 'Independent Laboratory A', action: 'Examined', at: '2026-06-05T10:10:00Z', location: 'US-NY', hash: 'sha256:c3' },
  { id: 'cust-4', actor: 'Qualified Custodian', action: 'Sealed', at: '2026-06-06T17:45:00Z', location: 'SG', hash: 'sha256:c4' }
];

const base: PolicyInput = {
  submitterIdentity: true, selfDeclaredOrigin: true, photographs: true, measurements: true, timestamp: true, registryId: true,
  signedAttestation: false, identifiedAttestingParty: false, legalDeclaration: false, signatureValid: false, signatureTimestamp: false,
  attestationVersion: false, appendOnlyEvent: false, integrityHash: false, qualifyingIndependentSources: 0, claimLevelCorrespondence: false,
  verifiedOrigin: false, physicalFingerprint: false, qualifyingLaboratoryEvidence: false, completeTransferHistory: false,
  completeCustodyTransfers: false
};
const t2: PolicyInput = { ...base, signedAttestation: true, identifiedAttestingParty: true, legalDeclaration: true, signatureValid: true, signatureTimestamp: true, attestationVersion: true, appendOnlyEvent: true, integrityHash: true };
const t3: PolicyInput = { ...t2, qualifyingIndependentSources: 1, claimLevelCorrespondence: true };
const t4: PolicyInput = { ...t3, qualifyingIndependentSources: 2, verifiedOrigin: true, physicalFingerprint: true, qualifyingLaboratoryEvidence: true, completeTransferHistory: true, completeCustodyTransfers: true };

const primaryApproval = {
  id: 'approval-primary', reviewerId: 'reviewer-alpha', role: 'primary' as const, independent: true, conflictFree: true,
  decision: 'approve' as const, decidedAt: '2026-07-16T09:40:00Z', reasonCodes: ['PV_REVIEW_EVIDENCE_SUFFICIENT']
};
const secondaryApproval = {
  id: 'approval-secondary', reviewerId: 'reviewer-beta', role: 'secondary' as const, independent: true, conflictFree: true,
  decision: 'approve' as const, decidedAt: '2026-07-16T09:44:00Z', reasonCodes: ['PV_SECOND_APPROVAL_CONFIRMED']
};

const authority = (overrides: Partial<AuthorityInput> = {}): AuthorityInput => ({
  reviewerApprovals: [primaryApproval],
  conflictClearance: 'clear',
  custosVerdict: { status: 'pass', verdictId: 'custos-test-001', evaluatedAt: '2026-07-16T09:48:00Z', reasonCodes: ['CUSTOS_TEST_PASS'] },
  signingKeyStatus: 'active',
  registryStatus: 'ready',
  revocationCapability: true,
  markAuthorization: 'authorized',
  ...overrides
});
const t4Authority = authority({ reviewerApprovals: [primaryApproval, secondaryApproval] });

const scope = (tier: 1 | 2 | 3 | 4) => claims.map((claim) => {
  if (tier === 1 && claim.material) return { ...claim, status: claim.id === 'claim-origin' ? 'self-attested' as const : 'unknown' as const, evidenceIds: claim.evidenceIds.slice(0, 1) };
  if (tier === 2 && claim.material) return { ...claim, status: claim.id === 'claim-origin' ? 'self-attested' as const : claim.id === 'claim-identity' ? 'verified' as const : 'unknown' as const };
  if (tier === 3 && claim.id === 'claim-treatment') return { ...claim, status: 'corroborated' as const, evidenceIds: ['ev-lab-a'] };
  return claim;
});

export const fixtures: Record<string, FixtureRecord> = {
  t1: { key: 't1', name: 'Tier 1 — Self-Reported', description: 'Submitter identity, declared origin, photographs, measurements, timestamp, and registry ID.', policy: base, authority: authority(), claims: scope(1), evidence: evidence.slice(0, 2), sources: sources.slice(0, 1), custody: custody.slice(0, 1), lifecycle: 'active', expectedTier: 1, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-T1A001' },
  t2: { key: 't2', name: 'Tier 2 — Bronze', description: 'Tier 1 plus a signed attestation and append-only integrity event.', policy: t2, authority: authority(), claims: scope(2), evidence: evidence.slice(0, 3), sources: sources.slice(0, 2), custody: custody.slice(0, 2), lifecycle: 'active', expectedTier: 2, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-T2B002' },
  t3: { key: 't3', name: 'Tier 3 — Silver', description: 'A qualifying independent source confirms a material claim at claim level.', policy: t3, authority: authority(), claims: scope(3), evidence: evidence.slice(0, 4), sources: sources.slice(0, 3), custody: custody.slice(0, 3), lifecycle: 'active', expectedTier: 3, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-T3C003' },
  t4: { key: 't4', name: 'Tier 4 — Gold', description: 'Complete evidence profile plus dual independent approval, conflict clearance, CUSTOS, signing, registry, revocation control, and mark authorization.', policy: t4, authority: t4Authority, claims: scope(4), evidence, sources, custody, lifecycle: 'active', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-T4D004' },
  conflicting: { key: 'conflicting', name: 'Conflicting evidence', description: 'A material evidence conflict caps eligibility and blocks review acceptance.', policy: t3, authority: authority({ reviewerApprovals: [{ ...primaryApproval, decision: 'reject', reasonCodes: ['PV_MATERIAL_CONFLICT_UNRESOLVED'] }] }), claims: claims.map(c => c.id === 'claim-treatment' ? { ...c, status: 'conflicting', scopeNote: 'Independent source reports conflict; no resolved conclusion is published.' } : c), evidence: evidence.slice(0, 5), sources: sources.slice(0, 4), custody: custody.slice(0, 3), lifecycle: 'draft', expectedTier: 2, expectedIssuanceStatus: 'review-rejected', expectedIssued: false, publicId: 'PV-TEST-CF1001' },
  invalidSignature: { key: 'invalidSignature', name: 'Invalid attestation signature', description: 'Attestation signature validation failed; evidence eligibility falls back to Tier 1.', policy: { ...t2, signatureValid: false }, authority: authority(), claims: scope(1), evidence: evidence.slice(0, 3), sources: sources.slice(0, 2), custody: custody.slice(0, 2), lifecycle: 'active', expectedTier: 1, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-SG1002' },
  t4MissingSecondApproval: { key: 't4MissingSecondApproval', name: 'Tier 4 — second approval missing', description: 'Evidence is Gold-eligible but no Gold credential may issue without the second independent approval.', policy: t4, authority: authority(), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'second-approval-required', expectedIssued: false, publicId: 'PV-TEST-A21008' },
  t4ReviewerConflict: { key: 't4ReviewerConflict', name: 'Tier 4 — reviewer conflict', description: 'A conflicted reviewer blocks issuance and requires reassignment.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, { ...secondaryApproval, conflictFree: false }], conflictClearance: 'conflict' }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'reviewer-conflict', expectedIssued: false, publicId: 'PV-TEST-C21009' },
  t4CustosPending: { key: 't4CustosPending', name: 'Tier 4 — CUSTOS pending', description: 'Dual approval is complete, but the independent CUSTOS gate has not passed.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], custosVerdict: { status: 'pending', reasonCodes: [] } }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'custos-required', expectedIssued: false, publicId: 'PV-TEST-U21010' },
  t4SigningUnavailable: { key: 't4SigningUnavailable', name: 'Tier 4 — signing unavailable', description: 'Cryptographic signing uncertainty fails closed.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], signingKeyStatus: 'unavailable' }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'signing-key-required', expectedIssued: false, publicId: 'PV-TEST-K21011' },
  t4RegistryUnavailable: { key: 't4RegistryUnavailable', name: 'Tier 4 — registry unavailable', description: 'Registry uncertainty blocks issuance and public projection.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], registryStatus: 'unavailable' }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'registry-required', expectedIssued: false, publicId: 'PV-TEST-R21012' },
  t4MarkPending: { key: 't4MarkPending', name: 'Tier 4 — mark authorization pending', description: 'Credential may issue, but the Gold seal remains unavailable until mark control authorizes it.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], markAuthorization: 'pending' }), claims: scope(4), evidence, sources, custody, lifecycle: 'active', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-M21013' },
  t4ConflictClearancePending: { key: 't4ConflictClearancePending', name: 'Tier 4 — conflict clearance pending', description: 'Dual review is complete, but the formal conflict-clearance gate has not closed.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], conflictClearance: 'pending' }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'conflict-clearance-required', expectedIssued: false, publicId: 'PV-TEST-L21014' },
  t4CustosFailed: { key: 't4CustosFailed', name: 'Tier 4 — CUSTOS failed', description: 'A failed CUSTOS verdict blocks issuance even after dual reviewer approval.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], custosVerdict: { status: 'fail', verdictId: 'custos-test-fail', evaluatedAt: '2026-07-16T09:48:00Z', reasonCodes: ['CUSTOS_POLICY_FAILURE'] } }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'custos-required', expectedIssued: false, publicId: 'PV-TEST-F21015' },
  t4SigningRevoked: { key: 't4SigningRevoked', name: 'Tier 4 — signing key revoked', description: 'A revoked issuer key fails closed and cannot create a credential.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], signingKeyStatus: 'revoked' }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'signing-key-required', expectedIssued: false, publicId: 'PV-TEST-V21016' },
  t4RevocationUnavailable: { key: 't4RevocationUnavailable', name: 'Tier 4 — revocation control unavailable', description: 'Issuance is prohibited when suspension, revocation, and supersession controls are unavailable.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], revocationCapability: false }), claims: scope(4), evidence, sources, custody, lifecycle: 'draft', expectedTier: 4, expectedIssuanceStatus: 'revocation-control-required', expectedIssued: false, publicId: 'PV-TEST-X21017' },
  t4MarkDenied: { key: 't4MarkDenied', name: 'Tier 4 — mark authorization denied', description: 'The credential is issued, but certification-mark use is explicitly denied.', policy: t4, authority: authority({ reviewerApprovals: [primaryApproval, secondaryApproval], markAuthorization: 'denied' }), claims: scope(4), evidence, sources, custody, lifecycle: 'active', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-D21018' },
  suspended: { key: 'suspended', name: 'Suspended credential', description: 'Credential remains resolvable while active reliance is paused.', policy: t4, authority: t4Authority, claims: scope(4), evidence, sources, custody, lifecycle: 'suspended', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-SP1003' },
  revoked: { key: 'revoked', name: 'Revoked credential', description: 'Credential remains resolvable with an explicit invalid lifecycle state.', policy: t4, authority: t4Authority, claims: scope(4), evidence, sources, custody, lifecycle: 'revoked', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-RV1004' },
  superseded: { key: 'superseded', name: 'Superseded credential', description: 'A newer credential version replaces this record and is linked as successor.', policy: t4, authority: t4Authority, claims: scope(4), evidence, sources, custody, lifecycle: 'superseded', expectedTier: 4, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-SS1005' },
  expired: { key: 'expired', name: 'Expired credential', description: 'Time-bounded credential remains resolvable after expiration.', policy: t3, authority: authority(), claims: scope(3), evidence: evidence.slice(0, 4), sources: sources.slice(0, 3), custody: custody.slice(0, 3), lifecycle: 'expired', expectedTier: 3, expectedIssuanceStatus: 'authorized', expectedIssued: true, publicId: 'PV-TEST-EX1006' },
  notFound: { key: 'notFound', name: 'Not found', description: 'Stable negative response for an unknown public identifier.', policy: { ...base, submitterIdentity: false }, authority: authority({ reviewerApprovals: [] }), claims: [], evidence: [], sources: [], custody: [], lifecycle: 'not-found', expectedTier: 1, expectedIssuanceStatus: 'not-eligible', expectedIssued: false, publicId: 'PV-TEST-NF1007' }
};

export const fixtureList = Object.values(fixtures);
export function fixtureByPublicId(publicId: string) { return fixtureList.find((item) => item.publicId === publicId); }
