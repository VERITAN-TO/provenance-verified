import { NextRequest } from 'next/server';
import { reviewDecisionSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, createOperationalEventReceipt, credentialForOperationalAsset, projectAssetToAuthority } from '@/operations/kernel';
import { evaluateCertification } from '@/domain/kernel';
import { appendOperationalAudit } from '@/operations/audit';
import { stableHash } from '@/domain/hash';
import type { ReviewCase } from '@/operations/types';

export const dynamic = 'force-dynamic';

function approved(review: ReviewCase, role: 'primary' | 'secondary') {
  return review.approvals.find((item) => item.role === role && item.decision === 'approve' && item.independent && item.conflictFree);
}

function appendReceipt(review: ReviewCase, type: Parameters<typeof createOperationalEventReceipt>[1], targetId: string, actorId: string, at: string) {
  review.eventReceipts = [...review.eventReceipts, createOperationalEventReceipt(review.eventReceipts, type, targetId, actorId, at)];
}

function statusFromCredential(review: ReviewCase): ReviewCase['status'] {
  const credential = review.credential;
  if (credential?.status === 'issued') return credential.sealAuthorization.status === 'authorized' ? 'issued' : 'mark-required';
  switch (credential?.authorization.status) {
    case 'second-approval-required': return 'secondary-required';
    case 'custos-required': return 'custos-required';
    case 'signing-key-required':
    case 'registry-required':
    case 'revocation-control-required': return 'issuer-required';
    case 'review-rejected': return 'rejected';
    default: return 'blocked';
  }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ caseId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'review.decide');
    const { caseId } = await params;
    const repository = getOperationalRepository();
    const review = repository.getReviewCase(session, caseId);
    if (!review) return Response.json({ error: { code: 'review_not_found', message: 'Review case does not exist in the active tenant.' } }, { status: 404 });
    const input = reviewDecisionSchema.parse(await request.json());
    if (input.reviewerId !== session.userId) throw new Error('REVIEWER_IDENTITY_MISMATCH');
    if (input.action === 'review' && input.role === 'secondary') assertPermission(session, 'review.approve-tier4');
    const updated = structuredClone(review);
    updated.corrections ??= [];
    updated.lifecycleEvents ??= [];
    updated.credentialLifecycle ??= 'active';
    const asset = repository.getAsset(session, review.assetId)!;
    const evidence = repository.listEvidence(session, review.assetId);
    const attestation = repository.listAttestations(session, review.batchId).find((item) => item.id === review.attestationId);
    const preProjection = projectAssetToAuthority(asset, evidence, updated, attestation);
    const eligibleTier = evaluateCertification(preProjection.policy, preProjection.fixture.claims).tier;
    const actionAt = new Date().toISOString();

    if (input.action === 'review') {
      if (input.role === 'secondary' && !approved(updated, 'primary')) throw new Error('PRIMARY_APPROVAL_REQUIRED');
      const otherApproval = updated.approvals.find((item) => item.role !== input.role && item.decision === 'approve');
      if (otherApproval?.reviewerId === session.userId) throw new Error('DISTINCT_REVIEWER_REQUIRED');
      updated.approvals = [...updated.approvals.filter((item) => item.role !== input.role), { id: `approval_${input.role}_${review.assetId}`, reviewerId: session.userId, role: input.role, independent: input.independent, conflictFree: input.conflictFree, decision: input.decision, decidedAt: input.decision === 'pending' ? undefined : actionAt, reasonCodes: input.reasonCodes }];
      updated.conflictClearance = input.conflictFree ? 'clear' : 'conflict';
      appendReceipt(updated, input.role === 'primary' ? 'review.primary-recorded' : 'review.secondary-recorded', review.id, session.userId, actionAt);
    }

    if (input.action === 'custos-pass' || input.action === 'custos-fail') {
      assertPermission(session, 'custos.decide');
      if (eligibleTier === 4 && (!approved(updated, 'primary') || !approved(updated, 'secondary') || updated.conflictClearance !== 'clear')) throw new Error('DUAL_REVIEW_AND_CLEARANCE_REQUIRED');
      updated.custosVerdict = { status: input.action === 'custos-pass' ? 'pass' : 'fail', verdictId: `custos_${caseId}`, evaluatedAt: actionAt, reasonCodes: input.reasonCodes };
      appendReceipt(updated, 'custos.recorded', `custos_${caseId}`, session.userId, actionAt);
    }

    if (input.action === 'authorize-signing') {
      assertPermission(session, 'credential.issue');
      if (!approved(updated, 'primary')) throw new Error('PRIMARY_APPROVAL_REQUIRED');
      if (eligibleTier >= 3 && !updated.approvals.some((item) => item.decision === 'approve' && item.independent && item.conflictFree)) throw new Error('INDEPENDENT_REVIEW_REQUIRED');
      if (eligibleTier === 4 && (!approved(updated, 'secondary') || updated.conflictClearance !== 'clear' || updated.custosVerdict.status !== 'pass')) throw new Error('TIER4_AUTHORITY_GATES_INCOMPLETE');
      updated.signingKeyStatus = 'active';
      appendReceipt(updated, 'signing.authorized', review.id, session.userId, actionAt);
    }

    if (input.action === 'publish-registry') {
      assertPermission(session, 'credential.issue');
      if (updated.signingKeyStatus !== 'active' || !updated.eventReceipts.some((receipt) => receipt.type === 'signing.authorized')) throw new Error('SIGNING_AUTHORIZATION_REQUIRED');
      updated.registryStatus = 'ready';
      const receipt = createOperationalEventReceipt(updated.eventReceipts, 'registry.published', updated.registryId, session.userId, actionAt);
      updated.eventReceipts = [...updated.eventReceipts, receipt];
      updated.registryPublication = { publicId: updated.registryId, receiptId: receipt.id, publishedAt: actionAt, integrityHash: `sha256:${stableHash(`${updated.registryId}:${receipt.eventHash}:${actionAt}`)}` };
    }

    if (input.action === 'enable-revocation-control') {
      assertPermission(session, 'credential.issue');
      if (updated.registryStatus !== 'ready' || !updated.registryPublication) throw new Error('REGISTRY_PUBLICATION_REQUIRED');
      updated.revocationCapability = true;
      appendReceipt(updated, 'revocation-control.enabled', updated.registryId, session.userId, actionAt);
    }

    if (input.action === 'authorize-mark' || input.action === 'deny-mark') {
      assertPermission(session, 'mark.authorize');
      if (updated.credentialLifecycle !== 'active') throw new Error('ACTIVE_LIFECYCLE_REQUIRED');
      if (updated.corrections.some((item) => item.status === 'open')) throw new Error('OPEN_CORRECTION_BLOCKS_MARK');
      const preMarkCredential = credentialForOperationalAsset(asset, evidence, { ...updated, markAuthorization: 'pending' }, attestation);
      if (preMarkCredential.status !== 'issued') throw new Error('CREDENTIAL_ISSUANCE_REQUIRED');
      updated.markAuthorization = input.action === 'authorize-mark' ? 'authorized' : 'denied';
      appendReceipt(updated, input.action === 'authorize-mark' ? 'mark.authorized' : 'mark.denied', updated.registryId, session.userId, actionAt);
    }

    const projection = projectAssetToAuthority(asset, evidence, updated, attestation);
    updated.decision = evaluateCertification(projection.policy, projection.fixture.claims);
    updated.credential = credentialForOperationalAsset(asset, evidence, updated, attestation);
    updated.status = statusFromCredential(updated);
    updated.updatedAt = actionAt;
    const persisted = repository.upsertReviewCase(session, updated);
    appendOperationalAudit(repository, session, request, `review.${input.action}`, 'review-case', caseId, { status: persisted.status, credentialStatus: persisted.credential?.status, markStatus: persisted.credential?.sealAuthorization.status, registryPublication: persisted.registryPublication?.receiptId }, { status: review.status });
    return Response.json({ data: persisted, meta: { mode: 'test', authorityKernel: 'phase-1', evidenceProjection: 'record-derived' } });
  } catch (error) { return operationError(error); }
}
