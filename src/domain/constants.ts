import type { CertificationTier, TierName, VerificationStage } from './types';

export const POLICY_VERSION = 'PV-POLICY-2026.07-R2';
export const TEST_MODE_LABELS = ['TEST MODE', 'NON-AUTHORITATIVE', 'NOT A PRODUCTION CREDENTIAL'] as const;
export const STAGES: { id: VerificationStage; label: string; detail: string }[] = [
  { id: 'identify', label: 'Identify', detail: 'Resolve subject and submitter identity.' },
  { id: 'bind', label: 'Bind', detail: 'Bind evidence, hashes, timestamps, and custody.' },
  { id: 'resolve', label: 'Resolve', detail: 'Resolve every public claim independently.' },
  { id: 'corroborate', label: 'Corroborate', detail: 'Evaluate qualifying independent sources.' },
  { id: 'sign', label: 'Sign', detail: 'Issue a versioned signed credential.' },
  { id: 'publish', label: 'Publish', detail: 'Project the same credential to the public registry.' },
  { id: 'control', label: 'Control', detail: 'Observe events, webhooks, and lifecycle state.' }
];
export const TIER_NAMES: Record<CertificationTier, TierName> = { 1: 'Self-Reported', 2: 'Bronze', 3: 'Silver', 4: 'Gold' };
export const TIER_DISCLOSURES: Record<CertificationTier, string> = {
  1: 'SELF-REPORTED RECORD — Origin information has not been independently corroborated.',
  2: 'SIGNED ATTESTATION — Claims are declared under legal accountability but may not yet be independently corroborated.',
  3: 'INDEPENDENTLY CORROBORATED — At least one material claim is confirmed by an approved independent source.',
  4: 'COMPLETE PROVENANCE CHAIN — Origin, identity, laboratory evidence, transfers, and independent corroborations are documented and cryptographically signed.'
};
