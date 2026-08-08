import { NextRequest } from 'next/server';
import { submitBatchSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, createOperationalEventReceipt, isBatchSubmittable, signAttestation, validateBatch } from '@/operations/kernel';
import { appendOperationalAudit } from '@/operations/audit';
import { stableHash } from '@/domain/hash';
import type { ReviewCase } from '@/operations/types';

export const dynamic = 'force-dynamic';

function resetReviewForAttestation(existing: ReviewCase | undefined, assetId: string, tenantId: string, batchId: string, attestationId: string, signerId: string, signedAt: string): ReviewCase {
  const registryId = existing?.registryId ?? `PV-OPS-${stableHash(assetId).slice(0, 8).toUpperCase()}`;
  const eventReceipts = [createOperationalEventReceipt([], 'attestation.recorded', attestationId, signerId, signedAt)];
  return {
    id: existing?.id ?? `review_${assetId}`,
    tenantId,
    batchId,
    assetId,
    attestationId,
    registryId,
    eventReceipts,
    status: 'unassigned',
    assignedReviewerIds: [],
    approvals: [],
    conflictClearance: 'pending',
    custosVerdict: { status: 'pending', reasonCodes: [] },
    signingKeyStatus: 'pending',
    registryStatus: 'pending',
    revocationCapability: false,
    markAuthorization: 'pending',
    correctionRequest: undefined,
    corrections: existing?.corrections ?? [],
    credentialLifecycle: 'active',
    successorId: undefined,
    lifecycleEvents: existing?.lifecycleEvents ?? [],
    decision: undefined,
    credential: undefined,
    registryPublication: undefined,
    openedAt: existing?.openedAt ?? signedAt,
    updatedAt: signedAt,
    serviceLevelDueAt: '2026-07-22T05:00:00Z',
  };
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ batchId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'batch.submit');
    assertPermission(session, 'attestation.sign');
    const { batchId } = await params;
    const repository = getOperationalRepository();
    const batch = repository.getBatch(session, batchId);
    if (!batch) return Response.json({ error: { code: 'batch_not_found', message: 'Batch does not exist in the active tenant.' } }, { status: 404 });
    const input = submitBatchSchema.parse(await request.json());
    const assets = repository.listAssets(session, batchId);
    const evidence = assets.flatMap((asset) => repository.listEvidence(session, asset.id));
    const issues = validateBatch(batch, assets, evidence);
    if (!isBatchSubmittable(issues)) return Response.json({ error: { code: 'batch_validation_failed', issues }, meta: { mode: 'test' } }, { status: 409 });
    const prior = repository.listAttestations(session, batch.id).sort((a, b) => b.version - a.version)[0];
    const attestation = signAttestation(session, batch, assets, input.claimSummary, input.evidenceSummary, input.limitations, prior);
    repository.appendAttestation(session, attestation);
    const existingReviews = repository.listReviewCases(session);
    for (const asset of assets) {
      const existing = existingReviews.find((item) => item.assetId === asset.id);
      repository.upsertReviewCase(session, resetReviewForAttestation(existing, asset.id, asset.tenantId, batch.id, attestation.id, session.userId, attestation.signedAt));
    }
    repository.upsertAssets(session, assets.map((asset) => ({ ...asset, status: 'submitted' as const, version: asset.version + 1, updatedAt: attestation.signedAt })));
    const updated = repository.upsertBatch(session, { ...batch, status: 'submitted', validationErrors: issues, submittedAt: attestation.signedAt, attestationId: attestation.id, version: batch.version + 1, updatedAt: attestation.signedAt });
    appendOperationalAudit(repository, session, request, 'batch.submitted', 'batch', batch.id, { attestationId: attestation.id, assetCount: assets.length, status: updated.status, reviewAuthorityReset: true }, { status: batch.status, version: batch.version });
    return Response.json({ data: { batch: updated, attestation, reviewCaseCount: assets.length }, meta: { mode: 'test', immutableAttestation: true, priorAuthorityInvalidated: true } });
  } catch (error) { return operationError(error); }
}
