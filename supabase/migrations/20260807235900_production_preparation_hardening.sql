-- production-preparation: reconcile hosted database hardening
--
-- This migration reconciles five production corrections that were applied
-- during the hosted migration replay but are absent from canonical source:
--
--   A. Idempotency conflict target: column-list → named-constraint reference
--   B. Legacy permissive RLS policies using current_setting('app.tenant_id')
--      removed for all remaining tables beyond pv_assets (already removed in Wave 1)
--   C. Cross-tenant permission path: has_permission now requires caller's
--      current tenant to match the requested tenant_id
--   D. Fail-closed public table baseline: force row level security on all
--      tables that were missing it after Wave 1 (41 additional tables)
--   E. Anonymous write privileges: legacy {public} ALL policies eliminated,
--      removing the remaining path for anonymous INSERT/UPDATE/DELETE
--   F. SECURITY DEFINER search_path: canonical functions re-stated to
--      ensure pg_catalog-first paths survive split-migration replay artifacts
--
-- This migration is a forward-only additive correction.
-- It does not rewrite historical migrations.
-- It preserves fail-closed behavior throughout.

begin;

-- =============================================================================
-- A + F: Fix claim_idempotency_key — named constraint conflict target
-- =============================================================================
-- Production correction: production_correction_idempotency_conflict_target
-- Change: on conflict (tenant_id, idempotency_key) → on conflict on constraint pv_idempotency_keys_pkey
-- Rationale: named constraint is precise and immune to column rename/reorder.
-- The search_path is also restated to defend against split-migration replay drift.

create or replace function provenance_api.claim_idempotency_key(
  p_key text,
  p_operation text,
  p_request_digest text,
  p_tenant_hint text default null,
  p_expires_at timestamptz default (now() + interval '24 hours'),
  p_correlation_id uuid default gen_random_uuid()
)
returns table (
  status text,
  replay boolean,
  reason_code text,
  key text,
  actor_id uuid,
  tenant_id text,
  operation text,
  request_digest text,
  result_reference text,
  first_seen_at timestamptz,
  expires_at timestamptz,
  correlation_id uuid
)
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
  v_context record;
  v_row public.pv_idempotency_keys%rowtype;
  v_inserted bigint := 0;
begin
  if p_key is null or length(btrim(p_key)) = 0 or length(p_key) > 255 then
    return query select 'DENIED', false, 'PV_IDEMPOTENCY_KEY_INVALID', p_key,
      null::uuid, null::text, p_operation, p_request_digest, null::text,
      null::timestamptz, p_expires_at, p_correlation_id;
    return;
  end if;

  if p_request_digest is null or p_request_digest !~ '^sha256:[0-9a-f]{64}$' then
    return query select 'DENIED', false, 'PV_IDEMPOTENCY_DIGEST_INVALID', p_key,
      null::uuid, null::text, p_operation, p_request_digest, null::text,
      null::timestamptz, p_expires_at, p_correlation_id;
    return;
  end if;

  select * into v_context
  from provenance_api.derive_tenant_context(p_tenant_hint, p_correlation_id);

  if v_context.outcome <> 'RESOLVED' then
    return query select 'DENIED', false, coalesce(v_context.reason_code,'AUTHORITY_UNAVAILABLE'),
      p_key, v_context.actor_id, v_context.tenant_id, p_operation,
      p_request_digest, null::text, null::timestamptz, p_expires_at,
      p_correlation_id;
    return;
  end if;

  insert into public.pv_idempotency_keys(
    tenant_id, idempotency_key, actor_id, operation, request_digest,
    status, first_seen_at, expires_at, correlation_id
  ) values (
    v_context.tenant_id, p_key, v_context.actor_id, p_operation,
    p_request_digest, 'IN_PROGRESS', now(), p_expires_at, p_correlation_id
  )
  on conflict on constraint pv_idempotency_keys_pkey do nothing;

  get diagnostics v_inserted = row_count;

  select * into v_row
  from public.pv_idempotency_keys i
  where i.tenant_id = v_context.tenant_id
    and i.idempotency_key = p_key
  for update;

  if v_row.actor_id <> v_context.actor_id
    or v_row.operation <> p_operation
    or v_row.request_digest <> p_request_digest then
    return query select 'DENIED', false, 'PV_IDEMPOTENCY_FINGERPRINT_CONFLICT',
      p_key, v_context.actor_id, v_context.tenant_id, p_operation,
      p_request_digest, null::text, v_row.first_seen_at, v_row.expires_at,
      p_correlation_id;
    return;
  end if;

  return query select v_row.status, (v_inserted = 0), null::text,
    v_row.idempotency_key, v_row.actor_id, v_row.tenant_id,
    v_row.operation, v_row.request_digest, v_row.result_reference,
    v_row.first_seen_at, v_row.expires_at, p_correlation_id;
end;
$$;

-- =============================================================================
-- C + F: Fix has_permission — require caller's current tenant context
-- =============================================================================
-- Production correction: production_correction_permission_requires_current_tenant
-- Change: added p_tenant_id = provenance_api.current_tenant_id() as the first
--   AND condition, preventing a user with membership in tenant B from reading
--   tenant B's data while operating in tenant A's session context.
-- The search_path is also restated.

create or replace function provenance_api.has_permission(
  p_tenant_id text,
  p_resource_type text,
  p_action text,
  p_resource_id text default null
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, provenance_api
as $$
  select p_tenant_id = provenance_api.current_tenant_id()
    and exists (
      select 1
      from public.pv_memberships m
      join public.pv_role_permissions rp
        on rp.role = m.authority_role
       and rp.resource_type = p_resource_type
       and rp.action = p_action
       and rp.active
      where m.actor_id = provenance_api.current_actor_id()
        and m.tenant_id = p_tenant_id
        and m.lifecycle_status = 'active'
        and m.revoked_at is null
        and (m.expires_at is null or m.expires_at > now())
        and (
          m.resource_scope = '{}'::jsonb
          or not (m.resource_scope ? 'resource_types')
          or p_resource_type in (
            select jsonb_array_elements_text(m.resource_scope->'resource_types')
          )
        )
        and (
          p_resource_id is null
          or not (m.resource_scope ? 'resource_ids')
          or p_resource_id in (
            select jsonb_array_elements_text(m.resource_scope->'resource_ids')
          )
        )
    );
$$;

-- =============================================================================
-- B + E: Drop all legacy current_setting('app.tenant_id') permissive policies
-- =============================================================================
-- Production correction: production_correction_wave1_assets_remove_legacy_permissive_policies
--   covered pv_assets (already done in Wave 1), pv_locations, pv_attestations.
--   The remaining six were not removed in production corrections but are explicitly
--   required by section 5B/5E of the production-preparation governance mandate.
--
-- All nine original phase4 policies are dropped here. Each was an ALL-command
-- policy on the {public} role (applying to anon AND authenticated), gated only
-- on a client-settable GUC. They are superseded by the proper pv_member_of /
-- pv_direct_tenant_scope / has_permission policies applied in later migrations.

-- pv_assets: already dropped in Wave 1 migration (20260725050000). Idempotent here.
drop policy if exists tenant_scope_assets on public.pv_assets;

-- pv_locations
drop policy if exists tenant_scope_locations on public.pv_locations;

-- pv_attestations
drop policy if exists tenant_scope_attestations on public.pv_attestations;

-- pv_evidence_objects
drop policy if exists tenant_scope_evidence on public.pv_evidence_objects;

-- pv_intake_batches
drop policy if exists tenant_scope_batches on public.pv_intake_batches;

-- pv_inventory_lots
drop policy if exists tenant_scope_lots on public.pv_inventory_lots;

-- pv_operational_audit_events
drop policy if exists tenant_scope_audit on public.pv_operational_audit_events;

-- pv_review_cases
drop policy if exists tenant_scope_reviews on public.pv_review_cases;

-- pv_sync_operations
drop policy if exists tenant_scope_sync on public.pv_sync_operations;

-- =============================================================================
-- D: Force row level security on all operational tables missing it
-- =============================================================================
-- Production correction: production_fail_closed_public_table_baseline
-- 41 tables received force row level security beyond the 9 already covered
-- by Wave 1. Force RLS ensures service-role connections cannot bypass policies.
-- Tables are listed explicitly to avoid broad ALTER statements.

alter table public.pv_access_reviews force row level security;
alter table public.pv_api_quotas force row level security;
alter table public.pv_api_rate_windows force row level security;
alter table public.pv_api_usage_events force row level security;
alter table public.pv_appeals force row level security;
alter table public.pv_audit_export_events force row level security;
alter table public.pv_audit_exports force row level security;
alter table public.pv_audit_runs force row level security;
alter table public.pv_authority_key_lifecycle force row level security;
alter table public.pv_batch_commands force row level security;
alter table public.pv_billing_reconciliations force row level security;
alter table public.pv_break_glass_leases force row level security;
alter table public.pv_commercial_accounts force row level security;
alter table public.pv_commercial_opportunities force row level security;
alter table public.pv_commercial_remedies force row level security;
alter table public.pv_contract_versions force row level security;
alter table public.pv_contracts force row level security;
alter table public.pv_customer_provisioning_events force row level security;
alter table public.pv_devices force row level security;
alter table public.pv_dual_control_approvals force row level security;
alter table public.pv_entitlements force row level security;
alter table public.pv_evidence_access_grants force row level security;
alter table public.pv_evidence_derivatives force row level security;
alter table public.pv_evidence_retention force row level security;
alter table public.pv_ingestion_quotas force row level security;
alter table public.pv_invoices force row level security;
alter table public.pv_notification_attempts force row level security;
alter table public.pv_notifications force row level security;
alter table public.pv_payment_references force row level security;
alter table public.pv_portable_verification_bundles force row level security;
alter table public.pv_preference_records force row level security;
alter table public.pv_readiness_waivers force row level security;
alter table public.pv_refunds force row level security;
alter table public.pv_reviewer_calibrations force row level security;
alter table public.pv_runtime_claim_evidence force row level security;
alter table public.pv_runtime_claims force row level security;
alter table public.pv_source_authorities force row level security;
alter table public.pv_status_lists force row level security;
alter table public.pv_support_case_events force row level security;
alter table public.pv_support_cases force row level security;
alter table public.pv_task_execution_events force row level security;

commit;
