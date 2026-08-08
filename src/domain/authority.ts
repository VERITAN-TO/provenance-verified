import type { AuthorityInput, CertificationDecision, IssuanceDecision, ReviewerApproval } from './types';

function approved(approval: ReviewerApproval) {
  return approval.decision === 'approve' && approval.conflictFree;
}

export function evaluateIssuance(decision: CertificationDecision, authority: AuthorityInput): IssuanceDecision {
  const blockers: string[] = [];
  const reasonCodes: string[] = [];
  const requiredApprovalCount = decision.tier === 4 ? 2 : 1;
  const accepted = authority.reviewerApprovals.filter(approved);
  const rejected = authority.reviewerApprovals.some((approval) => approval.decision === 'reject');
  const distinctAcceptedReviewers = new Set(accepted.map((approval) => approval.reviewerId));
  const anyConflict = authority.reviewerApprovals.some((approval) => !approval.conflictFree);

  let status: IssuanceDecision['status'] = 'authorized';

  if (!decision.eligible) {
    status = 'not-eligible';
    blockers.push('Minimum Tier 1 evidence requirements are not satisfied.');
    reasonCodes.push('PV_NOT_ELIGIBLE');
  } else if (rejected) {
    status = 'review-rejected';
    blockers.push('An authorized reviewer rejected the evidence determination.');
    reasonCodes.push('PV_REVIEW_REJECTED');
  } else if (anyConflict || authority.conflictClearance === 'conflict') {
    status = 'reviewer-conflict';
    blockers.push('Reviewer conflict is present; the record must be reassigned.');
    reasonCodes.push('PV_REVIEWER_CONFLICT');
  } else if (accepted.length < 1) {
    status = 'review-required';
    blockers.push('At least one authorized reviewer approval is required.');
    reasonCodes.push('PV_REVIEW_REQUIRED');
  } else if (decision.tier >= 3 && !accepted.some((approval) => approval.independent)) {
    status = 'independent-review-required';
    blockers.push('Tier 3 and Tier 4 require an independent reviewer approval.');
    reasonCodes.push('PV_INDEPENDENT_REVIEW_REQUIRED');
  } else if (decision.tier === 4 && (accepted.length < 2 || distinctAcceptedReviewers.size < 2)) {
    status = 'second-approval-required';
    blockers.push('Tier 4 requires two approvals from distinct independent reviewers.');
    reasonCodes.push('PV_T4_SECOND_APPROVAL_REQUIRED');
  } else if (decision.tier === 4 && accepted.filter((approval) => approval.independent).length < 2) {
    status = 'second-approval-required';
    blockers.push('Both Tier 4 approvals must be independent.');
    reasonCodes.push('PV_T4_DUAL_INDEPENDENCE_REQUIRED');
  } else if (decision.tier === 4 && authority.conflictClearance !== 'clear') {
    status = 'conflict-clearance-required';
    blockers.push('Tier 4 conflict clearance is required.');
    reasonCodes.push('PV_T4_CONFLICT_CLEARANCE_REQUIRED');
  } else if (decision.tier === 4 && authority.custosVerdict.status !== 'pass') {
    status = 'custos-required';
    blockers.push('Tier 4 requires a passing CUSTOS verdict.');
    reasonCodes.push(authority.custosVerdict.status === 'fail' ? 'PV_CUSTOS_FAILED' : 'PV_CUSTOS_REQUIRED');
  } else if (authority.signingKeyStatus !== 'active') {
    status = 'signing-key-required';
    blockers.push('An active issuer signing key is required.');
    reasonCodes.push(authority.signingKeyStatus === 'revoked' ? 'PV_SIGNING_KEY_REVOKED' : 'PV_SIGNING_KEY_UNAVAILABLE');
  } else if (authority.registryStatus !== 'ready') {
    status = 'registry-required';
    blockers.push('Registry publication readiness is required.');
    reasonCodes.push('PV_REGISTRY_UNAVAILABLE');
  } else if (!authority.revocationCapability) {
    status = 'revocation-control-required';
    blockers.push('Credential revocation and supersession capability is required.');
    reasonCodes.push('PV_REVOCATION_CONTROL_REQUIRED');
  } else {
    reasonCodes.push('PV_CREDENTIAL_AUTHORIZED');
  }

  const credentialAuthorized = status === 'authorized';
  const sealAuthorized = credentialAuthorized && authority.markAuthorization === 'authorized';
  if (credentialAuthorized && authority.markAuthorization === 'pending') reasonCodes.push('PV_MARK_PENDING');
  if (credentialAuthorized && authority.markAuthorization === 'denied') reasonCodes.push('PV_MARK_DENIED');
  if (sealAuthorized) reasonCodes.push('PV_MARK_AUTHORIZED');

  return {
    eligibleTier: decision.tier,
    status,
    credentialAuthorized,
    sealAuthorized,
    requiredApprovalCount,
    acceptedApprovalCount: accepted.length,
    blockers,
    reasonCodes,
  };
}
