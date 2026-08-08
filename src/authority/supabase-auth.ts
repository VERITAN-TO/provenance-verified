import 'server-only';

import { getAuthorityRuntimeConfig } from './config';
import { decodeJwtClaims, type JwtClaims } from './cookies';

export interface SupabaseTokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  user: { id: string; email?: string; app_metadata?: Record<string, unknown> };
}

export interface VerifiedSupabaseSession {
  user: { id: string; email?: string; app_metadata?: Record<string, unknown> };
  claims: JwtClaims & { sub: string; exp: number };
}

export class SupabaseAuthBoundaryError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, status: number) {
    super(code);
    this.name = 'SupabaseAuthBoundaryError';
    this.code = code;
    this.status = status;
  }
}

function authHeaders(accessToken?: string): HeadersInit {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabasePublishableKey) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  return {
    apikey: config.supabasePublishableKey,
    'content-type': 'application/json',
    ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
  };
}

async function parseAuthResponse<T>(response: Response): Promise<T> {
  const body = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    const providerCode = typeof body.code === 'string' ? body.code.toUpperCase() : '';
    if (response.status === 401 || response.status === 403 || providerCode.includes('INVALID')) {
      throw new SupabaseAuthBoundaryError('AUTHENTICATION_INVALID', 401);
    }
    if (response.status === 429) throw new SupabaseAuthBoundaryError('AUTHENTICATION_RATE_LIMITED', 429);
    throw new SupabaseAuthBoundaryError('AUTHENTICATION_PROVIDER_UNAVAILABLE', response.status >= 500 ? 503 : 401);
  }
  return body as T;
}

export async function signInWithPassword(email: string, password: string): Promise<SupabaseTokenResponse> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ email, password }),
    cache: 'no-store',
  });
  return parseAuthResponse<SupabaseTokenResponse>(response);
}

export async function refreshSession(refreshToken: string): Promise<SupabaseTokenResponse> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ refresh_token: refreshToken }),
    cache: 'no-store',
  });
  return parseAuthResponse<SupabaseTokenResponse>(response);
}

export async function getAuthenticatedUser(accessToken: string) {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/user`, {
    headers: authHeaders(accessToken),
    cache: 'no-store',
  });
  return parseAuthResponse<{ id: string; email?: string; app_metadata?: Record<string, unknown> }>(response);
}

export async function verifyAuthenticatedSession(accessToken: string): Promise<VerifiedSupabaseSession> {
  const user = await getAuthenticatedUser(accessToken);
  const claims = verifiedClaims(accessToken);
  if (claims.sub !== user.id) throw new SupabaseAuthBoundaryError('AUTHENTICATION_SUBJECT_MISMATCH', 401);
  return { user, claims };
}

export async function signOut(accessToken: string): Promise<void> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/logout`, {
    method: 'POST',
    headers: authHeaders(accessToken),
    cache: 'no-store',
  });
  if (!response.ok && response.status !== 401) await parseAuthResponse(response);
}

export async function listMfaFactors(accessToken: string): Promise<Record<string, unknown>> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/factors`, {
    headers: authHeaders(accessToken),
    cache: 'no-store',
  });
  return parseAuthResponse<Record<string, unknown>>(response);
}

export interface TotpEnrollment {
  id: string;
  type: 'totp';
  status: string;
  totp?: { qr_code?: string; secret?: string; uri?: string };
}

export async function enrollTotpFactor(accessToken: string, friendlyName: string): Promise<TotpEnrollment> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/factors`, {
    method: 'POST',
    headers: authHeaders(accessToken),
    body: JSON.stringify({ factor_type: 'totp', friendly_name: friendlyName }),
    cache: 'no-store',
  });
  return parseAuthResponse<TotpEnrollment>(response);
}

export async function challengeMfa(accessToken: string, factorId: string): Promise<{ id: string; expires_at?: number }> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/factors/${encodeURIComponent(factorId)}/challenge`, {
    method: 'POST',
    headers: authHeaders(accessToken),
    body: JSON.stringify({}),
    cache: 'no-store',
  });
  return parseAuthResponse(response);
}

export async function verifyMfa(accessToken: string, factorId: string, challengeId: string, code: string): Promise<SupabaseTokenResponse> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthBoundaryError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/auth/v1/factors/${encodeURIComponent(factorId)}/verify`, {
    method: 'POST',
    headers: authHeaders(accessToken),
    body: JSON.stringify({ challenge_id: challengeId, code }),
    cache: 'no-store',
  });
  return parseAuthResponse(response);
}

export function verifiedClaims(accessToken: string): JwtClaims & { sub: string; exp: number } {
  const claims = decodeJwtClaims(accessToken);
  if (!claims.sub || !claims.exp) throw new SupabaseAuthBoundaryError('AUTHENTICATION_REQUIRED_CLAIMS_MISSING', 401);
  if (claims.exp * 1000 <= Date.now()) throw new SupabaseAuthBoundaryError('AUTHENTICATION_SESSION_EXPIRED', 401);
  return claims as JwtClaims & { sub: string; exp: number };
}
