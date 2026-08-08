import 'server-only';

import { getAuthorityRuntimeConfig } from './config';

export const A1_WAVE1_PRODUCER_COMMIT = '79204ec9733062725aaf0e0d6cdfe560cb4a9444' as const;
export const A1_WAVE1_RPC_NAMESPACE = 'provenance_api' as const;

export class A1Wave1RpcError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, status = 503) {
    super(code);
    this.name = 'A1Wave1RpcError';
    this.code = code;
    this.status = status;
  }
}

type BigIntJson = number | string;

export interface A1ResolveActorIdentityRow {
  outcome: 'RESOLVED' | 'DENY';
  reason_code: string | null;
  actor_id: string | null;
  actor_type: 'user' | 'workload' | null;
  session_id_or_workload_id: string | null;
  authentication_strength: string | null;
  issued_at: string | null;
  correlation_id: string;
  authority_version: BigIntJson | null;
}

export interface A1DeriveTenantContextRow {
  outcome: 'RESOLVED' | 'DENY';
  reason_code: string | null;
  tenant_id: string | null;
  actor_id: string | null;
  membership_id: string | null;
  derivation_source: string;
  derived_at: string;
  correlation_id: string;
  role: string | null;
  membership_status: string | null;
  authority_version: BigIntJson | null;
}

export interface A1AuthorizeAndAuditRow {
  decision_id: string;
  outcome: 'ALLOW' | 'DENY';
  reason_code: string | null;
  actor_id: string | null;
  tenant_id: string | null;
  action: string;
  resource_type: string;
  resource_id: string;
  policy_version: string;
  authority_version: BigIntJson | null;
  decided_at: string;
  correlation_id: string;
}

export interface A1ClaimIdempotencyRow {
  status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'DENIED';
  replay: boolean;
  reason_code: string | null;
  key: string;
  actor_id: string | null;
  tenant_id: string | null;
  operation: string;
  request_digest: string;
  result_reference: string | null;
  first_seen_at: string | null;
  expires_at: string;
  correlation_id: string;
}

export interface A1CompleteIdempotencyRow {
  status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'DENIED';
  replay: boolean;
  reason_code: string | null;
  key: string;
  actor_id: string | null;
  tenant_id: string | null;
  operation: string;
  request_digest: string;
  result_reference: string | null;
  completed_at: string | null;
  correlation_id: string;
}

function rpcHeaders(accessToken: string): HeadersInit {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabasePublishableKey) {
    throw new A1Wave1RpcError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  }
  return {
    apikey: config.supabasePublishableKey,
    authorization: `Bearer ${accessToken}`,
    'content-type': 'application/json',
    'content-profile': A1_WAVE1_RPC_NAMESPACE,
    'accept-profile': A1_WAVE1_RPC_NAMESPACE,
  };
}

async function parseRpcResponse<T>(response: Response): Promise<T> {
  const body = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    const providerCode = typeof body.code === 'string' ? body.code.toUpperCase() : '';
    if (response.status === 401) throw new A1Wave1RpcError('AUTHENTICATION_INVALID', 401);
    if (response.status === 403) throw new A1Wave1RpcError('AUTHORITY_DENIED', 403);
    if (response.status === 409 || providerCode.includes('CONFLICT')) {
      throw new A1Wave1RpcError(providerCode || 'AUTHORITY_CONFLICT', 409);
    }
    if (response.status === 429) throw new A1Wave1RpcError('AUTHORITY_RATE_LIMITED', 429);
    throw new A1Wave1RpcError('AUTHORITY_DEPENDENCY_UNAVAILABLE', response.status >= 500 ? 503 : 400);
  }
  return body as T;
}

function firstRow<T>(value: T | T[]): T {
  if (!Array.isArray(value)) return value;
  if (value.length !== 1) throw new A1Wave1RpcError('AUTHORITY_RESULT_CARDINALITY_INVALID', 503);
  return value[0];
}

async function callA1Rpc<T>(accessToken: string, functionName: string, parameters: Record<string, unknown>): Promise<T> {
  const config = getAuthorityRuntimeConfig();
  if (!config.supabaseUrl) throw new A1Wave1RpcError('AUTHORITY_CONFIGURATION_UNAVAILABLE', 503);
  const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${encodeURIComponent(functionName)}`, {
    method: 'POST',
    headers: rpcHeaders(accessToken),
    body: JSON.stringify(parameters),
    cache: 'no-store',
  });
  return firstRow(await parseRpcResponse<T | T[]>(response));
}

export function authorityVersionNumber(value: BigIntJson | null, code = 'AUTHORITY_VERSION_INVALID'): number {
  const parsed = typeof value === 'string' ? Number(value) : value;
  if (parsed === null || !Number.isSafeInteger(parsed) || parsed < 0) {
    throw new A1Wave1RpcError(code, 503);
  }
  return parsed;
}

export function resolveActorIdentityRpc(accessToken: string, correlationId: string): Promise<A1ResolveActorIdentityRow> {
  return callA1Rpc(accessToken, 'resolve_actor_identity', {
    p_correlation_id: correlationId,
  });
}

export function deriveTenantContextRpc(
  accessToken: string,
  tenantHint: string | undefined,
  correlationId: string,
): Promise<A1DeriveTenantContextRow> {
  return callA1Rpc(accessToken, 'derive_tenant_context', {
    p_tenant_hint: tenantHint ?? null,
    p_correlation_id: correlationId,
  });
}

export function authorizeAndAuditRpc(
  accessToken: string,
  input: {
    action: string;
    resourceType: string;
    resourceId: string;
    resourceTenantId: string;
    tenantHint?: string;
    expectedAuthorityVersion?: number;
    correlationId: string;
    metadataDigest?: string;
  },
): Promise<A1AuthorizeAndAuditRow> {
  return callA1Rpc(accessToken, 'authorize_and_audit', {
    p_action: input.action,
    p_resource_type: input.resourceType,
    p_resource_id: input.resourceId,
    p_resource_tenant_id: input.resourceTenantId,
    p_tenant_hint: input.tenantHint ?? null,
    p_expected_authority_version: input.expectedAuthorityVersion ?? null,
    p_correlation_id: input.correlationId,
    p_metadata_digest: input.metadataDigest ?? null,
  });
}

export function claimIdempotencyKeyRpc(
  accessToken: string,
  input: {
    key: string;
    operation: string;
    requestDigest: string;
    tenantHint?: string;
    expiresAt?: string;
    correlationId: string;
  },
): Promise<A1ClaimIdempotencyRow> {
  return callA1Rpc(accessToken, 'claim_idempotency_key', {
    p_key: input.key,
    p_operation: input.operation,
    p_request_digest: input.requestDigest,
    p_tenant_hint: input.tenantHint ?? null,
    ...(input.expiresAt ? { p_expires_at: input.expiresAt } : {}),
    p_correlation_id: input.correlationId,
  });
}

export function completeIdempotencyKeyRpc(
  accessToken: string,
  input: {
    key: string;
    operation: string;
    requestDigest: string;
    resultReference: string;
    tenantHint?: string;
    correlationId: string;
  },
): Promise<A1CompleteIdempotencyRow> {
  return callA1Rpc(accessToken, 'complete_idempotency_key', {
    p_key: input.key,
    p_operation: input.operation,
    p_request_digest: input.requestDigest,
    p_result_reference: input.resultReference,
    p_tenant_hint: input.tenantHint ?? null,
    p_correlation_id: input.correlationId,
  });
}

export const A1_WAVE1_RPC_SIGNATURES = {
  resolve_actor_identity: {
    parameters: ['p_correlation_id uuid DEFAULT gen_random_uuid()'],
    returns: ['outcome','reason_code','actor_id','actor_type','session_id_or_workload_id','authentication_strength','issued_at','correlation_id','authority_version'],
  },
  derive_tenant_context: {
    parameters: ['p_tenant_hint text DEFAULT NULL','p_correlation_id uuid DEFAULT gen_random_uuid()'],
    returns: ['outcome','reason_code','tenant_id','actor_id','membership_id','derivation_source','derived_at','correlation_id','role','membership_status','authority_version'],
  },
  authorize_and_audit: {
    parameters: ['p_action text','p_resource_type text','p_resource_id text','p_resource_tenant_id text','p_tenant_hint text DEFAULT NULL','p_expected_authority_version bigint DEFAULT NULL','p_correlation_id uuid DEFAULT gen_random_uuid()','p_metadata_digest text DEFAULT NULL'],
    returns: ['decision_id','outcome','reason_code','actor_id','tenant_id','action','resource_type','resource_id','policy_version','authority_version','decided_at','correlation_id'],
  },
  claim_idempotency_key: {
    parameters: ['p_key text','p_operation text','p_request_digest text','p_tenant_hint text DEFAULT NULL',"p_expires_at timestamptz DEFAULT (now() + interval '24 hours')",'p_correlation_id uuid DEFAULT gen_random_uuid()'],
    returns: ['status','replay','reason_code','key','actor_id','tenant_id','operation','request_digest','result_reference','first_seen_at','expires_at','correlation_id'],
  },
  complete_idempotency_key: {
    parameters: ['p_key text','p_operation text','p_request_digest text','p_result_reference text','p_tenant_hint text DEFAULT NULL','p_correlation_id uuid DEFAULT gen_random_uuid()'],
    returns: ['status','replay','reason_code','key','actor_id','tenant_id','operation','request_digest','result_reference','completed_at','correlation_id'],
  },
} as const;
