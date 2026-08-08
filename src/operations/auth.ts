import { stableHash } from '@/domain/hash';
import type { OperationalSession } from './types';

const TOKEN_PREFIX = 'pv_test_v1';
const TEST_TOKEN_CONTEXT = 'PROVENANCE-VERIFIED:DETERMINISTIC:SESSION:BOUNDARY';

function signatureFor(session: OperationalSession): string {
  return stableHash([
    TEST_TOKEN_CONTEXT,
    session.id,
    session.tenantId,
    session.userId,
    session.role,
    session.expiresAt,
  ].join(':'));
}

export function createTestModeToken(session: OperationalSession): string {
  return `${TOKEN_PREFIX}.${session.id}.${signatureFor(session)}`;
}

export function authorizationHeaders(session: OperationalSession, contentType?: string): Record<string, string> {
  const environment = (process.env.NEXT_PUBLIC_PV_ENVIRONMENT ?? 'sandbox').toLowerCase();
  return {
    ...(contentType ? { 'content-type': contentType } : {}),
    ...(environment === 'sandbox' || environment === 'test' ? { authorization: `Bearer ${createTestModeToken(session)}` } : {}),
  };
}

export async function authorityFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const response = await fetch(input, init);
  const environment = (process.env.NEXT_PUBLIC_PV_ENVIRONMENT ?? 'sandbox').toLowerCase();
  if (response.status !== 401 || environment === 'sandbox' || environment === 'test') return response;
  const refreshed = await fetch('/api/v1/auth/refresh', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
  if (!refreshed.ok) return response;
  return fetch(input, init);
}

export function authenticateTestModeToken(
  authorization: string | null,
  sessions: OperationalSession[],
  now = new Date(),
): OperationalSession {
  if (process.env.PV_SERVICE_MODE === 'production') throw new Error('PRODUCTION_IDENTITY_ADAPTER_REQUIRED');
  if (!authorization?.startsWith('Bearer ')) throw new Error('SESSION_REQUIRED');
  const token = authorization.slice('Bearer '.length).trim();
  const [prefix, sessionId, signature, ...extra] = token.split('.');
  if (prefix !== TOKEN_PREFIX || !sessionId || !signature || extra.length) throw new Error('SESSION_TOKEN_INVALID');
  const session = sessions.find((item) => item.id === sessionId);
  if (!session) throw new Error('SESSION_NOT_FOUND');
  if (signature !== signatureFor(session)) throw new Error('SESSION_TOKEN_INVALID');
  if (Date.parse(session.expiresAt) <= now.getTime()) throw new Error('SESSION_EXPIRED');
  return session;
}
