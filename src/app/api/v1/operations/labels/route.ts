import { NextRequest } from 'next/server';
import QRCode from 'qrcode';
import { labelRequestSchema } from '@/operations/schemas';
import { sessionFromRequest, operationError } from '@/operations/http';
import { getOperationalRepository } from '@/operations/runtime';
import { assertPermission, credentialForOperationalAsset } from '@/operations/kernel';
import { stableHash } from '@/domain/hash';
import { appendOperationalAudit } from '@/operations/audit';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const session = await sessionFromRequest(request);
    assertPermission(session, 'label.generate');
    const input = labelRequestSchema.parse(await request.json());
    const repository = getOperationalRepository();
    const baseUrl = process.env.NEXT_PUBLIC_CANONICAL_URL ?? 'https://provenanceverified.org';
    const labels: Array<{
      labelId: string; tenantId: string; assetId: string; serial: string; credentialId: string; publicId: string;
      tier: number | null; sealAsset: string; verificationUrl: string; qrPayload: string; qrSvg: string; generatedAt: string;
      canonicalRegistryAuthority: boolean;
    }> = [];
    const blocked: Array<{ assetId: string; reason: string; authorization?: string; markStatus?: string }> = [];
    for (const assetId of input.assetIds) {
      const asset = repository.getAsset(session, assetId);
      if (!asset) { blocked.push({ assetId, reason: 'ASSET_NOT_FOUND' }); continue; }
      const review = repository.listReviewCases(session).find((item) => item.assetId === asset.id);
      if (!review) { blocked.push({ assetId, reason: 'REVIEW_CASE_NOT_FOUND' }); continue; }
      const attestation = repository.listAttestations(session, review.batchId).find((item) => item.id === review.attestationId);
      const credential = review.credential ?? credentialForOperationalAsset(asset, repository.listEvidence(session, asset.id), review, attestation);
      if (credential.status !== 'issued') { blocked.push({ assetId, reason: 'CREDENTIAL_NOT_ISSUED', authorization: credential.authorization.status }); continue; }
      if (credential.sealAuthorization.status !== 'authorized') { blocked.push({ assetId, reason: 'MARK_NOT_AUTHORIZED', markStatus: credential.sealAuthorization.status }); continue; }
      const verificationUrl = `${baseUrl}/registry/${credential.publicId}`;
      const qrSvg = await QRCode.toString(verificationUrl, { type: 'svg', errorCorrectionLevel: 'H', margin: 0, width: 256 });
      labels.push({
        labelId: `label_${stableHash(`${session.tenantId}:${asset.id}:${credential.id}`)}`,
        tenantId: session.tenantId,
        assetId: asset.id,
        serial: asset.serial,
        credentialId: credential.id,
        publicId: credential.publicId,
        tier: credential.tier,
        sealAsset: `/r5/seals/pv-tier-${credential.tier}.svg`,
        verificationUrl,
        qrPayload: verificationUrl,
        qrSvg,
        generatedAt: '2026-07-20T06:20:00Z',
        canonicalRegistryAuthority: true,
      });
    }
    if (labels.length) appendOperationalAudit(repository, session, request, 'labels.generated', 'label-batch', `labels_${stableHash(input.assetIds.join(':'))}`, { generated: labels.length, requested: input.assetIds.length, assetIds: labels.map((item) => item.assetId) });
    const status = labels.length ? 200 : 409;
    return Response.json({ data: labels, blocked, meta: { mode: 'test', requested: input.assetIds.length, generated: labels.length, physicalCarrierIsAuthority: false } }, { status });
  } catch (error) { return operationError(error); }
}
