import { NextRequest } from 'next/server';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';

export const dynamic = 'force-dynamic';
export async function GET(request: NextRequest, { params }: { params: Promise<{ batchId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    const { batchId } = await params;
    const repository = getOperationalRepository();
    const batch = repository.getBatch(session, batchId);
    if (!batch) return Response.json({ error: { code: 'batch_not_found', message: 'Batch does not exist in the active tenant.' } }, { status: 404 });
    return Response.json({ data: { batch, assets: repository.listAssets(session, batchId) }, meta: { mode: 'test' } });
  } catch (error) { return operationError(error); }
}
