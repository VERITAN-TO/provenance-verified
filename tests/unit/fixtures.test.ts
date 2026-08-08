import { describe, expect, it } from 'vitest';
import { fixtureList } from '@/domain/fixtures';
import { publicIdSchema } from '@/domain/schemas';
import { buildCredential } from '@/domain/projectors';
import { authorityInputSchema } from '@/domain/schemas';

describe('deterministic fixtures', () => {
  it('uses stable unique public IDs', () => {
    const ids = fixtureList.map((fixture) => fixture.publicId);
    expect(new Set(ids).size).toBe(ids.length);
    ids.forEach((id) => expect(publicIdSchema.safeParse(id).success).toBe(true));
  });

  it('matches expected eligibility and issuance state', () => {
    fixtureList.forEach((fixture) => {
      const credential = buildCredential(fixture);
      expect(credential.eligibleTier).toBe(fixture.expectedTier);
      expect(credential.authorization.status).toBe(fixture.expectedIssuanceStatus);
      expect(credential.status === 'issued').toBe(fixture.expectedIssued);
      expect(() => authorityInputSchema.parse(fixture.authority)).not.toThrow();
      expect(credential.testMode).toBe(true);
    });
  });
});
