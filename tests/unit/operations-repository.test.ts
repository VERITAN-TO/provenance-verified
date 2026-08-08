import { describe, expect, it } from 'vitest';
import { OperationalRepository } from '@/operations/repository';
import { operationalDataset, defaultOperationalSession, otherTenantSession, reviewerSession } from '@/operations/fixtures';
import { can } from '@/operations/permissions';

describe('Phase 4 tenant and role boundaries', () => {
  it('lists only records in the active tenant', () => {
    const repository = new OperationalRepository(operationalDataset);
    expect(repository.listBatches(defaultOperationalSession).every((item) => item.tenantId === defaultOperationalSession.tenantId)).toBe(true);
    expect(repository.listBatches(otherTenantSession)).toHaveLength(1);
    expect(repository.listBatches(otherTenantSession)[0].id).toBe('batch_nyc_private');
  });

  it('fails closed on cross-tenant direct access', () => {
    const repository = new OperationalRepository(operationalDataset);
    expect(() => repository.getBatch(defaultOperationalSession, 'batch_nyc_private')).toThrow('TENANT_SCOPE_VIOLATION');
    expect(() => repository.getAsset(defaultOperationalSession, 'asset_private_tenant')).toThrow('TENANT_SCOPE_VIOLATION');
  });

  it('keeps intake and reviewer permissions distinct', () => {
    expect(can(defaultOperationalSession.role, 'asset.create')).toBe(true);
    expect(can(defaultOperationalSession.role, 'review.decide')).toBe(false);
    expect(can(reviewerSession.role, 'review.decide')).toBe(true);
    expect(can(reviewerSession.role, 'credential.issue')).toBe(false);
  });
});
