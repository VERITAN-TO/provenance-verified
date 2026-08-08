import { apiProjection, registryProjection } from '@/adapters/projections';
import { fixtureByPublicId, fixtures } from '@/domain/fixtures';
import { evaluateCertification } from '@/domain/kernel';
import { buildCredential, buildEvents } from '@/domain/projectors';
import type { Credential, FixtureRecord, PolicyInput } from '@/domain/types';
import { applyCredentialLifecycleTransition } from '@/operations/lifecycle';
import { assertPermission, credentialForOperationalAsset } from '@/operations/kernel';
import type { OperationalRepository } from '@/operations/repository';
import type { EvidenceObject, OperationalSession, ReviewCase } from '@/operations/types';
import type {
  ApiOperation,
  AssetIdentityQuery,
  CollectionState,
  ContinuityState,
  EvidenceValidation,
  LifecycleTransitionCommand,
  McpOperation,
  ProvenanceService,
  RegistryLookupResult,
  TierAssessment,
  VerificationResult,
} from './contract';

const SHA256_PATTERN = /^sha256:[a-f0-9]{8,}$/i;

export class DeterministicProvenanceService implements ProvenanceService {
  readonly mode = 'test' as const;
  readonly authoritative = false;

  constructor(private readonly repository: OperationalRepository) {}

  async identifyAsset(query: AssetIdentityQuery, session?: OperationalSession) {
    if (query.publicId) return fixtureByPublicId(query.publicId) ?? null;
    if (!session) return null;
    if (query.assetId) return this.repository.getAsset(session, query.assetId);
    if (query.serial) return this.repository.listAssets(session).find((item) => item.serial.toUpperCase() === query.serial!.toUpperCase()) ?? null;
    return null;
  }

  async submitEvidence(session: OperationalSession, evidence: EvidenceObject): Promise<EvidenceObject> {
    assertPermission(session, 'evidence.manage');
    const validation = await this.validateEvidence([evidence]);
    if (!validation.valid) throw new Error(`EVIDENCE_INVALID:${validation.blockers.join(',')}`);
    return this.repository.upsertEvidence(session, evidence);
  }

  async validateEvidence(evidence: EvidenceObject[]): Promise<EvidenceValidation> {
    const blockers: string[] = [];
    const warnings: string[] = [];
    if (!evidence.length) blockers.push('EVIDENCE_REQUIRED');
    for (const item of evidence) {
      if (!item.claimIds.length) blockers.push(`CLAIM_CORRESPONDENCE_REQUIRED:${item.id}`);
      if (!SHA256_PATTERN.test(item.integrityHash)) blockers.push(`INTEGRITY_HASH_INVALID:${item.id}`);
      if (item.status !== 'active') warnings.push(`EVIDENCE_NOT_ACTIVE:${item.id}:${item.status}`);
      if (!item.qualified) warnings.push(`EVIDENCE_UNQUALIFIED:${item.id}`);
    }
    return {
      valid: blockers.length === 0,
      eligible: blockers.length === 0 && evidence.some((item) => item.qualified && item.status === 'active'),
      blockers,
      warnings,
      integrity: blockers.some((item) => item.startsWith('INTEGRITY_HASH_INVALID')) ? 'invalid' : evidence.length ? 'verified' : 'missing',
    };
  }

  async assessTier(policy: PolicyInput, fixture: FixtureRecord): Promise<TierAssessment> {
    return { decision: evaluateCertification(policy, fixture.claims), fixture };
  }

  async issueCredential(session: OperationalSession, reviewCaseId: string): Promise<Credential> {
    assertPermission(session, 'credential.issue');
    const review = this.repository.getReviewCase(session, reviewCaseId);
    if (!review) throw new Error('REVIEW_NOT_FOUND');
    const asset = this.repository.getAsset(session, review.assetId);
    if (!asset) throw new Error('ASSET_NOT_FOUND');
    const evidence = this.repository.listEvidence(session, asset.id);
    const attestation = this.repository.listAttestations(session, review.batchId).find((item) => item.id === review.attestationId);
    const credential = credentialForOperationalAsset(asset, evidence, review, attestation);
    if (credential.status !== 'issued') throw new Error(`CREDENTIAL_NOT_AUTHORIZED:${credential.authorization.blockers.join(',')}`);
    return credential;
  }

  async verify(publicId: string, fixtureKey?: string): Promise<VerificationResult> {
    const fixture = fixtureKey ? fixtures[fixtureKey] : fixtureByPublicId(publicId);
    if (fixtureKey && fixture && fixture.publicId !== publicId) {
      return { status: 400, body: { error: { code: 'fixture_public_id_mismatch', message: 'The test fixture key does not match the requested public ID.' }, meta: this.meta() } };
    }
    if (!fixture || fixture.lifecycle === 'not-found') {
      return { status: 404, body: { error: { code: 'record_not_found', message: 'No deterministic record exists for this public ID.' }, meta: this.meta() } };
    }
    const credential = buildCredential(fixture);
    if (credential.status !== 'issued') {
      return {
        status: 409,
        body: {
          error: { code: 'credential_not_issued', message: 'Evidence eligibility exists, but issuance authority is incomplete or blocked.', blockers: credential.authorization.blockers },
          eligibility: { tier: credential.eligibleTier, name: credential.eligibleTierName },
          authorization: credential.authorization,
          meta: { ...this.meta(), canonicalDigest: credential.integrityHash },
        },
      };
    }
    return { status: 200, body: apiProjection(credential) as unknown as Record<string, unknown> };
  }

  async transitionLifecycle(command: LifecycleTransitionCommand): Promise<ReviewCase> {
    assertPermission(command.session, 'credential.lifecycle');
    const current = this.repository.getReviewCase(command.session, command.reviewCaseId);
    if (!current) throw new Error('REVIEW_NOT_FOUND');
    const at = new Date().toISOString();
    const transitioned = applyCredentialLifecycleTransition(current, { ...command, actorId: command.session.userId, at });
    const asset = this.repository.getAsset(command.session, transitioned.assetId);
    if (!asset) throw new Error('ASSET_NOT_FOUND');
    const evidence = this.repository.listEvidence(command.session, asset.id);
    const attestation = this.repository.listAttestations(command.session, transitioned.batchId).find((item) => item.id === transitioned.attestationId);
    transitioned.credential = credentialForOperationalAsset(asset, evidence, transitioned, attestation);
    transitioned.status = transitioned.credential.status === 'issued' ? 'issued' : 'blocked';
    return this.repository.upsertReviewCase(command.session, transitioned);
  }

  async lookupRegistry(publicId: string): Promise<RegistryLookupResult> {
    const fixture = fixtureByPublicId(publicId);
    if (!fixture || fixture.lifecycle === 'not-found') return { record: null };
    const credential = buildCredential(fixture);
    if (credential.status !== 'issued') return { record: null, canonicalDigest: credential.integrityHash };
    return { record: registryProjection(credential) as unknown as Record<string, unknown>, canonicalDigest: credential.integrityHash };
  }

  async evaluatePolicy(policy: PolicyInput, fixture: FixtureRecord) {
    return evaluateCertification(policy, fixture.claims);
  }

  async continuity(publicId: string): Promise<ContinuityState | null> {
    const fixture = fixtureByPublicId(publicId);
    if (!fixture || fixture.lifecycle === 'not-found') return null;
    const credential = buildCredential(fixture);
    return {
      publicId,
      lifecycle: credential.lifecycle,
      successorId: credential.successorId,
      eventCount: buildEvents(credential).length,
      markPermitted: Boolean(credential.status === 'issued' && credential.lifecycle === 'active' && credential.sealAuthorization?.status === 'authorized'),
    };
  }

  async collectionState(session: OperationalSession): Promise<CollectionState> {
    const snapshot = this.repository.snapshot();
    const lots = snapshot.lots.filter((item) => item.tenantId === session.tenantId);
    const assets = snapshot.assets.filter((item) => item.tenantId === session.tenantId);
    const batches = snapshot.batches.filter((item) => item.tenantId === session.tenantId);
    const evidence = snapshot.evidence.filter((item) => item.tenantId === session.tenantId);
    const reviews = snapshot.reviewCases.filter((item) => item.tenantId === session.tenantId);
    return {
      tenantId: session.tenantId,
      lots: lots.length,
      declaredUnits: lots.reduce((sum, item) => sum + item.declaredQuantity, 0),
      identifiedAssets: assets.length,
      batches: batches.length,
      evidenceObjects: evidence.length,
      openReviews: reviews.filter((item) => !['issued', 'rejected'].includes(item.status)).length,
      issuedCredentials: reviews.filter((item) => item.credential?.status === 'issued').length,
    };
  }

  async dataset(session: OperationalSession) {
    const snapshot = this.repository.snapshot();
    return {
      ...snapshot,
      tenants: snapshot.tenants.filter((item) => item.id === session.tenantId),
      locations: snapshot.locations.filter((item) => item.tenantId === session.tenantId),
      sessions: snapshot.sessions.filter((item) => item.tenantId === session.tenantId),
      lots: snapshot.lots.filter((item) => item.tenantId === session.tenantId),
      batches: snapshot.batches.filter((item) => item.tenantId === session.tenantId),
      assets: snapshot.assets.filter((item) => item.tenantId === session.tenantId),
      evidence: snapshot.evidence.filter((item) => item.tenantId === session.tenantId),
      attestations: snapshot.attestations.filter((item) => item.tenantId === session.tenantId),
      reviewCases: snapshot.reviewCases.filter((item) => item.tenantId === session.tenantId),
      syncOperations: snapshot.syncOperations.filter((item) => item.tenantId === session.tenantId),
      auditEvents: snapshot.auditEvents.filter((item) => item.tenantId === session.tenantId),
    };
  }

  async executeApi(operation: ApiOperation): Promise<Record<string, unknown>> {
    switch (operation.name) {
      case 'verify': return (await this.verify(String(operation.input.publicId ?? ''), operation.input.fixtureKey ? String(operation.input.fixtureKey) : undefined)).body;
      case 'registry.lookup': return (await this.lookupRegistry(String(operation.input.publicId ?? ''))) as unknown as Record<string, unknown>;
      case 'events.list': {
        const fixture = fixtureByPublicId(String(operation.input.publicId ?? ''));
        return { data: fixture ? buildEvents(buildCredential(fixture)) : [], meta: this.meta() };
      }
      case 'operations.collection': throw new Error('SESSION_REQUIRED');
    }
  }

  async invokeMcp(operation: McpOperation): Promise<Record<string, unknown>> {
    switch (operation.name) {
      case 'provenance_verify': return this.executeApi({ name: 'verify', input: { publicId: operation.arguments.public_id } });
      case 'provenance_registry_lookup': return this.executeApi({ name: 'registry.lookup', input: { publicId: operation.arguments.public_id } });
      case 'provenance_collection_state': throw new Error('SESSION_REQUIRED');
    }
  }

  private meta() {
    return { mode: this.mode, authoritative: this.authoritative, productionCredential: false, adapter: 'deterministic-provenance-service-v1' };
  }
}
