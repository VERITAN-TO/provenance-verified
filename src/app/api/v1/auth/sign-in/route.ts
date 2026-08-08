import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAuthorityRuntimeConfig } from '@/authority/config';
import { ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, TENANT_COOKIE, secureCookieOptions } from '@/authority/cookies';
import { consumePreAuthenticationQuota } from '@/authority/supabase-data';
import { listMfaFactors, signInWithPassword } from '@/authority/supabase-auth';
import { Wave1Denied, correlationIdFromRequest, requestFingerprint } from '@/authority/wave1-contracts';
import { authenticateWave1Request, authorizeWave1Authentication, wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';

const schema = z.object({
  email: z.string().email().max(320),
  password: z.string().min(8).max(1024),
  tenantId: z.string().min(1).max(128).optional(),
}).strict();

export async function POST(request: NextRequest) {
  const correlationId = correlationIdFromRequest(request);
  try {
    const config = getAuthorityRuntimeConfig();
    if (config.environment === 'sandbox') throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);

    const parsed = schema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) {
      throw new Wave1Denied('DENY_VALIDATION', correlationId, parsed.error.flatten().fieldErrors as Record<string, string[]>);
    }

    const sourceAddress = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unavailable';
    const preAuthPrincipal = requestFingerprint({ email: parsed.data.email.trim().toLowerCase(), sourceAddress });
    await consumePreAuthenticationQuota(preAuthPrincipal);

    const token = await signInWithPassword(parsed.data.email, parsed.data.password);
    const authentication = await authenticateWave1Request(request, {
      accessToken: token.access_token,
      requestedTenantId: parsed.data.tenantId,
      enforceAal2: false,
    });
    const mfaRequired = config.requireAal2 && authentication.actor.authentication_strength !== 'aal2';
    let mfaEnrollmentRequired = false;
    if (mfaRequired) {
      const factors = await listMfaFactors(token.access_token) as { totp?: Array<{ status: string }>; phone?: Array<{ status: string }> };
      mfaEnrollmentRequired = ![...(factors.totp ?? []), ...(factors.phone ?? [])].some((factor) => factor.status === 'verified');
    }
    const context = mfaRequired
      ? authentication
      : await authorizeWave1Authentication(authentication, {
          action: 'tenant_resource/read',
          resourceType: 'tenant',
          quotaOperation: 'auth/sign-in/session',
          metadata: { authentication: 'password', requestedTenant: Boolean(parsed.data.tenantId) },
        });

    const response = NextResponse.json({
      ok: true,
      data: {
        actor: {
          actorId: context.actor.actor_id,
          actorType: context.actor.actor_type,
        },
        tenant: {
          tenantId: context.tenant.tenant_id,
          membershipId: context.tenant.membership_id,
          role: context.tenant.role,
        },
        assuranceLevel: context.actor.authentication_strength,
        mfaRequired,
        mfaEnrollmentRequired,
      },
      meta: {
        contractVersion: 'v1-wave1',
        correlationId: context.correlationId,
        authoritative: config.authoritative,
        browserAuthority: false,
      },
    }, {
      status: mfaRequired ? 202 : 200,
      headers: { 'cache-control': 'no-store', 'x-correlation-id': context.correlationId },
    });
    response.cookies.set(ACCESS_COOKIE, token.access_token, secureCookieOptions(token.expires_in));
    response.cookies.set(REFRESH_COOKIE, token.refresh_token, secureCookieOptions(60 * 60 * 24 * 30));
    response.cookies.set(SESSION_COOKIE, context.actor.session_id_or_workload_id, secureCookieOptions(token.expires_in));
    response.cookies.set(TENANT_COOKIE, context.tenant.tenant_id, secureCookieOptions(60 * 60 * 12));
    return response;
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
