import { NextRequest } from 'next/server';
import { evidenceInputSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';
import { stableHash } from '@/domain/hash';
import type { EvidenceObject } from '@/operations/types';

export const dynamic = 'force-dynamic';
export async function POST(request: NextRequest, { params }: { params: Promise<{ assetId: string }> }) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'evidence.manage');
    const { assetId } = await params;
    const repository = getOperationalRepository();
    const asset = repository.getAsset(session, assetId);
    if (!asset) return Response.json({ error: { code: 'asset_not_found', message: 'Asset does not exist in the active tenant.' } }, { status: 404 });
    const input = evidenceInputSchema.parse({ ...(await request.json()), assetId });
    const id = `ev_${stableHash(`${session.tenantId}:${assetId}:${input.integrityHash}`)}`;
    const evidence: EvidenceObject = { id, tenantId: session.tenantId, assetId, type: input.type, label: input.label, sourceOrganization: input.sourceOrganization, sourceType: input.sourceType, acquisitionMethod: input.acquisitionMethod, issueDate: '2026-07-20T05:21:00Z', claimIds: input.claimIds, independent: input.independent, qualified: input.qualified, integrityHash: input.integrityHash, storageKey: input.storageKey, visibility: input.visibility, status: 'active', createdAt: '2026-07-20T05:21:00Z', createdBy: session.userId };
    return Response.json({ data: repository.upsertEvidence(session, evidence), meta: { mode: 'test', phoneImageIsLaboratoryAuthentication: false } }, { status: 201 });
  } catch (error) { return operationError(error); }
}
