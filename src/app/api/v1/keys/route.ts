import { getPublicAuthorityKeys } from '@/authority/publicKeys';
import { wave1ErrorResponse } from '@/operations/http';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const includeHistorical = new URL(request.url).searchParams.get('include') === 'historical';
    const data = await getPublicAuthorityKeys(includeHistorical);
    return Response.json(data, { headers: { 'cache-control': 'public, max-age=300, stale-while-revalidate=60' } });
  } catch (error) {
    return wave1ErrorResponse(error, request, '/api/v1/keys');
  }
}
