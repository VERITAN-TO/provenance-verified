import { describe, expect, it } from 'vitest';
import { fixtures } from '@/domain/fixtures';
import { evaluateCertification } from '@/domain/kernel';

describe('deterministic four-tier evidence eligibility kernel', () => {
  it.each(['t1', 't2', 't3', 't4'] as const)('evaluates %s to its exact evidence-supported tier', (key) => {
    const fixture = fixtures[key];
    const decision = evaluateCertification(fixture.policy, fixture.claims);
    expect(decision.tier).toBe(fixture.expectedTier);
    expect(decision.ringCount).toBe(fixture.expectedTier);
    expect(decision.policyVersion).toBe('PV-POLICY-2026.07-R2');
  });

  it('falls back when the signed attestation is invalid', () => {
    const fixture = fixtures.invalidSignature;
    expect(evaluateCertification(fixture.policy, fixture.claims).tier).toBe(1);
  });

  it('requires two qualifying independent sources for Gold eligibility', () => {
    const fixture = fixtures.t4;
    const decision = evaluateCertification({ ...fixture.policy, qualifyingIndependentSources: 1 }, fixture.claims);
    expect(decision.tier).toBe(3);
    expect(decision.upgradePath).toContain('At least two qualifying independent sources');
  });

  it('caps material conflict below independently corroborated tiers', () => {
    const fixture = fixtures.conflicting;
    const decision = evaluateCertification(fixture.policy, fixture.claims);
    expect(decision.tier).toBe(2);
    expect(decision.reasonCodes).toContain('PV_MATERIAL_CONFLICT_CAP');
    expect(decision.upgradePath).toContain('Resolve every material evidence conflict before Tier 3 or Tier 4 eligibility');
  });
});
