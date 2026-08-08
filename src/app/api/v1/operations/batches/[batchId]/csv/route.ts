import { NextRequest } from 'next/server';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, createAssetId } from '@/operations/kernel';
import { appendOperationalAudit } from '@/operations/audit';
import { parseGemstoneCsv } from '@/operations/csv';
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
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > 5 * 1024 * 1024) return Response.json({ error: { code: 'csv_too_large', message: 'CSV import exceeds 5 MB.' } }, { status: 413 });
    const parsed = parseGemstoneCsv(text);
    if (parsed.errors.length) return Response.json({ error: { code: 'csv_validation_failed', message: 'CSV contains invalid rows.', rows: parsed.errors }, meta: { accepted: 0, rejected: parsed.errors.length } }, { status: 422 });
    const existingSerials = new Set(repository.listAssets(session).map((item) => item.serial.toUpperCase()));
    const duplicates = parsed.assets.filter((item) => existingSerials.has(item.serial.toUpperCase())).map((item) => item.serial);
    if (duplicates.length) return Response.json({ error: { code: 'duplicate_serial', message: 'CSV contains serials already registered in the tenant.', serials: duplicates } }, { status: 409 });
    const assets: GemstoneAsset[] = parsed.assets.map((item) => ({ id: createAssetId(session.tenantId, item.serial), tenantId: session.tenantId, locationId: batch.locationId, batchId: batch.id, status: 'draft', ...item, evidenceIds: [], version: 1, createdAt: '2026-07-20T06:40:00Z', updatedAt: '2026-07-20T06:40:00Z', createdBy: session.userId }));
    repository.upsertAssets(session, assets);
    repository.upsertBatch(session, { ...batch, assetIds: [...new Set([...batch.assetIds, ...assets.map((item) => item.id)])], version: batch.version + 1, updatedAt: '2026-07-20T06:40:00Z' });
    appendOperationalAudit(repository, session, request, 'assets.csv-imported', 'batch', batch.id, { count: assets.length, explicitUnitRecords: true });
    return Response.json({ data: assets, meta: { count: assets.length, noArtificialExpansion: true, mode: 'test' } }, { status: 201 });
  } catch (error) { return operationError(error); }
}
