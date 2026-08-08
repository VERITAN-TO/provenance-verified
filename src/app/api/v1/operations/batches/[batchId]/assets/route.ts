import { NextRequest } from 'next/server';
import { bulkAssetImportSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, createAssetId } from '@/operations/kernel';
import type { GemstoneAsset } from '@/operations/types';

export const dynamic = 'force-dynamic';
export async function POST(request: NextRequest, { params }: { params: Promise<{ batchId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'asset.create');
    const { batchId } = await params;
    const repository = getOperationalRepository();
    const batch = repository.getBatch(session, batchId);
    if (!batch) return Response.json({ error: { code: 'batch_not_found', message: 'Batch does not exist in the active tenant.' } }, { status: 404 });
    const input = bulkAssetImportSchema.parse(await request.json());
    const seen = new Set<string>();
    const assets: GemstoneAsset[] = input.assets.map((item) => {
      const normalized = item.serial.trim().toUpperCase();
      if (seen.has(normalized)) throw new Error(`DUPLICATE_SERIAL:${normalized}`);
      seen.add(normalized);
      return { id: createAssetId(session.tenantId, normalized), tenantId: session.tenantId, locationId: batch.locationId, batchId: batch.id, status: 'draft', ...item, serial: normalized, evidenceIds: [], version: 1, createdAt: '2026-07-20T05:01:00Z', updatedAt: '2026-07-20T05:01:00Z', createdBy: session.userId };
    });
    const persisted = repository.upsertAssets(session, assets);
    repository.upsertBatch(session, { ...batch, assetIds: [...new Set([...batch.assetIds, ...persisted.map((item) => item.id)])], updatedAt: '2026-07-20T05:01:00Z', version: batch.version + 1 });
    return Response.json({ data: persisted, meta: { count: persisted.length, mode: 'test', noArtificialExpansion: true } }, { status: 201 });
  } catch (error) { return operationError(error); }
}
