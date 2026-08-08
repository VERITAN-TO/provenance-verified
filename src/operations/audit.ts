import type { NextRequest } from 'next/server';
import { stableHash } from '@/domain/hash';
import type { OperationalRepository } from './repository';
import type { OperationalSession } from './types';

export function appendOperationalAudit(
  repository: OperationalRepository,
  session: OperationalSession,
  request: NextRequest,
  action: string,
  targetType: string,
  targetId: string,
  resultingState: Record<string, unknown>,
  previousState?: Record<string, unknown>,
  reason?: string,
) {
  const requestId = request.headers.get('x-request-id') ?? `req_${stableHash(`${session.id}:${action}:${targetId}:${repository.listAudit(session).length}`)}`;
  repository.appendAudit(session, {
    id: `audit_${stableHash(`${requestId}:${action}:${targetId}`)}`,
    tenantId: session.tenantId,
    actorId: session.userId,
    actorRole: session.role,
    action,
    targetType,
    targetId,
    previousState,
    resultingState,
    reason,
    requestId,
    at: '2026-07-20T06:30:00Z',
  });
}
