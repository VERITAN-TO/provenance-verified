import { getPublicAuthorityKeys } from '@/authority/publicKeys';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const data = await getPublicAuthorityKeys(true);
    return Response.json({ keys: data.keys }, { headers: { 'cache-control': 'public, max-age=300, stale-while-revalidate=60' } });
  } catch (error) {
    return Response.json({ error: 'authority_verification_keys_unavailable', detail: error instanceof Error ? error.message : 'AUTHORITY_VERIFICATION_KEYS_UNAVAILABLE' }, { status: 503 });
  }
}
