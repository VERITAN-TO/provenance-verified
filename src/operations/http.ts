import type { NextRequest } from 'next/server';
import { getAuthorityRuntimeConfig } from '@/authority/config';
import { ACCESS_COOKIE, TENANT_COOKIE, decodeJwtClaims } from '@/authority/cookies';
import { getAuthenticatedUser, verifyAuthenticatedSession } from '@/authority/supabase-auth';
import {
  SupabaseAuthorityError,
  authorizeAndAudit,
  claimIdempotency,
  completeIdempotency,
  consumeApiQuota,
  deriveTenantContext,
  listMemberships,
  resolveActorIdentity,
  type TenantReadRecord,
} from '@/authority/supabase-data';
import {
  WAVE1_CONTRACT_VERSION,
  Wave1Denied,
  Wave1TenantSelectionRequired,
  correlationIdFromRequest,
  denialFromAuthorityReason,
  requestFingerprint,
  tenantHintFromRequest,
  validateIdempotencyKey,
  type ActorIdentityContract,
  type EligibleTenantContract,
  type AuthorizedRequestContext,
  type TenantContextContract,
  type Wave1Role,
} from '@/authority/wave1-contracts';
import { operationalDataset } from './fixtures';
import { authenticateTestModeToken } from './auth';
import type { OperationalSession, OrganizationRole } from './types';
import { mapPublicAuthorityError, recordServerDiagnostic } from './public-error-mapper';

function bearerToken(request: Request): string | undefined {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return undefined;
  const token = authorization.slice('Bearer '.length).trim();
  return token || undefined;
}

function accessTokenFromRequest(request: NextRequest): string | undefined {
  return request.cookies.get(ACCESS_COOKIE)?.value ?? bearerToken(request);
}

const WAVE1_ROLES = new Set<Wave1Role>([
  'organization_owner',
  'organization_admin',
  'operator',
  'reviewer',
  'member',
]);

export async function listEligibleWave1Tenants(accessToken: string, userId: string): Promise<EligibleTenantContract[]> {
  const rows = await listMemberships(accessToken, userId);
  const unique = new Map<string, EligibleTenantContract>();
  for (const row of rows) {
    if (row.status !== 'active' || !WAVE1_ROLES.has(row.role as Wave1Role)) continue;
    unique.set(row.tenant_id, {
      tenantId: row.tenant_id,
      displayName: row.display_name || row.tenant_id,
      role: row.role as Wave1Role,
    });
  }
  return [...unique.values()].sort((left, right) => left.tenantId.localeCompare(right.tenantId));
}

const mappedBoundaryDiagnostics = new WeakMap<Wave1Denied, ReturnType<typeof mapPublicAuthorityError>['diagnostic']>();

function mapBoundaryError(error: unknown, correlationId: string, endpoint = 'wave1-authority-boundary'): Wave1Denied {
  if (error instanceof Wave1Denied) return error;
  const mapped = mapPublicAuthorityError(error, { correlationId, endpoint });
  const denial = new Wave1Denied(mapped.public.code, correlationId);
  mappedBoundaryDiagnostics.set(denial, mapped.diagnostic);
  return denial;
}

export interface Wave1AuthenticationContext {
  accessToken: string;
  actor: ActorIdentityContract;
  tenant: TenantContextContract;
  correlationId: string;
  subject: { id: string; email?: string };
  expiresAt: string;
}

export async function authenticateWave1Request(
  request: NextRequest,
  options: { accessToken?: string; requestedTenantId?: string; enforceAal2?: boolean } = {},
): Promise<Wave1AuthenticationContext> {
  const correlationId = correlationIdFromRequest(request);
  try {
    const config = getAuthorityRuntimeConfig();
    if (config.environment === 'sandbox') throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);

    const accessToken = options.accessToken ?? accessTokenFromRequest(request);
    if (!accessToken) throw new Wave1Denied('DENY_UNAUTHENTICATED', correlationId);

    const verified = await verifyAuthenticatedSession(accessToken);
    if (options.enforceAal2 !== false && config.requireAal2 && verified.claims.aal !== 'aal2') throw new Wave1Denied('DENY_MFA_REQUIRED', correlationId);

    const actor = await resolveActorIdentity(accessToken, correlationId);
    if (actor.session_id_or_workload_id !== verified.claims.session_id && actor.actor_type === 'user') {
      throw new Wave1Denied('DENY_UNAUTHENTICATED', correlationId);
    }

    const cookieTenant = request.cookies.get(TENANT_COOKIE)?.value;
    const requestedTenantId = options.requestedTenantId ?? tenantHintFromRequest(request, cookieTenant, correlationId);
    let tenant: TenantContextContract;
    try {
      tenant = await deriveTenantContext(accessToken, actor.actor_id, requestedTenantId, correlationId);
    } catch (error) {
      if (
        error instanceof SupabaseAuthorityError
        && error.code.toUpperCase().includes('TENANT_AMBIGUOUS')
        && !requestedTenantId
      ) {
        const memberships = await listEligibleWave1Tenants(accessToken, verified.user.id);
        if (memberships.length < 2) throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', correlationId);
        throw new Wave1TenantSelectionRequired(correlationId, memberships);
      }
      throw error;
    }
    if (tenant.membership_status !== 'active') throw new Wave1Denied('DENY_MEMBERSHIP_INACTIVE', correlationId);
    if (requestedTenantId && tenant.tenant_id !== requestedTenantId) throw new Wave1Denied('DENY_TENANT_UNAUTHORIZED', correlationId);

    return {
      accessToken,
      actor,
      tenant,
      correlationId,
      subject: { id: verified.user.id, email: verified.user.email },
      expiresAt: new Date(verified.claims.exp * 1000).toISOString(),
    };
  } catch (error) {
    throw mapBoundaryError(error, correlationId);
  }
}

export interface Wave1AuthorizationTarget {
  action: string;
  resourceType: string;
  resourceId?: string;
  resourceTenantId?: string;
  authorityVersion?: number;
  quotaOperation?: string;
  metadata?: unknown;
}

export async function authorizeWave1Authentication(
  authentication: Wave1AuthenticationContext,
  target: Wave1AuthorizationTarget,
): Promise<AuthorizedRequestContext & { subject: { id: string; email?: string }; expiresAt: string }> {
  try {
    const resourceId = target.resourceId ?? authentication.tenant.tenant_id;
    const resourceTenantId = target.resourceTenantId ?? authentication.tenant.tenant_id;

    await consumeApiQuota(
      authentication.tenant.tenant_id,
      authentication.actor.actor_id,
      target.quotaOperation ?? target.action,
    );

    const decision = await authorizeAndAudit(authentication.accessToken, {
      actorId: authentication.actor.actor_id,
      tenantId: authentication.tenant.tenant_id,
      role: authentication.tenant.role,
      action: target.action,
      resourceType: target.resourceType,
      resourceId,
      resourceTenantId,
      expectedAuthorityVersion: target.authorityVersion ?? authentication.tenant.authority_version,
      correlationId: authentication.correlationId,
      metadataDigest: requestFingerprint(target.metadata ?? { action: target.action, resourceType: target.resourceType, resourceId }),
    });

    if (decision.outcome !== 'ALLOW') throw denialFromAuthorityReason(decision.reason_code, authentication.correlationId);
    if (decision.policy_version !== WAVE1_CONTRACT_VERSION
      || decision.authority_version !== (target.authorityVersion ?? authentication.tenant.authority_version)) {
      throw new Wave1Denied('DENY_AUTHORITY_VERSION_CONFLICT', authentication.correlationId);
    }

    return { ...authentication, decision };
  } catch (error) {
    throw mapBoundaryError(error, authentication.correlationId);
  }
}

export async function authorizeWave1Request(
  request: NextRequest,
  target: Wave1AuthorizationTarget,
  options: { accessToken?: string; requestedTenantId?: string; enforceAal2?: boolean } = {},
): Promise<AuthorizedRequestContext & { subject: { id: string; email?: string }; expiresAt: string }> {
  const authentication = await authenticateWave1Request(request, options);
  return authorizeWave1Authentication(authentication, target);
}

export async function projectWave1AuthorityContext(
  context: AuthorizedRequestContext & { subject: { id: string; email?: string }; expiresAt: string },
  tenant: TenantReadRecord,
) {
  const eligibleTenants = await listEligibleWave1Tenants(context.accessToken, context.subject.id);
  if (!eligibleTenants.some((entry) => entry.tenantId === context.tenant.tenant_id)) {
    throw new Wave1Denied('DENY_AUTHORITY_UNAVAILABLE', context.correlationId);
  }
  let settingsAuthorized = false;
  try {
    const settingsDecision = await authorizeAndAudit(context.accessToken, {
      actorId: context.actor.actor_id,
      tenantId: context.tenant.tenant_id,
      role: context.tenant.role,
      action: 'membership/manage',
      resourceType: 'membership',
      resourceId: 'settings',
      resourceTenantId: context.tenant.tenant_id,
      expectedAuthorityVersion: context.decision.authority_version,
      correlationId: context.correlationId,
      metadataDigest: requestFingerprint({ surface: '/app/settings', purpose: 'navigation' }),
    });
    settingsAuthorized = settingsDecision.outcome === 'ALLOW'
      && settingsDecision.actor_id === context.actor.actor_id
      && settingsDecision.tenant_id === context.tenant.tenant_id
      && settingsDecision.authority_version === context.decision.authority_version;
  } catch {
    settingsAuthorized = false;
  }
  return {
    actor: {
      actorId: context.actor.actor_id,
      actorType: context.actor.actor_type,
      displayName: context.subject.email ?? context.actor.actor_id,
      authenticationStrength: context.actor.authentication_strength,
    },
    tenant: {
      tenantId: context.tenant.tenant_id,
      displayName: tenant.display_name ?? tenant.legal_name ?? tenant.id,
    },
    membership: {
      membershipId: context.tenant.membership_id,
      status: context.tenant.membership_status,
      role: context.tenant.role,
    },
    authorization: {
      decision: context.decision.outcome,
      authorityVersion: String(context.decision.authority_version),
      decisionId: context.decision.decision_id,
      policyVersion: context.decision.policy_version,
    },
    session: {
      sessionId: context.actor.session_id_or_workload_id,
      expiresAt: context.expiresAt,
    },
    eligibleTenants,
    navigation: { settings: settingsAuthorized },
    correlationId: context.correlationId,
  } as const;
}

export async function executeIdempotentWave1Operation<T>(
  context: AuthorizedRequestContext,
  request: Request,
  operation: string,
  input: unknown,
  execute: () => Promise<{ result: T; resultReference: string }>,
): Promise<{ result?: T; replay: boolean; resultReference: string }> {
  const key = validateIdempotencyKey(request.headers.get('idempotency-key'), context.correlationId);
  const digest = requestFingerprint(input);
  try {
    const claim = await claimIdempotency(context.accessToken, {
      key,
      actorId: context.actor.actor_id,
      tenantId: context.tenant.tenant_id,
      operation,
      requestDigest: digest,
      correlationId: context.correlationId,
    });
    if (claim.replay && claim.status === 'COMPLETED' && claim.result_reference) {
      return { replay: true, resultReference: claim.result_reference };
    }
    const completed = await execute();
    await completeIdempotency(context.accessToken, {
      key,
      actorId: context.actor.actor_id,
      tenantId: context.tenant.tenant_id,
      operation,
      requestDigest: digest,
      resultReference: completed.resultReference,
      correlationId: context.correlationId,
    });
    return { result: completed.result, replay: false, resultReference: completed.resultReference };
  } catch (error) {
    throw mapBoundaryError(error, context.correlationId);
  }
}

export function wave1ErrorResponse(error: unknown, request?: Request, endpoint?: string): Response {
  const fallbackCorrelationId = request ? correlationIdFromRequest(request) : crypto.randomUUID();
  const resolvedEndpoint = endpoint ?? (request ? new URL(request.url).pathname : 'wave1-authority-boundary');
  const denial = error instanceof Wave1Denied ? error : mapBoundaryError(error, fallbackCorrelationId, resolvedEndpoint);
  const diagnostic = mappedBoundaryDiagnostics.get(denial)
    ?? mapPublicAuthorityError(error, { correlationId: denial.correlationId, endpoint: resolvedEndpoint }).diagnostic;
  recordServerDiagnostic(diagnostic);
  return Response.json(denial.envelope(), {
    status: denial.status,
    headers: {
      'cache-control': 'no-store',
      'x-correlation-id': denial.correlationId,
    },
  });
}

/**
 * Legacy deterministic route boundary retained for non-targeted routes. Slice 1
 * routes use authenticateWave1Request/authorizeWave1Request instead.
 */
export async function sessionFromRequest(request: NextRequest): Promise<OperationalSession> {
  const config = getAuthorityRuntimeConfig();
  if (config.environment === 'sandbox') return authenticateTestModeToken(request.headers.get('authorization'), operationalDataset.sessions);

  const accessToken = request.cookies.get(ACCESS_COOKIE)?.value;
  const requestedTenant = request.headers.get('x-provenance-tenant') ?? request.cookies.get(TENANT_COOKIE)?.value;
  if (!accessToken) throw new Error('SESSION_REQUIRED');
  if (!requestedTenant) throw new Error('TENANT_REQUIRED');
  const [user, claims] = await Promise.all([
    getAuthenticatedUser(accessToken),
    Promise.resolve(decodeJwtClaims(accessToken)),
  ]);
  if (!claims.sub || claims.sub !== user.id || !claims.session_id || !claims.exp) throw new Error('SESSION_REQUIRED_CLAIMS_MISSING');
  if (claims.exp * 1000 <= Date.now()) throw new Error('SESSION_EXPIRED');
  if (config.requireAal2 && claims.aal !== 'aal2') throw new Error('MFA_REQUIRED');
  const memberships = await listMemberships(accessToken, user.id);
  const membership = memberships.find((item) => item.tenant_id === requestedTenant && item.status === 'active');
  if (!membership) throw new Error('TENANT_MEMBERSHIP_REQUIRED');
  return {
    id: claims.session_id,
    tenantId: membership.tenant_id,
    userId: user.id,
    displayName: membership.display_name || user.email || user.id,
    role: membership.role as OrganizationRole,
    locationIds: membership.location_ids,
    deviceId: request.headers.get('x-provenance-device-id') ?? 'server-authenticated-device',
    authenticatedAt: new Date().toISOString(),
    expiresAt: new Date(claims.exp * 1000).toISOString(),
    testMode: false,
    environment: config.environment,
    assuranceLevel: claims.aal ?? 'aal1',
  };
}

export function operationError(error: unknown) {
  const message = error instanceof Error ? error.message : 'OPERATION_FAILED';
  const code = message.split(':')[0];
  const authenticationErrors = new Set(['SESSION_REQUIRED', 'SESSION_REQUIRED_CLAIMS_MISSING', 'SESSION_NOT_FOUND', 'SESSION_EXPIRED', 'SESSION_TOKEN_INVALID']);
  const authorizationErrors = new Set(['TENANT_REQUIRED', 'TENANT_MEMBERSHIP_REQUIRED', 'MFA_REQUIRED', 'PERMISSION_DENIED']);
  const status = message.startsWith('TENANT_SCOPE_VIOLATION') || authorizationErrors.has(code)
    ? 403
    : authenticationErrors.has(code)
      ? 401
      : message === 'PRODUCTION_IDENTITY_ADAPTER_REQUIRED'
        ? 503
        : 400;
  let environment = 'sandbox';
  let authoritative = false;
  try {
    const config = getAuthorityRuntimeConfig();
    environment = config.environment;
    authoritative = config.authoritative;
  } catch {
    environment = 'invalid';
  }
  return Response.json({
    error: { code: code.toLowerCase(), message: 'The operation could not be completed.' },
    meta: { mode: environment, authoritative, productionCredential: false, failClosed: true },
  }, { status });
}
