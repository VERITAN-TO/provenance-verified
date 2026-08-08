import { NextResponse } from 'next/server';
import { resolveRegistry } from '@/api/service';
export async function GET(_: Request, context: { params: Promise<{ publicId: string }> }) {
  const { publicId } = await context.params;
  const record = await resolveRegistry(publicId);
  if (!record) return NextResponse.json({ error: { code: 'record_not_found' }, meta: { mode: 'test' } }, { status: 404 });
  return NextResponse.json({ data: record, meta: { mode: 'test', authoritative: false, productionCredential: false } }, { headers: { 'Cache-Control': 'public, max-age=60', 'X-Provenance-Mode': 'test' } });
}
