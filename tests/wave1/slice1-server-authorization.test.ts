import { beforeEach, describe, expect, it, vi } from 'vitest';
import { SupabaseAuthBoundaryError } from '@/authority/supabase-auth';
import { SupabaseAuthorityError } from '@/authority/supabase-data';
import {
  Wave1Denied,
  correlationIdFromRequest,
  requestFingerprint,
  validateIdempotencyKey,
} from '@/authority/wave1-contracts';

const authority = vi.hoisted(() => ({
  config: vi.fn(),
  verifySession: vi.fn(),
  resolveActor: vi.fn(),
  deriveTenant: vi.fn(),
  authorizeAndAudit: vi.fn(),
  consumeQuota: vi.fn(),
  claimIdempotency: vi.fn(),
  completeIdempotency: vi.fn(),
  getAuthenticatedUser: vi.fn(),
  listMemberships: vi.fn(),
}));

vi.mock('@/authority/config', () => ({ getAuthorityRuntimeConfig: authority.config }));
vi.mock('@/authority/supabase-auth', async (importOriginal) => {
  const original = await importOriginal<typeof import('@/authority/supabase-auth')>();
  return {
    ...original,
    verifyAuthenticatedSession: authority.verifySession,
    getAuthenticatedUser: authority.getAuthenticatedUser,
  };
});
vi.mock('@/authority/supabase-data', async (importOriginal) => {
  const original = await importOriginal<typeof import('@/authority/supabase-data')>();
  return {
    ...original,
    resolveActorIdentity: authority.resolveActor,
    deriveTenantContext: authority.deriveTenant,
    authorizeAndAudit: authority.authorizeAndAudit,
    consumeApiQuota: authority.consumeQuota,
    claimIdempotency: authority.claimIdempotency,
    completeIdempotency: authority.completeIdempotency,
    listMemberships: authority.listMemberships,
  };
});

import {
  authenticateWave1Request,
  authorizeWave1Authentication,
  authorizeWave1Request,
  executeIdempotentWave1Operation,
  projectWave1AuthorityContext,
  wave1ErrorResponse,
} from '@/operations/http';

function request(
  headers: Record<string, string> = {},
  cookies: Record<string, string> = {},
): Parameters<typeof authenticateWave1Request>[0] {
  const value = new Request('https://provenance.test/api/v1/auth/session', { headers }) as Parameters<typeof authenticateWave1Request>[0];
  Object.defineProperty(value, 'cookies', {
    value: { get: (name: string) => cookies[name] ? { value: cookies[name] } : undefined },
  });
  return value;
}

const actor = {
  outcome: 'RESOLVED' as const,
  reason_code: null,
  actor_id: 'actor-1',
  actor_type: 'user' as const,
  session_id_or_workload_id: 'session-1',
  authentication_strength: 'aal2',
  issued_at: '2026-07-25T00:00:00.000Z',
  correlation_id: '00000000-0000-4000-8000-000000000001',
  authority_version: 7,
};

const tenant = {
  outcome: 'RESOLVED' as const,
  reason_code: null,
  tenant_id: 'tenant-1',
  actor_id: 'actor-1',
  membership_id: 'membership-1',
  derivation_source: 'active_membership',
  derived_at: '2026-07-25T00:00:00.000Z',
  correlation_id: '00000000-0000-4000-8000-000000000001',
  role: 'organization_admin' as const,
  membership_status: 'active' as const,
  authority_version: 7,
};

const decision = {
  decision_id: 'decision-1',
  outcome: 'ALLOW' as const,
  reason_code: null,
  actor_id: 'actor-1',
  tenant_id: 'tenant-1',
  action: 'tenant_resource/read',
  resource_type: 'tenant',
  resource_id: 'tenant-1',
  policy_version: 'v1-wave1' as const,
  authority_version: 7,
  decided_at: '2026-07-25T00:00:00.000Z',
  correlation_id: '00000000-0000-4000-8000-000000000001',
};

beforeEach(() => {
  vi.clearAllMocks();
  authority.config.mockReturnValue({ environment: 'pilot', requireAal2: false, authoritative: false });
  authority.verifySession.mockResolvedValue({
    user: { id: 'subject-1', email: 'member@example.test' },
    claims: { sub: 'subject-1', exp: 4_102_444_800, session_id: 'session-1', aal: 'aal2' },
  });
  authority.resolveActor.mockImplementation(async (_token: string, correlationId: string) => ({ ...actor, correlation_id: correlationId }));
  authority.deriveTenant.mockImplementation(async (_token: string, _actorId: string, requested: string | undefined, correlationId: string) => ({
    ...tenant,
    tenant_id: requested ?? tenant.tenant_id,
    correlation_id: correlationId,
  }));
  authority.consumeQuota.mockResolvedValue({ remaining: 9 });
  authority.authorizeAndAudit.mockImplementation(async (_token: string, input: Record<string, unknown>) => ({
    ...decision,
    actor_id: input.actorId,
    tenant_id: input.tenantId,
    action: input.action,
    resource_type: input.resourceType,
    resource_id: input.resourceId,
    policy_version: 'v1-wave1',
    authority_version: input.expectedAuthorityVersion,
    correlation_id: input.correlationId,
  }));
  authority.claimIdempotency.mockResolvedValue({ status: 'IN_PROGRESS', replay: false });
  authority.completeIdempotency.mockResolvedValue({ status: 'COMPLETED', replay: false, result_reference: 'result-1' });
  authority.listMemberships.mockResolvedValue([
    { tenant_id: 'tenant-1', user_id: 'subject-1', role: 'organization_admin', status: 'active', location_ids: [], display_name: 'Tenant One' },
    { tenant_id: 'tenant-2', user_id: 'subject-1', role: 'member', status: 'active', location_ids: [], display_name: 'Tenant Two' },
  ]);
});

describe('Wave 1 Slice 1 acceptance definitions', () => {
  it('S1-A5-AT-001 resolves a valid authenticated request to a server-derived actor', async () => {
    const result = await authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }));
    expect(result.actor.actor_id).toBe('actor-1');
    expect(authority.resolveActor).toHaveBeenCalledWith('verified-token', '00000000-0000-4000-8000-000000000001');
  });

  it('S1-A5-AT-002 validates an explicit tenant selection through the A1 tenant primitive', async () => {
    const result = await authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001', 'x-provenance-tenant': 'tenant-2' }, { pv_access_token: 'verified-token' }));
    expect(result.tenant.tenant_id).toBe('tenant-2');
    expect(authority.deriveTenant).toHaveBeenCalledWith('verified-token', 'actor-1', 'tenant-2', '00000000-0000-4000-8000-000000000001');
  });

  it('S1-A5-AT-003 authorizes an in-tenant read and receives an audited A1 decision', async () => {
    const result = await authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), {
      action: 'tenant_resource/read',
      resourceType: 'tenant',
    });
    expect(result.decision.outcome).toBe('ALLOW');
    expect(authority.authorizeAndAudit).toHaveBeenCalledTimes(1);
  });

  it('S1-A5-AT-004 enforces distributed quota after actor and tenant derivation', async () => {
    const authentication = await authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }));
    await authorizeWave1Authentication(authentication, { action: 'tenant_resource/read', resourceType: 'tenant' });
    expect(authority.consumeQuota).toHaveBeenCalledWith('tenant-1', 'actor-1', 'tenant_resource/read');
  });

  it('S1-A5-AT-005 returns the stored result reference for a valid idempotent replay without a new side effect', async () => {
    authority.claimIdempotency.mockResolvedValue({ status: 'COMPLETED', replay: true, result_reference: 'stable-result' });
    const execute = vi.fn();
    const result = await executeIdempotentWave1Operation(
      { accessToken: 'verified-token', actor, tenant, decision, correlationId: '00000000-0000-4000-8000-000000000001' },
      new Request('https://provenance.test/mutate', { headers: { 'idempotency-key': 'idem-key-00000001' } }),
      'asset/write',
      { value: 1 },
      execute,
    );
    expect(result).toEqual({ replay: true, resultReference: 'stable-result' });
    expect(execute).not.toHaveBeenCalled();
  });

  it('S1-A5-AT-006 completes a new idempotent operation with the canonical request digest', async () => {
    const result = await executeIdempotentWave1Operation(
      { accessToken: 'verified-token', actor, tenant, decision, correlationId: '00000000-0000-4000-8000-000000000001' },
      new Request('https://provenance.test/mutate', { headers: { 'idempotency-key': 'idem-key-00000002' } }),
      'asset/write',
      { value: 2 },
      async () => ({ result: { ok: true }, resultReference: 'result-2' }),
    );
    expect(result.replay).toBe(false);
    expect(authority.completeIdempotency).toHaveBeenCalledWith('verified-token', expect.objectContaining({ requestDigest: requestFingerprint({ value: 2 }) }));
  });

  it('S1-A5-AT-007 preserves a valid caller correlation ID for safe traceability', () => {
    expect(correlationIdFromRequest(new Request('https://provenance.test', { headers: { 'x-correlation-id': '00000000-0000-4000-8000-000000000001' } }))).toBe('00000000-0000-4000-8000-000000000001');
  });

  it('S1-A5-AT-008 preserves the server-derived valid role through authorization', async () => {
    const result = await authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), {
      action: 'tenant_resource/read',
      resourceType: 'tenant',
    });
    expect(result.tenant.role).toBe('organization_admin');
    expect(authority.authorizeAndAudit).toHaveBeenCalledWith('verified-token', expect.objectContaining({ role: 'organization_admin' }));
  });


  it('S1-A0-AT-001 projects one canonical authority response for both session endpoints', async () => {
    const projected = await projectWave1AuthorityContext({
      accessToken: 'verified-token', actor, tenant, decision,
      correlationId: '00000000-0000-4000-8000-000000000001',
      subject: { id: 'subject-1', email: 'member@example.test' },
      expiresAt: '2099-01-01T00:00:00.000Z',
    }, { id: 'tenant-1', display_name: 'Tenant One', status: 'active' });
    expect(projected).toMatchObject({
      actor: { actorId: 'actor-1', authenticationStrength: 'aal2' },
      tenant: { tenantId: 'tenant-1', displayName: 'Tenant One' },
      membership: { membershipId: 'membership-1', status: 'active', role: 'organization_admin' },
      authorization: { decision: 'ALLOW', authorityVersion: '7' },
      session: { sessionId: 'session-1' },
      correlationId: '00000000-0000-4000-8000-000000000001',
    });
    expect(projected.eligibleTenants).toHaveLength(2);
  });
});

describe('Wave 1 Slice 1 negative definitions', () => {
  it('S1-A5-NT-001 denies missing authentication', async () => {
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }))).rejects.toMatchObject({ code: 'DENY_UNAUTHENTICATED' });
  });

  it('S1-A5-NT-002 denies an invalid authentication token', async () => {
    authority.verifySession.mockRejectedValue(new SupabaseAuthBoundaryError('AUTHENTICATION_INVALID', 401));
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'bad-token' }))).rejects.toMatchObject({ code: 'DENY_UNAUTHENTICATED' });
  });

  it('S1-A5-NT-003 denies an unknown actor', async () => {
    authority.resolveActor.mockRejectedValue(new SupabaseAuthorityError('ACTOR_UNKNOWN', 403));
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({ code: 'DENY_ACTOR_UNKNOWN' });
  });

  it('S1-A5-NT-004 denies an inactive actor', async () => {
    authority.resolveActor.mockRejectedValue(new SupabaseAuthorityError('ACTOR_INACTIVE', 403));
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({ code: 'DENY_ACTOR_UNKNOWN' });
  });

  it('S1-A5-NT-005 denies inactive membership', async () => {
    authority.deriveTenant.mockResolvedValue({ ...tenant, membership_status: 'suspended' });
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({ code: 'DENY_MEMBERSHIP_INACTIVE' });
  });

  it('S1-A5-NT-006 denies unauthorized tenant selection', async () => {
    authority.deriveTenant.mockResolvedValue({ ...tenant, tenant_id: 'tenant-1' });
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001', 'x-provenance-tenant': 'tenant-2' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({ code: 'DENY_TENANT_UNAUTHORIZED' });
  });

  it('S1-A5-NT-007 denies an invalid role decision', async () => {
    authority.authorizeAndAudit.mockResolvedValue({ ...decision, outcome: 'DENY', reason_code: 'ROLE_NOT_AUTHORIZED' });
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_ROLE' });
  });

  it('S1-A5-NT-008 denies an unknown action', async () => {
    authority.authorizeAndAudit.mockResolvedValue({ ...decision, outcome: 'DENY', reason_code: 'ACTION_UNKNOWN' });
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'unknown/action', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_ACTION' });
  });

  it('S1-A5-NT-009 denies a resource tenant mismatch through the audited A1 decision', async () => {
    authority.authorizeAndAudit.mockResolvedValue({ ...decision, outcome: 'DENY', reason_code: 'RESOURCE_TENANT_MISMATCH' });
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), {
      action: 'tenant_resource/read', resourceType: 'tenant', resourceTenantId: 'tenant-other',
    })).rejects.toMatchObject({ code: 'DENY_RESOURCE_TENANT_MISMATCH' });
    expect(authority.authorizeAndAudit).toHaveBeenCalledTimes(1);
  });

  it('S1-A5-NT-010 denies an authority-version conflict after fail-closed comparison', async () => {
    authority.authorizeAndAudit.mockResolvedValue({ ...decision, authority_version: 6 });
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_AUTHORITY_VERSION_CONFLICT' });
  });

  it('S1-A5-NT-011 fails closed when authorization authority is unavailable', async () => {
    authority.authorizeAndAudit.mockRejectedValue(new SupabaseAuthorityError('AUTHORITY_DEPENDENCY_UNAVAILABLE', 503));
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_AUTHORITY_UNAVAILABLE' });
  });

  it('S1-A5-NT-012 fails closed when the distributed quota boundary is unavailable', async () => {
    authority.consumeQuota.mockRejectedValue(new SupabaseAuthorityError('SERVICE_ROLE_BOUNDARY_UNAVAILABLE', 503));
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_AUTHORITY_UNAVAILABLE' });
  });

  it('S1-A5-NT-013 denies an idempotency fingerprint conflict without executing the operation', async () => {
    authority.claimIdempotency.mockRejectedValue(new SupabaseAuthorityError('PV_IDEMPOTENCY_FINGERPRINT_CONFLICT', 409));
    const execute = vi.fn();
    await expect(executeIdempotentWave1Operation(
      { accessToken: 'verified-token', actor, tenant, decision, correlationId: '00000000-0000-4000-8000-000000000001' },
      new Request('https://provenance.test/mutate', { headers: { 'idempotency-key': 'idem-key-00000003' } }),
      'asset/write',
      { value: 3 },
      execute,
    )).rejects.toMatchObject({ code: 'DENY_IDEMPOTENCY_CONFLICT' });
    expect(execute).not.toHaveBeenCalled();
  });

  it('S1-A5-NT-014 rejects a malformed idempotency key', () => {
    expect(() => validateIdempotencyKey('short', '00000000-0000-4000-8000-000000000001')).toThrowError(Wave1Denied);
  });

  it('S1-A5-NT-015 emits a typed safe error without stack, SQL, token, or provider detail', async () => {
    const internal = new Error('SQL select secret_token from private_policy');
    const response = wave1ErrorResponse(internal, new Request('https://provenance.test', { headers: { 'x-correlation-id': '00000000-0000-4000-8000-000000000001' } }));
    const body = await response.json() as Record<string, unknown>;
    const serialized = JSON.stringify(body);
    expect(serialized).not.toContain('SQL');
    expect(serialized).not.toContain('secret_token');
    expect(serialized).not.toContain('private_policy');
    expect(body).toMatchObject({ ok: false, denied: true, correlation_id: '00000000-0000-4000-8000-000000000001' });
  });

  it('S1-A5-NT-016 replaces an invalid correlation header rather than reflecting it', () => {
    const value = correlationIdFromRequest(new Request('https://provenance.test', { headers: { 'x-correlation-id': '<script>' } }));
    expect(value).not.toBe('<script>');
    expect(value.length).toBeGreaterThan(20);
  });


  it('S1-A5-NT-017 returns only server-derived eligible memberships for ambiguous tenant authority', async () => {
    authority.deriveTenant.mockRejectedValue(new SupabaseAuthorityError('TENANT_AMBIGUOUS', 403));
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({
      code: 'DENY_TENANT_AMBIGUOUS',
      status: 409,
      memberships: [
        { tenantId: 'tenant-1', displayName: 'Tenant One', role: 'organization_admin' },
        { tenantId: 'tenant-2', displayName: 'Tenant Two', role: 'member' },
      ],
    });
  });

  it('S1-A5-NT-018 denies a client tenant override rejected by A1', async () => {
    authority.deriveTenant.mockRejectedValue(new SupabaseAuthorityError('TENANT_OVERRIDE_DENIED', 403));
    await expect(authenticateWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001', 'x-provenance-tenant': 'tenant-other' }, { pv_access_token: 'verified-token' }))).rejects.toMatchObject({ code: 'DENY_TENANT_UNAUTHORIZED' });
  });

  it('S1-A5-NT-019 denies normal-request service-role bypass failure', async () => {
    authority.consumeQuota.mockRejectedValue(new SupabaseAuthorityError('SERVICE_ROLE_BOUNDARY_INVALID', 503));
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_AUTHORITY_UNAVAILABLE' });
  });

  it('S1-A5-NT-020 fails closed when mandatory audit persistence fails', async () => {
    authority.authorizeAndAudit.mockRejectedValue(new SupabaseAuthorityError('AUDIT_PERSISTENCE_FAILED', 503));
    await expect(authorizeWave1Request(request({ 'x-correlation-id': '00000000-0000-4000-8000-000000000001' }, { pv_access_token: 'verified-token' }), { action: 'tenant_resource/read', resourceType: 'tenant' })).rejects.toMatchObject({ code: 'DENY_AUDIT_PERSISTENCE' });
  });
});
