import { NextRequest, NextResponse } from 'next/server';
import { resolveEvents } from '@/api/service';
export async function GET(request: NextRequest) {
  const publicId = request.nextUrl.searchParams.get('publicId') ?? 'PV-TEST-T4D004';
  return NextResponse.json({ data: await resolveEvents(publicId), meta: { mode: 'test', authoritative: false } }, { headers: { 'X-Provenance-Mode': 'test' } });
}
