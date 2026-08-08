import { createHash, randomUUID } from 'node:crypto';

export const WAVE1_CONTRACT_VERSION = 'v1-wave1' as const;

export type Wave1Role =
  | 'organization_owner'
  | 'organization_admin'
  | 'operator'
  | 'reviewer'
  | 'member';

export type Wave1DenialCode =
  | 'DENY_UNAUTHENTICATED'
  | 'DENY_ACTOR_UNKNOWN'
  | 'DENY_MEMBERSHIP_INACTIVE'
  | 'DENY_TENANT_UNAUTHORIZED'
  | 'DENY_TENANT_AMBIGUOUS'
  | 'DENY_ROLE'
  | 'DENY_ACTION'
  | 'DENY_RESOURCE_TENANT_MISMATCH'
  | 'DENY_AUTHORITY_VERSION_CONFLICT'
  | 'DENY_AUTHORITY_UNAVAILABLE'
  | 'DENY_MFA_REQUIRED'
  | 'DENY_RATE_LIMITED'
  | 'DENY_IDEMPOTENCY_CONFLICT'
  | 'DENY_VALIDATION'
  | 'DENY_AUDIT_PERSISTENCE';

export interface ActorIdentityContract {
  outcome: 'RESOLVED';
  reason_code: null;
  actor_id: string;
  actor_type: 'user' | 'workload';
  session_id_or_workload_id: string;
  authentication_strength: string;
  issued_at: string | null;
  correlation_id: string;
  authority_version: number;
}

export interface TenantContextContract {
  outcome: 'RESOLVED';
  reason_code: null;
  tenant_id: string;
  actor_id: string;
  membership_id: string;
  derivation_source: string;
  derived_at: string;
  correlation_id: string;
  role: Wave1Role;
  membership_status: 'active';
  authority_version: number;
}

export interface AuthorizationDecisionContract {
  decision_id: string;
  outcome: 'ALLOW' | 'DENY';
  reason_code: string | null;
  actor_id: string;
  tenant_id: string;
  action: string;
  resource_type: string;
  resource_id: string;
  policy_version: typeof WAVE1_CONTRACT_VERSION;
  authority_version: number;
  decided_at: string;
  correlation_id: string;
}

export interface AuthorizedRequestContext {
  accessToken: string;
  actor: ActorIdentityContract;
  tenant: TenantContextContract;
  decision: AuthorizationDecisionContract;
  correlationId: string;
}

export interface EligibleTenantContract {
  tenantId: string;
  displayName: string;
  role: Wave1Role;
}

export interface DenialEnvelope {
  ok: false;
  code: Wave1DenialCode;
  message: string;
  correlation_id: string;
  retryable: boolean;
  denied: true;
  status: number;
  field_errors?: Record<string, string[]>;
}

export interface TenantSelectionEnvelope extends DenialEnvelope {
  code: 'DENY_TENANT_AMBIGUOUS';
  status: 409;
  data: { memberships: EligibleTenantContract[] };
}

const SAFE_MESSAGES: Record<Wave1DenialCode, string> = {
  DENY_UNAUTHENTICATED: 'Authentication is required.',
  DENY_ACTOR_UNKNOWN: 'The authenticated identity is not authorized.',
  DENY_MEMBERSHIP_INACTIVE: 'An active organization membership is required.',
  DENY_TENANT_UNAUTHORIZED: 'The requested organization is not authorized.',
  DENY_TENANT_AMBIGUOUS: 'Select one eligible organization to continue.',
  DENY_ROLE: 'The current role is not authorized for this action.',
  DENY_ACTION: 'This action is not authorized.',
  DENY_RESOURCE_TENANT_MISMATCH: 'The requested resource is outside the authorized organization.',
  DENY_AUTHORITY_VERSION_CONFLICT: 'Authorization state changed. Retry with a current session.',
  DENY_AUTHORITY_UNAVAILABLE: 'Authorization is temporarily unavailable.',
  DENY_MFA_REQUIRED: 'Additional authentication is required.',
  DENY_RATE_LIMITED: 'Request limit reached. Try again later.',
  DENY_IDEMPOTENCY_CONFLICT: 'The idempotency key conflicts with an earlier request.',
  DENY_VALIDATION: 'The request is invalid.',
  DENY_AUDIT_PERSISTENCE: 'The operation could not be recorded and was not completed.',
};

const STATUS_BY_CODE: Record<Wave1DenialCode, number> = {
  DENY_UNAUTHENTICATED: 401,
  DENY_ACTOR_UNKNOWN: 403,
  DENY_MEMBERSHIP_INACTIVE: 403,
  DENY_TENANT_UNAUTHORIZED: 403,
  DENY_TENANT_AMBIGUOUS: 409,
  DENY_ROLE: 403,
  DENY_ACTION: 403,
  DENY_RESOURCE_TENANT_MISMATCH: 403,
  DENY_AUTHORITY_VERSION_CONFLICT: 409,
  DENY_AUTHORITY_UNAVAILABLE: 503,
  DENY_MFA_REQUIRED: 403,
  DENY_RATE_LIMITED: 429,
  DENY_IDEMPOTENCY_CONFLICT: 409,
  DENY_VALIDATION: 422,
  DENY_AUDIT_PERSISTENCE: 503,
};

const RETRYABLE = new Set<Wave1DenialCode>([
  'DENY_AUTHORITY_VERSION_CONFLICT',
  'DENY_AUTHORITY_UNAVAILABLE',
  'DENY_RATE_LIMITED',
  'DENY_AUDIT_PERSISTENCE',
]);

export class Wave1Denied extends Error {
  readonly code: Wave1DenialCode;
  readonly correlationId: string;
  readonly status: number;
  readonly retryable: boolean;
  readonly fieldErrors?: Record<string, string[]>;

  constructor(code: Wave1DenialCode, correlationId: string, fieldErrors?: Record<string, string[]>) {
    super(SAFE_MESSAGES[code]);
    this.name = 'Wave1Denied';
    this.code = code;
    this.correlationId = correlationId;
    this.status = STATUS_BY_CODE[code];
    this.retryable = RETRYABLE.has(code);
    this.fieldErrors = fieldErrors;
  }

  envelope(): DenialEnvelope {
    return {
      ok: false,
      code: this.code,
      message: SAFE_MESSAGES[this.code],
      correlation_id: this.correlationId,
      retryable: this.retryable,
      denied: true,
      status: this.status,
      ...(this.fieldErrors ? { field_errors: this.fieldErrors } : {}),
    };
  }
}

export class Wave1TenantSelectionRequired extends Wave1Denied {
  readonly memberships: EligibleTenantContract[];

  constructor(correlationId: string, memberships: EligibleTenantContract[]) {
    super('DENY_TENANT_AMBIGUOUS', correlationId);
    this.name = 'Wave1TenantSelectionRequired';
    this.memberships = memberships;
  }

  override envelope(): TenantSelectionEnvelope {
    return {
      ...super.envelope(),
      code: 'DENY_TENANT_AMBIGUOUS',
      status: 409,
      data: { memberships: this.memberships },
    };
  }
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TENANT_HINT_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;
const IDEMPOTENCY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$/;

export function correlationIdFromRequest(request: Request): string {
  const candidate = request.headers.get('x-correlation-id')?.trim();
  return candidate && UUID_PATTERN.test(candidate) ? candidate : randomUUID();
}

export function tenantHintFromRequest(request: Request, cookieValue?: string, correlationId?: string): string | undefined {
  const header = request.headers.get('x-provenance-tenant')?.trim();
  const candidate = header || cookieValue?.trim();
  if (!candidate) return undefined;
  if (!TENANT_HINT_PATTERN.test(candidate)) {
    throw new Wave1Denied('DENY_TENANT_UNAUTHORIZED', correlationId ?? correlationIdFromRequest(request));
  }
  return candidate;
}

function canonicalize(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(',')}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record).sort().map((key) => `${JSON.stringify(key)}:${canonicalize(record[key])}`).join(',')}}`;
}

export function requestFingerprint(value: unknown): string {
  return `sha256:${createHash('sha256').update(canonicalize(value)).digest('hex')}`;
}

export function validateIdempotencyKey(value: string | null, correlationId: string): string {
  const key = value?.trim();
  if (!key || !IDEMPOTENCY_PATTERN.test(key)) {
    throw new Wave1Denied('DENY_VALIDATION', correlationId, {
      idempotency_key: ['A 16-128 character idempotency key is required.'],
    });
  }
  return key;
}

export function denialFromAuthorityReason(reason: string | null | undefined, correlationId: string): Wave1Denied {
  const normalized = (reason ?? '').toUpperCase();
  if (normalized.includes('AUDIT')) return new Wave1Denied('DENY_AUDIT_PERSISTENCE', correlationId);
  if (normalized.includes('VERSION')) return new Wave1Denied('DENY_AUTHORITY_VERSION_CONFLICT', correlationId);
  if (normalized.includes('RESOURCE_TENANT') || (normalized.includes('TENANT') && normalized.includes('MISMATCH'))) {
    return new Wave1Denied('DENY_RESOURCE_TENANT_MISMATCH', correlationId);
  }
  if (normalized.includes('ACTOR')) return new Wave1Denied('DENY_ACTOR_UNKNOWN', correlationId);
  if (normalized.includes('MEMBERSHIP')) return new Wave1Denied('DENY_MEMBERSHIP_INACTIVE', correlationId);
  if (normalized.includes('TENANT')) return new Wave1Denied('DENY_TENANT_UNAUTHORIZED', correlationId);
  if (normalized.includes('ROLE')) return new Wave1Denied('DENY_ROLE', correlationId);
  if (normalized.includes('ACTION') || normalized.includes('PERMISSION')) return new Wave1Denied('DENY_ACTION', correlationId);
  if (normalized.includes('UNAVAILABLE')) return new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
  return new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
}
