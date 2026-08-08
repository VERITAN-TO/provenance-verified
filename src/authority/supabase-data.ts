import 'server-only';

import { getAuthorityRuntimeConfig } from './config';
import {
  A1_WAVE1_PRODUCER_COMMIT,
  A1_WAVE1_RPC_SIGNATURES,
  A1Wave1RpcError,
  authorityVersionNumber,
  authorizeAndAuditRpc,
  claimIdempotencyKeyRpc,
  completeIdempotencyKeyRpc,
  deriveTenantContextRpc,
  resolveActorIdentityRpc,
} from './a1-wave1-rpc-adapter';
import type {
  ActorIdentityContract,
  AuthorizationDecisionContract,
  TenantContextContract,
  Wave1Role,
} from './wave1-contracts';
import { WAVE1_CONTRACT_VERSION } from './wave1-contracts';

export class SupabaseAuthorityError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, status = 503) {
    super(code);
    this.name = 'SupabaseAuthorityError';
    this.code = code;
    this.status = status;
  }
}

function fromA1Error(error: unknown): never {
  if (error instanceof SupabaseAuthorityError) throw error;
  if (error instanceof A1Wave1RpcError) throw new SupabaseAuthorityError(error.code, error.status);
  throw new SupabaseAuthorityError('AUTHORITY_DEPENDENCY_UNAVAILABLE', 503);
}

function userHeaders(accessToken: string): HeadersInit {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabasePublishableKey) throw new SupabaseAuthorityError('AUTHORITY_CONFIGURATION_UNAVAILABLE');
  return {
    apikey: config.supabasePublishableKey,
    authorization: `Bearer ${accessToken}`,
    'content-type': 'application/json',
  };
}

function serviceRoleHeaders(): HeadersInit {
  const serviceKey = process.env.PV_SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!serviceKey) throw new SupabaseAuthorityError('SERVICE_ROLE_BOUNDARY_UNAVAILABLE');
  return {
    apikey: serviceKey,
    authorization: `Bearer ${serviceKey}`,
    'content-type': 'application/json',
  };
}

async function parse<T>(response: Response): Promise<T> {
  const body = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    const providerCode = typeof body.code === 'string' ? body.code.toUpperCase() : '';
    if (response.status === 409 || providerCode.includes('CONFLICT')) {
      throw new SupabaseAuthorityError(providerCode || 'AUTHORITY_CONFLICT', 409);
    }
    if (response.status === 429 || providerCode.includes('QUOTA') || providerCode.includes('RATE')) {
      throw new SupabaseAuthorityError(providerCode || 'AUTHORITY_RATE_LIMITED', 429);
    }
    if (response.status === 401 || response.status === 403) {
      throw new SupabaseAuthorityError(providerCode || 'AUTHORITY_DENIED', response.status);
    }
    throw new SupabaseAuthorityError('AUTHORITY_DEPENDENCY_UNAVAILABLE', response.status >= 500 ? 503 : 400);
  }
  return body as T;
}

async function callServiceRoleRpc<T>(name: string, parameters: Record<string, unknown>): Promise<T> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthorityError('AUTHORITY_CONFIGURATION_UNAVAILABLE');
  const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${encodeURIComponent(name)}`, {
    method: 'POST',
    headers: serviceRoleHeaders(),
    body: JSON.stringify(parameters),
    cache: 'no-store',
  });
  return parse<T>(response);
}

function isWave1Role(value: string | null): value is Wave1Role {
  return value === 'organization_owner'
    || value === 'organization_admin'
    || value === 'operator'
    || value === 'reviewer'
    || value === 'member';
}

export async function resolveActorIdentity(accessToken: string, correlationId: string): Promise<ActorIdentityContract> {
  try {
    const result = await resolveActorIdentityRpc(accessToken, correlationId);
    if (result.outcome !== 'RESOLVED') throw new SupabaseAuthorityError(result.reason_code || 'ACTOR_UNKNOWN', 403);
    if (!result.actor_id || !result.actor_type || !result.session_id_or_workload_id || !result.authentication_strength) {
      throw new SupabaseAuthorityError('ACTOR_IDENTITY_INVALID', 503);
    }
    if (result.correlation_id !== correlationId) throw new SupabaseAuthorityError('CORRELATION_MISMATCH', 503);
    return {
      outcome: 'RESOLVED',
      reason_code: null,
      actor_id: result.actor_id,
      actor_type: result.actor_type,
      session_id_or_workload_id: result.session_id_or_workload_id,
      authentication_strength: result.authentication_strength,
      issued_at: result.issued_at,
      correlation_id: result.correlation_id,
      authority_version: authorityVersionNumber(result.authority_version),
    };
  } catch (error) {
    return fromA1Error(error);
  }
}

export async function deriveTenantContext(
  accessToken: string,
  expectedActorId: string,
  tenantHint: string | undefined,
  correlationId: string,
): Promise<TenantContextContract> {
  try {
    const result = await deriveTenantContextRpc(accessToken, tenantHint, correlationId);
    if (result.outcome !== 'RESOLVED') throw new SupabaseAuthorityError(result.reason_code || 'TENANT_UNAUTHORIZED', 403);
    if (!result.tenant_id || !result.actor_id || !result.membership_id || !isWave1Role(result.role)) {
      throw new SupabaseAuthorityError('TENANT_CONTEXT_INVALID', 503);
    }
    if (result.actor_id !== expectedActorId || result.correlation_id !== correlationId) {
      throw new SupabaseAuthorityError('TENANT_CONTEXT_BINDING_INVALID', 503);
    }
    if (result.membership_status !== 'active') throw new SupabaseAuthorityError('MEMBERSHIP_INACTIVE', 403);
    return {
      outcome: 'RESOLVED',
      reason_code: null,
      tenant_id: result.tenant_id,
      actor_id: result.actor_id,
      membership_id: result.membership_id,
      derivation_source: result.derivation_source,
      derived_at: result.derived_at,
      correlation_id: result.correlation_id,
      role: result.role,
      membership_status: 'active',
      authority_version: authorityVersionNumber(result.authority_version),
    };
  } catch (error) {
    return fromA1Error(error);
  }
}

export interface AuthorizationInput {
  actorId: string;
  tenantId: string;
  role: Wave1Role;
  action: string;
  resourceType: string;
  resourceId: string;
  resourceTenantId: string;
  expectedAuthorityVersion: number;
  correlationId: string;
  metadataDigest: string;
}

export async function authorizeAndAudit(accessToken: string, input: AuthorizationInput): Promise<AuthorizationDecisionContract> {
  try {
    const result = await authorizeAndAuditRpc(accessToken, {
      action: input.action,
      resourceType: input.resourceType,
      resourceId: input.resourceId,
      resourceTenantId: input.resourceTenantId,
      tenantHint: input.tenantId,
      expectedAuthorityVersion: input.expectedAuthorityVersion,
      correlationId: input.correlationId,
      metadataDigest: input.metadataDigest,
    });
    const authorityVersion = authorityVersionNumber(result.authority_version);
    if (!result.decision_id || !result.actor_id || !result.tenant_id) {
      throw new SupabaseAuthorityError('AUTHORIZATION_DECISION_INVALID', 503);
    }
    if (
      result.actor_id !== input.actorId
      || result.tenant_id !== input.tenantId
      || result.action !== input.action
      || result.resource_type !== input.resourceType
      || result.resource_id !== input.resourceId
      || result.correlation_id !== input.correlationId
    ) {
      throw new SupabaseAuthorityError('AUTHORIZATION_DECISION_BINDING_INVALID', 503);
    }
    if (result.policy_version !== WAVE1_CONTRACT_VERSION) {
      throw new SupabaseAuthorityError('AUTHORITY_VERSION_CONFLICT', 409);
    }
    return {
      decision_id: result.decision_id,
      outcome: result.outcome,
      reason_code: result.reason_code,
      actor_id: result.actor_id,
      tenant_id: result.tenant_id,
      action: result.action,
      resource_type: result.resource_type,
      resource_id: result.resource_id,
      policy_version: WAVE1_CONTRACT_VERSION,
      authority_version: authorityVersion,
      decided_at: result.decided_at,
      correlation_id: result.correlation_id,
    };
  } catch (error) {
    return fromA1Error(error);
  }
}

export interface TenantReadRecord {
  id: string;
  legal_name?: string;
  display_name?: string;
  status?: string;
  [key: string]: unknown;
}

export async function readAuthorizedTenant(accessToken: string, tenantId: string): Promise<TenantReadRecord> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthorityError('AUTHORITY_CONFIGURATION_UNAVAILABLE');
  const query = new URLSearchParams({ select: 'id,legal_name,display_name,status', id: `eq.${tenantId}`, limit: '2' });
  const response = await fetch(`${config.supabaseUrl}/rest/v1/pv_tenants?${query}`, {
    headers: userHeaders(accessToken),
    cache: 'no-store',
  });
  const rows = await parse<TenantReadRecord[]>(response);
  if (rows.length !== 1 || rows[0].id !== tenantId) throw new SupabaseAuthorityError('RLS_RESOURCE_NOT_VISIBLE', 403);
  return rows[0];
}

export interface QuotaReceipt {
  limit: number;
  burst: number;
  used: number;
  remaining: number;
  windowStartedAt: string;
  windowSeconds: number;
}

/** Service-role use is confined to the distributed quota RPC. */
export async function consumeApiQuota(tenantId: string, actorId: string, operation: string): Promise<QuotaReceipt> {
  if (!tenantId || !actorId || !operation) throw new SupabaseAuthorityError('SERVICE_ROLE_BOUNDARY_INVALID', 503);
  return callServiceRoleRpc<QuotaReceipt>('pv_r3_consume_api_quota', {
    p_tenant: tenantId,
    p_principal: actorId,
    p_operation: operation,
  });
}

export async function consumePreAuthenticationQuota(principalDigest: string): Promise<QuotaReceipt> {
  const platformTenantId = process.env.PV_AUTH_PLATFORM_TENANT_ID?.trim();
  if (!platformTenantId) throw new SupabaseAuthorityError('PREAUTH_QUOTA_UNAVAILABLE');
  return consumeApiQuota(platformTenantId, principalDigest, 'auth/sign-in');
}

export interface IdempotencyClaim {
  status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  replay: boolean;
  result_reference?: string | null;
}

export async function claimIdempotency(
  accessToken: string,
  input: { key: string; actorId: string; tenantId: string; operation: string; requestDigest: string; correlationId: string },
): Promise<IdempotencyClaim> {
  try {
    const result = await claimIdempotencyKeyRpc(accessToken, {
      key: input.key,
      operation: input.operation,
      requestDigest: input.requestDigest,
      tenantHint: input.tenantId,
      correlationId: input.correlationId,
    });
    if (result.status === 'DENIED' || result.reason_code) {
      throw new SupabaseAuthorityError(result.reason_code || 'PV_IDEMPOTENCY_DENIED', 409);
    }
    if (
      result.actor_id !== input.actorId
      || result.tenant_id !== input.tenantId
      || result.operation !== input.operation
      || result.request_digest !== input.requestDigest
      || result.correlation_id !== input.correlationId
    ) {
      throw new SupabaseAuthorityError('PV_IDEMPOTENCY_BINDING_INVALID', 503);
    }
    return { status: result.status, replay: result.replay, result_reference: result.result_reference };
  } catch (error) {
    return fromA1Error(error);
  }
}

export async function completeIdempotency(
  accessToken: string,
  input: { key: string; actorId: string; tenantId: string; operation: string; requestDigest: string; resultReference: string; correlationId: string },
): Promise<IdempotencyClaim> {
  try {
    const result = await completeIdempotencyKeyRpc(accessToken, {
      key: input.key,
      operation: input.operation,
      requestDigest: input.requestDigest,
      resultReference: input.resultReference,
      tenantHint: input.tenantId,
      correlationId: input.correlationId,
    });
    if (result.status === 'DENIED' || result.reason_code) {
      throw new SupabaseAuthorityError(result.reason_code || 'PV_IDEMPOTENCY_DENIED', 409);
    }
    if (
      result.actor_id !== input.actorId
      || result.tenant_id !== input.tenantId
      || result.operation !== input.operation
      || result.request_digest !== input.requestDigest
      || result.result_reference !== input.resultReference
      || result.correlation_id !== input.correlationId
    ) {
      throw new SupabaseAuthorityError('PV_IDEMPOTENCY_BINDING_INVALID', 503);
    }
    return { status: result.status, replay: result.replay, result_reference: result.result_reference };
  } catch (error) {
    return fromA1Error(error);
  }
}

export const A1_RPC_SIGNATURE_DEPENDENCY = {
  producerCommit: A1_WAVE1_PRODUCER_COMMIT,
  namespace: 'provenance_api',
  signatures: A1_WAVE1_RPC_SIGNATURES,
  disposition: 'CLOSED_WITH_A5_ADAPTER',
} as const;

// Legacy membership projection retained only for non-targeted routes pending later packets.
export interface MembershipRecord {
  tenant_id: string;
  user_id: string;
  role: string;
  status: 'active' | 'inactive' | 'suspended' | 'revoked';
  location_ids: string[];
  display_name: string;
}

interface MembershipAuthorityRow {
  tenant_id: string;
  user_id: string;
  role?: string | null;
  status?: string | null;
  authority_role?: string | null;
  lifecycle_status?: string | null;
  location_ids?: string[] | null;
  display_name?: string | null;
}

export async function listMemberships(accessToken: string, userId: string): Promise<MembershipRecord[]> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new SupabaseAuthorityError('AUTHORITY_CONFIGURATION_UNAVAILABLE');
  const query = new URLSearchParams({
    select: 'tenant_id,user_id,role,status,authority_role,lifecycle_status,location_ids,display_name',
    user_id: `eq.${userId}`,
  });
  const response = await fetch(`${config.supabaseUrl}/rest/v1/pv_memberships?${query}`, {
    headers: userHeaders(accessToken),
    cache: 'no-store',
  });
  const rows = await parse<MembershipAuthorityRow[]>(response);
  return rows.map((row) => ({
    tenant_id: row.tenant_id,
    user_id: row.user_id,
    role: row.authority_role ?? row.role ?? 'member',
    status: (row.lifecycle_status ?? row.status ?? 'inactive') as MembershipRecord['status'],
    location_ids: row.location_ids ?? [],
    display_name: row.display_name ?? row.tenant_id,
  }));
}
