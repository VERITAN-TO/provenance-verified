import { NextRequest, NextResponse } from 'next/server';
import { verifyRequestSchema } from '@/domain/schemas';
import { verifyPublicId } from '@/api/service';

export async function POST(request: NextRequest) {
  const parsed = verifyRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: { code: 'invalid_request', details: parsed.error.flatten() }, meta: { mode: 'test', authoritative: false } }, { status: 400 });
  const result = await verifyPublicId(parsed.data.publicId, parsed.data.fixtureKey);
  return NextResponse.json(result.body, { status: result.status, headers: { 'Cache-Control': 'no-store', 'X-Provenance-Mode': 'test' } });
}
