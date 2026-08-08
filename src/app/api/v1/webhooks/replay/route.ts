import { NextRequest, NextResponse } from 'next/server';
import { webhookReplaySchema } from '@/domain/schemas';
export async function POST(request: NextRequest) {
  const parsed = webhookReplaySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: { code: 'invalid_request', details: parsed.error.flatten() } }, { status: 400 });
  return NextResponse.json({ data: { replayId: `replay_${parsed.data.attemptId}`, originalAttemptId: parsed.data.attemptId, status: 'delivered', reason: parsed.data.reason }, meta: { mode: 'test', authoritative: false } }, { status: 202 });
}
