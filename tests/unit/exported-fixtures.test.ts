import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fixtureList } from '@/domain/fixtures';

type Manifest = {
  schemaVersion: string;
  fixtures: Array<{
    key: string;
    file: string;
    publicId: string;
    expectedEligibleTier: number;
    expectedIssuanceStatus: string;
    expectedCredentialStatus: 'issued' | 'not-issued';
    expectedRegistryPublished: boolean;
    expectedSealAuthorized: boolean;
  }>;
};

describe('generated authority fixtures', () => {
  const manifestPath = path.resolve('fixtures/fixture-manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as Manifest;

  it('covers every canonical fixture exactly once', () => {
    expect(manifest.schemaVersion).toBe('2.0.0');
    expect(manifest.fixtures).toHaveLength(fixtureList.length);
    expect(new Set(manifest.fixtures.map((entry) => entry.key)).size).toBe(fixtureList.length);
  });

  it('matches eligibility, issuance, registry, and mark expectations', () => {
    for (const entry of manifest.fixtures) {
      const snapshot = JSON.parse(fs.readFileSync(path.resolve('fixtures', entry.file), 'utf8'));
      expect(snapshot.fixtureKey).toBe(entry.key);
      expect(snapshot.publicId).toBe(entry.publicId);
      expect(snapshot.eligibility.tier).toBe(entry.expectedEligibleTier);
      expect(snapshot.credential.authorization.status).toBe(entry.expectedIssuanceStatus);
      expect(snapshot.credential.status).toBe(entry.expectedCredentialStatus);
      expect(snapshot.registry !== null).toBe(entry.expectedRegistryPublished);
      expect(snapshot.credential.sealAuthorization.status === 'authorized').toBe(entry.expectedSealAuthorized);
      if (entry.expectedCredentialStatus === 'not-issued') {
        expect(snapshot.credential.tier).toBeNull();
        expect(snapshot.credential.signature.valid).toBe(false);
        expect(snapshot.credential.signature.value).toBe('');
        expect(snapshot.webhooks).toEqual([]);
      }
    }
  });

  it('contains no stale demo IDs or contradictory tier announcements', () => {
    for (const entry of manifest.fixtures) {
      const text = fs.readFileSync(path.resolve('fixtures', entry.file), 'utf8');
      expect(text).not.toContain('PV-DEMO-');
      expect(text).not.toContain('Silver credential published for test record');
    }
  });
});
