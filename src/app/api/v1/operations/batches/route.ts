import { NextRequest } from 'next/server';
import { createBatchSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';
import { stableHash } from '@/domain/hash';
import type { IntakeBatch } from '@/operations/types';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    const repository = getOperationalRepository();
    return Response.json({ data: repository.listBatches(session), meta: { tenantId: session.tenantId, mode: 'test' } });
  } catch (error) { return operationError(error); }
}

export async function POST(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'batch.create');
    const input = createBatchSchema.parse(await request.json());
    if (!session.locationIds.includes(input.locationId)) throw new Error('LOCATION_SCOPE_VIOLATION');
    const id = `batch_${stableHash(`${session.tenantId}:${input.reference}`)}`;
    const batch: IntakeBatch = { id, tenantId: session.tenantId, locationId: input.locationId, name: input.name, reference: input.reference, status: 'draft', assetIds: [], lotIds: input.lotIds, validationErrors: [], createdAt: '2026-07-20T05:00:00Z', updatedAt: '2026-07-20T05:00:00Z', createdBy: session.userId, version: 1 };
    return Response.json({ data: getOperationalRepository().upsertBatch(session, batch), meta: { mode: 'test' } }, { status: 201 });
  } catch (error) { return operationError(error); }
}
