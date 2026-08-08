/**
 * GENERATED CONTRACT TYPES — PROVENANCE VERIFIED™ Wave 1 Slice 1
 * Source: database/012_wave1_slice1_tenant_safe_foundation.sql
 * Contracts: W1-C01 through W1-C07 / v1-wave1
 * Do not hand-edit without regenerating from the migration contract.
 */

export type UUID = string;
export type IsoTimestamp = string;
export type Sha256Digest = `sha256:${string}`;

export type ActorType = 'user' | 'workload';
export type ActorStatus = 'active' | 'inactive' | 'suspended' | 'revoked';
export type MembershipRole =
  | 'organization_owner'
  | 'organization_admin'
  | 'operator'
  | 'reviewer'
  | 'member';
export type MembershipStatus = 'active' | 'inactive' | 'suspended' | 'revoked';
export type AuthorizationOutcome = 'ALLOW' | 'DENY';
export type IdempotencyStatus = 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'DENIED';

export type ActorResolutionReason =
  | 'ACTOR_UNKNOWN'
  | 'ACTOR_INACTIVE'
  | 'ACTOR_SUSPENDED'
  | 'ACTOR_REVOKED'
  | 'ACTOR_AMBIGUOUS'
  | 'AUTHORITY_UNAVAILABLE';

export type TenantResolutionReason =
  | ActorResolutionReason
  | 'MEMBERSHIP_INACTIVE'
  | 'MEMBERSHIP_SUSPENDED'
  | 'MEMBERSHIP_REVOKED'
  | 'TENANT_AMBIGUOUS'
  | 'TENANT_OVERRIDE_DENIED'
  | 'TENANT_UNAUTHORIZED';

export type AuthorizationDenialReason =
  | 'DENY_ACTOR_UNKNOWN'
  | 'DENY_ACTOR_INACTIVE'
  | 'DENY_ACTOR_SUSPENDED'
  | 'DENY_ACTOR_REVOKED'
  | 'DENY_ACTOR_AMBIGUOUS'
  | 'DENY_MEMBERSHIP_INACTIVE'
  | 'DENY_MEMBERSHIP_SUSPENDED'
  | 'DENY_MEMBERSHIP_REVOKED'
  | 'DENY_TENANT_UNAUTHORIZED'
  | 'DENY_ROLE'
  | 'DENY_ACTION'
  | 'DENY_RESOURCE_TENANT_MISMATCH'
  | 'DENY_AUTHORITY_VERSION_CONFLICT'
  | 'DENY_AUTHORITY_UNAVAILABLE';

export type IdempotencyReason =
  | TenantResolutionReason
  | 'PV_IDEMPOTENCY_KEY_INVALID'
  | 'PV_IDEMPOTENCY_DIGEST_INVALID'
  | 'PV_IDEMPOTENCY_KEY_UNKNOWN'
  | 'PV_IDEMPOTENCY_FINGERPRINT_CONFLICT'
  | 'PV_IDEMPOTENCY_RESULT_CONFLICT';

export interface ActorIdentityRow {
  outcome: 'RESOLVED' | 'DENY';
  reason_code: ActorResolutionReason | null;
  actor_id: UUID | null;
  actor_type: ActorType | null;
  session_id_or_workload_id: string | null;
  authentication_strength: string | null;
  issued_at: IsoTimestamp | null;
  correlation_id: UUID;
  authority_version: number | null;
}

export interface TenantContextRow {
  outcome: 'RESOLVED' | 'DENY';
  reason_code: TenantResolutionReason | null;
  tenant_id: string | null;
  actor_id: UUID | null;
  membership_id: UUID | null;
  derivation_source: string;
  derived_at: IsoTimestamp;
  correlation_id: UUID;
  role: MembershipRole | 'workload' | null;
  membership_status: MembershipStatus | null;
  authority_version: number | null;
}

export interface AuthorizationDecisionRow {
  decision_id: UUID;
  outcome: AuthorizationOutcome;
  reason_code: AuthorizationDenialReason | null;
  actor_id: UUID | null;
  tenant_id: string | null;
  action: string;
  resource_type: string;
  resource_id: string;
  policy_version: 'v1-wave1';
  authority_version: number | null;
  decided_at: IsoTimestamp;
  correlation_id: UUID;
}

export interface IdempotencyClaimRow {
  status: IdempotencyStatus;
  replay: boolean;
  reason_code: IdempotencyReason | null;
  key: string;
  actor_id: UUID | null;
  tenant_id: string | null;
  operation: string;
  request_digest: Sha256Digest;
  result_reference: string | null;
  first_seen_at: IsoTimestamp | null;
  expires_at: IsoTimestamp;
  correlation_id: UUID;
}

export interface IdempotencyCompletionRow {
  status: IdempotencyStatus;
  replay: boolean;
  reason_code: IdempotencyReason | null;
  key: string;
  actor_id: UUID | null;
  tenant_id: string | null;
  operation: string;
  request_digest: Sha256Digest;
  result_reference: string | null;
  completed_at: IsoTimestamp | null;
  correlation_id: UUID;
}

export interface Wave1Slice1DatabaseContract {
  Functions: {
    resolve_actor_identity: {
      Args: {
        p_correlation_id?: UUID;
      };
      Returns: ActorIdentityRow[];
    };
    derive_tenant_context: {
      Args: {
        p_tenant_hint?: string | null;
        p_correlation_id?: UUID;
      };
      Returns: TenantContextRow[];
    };
    authorize_and_audit: {
      Args: {
        p_action: string;
        p_resource_type: string;
        p_resource_id: string;
        p_resource_tenant_id: string;
        p_tenant_hint?: string | null;
        p_expected_authority_version?: number | null;
        p_correlation_id?: UUID;
        p_metadata_digest?: Sha256Digest | null;
      };
      Returns: AuthorizationDecisionRow[];
    };
    claim_idempotency_key: {
      Args: {
        p_key: string;
        p_operation: string;
        p_request_digest: Sha256Digest;
        p_tenant_hint?: string | null;
        p_expires_at?: IsoTimestamp;
        p_correlation_id?: UUID;
      };
      Returns: IdempotencyClaimRow[];
    };
    complete_idempotency_key: {
      Args: {
        p_key: string;
        p_operation: string;
        p_request_digest: Sha256Digest;
        p_result_reference: string;
        p_tenant_hint?: string | null;
        p_correlation_id?: UUID;
      };
      Returns: IdempotencyCompletionRow[];
    };
  };
}

export const WAVE1_SLICE1_CONTRACT_VERSION = 'v1-wave1' as const;
export const WAVE1_SLICE1_PROVISIONAL_CONTRACTS_USED = 0 as const;
