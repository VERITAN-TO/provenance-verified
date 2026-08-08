export type ApprovedPublicErrorCode =
  | 'DENY_UNAUTHENTICATED'
  | 'DENY_ACTOR_UNKNOWN'
  | 'DENY_MEMBERSHIP_INACTIVE'
  | 'DENY_TENANT_AMBIGUOUS'
  | 'DENY_TENANT_UNAUTHORIZED'
  | 'DENY_AUTHORITY_VERSION_CONFLICT'
  | 'DENY_RESOURCE_TENANT_MISMATCH'
  | 'DENY_MFA_REQUIRED'
  | 'DENY_RATE_LIMITED'
  | 'DENY_IDEMPOTENCY_CONFLICT'
  | 'DENY_AUDIT_PERSISTENCE'
  | 'DENY_VALIDATION'
  | 'DENY_ROLE'
  | 'DENY_ACTION'
  | 'DENY_AUTHORITY_UNAVAILABLE';

export type PublicErrorEnvelope = {
  ok: false;
  code: ApprovedPublicErrorCode;
  message: string;
  correlation_id: string;
  retryable: boolean;
  denied: true;
};

export type ServerDiagnosticRecord = {
  correlationId: string;
  timestamp: string;
  endpoint: string;
  internalErrorClass: string;
  category: 'AUTHENTICATION'|'AUTHORIZATION'|'DATABASE'|'PROVIDER'|'NETWORK'|'TIMEOUT'|'RATE_LIMIT'|'AUDIT'|'IDEMPOTENCY'|'VALIDATION'|'UNEXPECTED';
};

const SAFE_MESSAGES: Record<ApprovedPublicErrorCode, string> = {
  DENY_UNAUTHENTICATED: 'Authentication is required.',
  DENY_ACTOR_UNKNOWN: 'The authenticated identity is not authorized.',
  DENY_MEMBERSHIP_INACTIVE: 'An active organization membership is required.',
  DENY_TENANT_AMBIGUOUS: 'Select one eligible organization to continue.',
  DENY_TENANT_UNAUTHORIZED: 'The requested organization is not authorized.',
  DENY_AUTHORITY_VERSION_CONFLICT: 'Authorization state changed. Retry with a current session.',
  DENY_RESOURCE_TENANT_MISMATCH: 'The requested resource is outside the authorized organization.',
  DENY_MFA_REQUIRED: 'Additional authentication is required.',
  DENY_RATE_LIMITED: 'Request limit reached. Try again later.',
  DENY_IDEMPOTENCY_CONFLICT: 'The idempotency key conflicts with an earlier request.',
  DENY_AUDIT_PERSISTENCE: 'The operation could not be recorded and was not completed.',
  DENY_VALIDATION: 'The request is invalid.',
  DENY_ROLE: 'The current role is not authorized for this action.',
  DENY_ACTION: 'This action is not authorized.',
  DENY_AUTHORITY_UNAVAILABLE: 'Authorization is temporarily unavailable.',
};

const STATUS: Record<ApprovedPublicErrorCode, number> = {
  DENY_UNAUTHENTICATED: 401,
  DENY_ACTOR_UNKNOWN: 403,
  DENY_MEMBERSHIP_INACTIVE: 403,
  DENY_TENANT_AMBIGUOUS: 409,
  DENY_TENANT_UNAUTHORIZED: 403,
  DENY_AUTHORITY_VERSION_CONFLICT: 409,
  DENY_RESOURCE_TENANT_MISMATCH: 403,
  DENY_MFA_REQUIRED: 403,
  DENY_RATE_LIMITED: 429,
  DENY_IDEMPOTENCY_CONFLICT: 409,
  DENY_AUDIT_PERSISTENCE: 503,
  DENY_VALIDATION: 422,
  DENY_ROLE: 403,
  DENY_ACTION: 403,
  DENY_AUTHORITY_UNAVAILABLE: 503,
};

const RETRYABLE = new Set<ApprovedPublicErrorCode>([
  'DENY_AUTHORITY_VERSION_CONFLICT','DENY_AUTHORITY_UNAVAILABLE','DENY_RATE_LIMITED','DENY_AUDIT_PERSISTENCE',
]);
const APPROVED = new Set<ApprovedPublicErrorCode>(Object.keys(SAFE_MESSAGES) as ApprovedPublicErrorCode[]);

type ErrorLike = { code?: unknown; status?: unknown; name?: unknown; message?: unknown; correlationId?: unknown };
const record = (value: unknown): ErrorLike | null => typeof value === 'object' && value !== null ? value as ErrorLike : null;
const stringValue = (value: unknown): string => typeof value === 'string' ? value : '';

function rawClassificationText(error: unknown): string {
  if (typeof error === 'string') return error.toUpperCase();
  const value = record(error);
  return [value?.code, value?.name, value?.message].map(stringValue).join(' ').toUpperCase();
}

function approvedCode(error: unknown): ApprovedPublicErrorCode | null {
  const value = record(error);
  const code = stringValue(value?.code).toUpperCase() as ApprovedPublicErrorCode;
  return APPROVED.has(code) ? code : null;
}

export function classifyPublicError(error: unknown): ApprovedPublicErrorCode {
  const existing = approvedCode(error);
  if (existing) return existing;
  const source = rawClassificationText(error);
  const status = Number(record(error)?.status ?? 0);
  if (/RATE|QUOTA|TOO MANY/.test(source) || status === 429) return 'DENY_RATE_LIMITED';
  if (/AUDIT/.test(source)) return 'DENY_AUDIT_PERSISTENCE';
  if (/IDEMPOTENCY|FINGERPRINT/.test(source)) return 'DENY_IDEMPOTENCY_CONFLICT';
  if (/RESOURCE[_ -]?TENANT|TENANT[_ -]?MISMATCH/.test(source)) return 'DENY_RESOURCE_TENANT_MISMATCH';
  if (/TENANT[_ -]?AMBIGUOUS|TENANT[_ -]?SELECTION/.test(source)) return 'DENY_TENANT_AMBIGUOUS';
  if (/VERSION/.test(source)) return 'DENY_AUTHORITY_VERSION_CONFLICT';
  if (/MFA|AAL2/.test(source)) return 'DENY_MFA_REQUIRED';
  if (/ACTOR/.test(source)) return 'DENY_ACTOR_UNKNOWN';
  if (/MEMBERSHIP/.test(source)) return 'DENY_MEMBERSHIP_INACTIVE';
  if (/TENANT|RLS/.test(source)) return 'DENY_TENANT_UNAUTHORIZED';
  if (/SERVICE_ROLE_BOUNDARY/.test(source)) return 'DENY_AUTHORITY_UNAVAILABLE';
  if (/ROLE/.test(source)) return 'DENY_ROLE';
  if (/ACTION|PERMISSION/.test(source)) return 'DENY_ACTION';
  if (/VALIDATION|INVALID REQUEST|ZOD/.test(source) || status === 400 || status === 422) return 'DENY_VALIDATION';
  if (/AUTHENTICATION|SESSION|TOKEN|JWT|COOKIE/.test(source) && status < 500) return 'DENY_UNAUTHENTICATED';
  return 'DENY_AUTHORITY_UNAVAILABLE';
}

function diagnosticCategory(error: unknown, code: ApprovedPublicErrorCode): ServerDiagnosticRecord['category'] {
  const source = rawClassificationText(error);
  if (code === 'DENY_UNAUTHENTICATED' || code === 'DENY_MFA_REQUIRED') return 'AUTHENTICATION';
  if (code === 'DENY_RATE_LIMITED') return 'RATE_LIMIT';
  if (code === 'DENY_AUDIT_PERSISTENCE') return 'AUDIT';
  if (code === 'DENY_IDEMPOTENCY_CONFLICT') return 'IDEMPOTENCY';
  if (code === 'DENY_VALIDATION') return 'VALIDATION';
  if (/POSTGRES|DATABASE|SQL|CONSTRAINT|RPC/.test(source)) return 'DATABASE';
  if (/PROVIDER|SUPABASE|AUTH0|OIDC/.test(source)) return 'PROVIDER';
  if (/TIMEOUT|ABORT/.test(source)) return 'TIMEOUT';
  if (/NETWORK|FETCH|DNS|ECONN/.test(source)) return 'NETWORK';
  if (code !== 'DENY_AUTHORITY_UNAVAILABLE') return 'AUTHORIZATION';
  return 'UNEXPECTED';
}

function internalClass(error: unknown): string {
  if (error instanceof Error) return error.constructor?.name || error.name || 'Error';
  if (typeof error === 'string') return 'StringThrow';
  if (typeof error === 'object' && error !== null) return 'ObjectThrow';
  return `${typeof error}Throw`;
}

export function mapPublicAuthorityError(
  error: unknown,
  input: { correlationId: string; endpoint: string; timestamp?: string },
): { public: PublicErrorEnvelope; status: number; diagnostic: ServerDiagnosticRecord } {
  const code = classifyPublicError(error);
  const publicEnvelope: PublicErrorEnvelope = {
    ok: false,
    code,
    message: SAFE_MESSAGES[code],
    correlation_id: input.correlationId,
    retryable: RETRYABLE.has(code),
    denied: true,
  };
  return {
    public: publicEnvelope,
    status: STATUS[code],
    diagnostic: {
      correlationId: input.correlationId,
      timestamp: input.timestamp ?? new Date().toISOString(),
      endpoint: input.endpoint,
      internalErrorClass: internalClass(error),
      category: diagnosticCategory(error, code),
    },
  };
}

export function recordServerDiagnostic(
  diagnostic: ServerDiagnosticRecord,
  sink: (event: string, record: ServerDiagnosticRecord) => void = (event, recordValue) => console.error(event, JSON.stringify(recordValue)),
): void {
  sink('wave1_authority_error', diagnostic);
}
