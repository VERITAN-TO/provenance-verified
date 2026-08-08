import { describe, expect, it } from 'vitest';
import { verifyPublicId, resolveRegistry, resolveEvents } from '@/api/service';

describe('service contracts', () => {
  it('resolves an issuer-authorized deterministic credential', async () => {
    const result = await verifyPublicId('PV-TEST-T4D004');
    expect(result.status).toBe(200);
    expect((result.body as { meta: { mode: string } }).meta.mode).toBe('test');
  });

  it('returns a stable 404 for unknown IDs', async () => {
    expect((await verifyPublicId('PV-TEST-NF1007')).status).toBe(404);
  });

  it('returns 409 and no registry record when evidence eligibility lacks issuance authority', async () => {
    const result = await verifyPublicId('PV-TEST-A21008');
    expect(result.status).toBe(409);
    expect(await resolveRegistry('PV-TEST-A21008')).toBeNull();
  });

  it('uses the same public ID across registry and events for issued credentials', async () => {
    expect((await resolveRegistry('PV-TEST-T3C003') as { publicId: string } | null)?.publicId).toBe('PV-TEST-T3C003');
    expect((await resolveEvents('PV-TEST-T3C003')).every((event) => event.recordId === 'PV-TEST-T3C003')).toBe(true);
  });

  it('rejects a fixture key that does not match the requested public ID', async () => {
    const result = await verifyPublicId('PV-TEST-T4D004', 't4MissingSecondApproval');
    expect(result.status).toBe(400);
    expect((result.body as { error: { code: string } }).error.code).toBe('fixture_public_id_mismatch');
  });
});
