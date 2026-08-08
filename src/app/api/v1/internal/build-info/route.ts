import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const token = request.headers.get('x-pv-internal-token');
  if (token !== process.env.PV_INTERNAL_BUILD_TOKEN) {
    return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  }
  return NextResponse.json({
    buildSha: process.env.PV_RELEASE_COMMIT ?? 'unset',
    environment: process.env.PV_ENVIRONMENT ?? 'unknown',
    injectedAt: 'build-time',
  });
}
