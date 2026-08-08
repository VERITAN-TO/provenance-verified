import { NextRequest } from 'next/server';
import { lifecycleTransitionSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getProvenanceService } from '@/services';
import { getOperationalRepository } from '@/operations/runtime';
import { appendOperationalAudit } from '@/operations/audit';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest, { params }: { params: Promise<{ caseId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    const { caseId } = await params;
    const input = lifecycleTransitionSchema.parse(await request.json());
    const repository = getOperationalRepository();
    const before = repository.getReviewCase(session, caseId);
    if (!before) return Response.json({ error: { code: 'review_not_found', message: 'Review case does not exist in the active tenant.' } }, { status: 404 });
    const updated = await getProvenanceService().transitionLifecycle({ session, reviewCaseId: caseId, ...input });
    appendOperationalAudit(repository, session, request, `credential.${input.action}`, 'review-case', caseId, {
      lifecycle: updated.credentialLifecycle,
      markAuthorization: updated.markAuthorization,
      successorId: updated.successorId,
    }, { lifecycle: before.credentialLifecycle, markAuthorization: before.markAuthorization }, input.reason);
    return Response.json({ data: updated, meta: { mode: 'test', authoritative: false, lifecycleReceipt: updated.lifecycleEvents.at(-1)?.receiptId } });
  } catch (error) { return operationError(error); }
}
