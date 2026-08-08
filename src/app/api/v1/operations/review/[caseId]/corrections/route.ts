import { NextRequest } from 'next/server';
import { correctionActionSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, credentialForOperationalAsset } from '@/operations/kernel';
import { rejectCorrection, requestCorrection, resolveCorrection } from '@/operations/corrections';
import { appendOperationalAudit } from '@/operations/audit';

export const dynamic = 'force-dynamic';

function refreshCredential(caseId: string, session: Awaited<ReturnType<typeof sessionFromRequest>>) {
  const repository = getOperationalRepository();
  const review = repository.getReviewCase(session, caseId);
  if (!review) throw new Error('REVIEW_NOT_FOUND');
  const asset = repository.getAsset(session, review.assetId);
  if (!asset) throw new Error('ASSET_NOT_FOUND');
  const evidence = repository.listEvidence(session, asset.id);
  const attestation = repository.listAttestations(session, review.batchId).find((item) => item.id === review.attestationId);
  review.credential = credentialForOperationalAsset(asset, evidence, review, attestation);
  return repository.upsertReviewCase(session, review);
}

export async function GET(request: NextRequest, { params }: { params: Promise<{ caseId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    const { caseId } = await params;
    const review = getOperationalRepository().getReviewCase(session, caseId);
    if (!review) return Response.json({ error: { code: 'review_not_found' } }, { status: 404 });
    return Response.json({ data: review.corrections, meta: { mode: 'test', versioned: true, immutableAttestations: true } });
  } catch (error) { return operationError(error); }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ caseId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    const { caseId } = await params;
    const repository = getOperationalRepository();
    const before = repository.getReviewCase(session, caseId);
    if (!before) return Response.json({ error: { code: 'review_not_found', message: 'Review case does not exist in the active tenant.' } }, { status: 404 });
    const input = correctionActionSchema.parse(await request.json());
    const at = new Date().toISOString();
    let updated;
    if (input.action === 'request') {
      assertPermission(session, 'correction.request');
      updated = requestCorrection(before, session, { reason: input.reason, fields: input.fields, at });
      repository.upsertReviewCase(session, updated);
      updated = refreshCredential(caseId, session);
    } else if (input.action === 'resolve') {
      assertPermission(session, 'correction.resolve');
      updated = resolveCorrection(repository, before, session, { ...input, at });
      repository.upsertReviewCase(session, updated);
    } else {
      assertPermission(session, 'correction.resolve');
      updated = rejectCorrection(before, session, { ...input, at });
      repository.upsertReviewCase(session, updated);
      updated = refreshCredential(caseId, session);
    }
    appendOperationalAudit(repository, session, request, `correction.${input.action}`, 'review-case', caseId, {
      status: updated.status,
      correctionVersion: updated.corrections.at(-1)?.version,
      attestationId: updated.attestationId,
    }, { status: before.status, attestationId: before.attestationId }, 'reason' in input ? input.reason : input.resolution);
    return Response.json({ data: updated, meta: { mode: 'test', authorityResetOnResolution: input.action === 'resolve' } });
  } catch (error) { return operationError(error); }
}
