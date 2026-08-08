import { describe, expect, it } from 'vitest';
import { evaluateCertification } from '@/domain/kernel';
import { applySyncOperation, buildAssetIndex, createOperationalEventReceipt, credentialForOperationalAsset, isBatchSubmittable, projectAssetToAuthority, signAttestation, validateBatch } from '@/operations/kernel';
import { attestorSession, operationalDataset } from '@/operations/fixtures';
import { stableHash } from '@/domain/hash';
import type { GemstoneAsset, ReviewCase, SyncOperation } from '@/operations/types';

const dataset = structuredClone(operationalDataset);
const batch = dataset.batches.find((item) => item.id === 'batch_phx_2026_0720_a')!;
const assets = dataset.assets.filter((item) => item.batchId === batch.id);
const attestation = dataset.attestations.find((item) => item.id === 'att_fixture_batch_phx')!;

function authorizedReview(source: ReviewCase): ReviewCase {
  const review = structuredClone(source);
  review.approvals.push({ id: 'approval_secondary', reviewerId: 'reviewer_secondary_02', role: 'secondary', independent: true, conflictFree: true, decision: 'approve', decidedAt: '2026-07-20T05:00:00Z', reasonCodes: ['PV_REVIEW_APPROVED'] });
  review.conflictClearance = 'clear';
  review.custosVerdict = { status: 'pass', verdictId: 'custos_pass_01', evaluatedAt: '2026-07-20T05:01:00Z', reasonCodes: ['PV_CUSTOS_PASS'] };
  review.eventReceipts.push(createOperationalEventReceipt(review.eventReceipts, 'review.secondary-recorded', review.id, 'reviewer_secondary_02', '2026-07-20T05:00:00Z'));
  review.eventReceipts.push(createOperationalEventReceipt(review.eventReceipts, 'custos.recorded', 'custos_pass_01', 'compliance_01', '2026-07-20T05:01:00Z'));
  review.signingKeyStatus = 'active';
  review.eventReceipts.push(createOperationalEventReceipt(review.eventReceipts, 'signing.authorized', review.id, 'compliance_01', '2026-07-20T05:02:00Z'));
  review.registryStatus = 'ready';
  const registryReceipt = createOperationalEventReceipt(review.eventReceipts, 'registry.published', review.registryId, 'compliance_01', '2026-07-20T05:03:00Z');
  review.eventReceipts.push(registryReceipt);
  review.registryPublication = { publicId: review.registryId, receiptId: registryReceipt.id, publishedAt: registryReceipt.at, integrityHash: `sha256:${stableHash(`${review.registryId}:${registryReceipt.eventHash}:${registryReceipt.at}`)}` };
  review.revocationCapability = true;
  review.eventReceipts.push(createOperationalEventReceipt(review.eventReceipts, 'revocation-control.enabled', review.registryId, 'compliance_01', '2026-07-20T05:04:00Z'));
  review.markAuthorization = 'authorized';
  review.eventReceipts.push(createOperationalEventReceipt(review.eventReceipts, 'mark.authorized', review.registryId, 'compliance_01', '2026-07-20T05:05:00Z'));
  return review;
}

describe('Phase 4 operational kernel', () => {
  it('keeps aggregate lot quantity separate from individual asset identity', () => {
    const lot = dataset.lots.find((item) => item.id === 'lot_phx_2026_0719')!;
    expect(lot.declaredQuantity).toBe(120);
    expect(lot.identifiedUnitCount).toBe(24);
    expect(assets).toHaveLength(24);
    expect(lot.declaredQuantity).not.toBe(assets.length);
  });

  it('validates an evidence-complete operational batch and retains warnings', () => {
    const issues = validateBatch(batch, dataset.assets, dataset.evidence);
    expect(isBatchSubmittable(issues)).toBe(true);
    expect(issues.some((item) => item.code === 'PV_TREATMENT_DISCLOSURE_UNKNOWN')).toBe(true);
    expect(issues.some((item) => item.severity === 'error')).toBe(false);
  });

  it('creates immutable, versioned structured attestations', () => {
    const first = signAttestation(attestorSession, batch, assets, 'Claims submitted for review.', 'Evidence linked per asset.', ['Phone images are not laboratory authentication.']);
    const second = signAttestation(attestorSession, batch, assets, 'Corrected claims submitted for review.', 'Evidence linked per asset.', ['Phone images are not laboratory authentication.'], first);
    expect(first.immutable).toBe(true);
    expect(second.version).toBe(2);
    expect(second.supersedesId).toBe(first.id);
    expect(second.signature).not.toBe(first.signature);
  });

  it('projects only actual operational records into the authority kernel', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const projection = projectAssetToAuthority(asset, dataset.evidence, review, attestation);
    const decision = evaluateCertification(projection.policy, projection.fixture.claims);
    const credential = credentialForOperationalAsset(asset, dataset.evidence, review, attestation);
    expect(decision.tier).toBe(4);
    expect(projection.policy.completeTransferHistory).toBe(true);
    expect(projection.policy.completeCustodyTransfers).toBe(true);
    expect(projection.policy.signedAttestation).toBe(true);
    expect(credential.status).toBe('not-issued');
    expect(credential.authorization.status).toBe('second-approval-required');
  });

  it('issues only after dual review, CUSTOS, signing, registry publication, revocation control, and mark gates have receipts', () => {
    const asset = assets[0];
    const source = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const review = authorizedReview(source);
    const credential = credentialForOperationalAsset(asset, dataset.evidence, review, attestation);
    expect(credential.status).toBe('issued');
    expect(credential.tier).toBe(4);
    expect(credential.sealAuthorization.status).toBe('authorized');
  });

  it('does not grant Tier 4 without actual transfer history', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const filtered = dataset.evidence.filter((item) => item.assetId !== asset.id || item.type !== 'transfer');
    const projection = projectAssetToAuthority(asset, filtered, review, attestation);
    const decision = evaluateCertification(projection.policy, projection.fixture.claims);
    expect(projection.policy.completeTransferHistory).toBe(false);
    expect(decision.tier).not.toBe(4);
    expect(decision.upgradePath).toContain('Complete transfer history');
  });

  it('does not grant Tier 4 without actual custody history', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const filtered = dataset.evidence.filter((item) => item.assetId !== asset.id || item.type !== 'custody');
    const projection = projectAssetToAuthority(asset, filtered, review, attestation);
    expect(projection.policy.completeCustodyTransfers).toBe(false);
    expect(evaluateCertification(projection.policy, projection.fixture.claims).tier).not.toBe(4);
  });

  it('does not elevate an asset without its immutable attestation record', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const projection = projectAssetToAuthority(asset, dataset.evidence, review, undefined);
    expect(projection.policy.signedAttestation).toBe(false);
    expect(evaluateCertification(projection.policy, projection.fixture.claims).tier).toBe(1);
  });

  it('rejects unqualified laboratory evidence at the projection boundary', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const altered = dataset.evidence.map((item) => item.assetId === asset.id && item.type === 'laboratory' ? { ...item, qualified: false } : item);
    const projection = projectAssetToAuthority(asset, altered, review, attestation);
    expect(projection.policy.qualifyingLaboratoryEvidence).toBe(false);
    expect(evaluateCertification(projection.policy, projection.fixture.claims).tier).not.toBe(4);
  });

  it('requires independently qualified evidence for verified origin', () => {
    const asset = assets[0];
    const review = dataset.reviewCases.find((item) => item.assetId === asset.id)!;
    const altered = dataset.evidence.map((item) => item.assetId === asset.id && item.claimIds.includes('claim_origin') ? { ...item, independent: false } : item);
    const projection = projectAssetToAuthority(asset, altered, review, attestation);
    expect(projection.policy.verifiedOrigin).toBe(false);
    expect(evaluateCertification(projection.policy, projection.fixture.claims).tier).not.toBe(4);
  });

  it('fails closed when an append-only authority receipt is tampered', () => {
    const asset = assets[0];
    const review = structuredClone(dataset.reviewCases.find((item) => item.assetId === asset.id)!);
    review.eventReceipts[0].eventHash = 'sha256:tampered0000';
    const projection = projectAssetToAuthority(asset, dataset.evidence, review, attestation);
    expect(projection.policy.appendOnlyEvent).toBe(false);
    expect(evaluateCertification(projection.policy, projection.fixture.claims).tier).toBe(1);
  });

  it('does not treat registry readiness as publication without a matching receipt', () => {
    const asset = assets[0];
    const review = authorizedReview(dataset.reviewCases.find((item) => item.assetId === asset.id)!);
    review.registryPublication = undefined;
    const credential = credentialForOperationalAsset(asset, dataset.evidence, review, attestation);
    expect(credential.status).toBe('not-issued');
    expect(credential.authorization.status).toBe('registry-required');
  });

  it('detects offline optimistic-concurrency conflicts', () => {
    const asset = assets[0];
    const operation: SyncOperation = { id: 'sync_conflict', tenantId: asset.tenantId, deviceId: 'device', entityType: 'asset', entityId: asset.id, operation: 'update', expectedVersion: 0, payload: { colorDescription: 'Updated' }, status: 'queued', attempts: 0, createdAt: '2026-07-20T05:00:00Z' };
    const result = applySyncOperation(operation, asset);
    expect(result.operation.status).toBe('conflict');
    expect(result.operation.error).toBe(`VERSION_CONFLICT:${asset.version}`);
  });

  it('indexes 100,000 assets without changing their identities', () => {
    const hundredThousand: GemstoneAsset[] = Array.from({ length: 100_000 }, (_, index) => ({ ...assets[0], id: `asset_scale_${index}`, serial: `SCALE-${index}`, version: 1 }));
    const index = buildAssetIndex(hundredThousand);
    expect(index.get('asset_scale_99999')?.serial).toBe('SCALE-99999');
    expect(index.get(`${assets[0].tenantId}:SCALE-50000`)?.id).toBe('asset_scale_50000');
    expect(index.size).toBe(200_000);
  });
});
