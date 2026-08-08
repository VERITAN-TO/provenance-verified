import { NextRequest, NextResponse } from 'next/server';
import { ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, TENANT_COOKIE } from '@/authority/cookies';
import { correlationIdFromRequest } from '@/authority/wave1-contracts';
import { signOut } from '@/authority/supabase-auth';
import { mapPublicAuthorityError, recordServerDiagnostic } from '@/operations/public-error-mapper';

export const dynamic = 'force-dynamic';

function clearAuthorityCookies(response: NextResponse): NextResponse {
  for (const name of [ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, TENANT_COOKIE]) {
    response.cookies.set(name, '', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 0,
    });
  }
  return response;
}

export async function POST(request: NextRequest) {
  const correlationId = correlationIdFromRequest(request);
  const accessToken = request.cookies.get(ACCESS_COOKIE)?.value;
  try {
    if (accessToken) await signOut(accessToken);
    return clearAuthorityCookies(NextResponse.json(
      { data: { signedOut: true }, meta: { correlationId } },
      { headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId } },
    ));
  } catch (error) {
    const mapped = mapPublicAuthorityError(error, { correlationId, endpoint: '/api/v1/auth/sign-out' });
    recordServerDiagnostic(mapped.diagnostic);
    return clearAuthorityCookies(NextResponse.json(mapped.public, {
      status: mapped.status,
      headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId },
    }));
  }
}
