import { POLICY_VERSION, TIER_DISCLOSURES, TIER_NAMES } from './constants';
import type { CertificationDecision, ClaimRecord, ClaimStatus, PolicyInput } from './types';

const T1: [keyof PolicyInput, string][] = [
  ['submitterIdentity', 'Submitter identity'], ['selfDeclaredOrigin', 'Self-declared origin'], ['photographs', 'Photographs'],
  ['measurements', 'Weight and dimensions'], ['timestamp', 'Timestamp'], ['registryId', 'Registry ID']
];
const T2: [keyof PolicyInput, string][] = [
  ...T1, ['signedAttestation', 'Structured signed attestation'], ['identifiedAttestingParty', 'Identified attesting party'],
  ['legalDeclaration', 'Legal declaration'], ['signatureValid', 'Valid attestation signature'], ['signatureTimestamp', 'Signature timestamp'],
  ['attestationVersion', 'Attestation version'], ['appendOnlyEvent', 'Append-only registry event'], ['integrityHash', 'Integrity hash']
];
const T3: [keyof PolicyInput, string][] = [...T2, ['claimLevelCorrespondence', 'Claim-level evidence correspondence']];
const T4: [keyof PolicyInput, string][] = [
  ...T3, ['verifiedOrigin', 'Verified origin'], ['physicalFingerprint', 'Physical fingerprint'],
  ['qualifyingLaboratoryEvidence', 'Qualifying laboratory evidence'], ['completeTransferHistory', 'Complete transfer history'],
  ['completeCustodyTransfers', 'Complete custody transfers']
];

function passes(input: PolicyInput, requirements: [keyof PolicyInput, string][], minSources = 0): boolean {
  return requirements.every(([key]) => Boolean(input[key])) && input.qualifyingIndependentSources >= minSources;
}

function names(requirements: [keyof PolicyInput, string][]) { return requirements.map(([, label]) => label); }

export function summarizeClaims(claims: ClaimRecord[]): Record<ClaimStatus, number> {
  const result: Record<ClaimStatus, number> = { verified: 0, corroborated: 0, 'self-attested': 0, unknown: 0, 'not-claimed': 0, conflicting: 0 };
  claims.forEach((claim) => { result[claim.status] += 1; });
  return result;
}

export function evaluateCertification(input: PolicyInput, claims: ClaimRecord[]): CertificationDecision {
  const materialConflict = claims.some((claim) => claim.material && claim.status === 'conflicting');
  const minimumEligible = passes(input, T1);
  let tier: 1 | 2 | 3 | 4 = 1;

  if (!materialConflict && passes(input, T4, 2)) tier = 4;
  else if (!materialConflict && passes(input, T3, 1)) tier = 3;
  else if (passes(input, T2)) tier = 2;

  const target = tier === 4 ? T4 : tier === 3 ? T3 : tier === 2 ? T2 : T1;
  const next = tier === 4 ? T4 : tier === 3 ? T4 : tier === 2 ? T3 : T2;
  const sourceRequirement = tier === 4 ? 2 : tier === 3 ? 1 : 0;
  const basis = names(target).filter((_, index) => Boolean(input[target[index][0]]));
  if (sourceRequirement > 0) basis.push(`${input.qualifyingIndependentSources} qualifying independent source${input.qualifyingIndependentSources === 1 ? '' : 's'}`);
  const failedRequirements = names(target).filter((_, index) => !Boolean(input[target[index][0]]));
  const upgradePath = tier === 4 ? [] : [
    ...names(next).filter((_, index) => !Boolean(input[next[index][0]])),
    ...((tier === 2 && input.qualifyingIndependentSources < 1) ? ['At least one qualifying independent source'] : []),
    ...((tier === 3 && input.qualifyingIndependentSources < 2) ? ['At least two qualifying independent sources'] : []),
    ...(materialConflict ? ['Resolve every material evidence conflict before Tier 3 or Tier 4 eligibility'] : [])
  ];
  const reasonCodes = [
    `PV_ELIGIBLE_TIER_${tier}`,
    ...(materialConflict ? ['PV_MATERIAL_CONFLICT_CAP'] : []),
    ...(!minimumEligible ? ['PV_MINIMUM_EVIDENCE_MISSING'] : [])
  ];

  return {
    policyVersion: POLICY_VERSION,
    tier,
    tierName: TIER_NAMES[tier],
    ringCount: tier,
    disclosure: TIER_DISCLOSURES[tier],
    basis,
    failedRequirements,
    upgradePath: [...new Set(upgradePath)],
    claimScope: summarizeClaims(claims),
    eligible: minimumEligible,
    reasonCodes,
  };
}
