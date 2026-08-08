import { NextRequest } from 'next/server';
import { syncRequestSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { applySyncOperation, assertPermission, assertTenantScope } from '@/operations/kernel';
import { appendOperationalAudit } from '@/operations/audit';
import type { EvidenceObject, GemstoneAsset, IntakeBatch, SyncOperation } from '@/operations/types';

export const dynamic = 'force-dynamic';

function failed(operation: SyncOperation, error: string) {
  return { operation: { ...operation, status: 'failed' as const, attempts: operation.attempts + 1, error } };
}

export async function POST(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    const input = syncRequestSchema.parse(await request.json());
    const repository = getOperationalRepository();
    const results: Array<{ operation: SyncOperation; entity?: GemstoneAsset | IntakeBatch | EvidenceObject }> = [];
    for (const raw of input.operations) {
      const operation = raw as SyncOperation;
      assertTenantScope(session, operation.tenantId);
      if (operation.deviceId !== session.deviceId) { results.push(failed(operation, 'DEVICE_SCOPE_VIOLATION')); continue; }

      if (operation.entityType === 'asset') {
        assertPermission(session, operation.operation === 'create' ? 'asset.create' : 'asset.edit');
        const current = repository.getAsset(session, operation.entityId) ?? undefined;
        const result = applySyncOperation<GemstoneAsset>(operation, current);
        if (result.entity) repository.upsertAssets(session, [result.entity]);
        if (result.operation.status === 'applied') appendOperationalAudit(repository, session, request, `sync.asset.${operation.operation}`, 'asset', operation.entityId, { version: result.entity?.version, deviceId: operation.deviceId });
        results.push(result);
        continue;
      }

      if (operation.entityType === 'batch') {
        assertPermission(session, operation.operation === 'create' ? 'batch.create' : 'batch.edit');
        const current = repository.getBatch(session, operation.entityId) ?? undefined;
        const result = applySyncOperation<IntakeBatch>(operation, current);
        if (result.entity) repository.upsertBatch(session, result.entity);
        if (result.operation.status === 'applied') appendOperationalAudit(repository, session, request, `sync.batch.${operation.operation}`, 'batch', operation.entityId, { version: result.entity?.version, deviceId: operation.deviceId });
        results.push(result);
        continue;
      }

      if (operation.entityType === 'evidence') {
        assertPermission(session, 'evidence.manage');
        const evidence = (operation.payload.evidence ?? operation.payload) as unknown as EvidenceObject;
        if (!evidence || evidence.id !== operation.entityId || evidence.tenantId !== session.tenantId) { results.push(failed(operation, 'INVALID_EVIDENCE_PAYLOAD')); continue; }
        if (evidence.storageKey.startsWith('offline://')) { results.push(failed(operation, 'MEDIA_UPLOAD_REQUIRED')); continue; }
        repository.upsertEvidence(session, evidence);
        const applied = { operation: { ...operation, status: 'applied' as const, attempts: operation.attempts + 1, lastAttemptAt: '2026-07-20T06:31:00Z', error: undefined }, entity: evidence };
        appendOperationalAudit(repository, session, request, 'sync.evidence.create', 'evidence', evidence.id, { assetId: evidence.assetId, integrityHash: evidence.integrityHash, deviceId: operation.deviceId });
        results.push(applied);
        continue;
      }

      results.push(failed(operation, 'ENTITY_TYPE_NOT_IMPLEMENTED'));
    }
    const conflicts = results.filter((item) => item.operation.status === 'conflict').length;
    const failedCount = results.filter((item) => item.operation.status === 'failed').length;
    return Response.json({ data: results, meta: { mode: 'test', applied: results.filter((item) => item.operation.status === 'applied').length, conflicts, failed: failedCount } }, { status: conflicts ? 409 : failedCount ? 422 : 200 });
  } catch (error) { return operationError(error); }
}
