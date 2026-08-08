import type { OperationalSession } from './types';
import type {
  OperationalDataset,
  IntakeBatch,
  GemstoneAsset,
  EvidenceObject,
  ReviewCase,
  OperationalAuditEvent,
  StructuredAttestation,
  InventoryLot,
} from './types';
import { assertTenantScope } from './kernel';

export type OperationalPersistenceHook = (dataset: OperationalDataset) => void;

export class OperationalRepository {
  private data: OperationalDataset;
  private readonly persist?: OperationalPersistenceHook;

  constructor(seed: OperationalDataset, persist?: OperationalPersistenceHook) {
    this.data = structuredClone(seed);
    this.persist = persist;
  }

  private commit(): void {
    this.persist?.(structuredClone(this.data));
  }

  snapshot(): OperationalDataset { return structuredClone(this.data); }

  replace(dataset: OperationalDataset): void {
    this.data = structuredClone(dataset);
    this.commit();
  }

  listLots(session: OperationalSession): InventoryLot[] {
    return this.data.lots.filter((lot) => lot.tenantId === session.tenantId).map((item) => structuredClone(item));
  }

  getLot(session: OperationalSession, lotId: string): InventoryLot | null {
    const lot = this.data.lots.find((item) => item.id === lotId);
    if (!lot) return null;
    assertTenantScope(session, lot.tenantId);
    return structuredClone(lot);
  }

  upsertLot(session: OperationalSession, lot: InventoryLot): InventoryLot {
    assertTenantScope(session, lot.tenantId);
    const index = this.data.lots.findIndex((item) => item.id === lot.id);
    if (index >= 0) this.data.lots[index] = structuredClone(lot); else this.data.lots.push(structuredClone(lot));
    this.commit();
    return structuredClone(lot);
  }

  listBatches(session: OperationalSession): IntakeBatch[] {
    return this.data.batches.filter((batch) => batch.tenantId === session.tenantId).map((item) => structuredClone(item));
  }

  getBatch(session: OperationalSession, batchId: string): IntakeBatch | null {
    const batch = this.data.batches.find((item) => item.id === batchId);
    if (!batch) return null;
    assertTenantScope(session, batch.tenantId);
    return structuredClone(batch);
  }

  listAssets(session: OperationalSession, batchId?: string): GemstoneAsset[] {
    return this.data.assets.filter((asset) => asset.tenantId === session.tenantId && (!batchId || asset.batchId === batchId)).map((item) => structuredClone(item));
  }

  getAsset(session: OperationalSession, assetId: string): GemstoneAsset | null {
    const asset = this.data.assets.find((item) => item.id === assetId);
    if (!asset) return null;
    assertTenantScope(session, asset.tenantId);
    return structuredClone(asset);
  }

  listEvidence(session: OperationalSession, assetId?: string): EvidenceObject[] {
    return this.data.evidence.filter((item) => item.tenantId === session.tenantId && (!assetId || item.assetId === assetId)).map((item) => structuredClone(item));
  }

  listReviewCases(session: OperationalSession): ReviewCase[] {
    return this.data.reviewCases.filter((item) => item.tenantId === session.tenantId).map((item) => structuredClone(item));
  }

  getReviewCase(session: OperationalSession, caseId: string): ReviewCase | null {
    const review = this.data.reviewCases.find((item) => item.id === caseId);
    if (!review) return null;
    assertTenantScope(session, review.tenantId);
    return structuredClone(review);
  }

  upsertBatch(session: OperationalSession, batch: IntakeBatch): IntakeBatch {
    assertTenantScope(session, batch.tenantId);
    const index = this.data.batches.findIndex((item) => item.id === batch.id);
    if (index >= 0) this.data.batches[index] = structuredClone(batch); else this.data.batches.push(structuredClone(batch));
    this.commit();
    return structuredClone(batch);
  }

  upsertAssets(session: OperationalSession, assets: GemstoneAsset[]): GemstoneAsset[] {
    for (const asset of assets) {
      assertTenantScope(session, asset.tenantId);
      const index = this.data.assets.findIndex((item) => item.id === asset.id);
      if (index >= 0) this.data.assets[index] = structuredClone(asset); else this.data.assets.push(structuredClone(asset));
    }
    this.commit();
    return assets.map((item) => structuredClone(item));
  }

  upsertEvidence(session: OperationalSession, evidence: EvidenceObject): EvidenceObject {
    assertTenantScope(session, evidence.tenantId);
    const asset = this.data.assets.find((item) => item.id === evidence.assetId);
    if (!asset) throw new Error('ASSET_NOT_FOUND');
    assertTenantScope(session, asset.tenantId);
    const index = this.data.evidence.findIndex((item) => item.id === evidence.id);
    if (index >= 0) this.data.evidence[index] = structuredClone(evidence); else this.data.evidence.push(structuredClone(evidence));
    if (!asset.evidenceIds.includes(evidence.id)) asset.evidenceIds.push(evidence.id);
    asset.version += 1;
    asset.updatedAt = evidence.createdAt;
    this.commit();
    return structuredClone(evidence);
  }

  appendAttestation(session: OperationalSession, attestation: StructuredAttestation): StructuredAttestation {
    assertTenantScope(session, attestation.tenantId);
    if (this.data.attestations.some((item) => item.id === attestation.id)) throw new Error('ATTESTATION_IMMUTABLE');
    this.data.attestations.push(structuredClone(attestation));
    this.commit();
    return structuredClone(attestation);
  }

  listAttestations(session: OperationalSession, batchId?: string): StructuredAttestation[] {
    return this.data.attestations.filter((item) => item.tenantId === session.tenantId && (!batchId || item.batchId === batchId)).map((item) => structuredClone(item));
  }

  upsertReviewCase(session: OperationalSession, review: ReviewCase): ReviewCase {
    assertTenantScope(session, review.tenantId);
    const index = this.data.reviewCases.findIndex((item) => item.id === review.id);
    if (index >= 0) this.data.reviewCases[index] = structuredClone(review); else this.data.reviewCases.push(structuredClone(review));
    this.commit();
    return structuredClone(review);
  }

  appendAudit(session: OperationalSession, event: OperationalAuditEvent): void {
    assertTenantScope(session, event.tenantId);
    this.data.auditEvents.push(structuredClone(event));
    this.commit();
  }

  listAudit(session: OperationalSession): OperationalAuditEvent[] {
    return this.data.auditEvents.filter((item) => item.tenantId === session.tenantId).map((item) => structuredClone(item));
  }
}
