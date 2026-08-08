import { NextRequest } from 'next/server';
import { stableHash } from '@/domain/hash';
import { createLotSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';
import { appendOperationalAudit } from '@/operations/audit';
import type { InventoryLot } from '@/operations/types';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'operations.search');
    return Response.json({ data: getOperationalRepository().listLots(session), meta: { aggregateInventoryOnly: true, mode: 'test' } });
  } catch (error) { return operationError(error); }
}

export async function POST(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'inventory.manage');
    const input = createLotSchema.parse(await request.json());
    if (!session.locationIds.includes(input.locationId)) return Response.json({ error: { code: 'location_forbidden', message: 'The active session cannot receive inventory into this location.' } }, { status: 403 });
    const now = new Date().toISOString();
    const lot: InventoryLot = {
      id: `lot_${stableHash(`${session.tenantId}:${input.supplierReference}:${now}`)}`,
      tenantId: session.tenantId,
      locationId: input.locationId,
      supplierReference: input.supplierReference,
      description: input.description,
      declaredQuantity: input.declaredQuantity,
      identifiedUnitCount: 0,
      status: 'received',
      receivedAt: now,
      notes: input.notes,
    };
    getOperationalRepository().upsertLot(session, lot);
    appendOperationalAudit(getOperationalRepository(), session, request, 'lot.received', 'lot', lot.id, { declaredQuantity: lot.declaredQuantity, identifiedUnitCount: 0, noArtificialExpansion: true });
    return Response.json({ data: lot, meta: { noArtificialExpansion: true, mode: 'test' } }, { status: 201 });
  } catch (error) { return operationError(error); }
}
