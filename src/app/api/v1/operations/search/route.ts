import { NextRequest } from 'next/server';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'operations.search');
    const repository = getOperationalRepository();
    const query = (request.nextUrl.searchParams.get('q') ?? '').trim().toLowerCase();
    const status = request.nextUrl.searchParams.get('status');
    const limit = Math.min(250, Math.max(1, Number(request.nextUrl.searchParams.get('limit') ?? 50)));
    const assets = repository.listAssets(session).filter((asset) => {
      const searchable = [asset.id, asset.serial, asset.material, asset.shape, asset.originClaim, asset.supplierReference, asset.laboratoryReportReference, asset.status].join(' ').toLowerCase();
      return (!query || searchable.includes(query)) && (!status || asset.status === status);
    }).slice(0, limit);
    const batches = repository.listBatches(session).filter((batch) => {
      const searchable = [batch.id, batch.name, batch.reference, batch.status].join(' ').toLowerCase();
      return !query || searchable.includes(query);
    }).slice(0, limit);
    const evidence = repository.listEvidence(session).filter((item) => {
      const searchable = [item.id, item.label, item.sourceOrganization, item.integrityHash, item.type, item.status].join(' ').toLowerCase();
      return !query || searchable.includes(query);
    }).slice(0, limit);
    const reviews = repository.listReviewCases(session).filter((item) => {
      const searchable = [item.id, item.assetId, item.batchId, item.status, item.credential?.id ?? '', item.credential?.publicId ?? ''].join(' ').toLowerCase();
      return !query || searchable.includes(query);
    }).slice(0, limit);
    return Response.json({ data: { assets, batches, evidence, reviews }, meta: { tenantId: session.tenantId, query, limit, mode: 'test', serverFiltered: true } });
  } catch (error) { return operationError(error); }
}
