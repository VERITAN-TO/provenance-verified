import { describe, expect, it } from 'vitest';
import { evaluateIssuance } from '@/domain/authority';
import { fixtures } from '@/domain/fixtures';
import { evaluateCertification } from '@/domain/kernel';
import { buildCredential } from '@/domain/projectors';

function issuance(key: keyof typeof fixtures) {
  const fixture = fixtures[key];
  return evaluateIssuance(evaluateCertification(fixture.policy, fixture.claims), fixture.authority);
}

describe('issuer authority gates', () => {
  it('issues Gold only after dual independent approval, conflict clearance, CUSTOS, signing, registry, and revocation controls', () => {
    const result = issuance('t4');
    expect(result.status).toBe('authorized');
    expect(result.credentialAuthorized).toBe(true);
    expect(result.acceptedApprovalCount).toBe(2);
    expect(result.sealAuthorized).toBe(true);
  });

  it('blocks Gold when the second independent approval is absent', () => {
    const result = issuance('t4MissingSecondApproval');
    expect(result.status).toBe('second-approval-required');
    expect(result.credentialAuthorized).toBe(false);
    expect(buildCredential(fixtures.t4MissingSecondApproval).tier).toBeNull();
  });

  it('blocks a conflicted reviewer and requires reassignment', () => {
    const result = issuance('t4ReviewerConflict');
    expect(result.status).toBe('reviewer-conflict');
    expect(result.reasonCodes).toContain('PV_REVIEWER_CONFLICT');
  });

  it('blocks Gold until CUSTOS passes', () => {
    expect(issuance('t4CustosPending').status).toBe('custos-required');
  });

  it('fails closed when the issuer signing key is unavailable', () => {
    const credential = buildCredential(fixtures.t4SigningUnavailable);
    expect(credential.status).toBe('not-issued');
    expect(credential.signature.status).toBe('key-unavailable');
  });

  it('fails closed when the registry cannot publish', () => {
    expect(issuance('t4RegistryUnavailable').status).toBe('registry-required');
  });

  it('can issue a credential while withholding the seal when mark control is pending', () => {
    const credential = buildCredential(fixtures.t4MarkPending);
    expect(credential.status).toBe('issued');
    expect(credential.tier).toBe(4);
    expect(credential.sealAuthorization.status).toBe('not-authorized');
  });

  it('requires explicit Tier 4 conflict clearance after dual review', () => {
    expect(issuance('t4ConflictClearancePending').status).toBe('conflict-clearance-required');
  });

  it('fails closed when CUSTOS returns a failed verdict', () => {
    const result = issuance('t4CustosFailed');
    expect(result.status).toBe('custos-required');
    expect(result.reasonCodes).toContain('PV_CUSTOS_FAILED');
  });

  it('fails closed when the issuer signing key is revoked', () => {
    const credential = buildCredential(fixtures.t4SigningRevoked);
    expect(credential.status).toBe('not-issued');
    expect(credential.signature.status).toBe('revoked-key');
    expect(credential.authorization.reasonCodes).toContain('PV_SIGNING_KEY_REVOKED');
  });

  it('blocks issuance when revocation and supersession controls are unavailable', () => {
    expect(issuance('t4RevocationUnavailable').status).toBe('revocation-control-required');
  });

  it('can issue a credential while explicitly denying certification-mark use', () => {
    const credential = buildCredential(fixtures.t4MarkDenied);
    expect(credential.status).toBe('issued');
    expect(credential.sealAuthorization.status).toBe('not-authorized');
    expect(credential.sealAuthorization.reasonCodes).toContain('PV_MARK_DENIED');
  });


  it('requires an authorized reviewer before any eligible credential can issue', () => {
    const fixture = fixtures.t2;
    const result = evaluateIssuance(evaluateCertification(fixture.policy, fixture.claims), { ...fixture.authority, reviewerApprovals: [] });
    expect(result.status).toBe('review-required');
  });

  it('requires an independent reviewer for Tier 3', () => {
    const fixture = fixtures.t3;
    const result = evaluateIssuance(evaluateCertification(fixture.policy, fixture.claims), {
      ...fixture.authority,
      reviewerApprovals: fixture.authority.reviewerApprovals.map((approval) => ({ ...approval, independent: false })),
    });
    expect(result.status).toBe('independent-review-required');
  });

  it('requires both Tier 4 approvals to be independent', () => {
    const fixture = fixtures.t4;
    const result = evaluateIssuance(evaluateCertification(fixture.policy, fixture.claims), {
      ...fixture.authority,
      reviewerApprovals: fixture.authority.reviewerApprovals.map((approval, index) => index === 1 ? { ...approval, independent: false } : approval),
    });
    expect(result.status).toBe('second-approval-required');
    expect(result.reasonCodes).toContain('PV_T4_DUAL_INDEPENDENCE_REQUIRED');
  });

});
