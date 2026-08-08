import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { ACCESS_COOKIE } from '@/authority/cookies';
import { enrollTotpFactor } from '@/authority/supabase-auth';
import { Wave1Denied, correlationIdFromRequest } from '@/authority/wave1-contracts';
import { wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';
const schema = z.object({ friendlyName: z.string().trim().min(2).max(64).default('PROVENANCE VERIFIED Authenticator') }).strict();

export async function POST(request: NextRequest) {
  const correlationId = correlationIdFromRequest(request);
  try {
    const accessToken = request.cookies.get(ACCESS_COOKIE)?.value;
    if (!accessToken) throw new Wave1Denied('DENY_UNAUTHENTICATED', correlationId);
    const parsed = schema.safeParse(await request.json().catch(() => ({})));
    if (!parsed.success) throw new Wave1Denied('DENY_VALIDATION', correlationId, parsed.error.flatten().fieldErrors as Record<string, string[]>);
    const factor = await enrollTotpFactor(accessToken, parsed.data.friendlyName);
    if (!factor.id || !factor.totp?.secret) throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
    const qrCode = factor.totp.qr_code;
    if (qrCode && !qrCode.startsWith('data:image/')) throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
    return NextResponse.json({
      ok: true,
      data: { factorId: factor.id, qrCode, secret: factor.totp.secret, uri: factor.totp.uri },
      meta: { contractVersion: 'v1-wave1', factorType: 'totp', requiresVerification: true, correlationId },
    }, { status: 201, headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId } });
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
