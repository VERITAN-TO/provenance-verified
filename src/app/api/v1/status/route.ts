import { NextResponse } from 'next/server';
import { getPublicEnvironment } from '@/authority/public-mode';

export async function GET() {
  const environment = getPublicEnvironment();
  if (environment !== 'sandbox') {
    return NextResponse.json({
      error: { code: 'authority_proxy_required', message: 'Pilot and Production status must resolve from the separate authority plane.' },
      meta: { environment, failClosed: true },
    }, { status: 503 });
  }
  return NextResponse.json({
    data: {
      environment: 'sandbox',
      operational: true,
      productionActivated: false,
      authoritativeIssuanceEnabled: false,
      certificationMarksEnabled: false,
      registryReady: true,
      revocationReady: true,
      dependencies: {
        deterministicKernel: { ready: true, status: 200 },
        fixtureRegistry: { ready: true, status: 200 },
        testWebhookRuntime: { ready: true, status: 200 },
      },
      checkedAt: new Date().toISOString(),
    },
    meta: { environment: 'sandbox', authoritative: false, deterministic: true, isolated: true },
  });
}
