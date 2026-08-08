import { fixtureList } from '@/domain/fixtures';
import { buildCredential } from '@/domain/projectors';

export async function GET(request: Request) {
  const query = new URL(request.url).searchParams.get('q')?.trim().toLowerCase() ?? '';
  const limit=Math.min(25,Math.max(1,Number(new URL(request.url).searchParams.get('limit') ?? 25)));
  const records = fixtureList.map((fixture) => ({ fixture, credential: buildCredential(fixture) }))
    .filter(({ credential }) => credential.status === 'issued')
    .map(({ fixture, credential }) => ({
      publicId: fixture.publicId, lifecycle: credential.lifecycle, tier: credential.tier, tierName: credential.tierName,
      description: fixture.description, claimCount: credential.claims.length, evidenceCount: credential.evidence.length,
      markAuthorized: credential.sealAuthorization.status === 'authorized', authoritative: false, environment: 'sandbox',
    }))
    .filter((record) => !query || Object.values(record).some((value) => String(value).toLowerCase().includes(query)))
    .slice(0,limit);
  return Response.json({ data: records, meta: { environment: 'sandbox', authoritative: false, appendOnly: true, deterministic: true, enumerationProtected: false, pageSize: limit, nextCursor: null, hasMore: false } });
}
