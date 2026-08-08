import type { CertificationTier } from '@/domain/types';

export const tierEducation: Record<CertificationTier, {
  label: string;
  eyebrow: string;
  disclosure: string;
  requirements: string[];
  boundary: string;
}> = {
  1: {
    label: 'Self-Reported',
    eyebrow: 'Asset fingerprint + declared record',
    disclosure: 'Origin information has not been independently corroborated.',
    requirements: ['Submitter identity', 'Photographs and measurements', 'Timestamp and registry ID', 'Explicit self-reported disclosure'],
    boundary: 'No independent corroboration is claimed.'
  },
  2: {
    label: 'Bronze',
    eyebrow: 'Legally accountable attestation',
    disclosure: 'Claims are signed under legal accountability but may remain uncorroborated.',
    requirements: ['Tier 1 foundation', 'Identified attesting party', 'Signed legal declaration', 'Versioned append-only event and integrity hash'],
    boundary: 'A signature does not create independent corroboration.'
  },
  3: {
    label: 'Silver',
    eyebrow: 'Independent claim corroboration',
    disclosure: 'At least one material claim is confirmed by an approved independent source.',
    requirements: ['Tier 2 foundation', 'One qualifying independent source', 'Claim-level correspondence', 'Source identity, evidence reference, date, and integrity'],
    boundary: 'Corroboration applies only to the claims explicitly supported.'
  },
  4: {
    label: 'Gold',
    eyebrow: 'Complete documented provenance chain',
    disclosure: 'Origin, identity, laboratory evidence, transfers, and independent corroborations are documented.',
    requirements: ['Verified origin and physical fingerprint', 'Qualifying laboratory evidence', 'Complete applicable transfer and custody history', 'Two independent corroborations', 'Dual review, conflict clearance, CUSTOS, signing, registry, and revocation control'],
    boundary: 'Evidence eligibility still does not authorize issuance or seal use.'
  }
};

export const phase3SourceAuthority = [
  { responsibility: 'Editorial sequence', source: 'V25 Authority Machine', sha256: 'cbbfcd6c869084b319dcd1e7c614b50ef49b539402c4acb6d610f2c988527594' },
  { responsibility: 'Operational transaction', source: 'V24 Operational Proof', sha256: '49e52e017998b35def0298c1954c90ee180eec64728cab7dc4ffc97eda6328dd' },
  { responsibility: 'Evidence continuity', source: 'V22 Proof OS', sha256: 'e3b1ed7db1ea10624052cc12a0b1617ac937bce278f4497e57e831d32632392d' },
  { responsibility: 'Lifecycle continuity', source: 'V23 Continuum', sha256: '96249f230893c2684a454798dcfe60a104a15ace44ff0a83dd10eaec3d831bac' },
  { responsibility: 'Verification mechanics', source: 'R4 Authority Complete', sha256: 'edbdf90655d6689c6322c1300a427b42083d8a64da9de80dd6b7cde9de38110f' },
  { responsibility: 'Tier education', source: 'Ultimate V11', sha256: '13a63cb0019ad632eddc359fff12ae8cb40fdf3a6e8ba776da24f736d4d0d73e' }
] as const;
