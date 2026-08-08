import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, decodeJwtClaims, secureCookieOptions } from '@/authority/cookies';
import { verifyMfa } from '@/authority/supabase-auth';
import { Wave1Denied, correlationIdFromRequest } from '@/authority/wave1-contracts';
import { wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';
const schema = z.object({ factorId: z.string().uuid(), challengeId: z.string().uuid(), code: z.string().regex(/^\d{6,8}$/) }).strict();

export async function POST(request: NextRequest) {
  const correlationId = correlationIdFromRequest(request);
  try {
    const accessToken = request.cookies.get(ACCESS_COOKIE)?.value;
    if (!accessToken) throw new Wave1Denied('DENY_UNAUTHENTICATED', correlationId);
    const parsed = schema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) throw new Wave1Denied('DENY_VALIDATION', correlationId, parsed.error.flatten().fieldErrors as Record<string, string[]>);
    const result = await verifyMfa(accessToken, parsed.data.factorId, parsed.data.challengeId, parsed.data.code);
    const claims = decodeJwtClaims(result.access_token);
    if (claims.aal !== 'aal2') throw new Wave1Denied('DENY_MFA_REQUIRED', correlationId);
    const response = NextResponse.json({
      ok: true,
      data: { verified: true, assuranceLevel: claims.aal },
      meta: { contractVersion: 'v1-wave1', correlationId },
    }, { headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId } });
    response.cookies.set(ACCESS_COOKIE, result.access_token, secureCookieOptions(result.expires_in));
    response.cookies.set(REFRESH_COOKIE, result.refresh_token, secureCookieOptions(60 * 60 * 24 * 30));
    if (claims.session_id) response.cookies.set(SESSION_COOKIE, claims.session_id, secureCookieOptions(result.expires_in));
    return response;
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
