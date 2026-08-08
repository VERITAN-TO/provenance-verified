import { NextRequest, NextResponse } from 'next/server';
import { ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, decodeJwtClaims, secureCookieOptions } from '@/authority/cookies';
import { correlationIdFromRequest } from '@/authority/wave1-contracts';
import { refreshSession } from '@/authority/supabase-auth';
import { mapPublicAuthorityError, recordServerDiagnostic } from '@/operations/public-error-mapper';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
    if (!refreshToken) throw new Error('REFRESH_SESSION_REQUIRED');
    const result = await refreshSession(refreshToken);
    const claims = decodeJwtClaims(result.access_token);
    const response = NextResponse.json({ data: { refreshed: true, assuranceLevel: claims.aal ?? 'aal1' } });
    response.cookies.set(ACCESS_COOKIE, result.access_token, secureCookieOptions(result.expires_in));
    response.cookies.set(REFRESH_COOKIE, result.refresh_token, secureCookieOptions(60 * 60 * 24 * 30));
    if (claims.session_id) response.cookies.set(SESSION_COOKIE, claims.session_id, secureCookieOptions(result.expires_in));
    return response;
  } catch (error) {
    const correlationId = correlationIdFromRequest(request);
    const mapped = mapPublicAuthorityError(error, { correlationId, endpoint: '/api/v1/auth/refresh' });
    recordServerDiagnostic(mapped.diagnostic);
    const response = NextResponse.json(mapped.public, {
      status: mapped.status,
      headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId },
    });
    for (const name of [ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE]) {
      response.cookies.set(name, '', { ...secureCookieOptions(0), maxAge: 0 });
    }
    return response;
  }
}
