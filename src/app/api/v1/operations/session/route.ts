import { NextRequest } from 'next/server';
import { getAuthorityRuntimeConfig } from '@/authority/config';
import { readAuthorizedTenant } from '@/authority/supabase-data';
import { authorizeWave1Request, projectWave1AuthorityContext, wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const config = getAuthorityRuntimeConfig();
    const context = await authorizeWave1Request(request, {
      action: 'tenant_resource/read',
      resourceType: 'tenant',
      quotaOperation: 'operations/session/read',
      metadata: { route: '/api/v1/operations/session', method: 'GET' },
    });
    const tenant = await readAuthorizedTenant(context.accessToken, context.tenant.tenant_id);
    const data = await projectWave1AuthorityContext(context, tenant);
    return Response.json({
      ok: true,
      data,
      meta: {
        mode: 'wave1-slice1',
        contractVersion: 'v1-wave1',
        authoritative: config.authoritative,
        authentication: 'verified-supabase-session',
        tenantDerivation: context.tenant.derivation_source,
        rlsProtected: true,
        auditedDecisionId: data.authorization.decisionId,
        authorityVersion: data.authorization.authorityVersion,
        correlationId: data.correlationId,
      },
    }, {
      headers: { 'cache-control': 'no-store', 'x-correlation-id': data.correlationId },
    });
  } catch (error) {
    return wave1ErrorResponse(error, request);
  }
}
