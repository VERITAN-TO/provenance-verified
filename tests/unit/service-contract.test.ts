import { describe, expect, it } from 'vitest';
import { DeterministicProvenanceService } from '@/services/deterministic';
import type { ProvenanceService } from '@/services/contract';
import { OperationalRepository } from '@/operations/repository';
import { operationalDataset } from '@/operations/fixtures';

function service(): ProvenanceService {
  return new DeterministicProvenanceService(new OperationalRepository(operationalDataset));
}

describe('canonical provenance service contract', () => {
  it('implements identity, verification, registry, continuity, collection, API, and MCP through one adapter', async () => {
    const adapter = service();
    expect(adapter.mode).toBe('test');
    expect(adapter.authoritative).toBe(false);
    const identified = await adapter.identifyAsset({ publicId: 'PV-TEST-T4D004' });
    expect(identified && 'publicId' in identified ? identified.publicId : null).toBe('PV-TEST-T4D004');
    expect((await adapter.verify('PV-TEST-T4D004')).status).toBe(200);
    expect((await adapter.lookupRegistry('PV-TEST-T4D004')).canonicalDigest).toMatch(/^sha256:/);
    expect((await adapter.continuity('PV-TEST-RV1004'))?.markPermitted).toBe(false);
    expect((await adapter.collectionState(operationalDataset.sessions[0])).identifiedAssets).toBeGreaterThan(0);
    expect((await adapter.executeApi({ name: 'verify', input: { publicId: 'PV-TEST-T3C003' } })).meta).toBeDefined();
    expect((await adapter.invokeMcp({ name: 'provenance_registry_lookup', arguments: { public_id: 'PV-TEST-T3C003' } })).record).toBeDefined();
  });

  it('validates evidence integrity and claim correspondence before submission', async () => {
    const adapter = service();
    const evidence = operationalDataset.evidence[0];
    expect((await adapter.validateEvidence([evidence])).valid).toBe(true);
    expect((await adapter.validateEvidence([{ ...evidence, claimIds: [], integrityHash: 'bad' }])).blockers).toEqual(expect.arrayContaining([
      `CLAIM_CORRESPONDENCE_REQUIRED:${evidence.id}`,
      `INTEGRITY_HASH_INVALID:${evidence.id}`,
    ]));
  });
});
