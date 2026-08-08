import { fixtureByPublicId } from '@/domain/fixtures';
import { buildCredential, buildEvents } from '@/domain/projectors';

export async function GET(_: Request, { params }: { params: Promise<{ publicId: string }> }) {
  const { publicId } = await params;
  const fixture = fixtureByPublicId(decodeURIComponent(publicId).toUpperCase());
  if (!fixture) return Response.json({ error: { code: 'record_not_found' } }, { status: 404 });
  const credential = buildCredential(fixture);
  if (credential.status !== 'issued') return Response.json({ error: { code: 'record_not_published' } }, { status: 404 });
  return Response.json({ data: {
    publicId: fixture.publicId,
    versions: [{ version: credential.version, payload: credential, payloadDigest: credential.integrityHash, credentialSignature: credential.signature.value, signingKeyId: credential.signature.keyId, signingKeyVersion: 1, createdAt: credential.issuedAt }],
    events: buildEvents(credential), independentlyRebuildable: true,
  }, meta: { environment: 'sandbox', authoritative: false, appendOnly: true, deterministic: true } });
}
