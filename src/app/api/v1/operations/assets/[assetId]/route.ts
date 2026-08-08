import { NextRequest } from 'next/server';
import { updateAssetSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';

export const dynamic = 'force-dynamic';
export async function PATCH(request: NextRequest, { params }: { params: Promise<{ assetId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'asset.edit');
    const { assetId } = await params;
    const repository = getOperationalRepository();
    const asset = repository.getAsset(session, assetId);
    if (!asset) return Response.json({ error: { code: 'asset_not_found', message: 'Asset does not exist in the active tenant.' } }, { status: 404 });
    const patch = updateAssetSchema.parse(await request.json());
    const updated = { ...asset, ...patch, measurements: patch.measurements ? { ...asset.measurements, ...patch.measurements } : asset.measurements, version: asset.version + 1, updatedAt: '2026-07-20T05:20:00Z' };
    repository.upsertAssets(session, [updated]);
    return Response.json({ data: updated, meta: { mode: 'test', optimisticVersion: updated.version } });
  } catch (error) { return operationError(error); }
}
