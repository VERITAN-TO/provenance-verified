import { fixtureByPublicId } from '@/domain/fixtures';
import { buildCredential, buildEvents } from '@/domain/projectors';
import { getProvenanceService } from '@/services';

export async function verifyPublicId(publicId: string, fixtureKey?: string) {
  return getProvenanceService().verify(publicId, fixtureKey);
}

export async function resolveRegistry(publicId: string) {
  const result = await getProvenanceService().lookupRegistry(publicId);
  return result.record;
}

export async function resolveEvents(publicId: string) {
  // Events are still generated from the same canonical fixture/credential projection.
  const fixture = fixtureByPublicId(publicId);
  if (!fixture) return [];
  return buildEvents(buildCredential(fixture));
}
