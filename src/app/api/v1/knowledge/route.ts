import { getPublicKnowledge } from '@/authority/publicKnowledge';
import { wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const body = await getPublicKnowledge(url.searchParams.get('locale') ?? 'en', url.searchParams.get('region') ?? 'global');
    return Response.json(body, { headers: { 'cache-control': 'public, max-age=300, stale-while-revalidate=60' } });
  } catch (error) {
    return wave1ErrorResponse(error, request, '/api/v1/knowledge');
  }
}
