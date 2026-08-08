import { stableHash } from '@/domain/hash';
import type { OperationalRepository } from './repository';
import type { CorrectionRequestRecord, OperationalSession, ReviewCase } from './types';
import { createOperationalEventReceipt, signAttestation } from './kernel';

export interface RequestCorrectionInput {
  reason: string;
  fields: string[];
  at: string;
}

export interface ResolveCorrectionInput {
  correctionId: string;
  resolution: string;
  claimSummary: string;
  evidenceSummary: string;
  limitations: string[];
  at: string;
}

export interface RejectCorrectionInput {
  correctionId: string;
  resolution: string;
  at: string;
}

export function requestCorrection(review: ReviewCase, session: OperationalSession, input: RequestCorrectionInput): ReviewCase {
  if (review.corrections.some((item) => item.status === 'open')) throw new Error('OPEN_CORRECTION_EXISTS');
  const updated = structuredClone(review);
  const record: CorrectionRequestRecord = {
    id: `correction_${stableHash(`${review.id}:${session.userId}:${input.reason}:${input.at}`)}`,
    version: updated.corrections.length + 1,
    status: 'open',
    requestedBy: session.userId,
    requestedAt: input.at,
    reason: input.reason,
    fields: [...new Set(input.fields)].sort(),
  };
  const receipt = createOperationalEventReceipt(updated.eventReceipts, 'correction.requested', record.id, session.userId, input.at);
  updated.eventReceipts = [...updated.eventReceipts, receipt];
  updated.corrections = [...updated.corrections, record];
  updated.correctionRequest = input.reason;
  updated.status = 'correction-requested';
  if (updated.credential?.status === 'issued' && (updated.credentialLifecycle === 'active' || updated.credentialLifecycle === 'suspended')) {
    // An open correction blocks mark use and leaves the public credential visibly suspended pending resolution.
    updated.credentialLifecycle = 'suspended';
    updated.markAuthorization = 'denied';
  }
  updated.updatedAt = input.at;
  return updated;
}

export function resolveCorrection(
  repository: OperationalRepository,
  review: ReviewCase,
  session: OperationalSession,
  input: ResolveCorrectionInput,
): ReviewCase {
  const correction = review.corrections.find((item) => item.id === input.correctionId && item.status === 'open');
  if (!correction) throw new Error('OPEN_CORRECTION_NOT_FOUND');
  const batch = repository.getBatch(session, review.batchId);
  if (!batch) throw new Error('BATCH_NOT_FOUND');
  const assets = repository.listAssets(session, review.batchId);
  const prior = repository.listAttestations(session, review.batchId).find((item) => item.id === review.attestationId);
  const replacement = signAttestation(session, batch, assets, input.claimSummary, input.evidenceSummary, input.limitations, prior);
  repository.appendAttestation(session, replacement);

  const updated = structuredClone(review);
  updated.corrections = updated.corrections.map((item) => item.id === correction.id ? {
    ...item,
    status: 'resolved',
    resolution: input.resolution,
    resolvedBy: session.userId,
    resolvedAt: input.at,
    supersededAttestationId: prior?.id,
    replacementAttestationId: replacement.id,
  } : item);
  const receipt = createOperationalEventReceipt(updated.eventReceipts, 'correction.resolved', correction.id, session.userId, input.at);
  const attestationReceipt = createOperationalEventReceipt([...updated.eventReceipts, receipt], 'attestation.recorded', replacement.id, session.userId, input.at);
  updated.eventReceipts = [...updated.eventReceipts, receipt, attestationReceipt];
  updated.attestationId = replacement.id;
  updated.correctionRequest = undefined;
  updated.status = 'unassigned';
  updated.approvals = [];
  updated.assignedReviewerIds = [];
  updated.conflictClearance = 'pending';
  updated.custosVerdict = { status: 'pending', reasonCodes: ['PV_CORRECTION_REVIEW_REQUIRED'] };
  updated.signingKeyStatus = 'pending';
  updated.registryStatus = 'pending';
  updated.registryPublication = undefined;
  updated.revocationCapability = false;
  updated.markAuthorization = 'pending';
  updated.credentialLifecycle = 'active';
  updated.successorId = undefined;
  updated.credential = undefined;
  updated.decision = undefined;
  updated.updatedAt = input.at;
  return updated;
}

export function rejectCorrection(review: ReviewCase, session: OperationalSession, input: RejectCorrectionInput): ReviewCase {
  const correction = review.corrections.find((item) => item.id === input.correctionId && item.status === 'open');
  if (!correction) throw new Error('OPEN_CORRECTION_NOT_FOUND');
  const updated = structuredClone(review);
  updated.corrections = updated.corrections.map((item) => item.id === correction.id ? {
    ...item,
    status: 'rejected',
    resolution: input.resolution,
    resolvedBy: session.userId,
    resolvedAt: input.at,
  } : item);
  const receipt = createOperationalEventReceipt(updated.eventReceipts, 'correction.rejected', correction.id, session.userId, input.at);
  updated.eventReceipts = [...updated.eventReceipts, receipt];
  updated.correctionRequest = undefined;
  updated.status = updated.credential?.status === 'issued' ? 'issued' : 'assigned';
  updated.updatedAt = input.at;
  return updated;
}
