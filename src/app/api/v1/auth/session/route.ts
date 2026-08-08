import { NextRequest, NextResponse } from 'next/server';
import { TENANT_COOKIE, secureCookieOptions } from '@/authority/cookies';
import { readAuthorizedTenant } from '@/authority/supabase-data';
import { authorizeWave1Request, projectWave1AuthorityContext, wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const context = await authorizeWave1Request(request, {
      action: 'tenant_resource/read',
      resourceType: 'tenant',
      quotaOperation: 'auth/session/read',
      metadata: { route: '/api/v1/auth/session', method: 'GET' },
    });
    const tenant = await readAuthorizedTenant(context.accessToken, context.tenant.tenant_id);
    const data = await projectWave1AuthorityContext(context, tenant);

    const response = NextResponse.json({
      ok: true,
      data,
      meta: {
        contractVersion: 'v1-wave1',
        authorityVersion: data.authorization.authorityVersion,
        correlationId: data.correlationId,
        auditedDecisionId: data.authorization.decisionId,
        rlsProtected: true,
      },
    }, { headers: { 'cache-control': 'no-store', 'x-correlation-id': data.correlationId } });
    response.cookies.set(TENANT_COOKIE, data.tenant.tenantId, secureCookieOptions(60 * 60 * 12));
    return response;
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
