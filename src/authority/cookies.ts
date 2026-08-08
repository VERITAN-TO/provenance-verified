export const ACCESS_COOKIE = 'pv_access_token';
export const REFRESH_COOKIE = 'pv_refresh_token';
export const TENANT_COOKIE = 'pv_tenant_id';
export const SESSION_COOKIE = 'pv_session_id';

export interface JwtClaims {
  sub?: string;
  aal?: 'aal1' | 'aal2';
  session_id?: string;
  exp?: number;
  role?: string;
  [key: string]: unknown;
}

export function decodeJwtClaims(token: string): JwtClaims {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('JWT_MALFORMED');
  const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = payload.padEnd(Math.ceil(payload.length / 4) * 4, '=');
  try {
    return JSON.parse(Buffer.from(padded, 'base64').toString('utf8')) as JwtClaims;
  } catch {
    throw new Error('JWT_PAYLOAD_INVALID');
  }
}

export function secureCookieOptions(maxAge: number) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production' || ['pilot','production'].includes((process.env.PV_ENVIRONMENT ?? process.env.PV_SERVICE_MODE ?? '').toLowerCase()),
    sameSite: 'lax' as const,
    path: '/',
    maxAge,
  };
}
