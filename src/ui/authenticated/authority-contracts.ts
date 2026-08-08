export const SLICE_LOCKED_CONTRACTS = [
  'W1-C01','W1-C02','W1-C03','W1-C04','W1-C05','W1-C06','W1-C07',
] as const;

export type DenialCode =
  | 'DENY_UNAUTHENTICATED' | 'DENY_ACTOR_UNKNOWN' | 'DENY_MEMBERSHIP_INACTIVE'
  | 'DENY_TENANT_UNAUTHORIZED' | 'DENY_TENANT_AMBIGUOUS' | 'DENY_ROLE'
  | 'DENY_ACTION' | 'DENY_RESOURCE_TENANT_MISMATCH'
  | 'DENY_AUTHORITY_VERSION_CONFLICT' | 'DENY_AUTHORITY_UNAVAILABLE'
  | 'DENY_SESSION_EXPIRED' | 'DENY_MFA_REQUIRED' | 'DENY_RATE_LIMITED'
  | 'DENY_VALIDATION' | 'DENY_AUDIT_PERSISTENCE' | 'DENY_IDEMPOTENCY_CONFLICT'
  | 'DENY_MALFORMED_RESPONSE' | 'DENY_NETWORK_FAILURE';

export type SafeDenial = { code: DenialCode; title: string; message: string; retryable: boolean; correlationId?: string };
export type EligibleTenant = { tenantId: string; displayName: string; role: string };
export type AuthorityContext = {
  actor: { actorId: string; displayName?: string };
  tenant: { tenantId: string; displayName: string };
  membership: { membershipId: string; status: 'active'; role: string };
  authorization: { decision: 'ALLOW'; authorityVersion: string };
  session: { sessionId: string; expiresAt: string };
  eligibleTenants: EligibleTenant[];
  navigation: { settings: boolean };
  correlationId: string;
};

const copy: Record<DenialCode, [string,string,boolean]> = {
  DENY_UNAUTHENTICATED:['Sign-in required','The protected session is not authenticated.',false],
  DENY_ACTOR_UNKNOWN:['Identity unavailable','The authenticated identity is not recognized for protected access.',false],
  DENY_MEMBERSHIP_INACTIVE:['Membership inactive','An active organization membership is required.',false],
  DENY_TENANT_UNAUTHORIZED:['Organization unavailable','The requested organization is not authorized for this identity.',false],
  DENY_TENANT_AMBIGUOUS:['Choose an organization','Select one server-returned eligible organization for revalidation.',false],
  DENY_ROLE:['Role not authorized','The effective server-returned role cannot open this protected surface.',false],
  DENY_ACTION:['Action not authorized','The requested action was denied by the server authority boundary.',false],
  DENY_RESOURCE_TENANT_MISMATCH:['Resource unavailable','The requested resource does not belong to the authorized organization context.',false],
  DENY_AUTHORITY_VERSION_CONFLICT:['Authority changed','Your authority context changed. Sign in again to resolve the current version.',false],
  DENY_AUTHORITY_UNAVAILABLE:['Authority service unavailable','The authority service could not safely resolve this request.',true],
  DENY_SESSION_EXPIRED:['Session expired','The protected session expired. Sign in again.',false],
  DENY_MFA_REQUIRED:['Additional authentication required','Complete the authenticator challenge before protected access can continue.',false],
  DENY_RATE_LIMITED:['Request limit reached','Wait briefly before trying this protected request again.',true],
  DENY_VALIDATION:['Check the submitted fields','The request was rejected before authority evaluation.',false],
  DENY_AUDIT_PERSISTENCE:['Operation withheld','The operation could not be recorded and was not completed.',true],
  DENY_IDEMPOTENCY_CONFLICT:['Request conflict','This idempotency key is already bound to a different request.',false],
  DENY_MALFORMED_RESPONSE:['Authority response rejected','The server response was incomplete and was denied safely.',true],
  DENY_NETWORK_FAILURE:['Network unavailable','The authority service could not be reached. No protected content was exposed.',true],
};

export function safeDenial(code: DenialCode, correlationId?: string): SafeDenial {
  const [title,message,retryable] = copy[code];
  return { code,title,message,retryable,correlationId };
}

const object = (v: unknown): Record<string, unknown> | null => typeof v === 'object' && v !== null ? v as Record<string, unknown> : null;
const text = (v: unknown): string | null => typeof v === 'string' && v.trim() ? v.trim() : null;

export function denialFromEnvelope(value: unknown, status?: number): SafeDenial {
  const root = object(value) ?? {};
  const error = object(root.error) ?? root;
  const raw = text(error.code)?.toUpperCase() ?? (status === 401 ? 'DENY_UNAUTHENTICATED' : 'DENY_AUTHORITY_UNAVAILABLE');
  const map: Record<string, DenialCode> = {
    UNAUTHENTICATED:'DENY_UNAUTHENTICATED', ACTOR_UNKNOWN:'DENY_ACTOR_UNKNOWN', MEMBERSHIP_INACTIVE:'DENY_MEMBERSHIP_INACTIVE',
    MEMBERSHIP_SUSPENDED:'DENY_MEMBERSHIP_INACTIVE', MEMBERSHIP_REVOKED:'DENY_MEMBERSHIP_INACTIVE', TENANT_UNAUTHORIZED:'DENY_TENANT_UNAUTHORIZED',
    TENANT_AMBIGUOUS:'DENY_TENANT_AMBIGUOUS', ROLE_DENIED:'DENY_ROLE', ACTION_DENIED:'DENY_ACTION', RESOURCE_TENANT_MISMATCH:'DENY_RESOURCE_TENANT_MISMATCH',
    AUTHORITY_VERSION_CONFLICT:'DENY_AUTHORITY_VERSION_CONFLICT', AUTHORITY_UNAVAILABLE:'DENY_AUTHORITY_UNAVAILABLE', SESSION_EXPIRED:'DENY_SESSION_EXPIRED',
    MFA_REQUIRED:'DENY_MFA_REQUIRED', RATE_LIMITED:'DENY_RATE_LIMITED', VALIDATION:'DENY_VALIDATION', AUDIT_PERSISTENCE:'DENY_AUDIT_PERSISTENCE', IDEMPOTENCY_CONFLICT:'DENY_IDEMPOTENCY_CONFLICT',
  };
  const code = (raw.startsWith('DENY_') ? raw : map[raw]) as DenialCode | undefined;
  const safe = safeDenial(code && copy[code] ? code : 'DENY_AUTHORITY_UNAVAILABLE', text(error.correlation_id) ?? text(root.correlation_id) ?? undefined);
  const retryable = error.retryable === true || root.retryable === true;
  return { ...safe, retryable: safe.retryable && retryable };
}

export function parseEligibleTenants(value: unknown): EligibleTenant[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((item) => {
    const row = object(item); if (!row) return [];
    const tenantId = text(row.tenantId) ?? text(row.tenant_id);
    const displayName = text(row.displayName) ?? text(row.display_name) ?? text(row.name);
    const role = text(row.role);
    return tenantId && displayName && role ? [{ tenantId, displayName, role }] : [];
  });
}

export function parseAuthorityContext(value: unknown): AuthorityContext | null {
  const root = object(value); if (!root) return null;
  const data = object(root.data) ?? root;
  const actor = object(data.actor); const tenant = object(data.tenant); const membership = object(data.membership);
  const authorization = object(data.authorization) ?? object(data.decision); const session = object(data.session);
  const actorId = actor && (text(actor.actorId) ?? text(actor.actor_id) ?? text(actor.id));
  const tenantId = tenant && (text(tenant.tenantId) ?? text(tenant.tenant_id) ?? text(tenant.id));
  const tenantName = tenant && (text(tenant.displayName) ?? text(tenant.display_name) ?? text(tenant.name));
  const membershipId = membership && (text(membership.membershipId) ?? text(membership.membership_id) ?? text(membership.id));
  const membershipStatus = membership && (text(membership.status) ?? text(membership.lifecycle_status));
  const role = membership && text(membership.role);
  const decision = authorization && text(authorization.decision)?.toUpperCase();
  const authorityVersion = authorization && (text(authorization.authorityVersion) ?? text(authorization.authority_version));
  const sessionId = session && (text(session.sessionId) ?? text(session.session_id) ?? text(session.id));
  const expiresAt = session && (text(session.expiresAt) ?? text(session.expires_at));
  const correlationId = text(root.correlation_id) ?? text(data.correlationId) ?? text(data.correlation_id);
  const navigation = object(data.navigation);
  const settingsAuthorized = navigation?.settings === true;
  if (!actorId || !tenantId || !tenantName || !membershipId || membershipStatus !== 'active' || !role || decision !== 'ALLOW' || !authorityVersion || !sessionId || !expiresAt || !correlationId) return null;
  if (!Number.isFinite(Date.parse(expiresAt))) return null;
  return {
    actor:{ actorId, displayName: actor ? text(actor.displayName) ?? text(actor.display_name) ?? undefined : undefined },
    tenant:{ tenantId, displayName:tenantName }, membership:{ membershipId,status:'active',role },
    authorization:{ decision:'ALLOW',authorityVersion }, session:{ sessionId,expiresAt },
    eligibleTenants: parseEligibleTenants(data.eligibleTenants ?? data.eligible_tenants ?? data.memberships),
    navigation: { settings: settingsAuthorized }, correlationId,
  };
}
