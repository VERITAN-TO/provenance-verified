-- PROVENANCE.CX R8.1 R3 operational completion controls
-- Consequential writes are service-role RPC only. Authenticated principals receive tenant-scoped read models.

create table if not exists public.pv_source_authorities (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id),
  authority_type text not null check (authority_type in ('governing','runtime','design','target','assumption','unverified')),
  name text not null, source_uri text not null, source_digest text not null check (source_digest ~ '^sha256:[0-9a-f]{64}$'),
  version text not null, effective_at timestamptz not null, expires_at timestamptz, superseded_by uuid references public.pv_source_authorities(id),
  created_at timestamptz not null default now(), created_by uuid
);
create table if not exists public.pv_runtime_claims (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id),
  source_authority_id uuid not null references public.pv_source_authorities(id), claim_key text not null,
  claim_class text not null check (claim_class in ('GOVERNING','VERIFIED_RUNTIME','DESIGN','TARGET','ASSUMPTION','UNVERIFIED')),
  environment text not null check (environment in ('sandbox','pilot','production')), owner_identity text not null,
  state text not null check (state in ('LIVE','VERIFIED','STALE','BLOCKED','SUPERSEDED')),
  observed_at timestamptz not null, expires_at timestamptz not null, superseded_by uuid references public.pv_runtime_claims(id),
  payload jsonb not null default '{}'::jsonb, payload_digest text not null check (payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  created_at timestamptz not null default now(), unique(tenant_id,claim_key,environment,observed_at)
);
create table if not exists public.pv_runtime_claim_evidence (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id),
  claim_id uuid not null references public.pv_runtime_claims(id), evidence_id uuid, evidence_digest text not null check (evidence_digest ~ '^sha256:[0-9a-f]{64}$'),
  observed_at timestamptz not null, expires_at timestamptz not null, revoked_at timestamptz, contradicted_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.pv_readiness_waivers (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id),
  scope text not null, risk text not null, approver_identities text[] not null, approval_signatures text[] not null,
  compensating_controls text[] not null, starts_at timestamptz not null, expires_at timestamptz not null, revoked_at timestamptz,
  evidence jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
  check (cardinality(approver_identities) >= 2 and cardinality(approval_signatures)=cardinality(approver_identities))
);
create table if not exists public.pv_audit_runs (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id),
  tool_version text not null, source_commit text not null, environment text not null, command text not null,
  result text not null check (result in ('pass','fail')), artifact_hashes text[] not null, signer_identity text not null,
  run_digest text not null check (run_digest ~ '^sha256:[0-9a-f]{64}$'), previous_run_digest text,
  created_at timestamptz not null default now(), superseded_by uuid references public.pv_audit_runs(id)
);

create table if not exists public.pv_devices (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), owner_identity text not null,
  attestation_type text not null check (attestation_type in ('webauthn','platform','managed','none')),
  attestation_evidence jsonb not null default '{}'::jsonb, risk_state text not null check (risk_state in ('trusted','elevated','revoked')),
  enrolled_at timestamptz not null, last_seen_at timestamptz not null, revoked_at timestamptz, revocation_reason text,
  created_at timestamptz not null default now()
);
create table if not exists public.pv_dual_control_approvals (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), action_type text not null,
  subject_id text not null, requester_identity text not null, approver_identity text not null,
  requester_aal int not null check (requester_aal between 1 and 3), approver_aal int not null check (approver_aal between 1 and 3),
  purpose text not null, approval_signature text not null, expires_at timestamptz not null, consumed_at timestamptz,
  created_at timestamptz not null default now(), check (requester_identity <> approver_identity)
);
create table if not exists public.pv_access_reviews (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), principal_identity text not null,
  entitlements text[] not null, reviewed_entitlements text[] not null default '{}', reviewer_identity text,
  reviewer_signature text, due_at timestamptz not null, completed_at timestamptz, blocker_open boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.pv_break_glass_leases (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), principal_identity text not null,
  reason text not null, hardware_mfa_verified boolean not null, starts_at timestamptz not null, expires_at timestamptz not null,
  alert_receipt_id text not null, post_event_review_id text, revoked_at timestamptz, created_at timestamptz not null default now()
);

create table if not exists public.pv_authority_key_lifecycle (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), service_identity text not null,
  key_id text not null, key_version int not null, algorithm text not null check (algorithm in ('Ed25519','ES256')),
  status text not null check (status in ('generated','active','suspended','retired','revoked','destroyed')),
  public_key text not null, not_before timestamptz not null, not_after timestamptz not null, replaced_by_key_id text,
  ceremony_reference text not null, lifecycle_evidence jsonb not null, created_at timestamptz not null default now(),
  unique(service_identity,key_id,key_version)
);
create table if not exists public.pv_evidence_retention (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), evidence_id uuid not null,
  retention_class text not null, retention_until timestamptz not null, legal_hold boolean not null default false,
  hold_reason text, credential_referenced boolean not null default false, disposition_authorized boolean not null default false,
  disposition_receipt_id text, created_at timestamptz not null default now(), unique(tenant_id,evidence_id)
);
create table if not exists public.pv_evidence_derivatives (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), original_evidence_id uuid not null,
  original_digest text not null check (original_digest ~ '^sha256:[0-9a-f]{64}$'), derivative_digest text not null check (derivative_digest ~ '^sha256:[0-9a-f]{64}$'),
  derivative_type text not null, transformation_version text not null, operator_identity text not null,
  approved_for_public_projection boolean not null default false, approval_receipt_id text, created_at timestamptz not null default now(),
  check (original_digest <> derivative_digest)
);
create table if not exists public.pv_evidence_access_grants (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), evidence_id uuid not null,
  principal_identity text not null, purpose text not null, granted_at timestamptz not null default now(), expires_at timestamptz not null,
  signed_access_reference text not null, revoked_at timestamptz
);
create table if not exists public.pv_ingestion_quotas (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), quota_type text not null,
  limit_value bigint not null check (limit_value > 0), used_value bigint not null default 0 check (used_value >= 0),
  window_starts_at timestamptz not null, window_ends_at timestamptz not null, updated_at timestamptz not null default now(),
  unique(tenant_id,quota_type,window_starts_at)
);

create table if not exists public.pv_appeals (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), original_decision_id uuid not null,
  appellant_identity text not null, standing_valid boolean not null, submitted_at timestamptz not null, deadline_at timestamptz not null,
  assigned_reviewer_identity text not null, original_reviewer_identity text not null, new_evidence_ids uuid[] not null default '{}',
  state text not null check (state in ('submitted','admissible','denied','under-review','resolved')),
  superseding_decision_id uuid, created_at timestamptz not null default now(),
  check (assigned_reviewer_identity <> original_reviewer_identity)
);
create table if not exists public.pv_reviewer_calibrations (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), reviewer_identity text not null,
  protocol_version text not null, sample_size int not null, agreement_rate numeric not null, threshold numeric not null,
  critical_disagreements int not null default 0, scope_restricted boolean not null, evidence jsonb not null,
  created_at timestamptz not null default now()
);
create table if not exists public.pv_denial_taxonomy (
  code text primary key, severity text not null, description text not null, remediation_requirements text[] not null,
  resubmission_allowed boolean not null, policy_version text not null, active boolean not null default true
);

create table if not exists public.pv_portable_verification_bundles (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), credential_id uuid not null,
  credential_version int not null, bundle_digest text not null check (bundle_digest ~ '^sha256:[0-9a-f]{64}$'),
  public_key_reference text not null, protocol_version text not null, generated_at timestamptz not null,
  bundle_payload jsonb not null, unique(credential_id,credential_version)
);
create table if not exists public.pv_status_lists (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), version bigint not null,
  effective_at timestamptz not null, list_digest text not null check (list_digest ~ '^sha256:[0-9a-f]{64}$'),
  signature text not null, key_id text not null, snapshot jsonb not null, created_at timestamptz not null default now(),
  unique(tenant_id,version)
);
create table if not exists public.pv_batch_commands (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), principal_identity text not null,
  operation text not null, target_ids text[] not null, target_digest text not null check (target_digest ~ '^sha256:[0-9a-f]{64}$'),
  dry_run_result jsonb not null, approval_ids text[] not null default '{}', idempotency_key text not null,
  state text not null check (state in ('preview','approved','running','completed','partial-failure','failed')),
  expires_at timestamptz not null, created_at timestamptz not null default now(), unique(tenant_id,idempotency_key)
);

create table if not exists public.pv_api_quotas (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), principal_id text not null,
  operation text not null, limit_value int not null, burst_value int not null, window_seconds int not null,
  status text not null check (status in ('active','suspended')), updated_at timestamptz not null default now(),
  unique(tenant_id,principal_id,operation)
);
create table if not exists public.pv_api_rate_windows (
  id bigint generated always as identity primary key, tenant_id text not null references public.pv_tenants(id),
  principal_id text not null, operation text not null, window_started_at timestamptz not null,
  used_value int not null default 0 check (used_value >= 0), updated_at timestamptz not null default now(),
  unique(tenant_id,principal_id,operation,window_started_at)
);
create table if not exists public.pv_api_usage_events (
  id bigint generated always as identity primary key, tenant_id text not null references public.pv_tenants(id), principal_id text not null,
  operation text not null, request_id text not null, receipt_id text, latency_ms int not null, status_code int not null,
  quota_remaining int, occurred_at timestamptz not null default now(), unique(tenant_id,request_id)
);
create table if not exists public.pv_sandbox_tenants (
  id uuid primary key default gen_random_uuid(), owner_identity text not null, status text not null check (status in ('provisioning','active','resetting','deleted')),
  limits jsonb not null, seeded_at timestamptz, reset_at timestamptz, deleted_at timestamptz, created_at timestamptz not null default now()
);

create table if not exists public.pv_task_execution_events (
  id bigint generated always as identity primary key, tenant_id text not null references public.pv_tenants(id), task_id text not null,
  attempt_id text not null, actor_identity text not null, event_type text not null check (event_type in ('created','started','tool-call','tool-result','continued','denied','approved','completed','failed')),
  payload jsonb not null, previous_event_digest text not null, event_digest text not null check (event_digest ~ '^sha256:[0-9a-f]{64}$'),
  occurred_at timestamptz not null default now(), unique(tenant_id,task_id,id, event_digest)
);
create table if not exists public.pv_notifications (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), event_id text not null,
  channel text not null check (channel in ('in-app','email','sms','webhook')), recipient text not null, template_version text not null,
  consent_reference text, state text not null check (state in ('queued','sending','delivered','failed','dead-letter','suppressed')),
  attempt_count int not null default 0, next_attempt_at timestamptz, delivery_receipt jsonb, created_at timestamptz not null default now()
);
create table if not exists public.pv_audit_exports (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), requester_identity text not null,
  approved_by text[] not null, scope jsonb not null, disclosure_policy_version text not null, encrypted_object_reference text,
  watermark text not null, expires_at timestamptz not null, revoked_at timestamptz, created_at timestamptz not null default now()
);

create table if not exists public.pv_public_claims (
  id uuid primary key default gen_random_uuid(), tenant_id text references public.pv_tenants(id), claim_key text not null,
  claim_text text not null, source_ids text[] not null, approver_ids text[] not null, channels text[] not null,
  effective_at timestamptz not null, expires_at timestamptz not null, withdrawn_at timestamptz,
  withdrawal_reason text, state text not null check (state in ('draft','approved','published','expired','withdrawn')),
  created_at timestamptz not null default now(), unique(claim_key,effective_at)
);
create table if not exists public.pv_consent_records (
  id uuid primary key default gen_random_uuid(), subject_reference text not null, jurisdiction text not null,
  purpose text not null, granted boolean not null, policy_version text not null, evidence jsonb not null,
  recorded_at timestamptz not null default now(), withdrawn_at timestamptz
);
create table if not exists public.pv_accessibility_cases (
  id uuid primary key default gen_random_uuid(), tenant_id text references public.pv_tenants(id), contact_reference text not null,
  route text not null, assistive_technology text, description text not null, severity text not null,
  state text not null check (state in ('open','triaged','remediating','resolved','closed')),
  sla_due_at timestamptz not null, resolution_evidence jsonb, created_at timestamptz not null default now()
);
create table if not exists public.pv_knowledge_blocks (
  id uuid primary key default gen_random_uuid(), canonical_key text not null, locale text not null, region text not null,
  source_ids text[] not null, owner_identity text not null, review_at timestamptz not null, expires_at timestamptz not null,
  state text not null check (state in ('draft','approved','published','stale','withdrawn')), body jsonb not null,
  created_at timestamptz not null default now(), unique(canonical_key,locale,region,created_at)
);

create table if not exists public.pv_commercial_accounts (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), external_crm_id text,
  lifecycle_state text not null, contract_state text not null, provisioning_state text not null, created_at timestamptz not null default now()
);
create table if not exists public.pv_contracts (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), account_id uuid not null references public.pv_commercial_accounts(id),
  status text not null check (status in ('draft','signed','active','terminated','expired')), effective_at timestamptz,
  expires_at timestamptz, document_digest text, provisioning_receipt_id text, created_at timestamptz not null default now()
);
create table if not exists public.pv_support_cases (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), case_type text not null,
  severity text not null, state text not null, customer_impact text, credential_impact text, sla_due_at timestamptz not null,
  escalation_path text[] not null, evidence_ids text[] not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.pv_status_incidents (
  id uuid primary key default gen_random_uuid(), component text not null, severity text not null, state text not null,
  observed_health text not null, override_evidence jsonb, public_message text, started_at timestamptz not null,
  resolved_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.pv_commercial_remedies (
  id uuid primary key default gen_random_uuid(), tenant_id text not null references public.pv_tenants(id), support_case_id uuid references public.pv_support_cases(id),
  remedy_type text not null, financial_state text not null, credential_action text not null, credential_action_reason text,
  created_at timestamptz not null default now()
);
create table if not exists public.pv_launch_communications (
  id uuid primary key default gen_random_uuid(), tenant_id text references public.pv_tenants(id), public_claim_id uuid not null references public.pv_public_claims(id),
  channel text not null, embargo_until timestamptz, state text not null check (state in ('draft','approved','scheduled','published','withdrawn')),
  external_message_id text, withdrawal_receipt jsonb, created_at timestamptz not null default now()
);

create table if not exists public.pv_service_catalog (
  service_id text primary key, owner_identity text not null, data_classification text not null, slo_ids text[] not null,
  dependencies text[] not null, alert_routes text[] not null, runbook_uri text not null, rto_seconds int not null, rpo_seconds int not null,
  active boolean not null default true, updated_at timestamptz not null default now()
);
create table if not exists public.pv_slos (
  id text primary key, service_id text not null references public.pv_service_catalog(service_id), indicator text not null,
  target numeric not null, comparator text not null check (comparator in ('gte','lte')), window_seconds int not null,
  error_budget_policy jsonb not null, active boolean not null default true
);
create table if not exists public.pv_slo_measurements (
  id bigint generated always as identity primary key, slo_id text not null references public.pv_slos(id),
  observed numeric not null, window_start timestamptz not null, window_end timestamptz not null,
  pass boolean not null, error_budget_consumed numeric not null, evidence jsonb not null, recorded_at timestamptz not null default now()
);
create table if not exists public.pv_incidents (
  id uuid primary key default gen_random_uuid(), tenant_id text references public.pv_tenants(id), severity text not null,
  commander_identity text not null, state text not null, timeline jsonb not null default '[]'::jsonb, customer_impact text,
  evidence jsonb not null, postmortem_uri text, actions jsonb not null default '[]'::jsonb, opened_at timestamptz not null default now(), resolved_at timestamptz
);
create table if not exists public.pv_synthetic_runs (
  id uuid primary key default gen_random_uuid(), environment text not null, journey text not null, result text not null,
  receipt_id text not null, latency_ms int not null, failure_stage text, evidence jsonb not null, ran_at timestamptz not null default now()
);
create table if not exists public.pv_integrity_findings (
  id uuid primary key default gen_random_uuid(), tenant_id text references public.pv_tenants(id), finding_type text not null,
  severity text not null, subject_reference text not null, quarantined boolean not null default false,
  evidence jsonb not null, state text not null check (state in ('open','quarantined','investigating','resolved')),
  detected_at timestamptz not null default now(), resolved_at timestamptz
);
create table if not exists public.pv_capacity_tests (
  id uuid primary key default gen_random_uuid(), environment text not null, workload_model text not null,
  duration_seconds int not null, peak_rps numeric not null, p95_latency_ms numeric not null, invariant_breaches int not null,
  headroom_percent numeric not null, result text not null, evidence jsonb not null, executed_at timestamptz not null default now()
);

-- Trust evidence and history are append-only.
do $$
declare rel text; begin
  foreach rel in array array[
    'pv_source_authorities','pv_runtime_claims','pv_runtime_claim_evidence','pv_readiness_waivers','pv_audit_runs',
    'pv_dual_control_approvals','pv_access_reviews','pv_break_glass_leases','pv_authority_key_lifecycle',
    'pv_evidence_derivatives','pv_evidence_access_grants','pv_appeals','pv_reviewer_calibrations',
    'pv_portable_verification_bundles','pv_status_lists','pv_api_usage_events','pv_task_execution_events',
    'pv_public_claims','pv_consent_records','pv_slo_measurements','pv_synthetic_runs','pv_capacity_tests'
  ] loop
    execute format('drop trigger if exists %I_immutable on public.%I',rel,rel);
    execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function provenance_api.deny_mutation()',rel,rel);
  end loop;
end $$;

-- Tenant-scoped read access. There are intentionally no general authenticated mutation policies.
do $$
declare rel text; begin
  foreach rel in array array[
    'pv_source_authorities','pv_runtime_claims','pv_runtime_claim_evidence','pv_readiness_waivers','pv_audit_runs','pv_devices',
    'pv_dual_control_approvals','pv_access_reviews','pv_break_glass_leases','pv_authority_key_lifecycle','pv_evidence_retention',
    'pv_evidence_derivatives','pv_evidence_access_grants','pv_ingestion_quotas','pv_appeals','pv_reviewer_calibrations',
    'pv_portable_verification_bundles','pv_status_lists','pv_batch_commands','pv_api_quotas','pv_api_rate_windows','pv_api_usage_events',
    'pv_task_execution_events','pv_notifications','pv_audit_exports','pv_commercial_accounts','pv_contracts','pv_support_cases',
    'pv_commercial_remedies'
  ] loop
    execute format('alter table public.%I enable row level security',rel);
    execute format('alter table public.%I force row level security',rel);
    execute format('revoke insert, update, delete on public.%I from anon, authenticated',rel);
    execute format('drop policy if exists %I_tenant_read on public.%I',rel,rel);
    execute format('create policy %I_tenant_read on public.%I for select to authenticated using (tenant_id = provenance_api.current_tenant_id())',rel,rel);
  end loop;
end $$;

-- Public/governance relations expose only explicit read paths or service-role writes.
revoke insert, update, delete on public.pv_public_claims, public.pv_consent_records, public.pv_accessibility_cases,
  public.pv_knowledge_blocks, public.pv_status_incidents, public.pv_launch_communications, public.pv_service_catalog,
  public.pv_slos, public.pv_slo_measurements, public.pv_incidents, public.pv_synthetic_runs, public.pv_integrity_findings,
  public.pv_capacity_tests, public.pv_denial_taxonomy, public.pv_sandbox_tenants from anon, authenticated;

create or replace function provenance_api.pv_r3_consume_quota(p_tenant text,p_quota_type text,p_amount bigint)
returns public.pv_ingestion_quotas language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare q public.pv_ingestion_quotas; begin
  select * into q from public.pv_ingestion_quotas where tenant_id=p_tenant and quota_type=p_quota_type and window_ends_at>now() order by window_starts_at desc limit 1 for update;
  if not found then raise exception 'PV_QUOTA_MISSING'; end if;
  if p_amount<=0 or q.used_value+p_amount>q.limit_value then raise exception 'PV_QUOTA_EXCEEDED'; end if;
  update public.pv_ingestion_quotas set used_value=used_value+p_amount,updated_at=now() where id=q.id returning * into q;
  return q;
end $$;


create or replace function provenance_api.pv_r3_consume_api_quota(p_tenant text,p_principal text,p_operation text)
returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare q public.pv_api_quotas; w public.pv_api_rate_windows; start_at timestamptz; remaining int; begin
  select * into q from public.pv_api_quotas where tenant_id=p_tenant and principal_id=p_principal and status='active' and operation in (p_operation,'*') order by case when operation=p_operation then 0 else 1 end limit 1;
  if not found then raise exception 'PV_API_QUOTA_NOT_CONFIGURED'; end if;
  start_at:=to_timestamp(floor(extract(epoch from now())/q.window_seconds)*q.window_seconds);
  insert into public.pv_api_rate_windows(tenant_id,principal_id,operation,window_started_at,used_value)
  values(p_tenant,p_principal,p_operation,start_at,1)
  on conflict(tenant_id,principal_id,operation,window_started_at) do update set used_value=public.pv_api_rate_windows.used_value+1,updated_at=now()
  returning * into w;
  if w.used_value>q.limit_value+q.burst_value then raise exception 'PV_API_QUOTA_EXCEEDED'; end if;
  remaining:=greatest(0,q.limit_value+q.burst_value-w.used_value);
  return jsonb_build_object('limit',q.limit_value,'burst',q.burst_value,'used',w.used_value,'remaining',remaining,'windowStartedAt',start_at,'windowSeconds',q.window_seconds);
end $$;

create or replace function provenance_api.pv_r3_claim_batch_command(p_id uuid,p_tenant text,p_target_digest text,p_idempotency_key text)
returns public.pv_batch_commands language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare b public.pv_batch_commands; begin
 select * into b from public.pv_batch_commands where id=p_id and tenant_id=p_tenant for update;
 if not found then raise exception 'PV_BATCH_NOT_FOUND'; end if;
 if b.target_digest<>p_target_digest then raise exception 'PV_BATCH_SCOPE_CHANGED'; end if;
 if b.idempotency_key<>p_idempotency_key then raise exception 'PV_BATCH_IDEMPOTENCY_MISMATCH'; end if;
 if b.expires_at<=now() then raise exception 'PV_BATCH_PREVIEW_EXPIRED'; end if;
 if cardinality(b.approval_ids)<2 then raise exception 'PV_BATCH_DUAL_CONTROL_REQUIRED'; end if;
 update public.pv_batch_commands set state='running' where id=b.id returning * into b; return b;
end $$;

revoke all on function provenance_api.pv_r3_consume_api_quota(text,text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_consume_quota(text,text,bigint) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_claim_batch_command(uuid,text,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_consume_api_quota(text,text,text) to service_role;
grant execute on function provenance_api.pv_r3_consume_quota(text,text,bigint) to service_role;
grant execute on function provenance_api.pv_r3_claim_batch_command(uuid,text,text,text) to service_role;
