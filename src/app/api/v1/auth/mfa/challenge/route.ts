import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { ACCESS_COOKIE } from '@/authority/cookies';
import { challengeMfa, listMfaFactors } from '@/authority/supabase-auth';
import { Wave1Denied, correlationIdFromRequest } from '@/authority/wave1-contracts';
import { wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';
const schema = z.object({ factorId: z.string().uuid().optional() }).strict();

export async function POST(request: NextRequest) {
  const correlationId = correlationIdFromRequest(request);
  try {
    const accessToken = request.cookies.get(ACCESS_COOKIE)?.value;
    if (!accessToken) throw new Wave1Denied('DENY_UNAUTHENTICATED', correlationId);
    const parsed = schema.safeParse(await request.json().catch(() => ({})));
    if (!parsed.success) throw new Wave1Denied('DENY_VALIDATION', correlationId, parsed.error.flatten().fieldErrors as Record<string, string[]>);
    let factorId = parsed.data.factorId;
    if (!factorId) {
      const factors = await listMfaFactors(accessToken) as { totp?: Array<{ id: string; status: string }>; phone?: Array<{ id: string; status: string }> };
      factorId = [...(factors.totp ?? []), ...(factors.phone ?? [])].find((item) => item.status === 'verified')?.id;
    }
    if (!factorId) throw new Wave1Denied('DENY_MFA_REQUIRED', correlationId);
    const challenge = await challengeMfa(accessToken, factorId);
    if (!challenge.id) throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
    return NextResponse.json({
      ok: true,
      data: { factorId, challengeId: challenge.id, expiresAt: challenge.expires_at },
      meta: { contractVersion: 'v1-wave1', correlationId },
    }, { headers: { 'cache-control': 'no-store', 'x-correlation-id': correlationId } });
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
