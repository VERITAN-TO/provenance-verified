import { NextRequest } from 'next/server';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission } from '@/operations/kernel';
export const dynamic = 'force-dynamic';
export async function GET(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'audit.read');
    return Response.json({ data: getOperationalRepository().listAudit(session), meta: { tenantId: session.tenantId, mode: 'test' } });
  } catch (error) { return operationError(error); }
}
