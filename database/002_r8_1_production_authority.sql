-- PROVENANCE.CX R8.1 production authority plane
-- Supabase/PostgreSQL 17+; fail-closed, tenant-isolated, append-only trust operations.

create extension if not exists pgcrypto;
create schema if not exists provenance_api;

create table if not exists public.pv_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('owner','administrator','intake-operator','evidence-manager','inventory-manager','authorized-attestor','reviewer','compliance-officer','auditor')),
  status text not null default 'active' check (status in ('active','suspended')),
  location_ids text[] not null default '{}',
  conflict_domains text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, user_id)
);

create table if not exists public.pv_api_clients (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id) on delete cascade,
  name text not null,
  key_prefix text not null unique,
  secret_hash text not null unique check (secret_hash ~ '^sha256:[0-9a-f]{64}$'),
  environment text not null check (environment in ('pilot','production')),
  role text not null check (role in ('intake-operator','evidence-manager','inventory-manager','auditor')),
  scopes text[] not null,
  status text not null default 'active' check (status in ('active','revoked','expired')),
  expires_at timestamptz,
  last_used_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id)
);

create index if not exists pv_api_clients_lookup_idx on public.pv_api_clients(secret_hash, status, environment);


create table if not exists public.pv_authority_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  environment text not null check (environment in ('pilot','production')),
  idempotency_key text not null,
  operation_type text not null check (operation_type in ('pilot-evaluation','credential-issuance','lifecycle-transition','webhook-replay')),
  stage text not null,
  status text not null check (status in ('running','blocked','completed','failed')),
  attempt integer not null default 1 check (attempt > 0),
  actor_id text not null,
  external_receipts jsonb not null default '{}'::jsonb,
  last_error_code text,
  last_error_detail text,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (tenant_id, environment, idempotency_key)
);

create index if not exists pv_authority_operations_recovery_idx
  on public.pv_authority_operations(tenant_id, status, updated_at);

create table if not exists public.pv_environment_controls (
  environment text primary key check (environment in ('pilot','production')),
  authoritative_issuance_enabled boolean not null default false,
  certification_marks_enabled boolean not null default false,
  registry_ready boolean not null default false,
  revocation_ready boolean not null default false,
  active_signing_key_id text,
  activation_record_id text,
  activation_record_sha256 text check (activation_record_sha256 is null or activation_record_sha256 ~ '^sha256:[0-9a-f]{64}$'),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.pv_environment_controls(environment)
values ('pilot'), ('production')
on conflict (environment) do nothing;

alter table public.pv_review_cases add column if not exists attestation_id text references public.pv_attestations(id);
alter table public.pv_review_cases add column if not exists registry_id text;
alter table public.pv_review_cases add column if not exists event_receipts jsonb not null default '[]'::jsonb;
alter table public.pv_review_cases add column if not exists registry_publication jsonb;
alter table public.pv_review_cases add column if not exists corrections jsonb not null default '[]'::jsonb;
alter table public.pv_review_cases add column if not exists credential_lifecycle text not null default 'draft';
alter table public.pv_review_cases add column if not exists successor_id text;
alter table public.pv_review_cases add column if not exists lifecycle_events jsonb not null default '[]'::jsonb;
alter table public.pv_review_cases add column if not exists current_review_round integer not null default 1 check (current_review_round > 0);

alter table public.pv_evidence_objects add column if not exists scan_receipt_id uuid;

create table if not exists public.pv_evidence_scan_receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  storage_key text not null unique,
  object_sha256 text not null check (object_sha256 ~ '^sha256:[0-9a-f]{64}$'),
  byte_size bigint not null check (byte_size > 0),
  mime_type text not null,
  status text not null check (status in ('passed','failed','quarantined')),
  external_receipt_id text not null unique,
  scanner_signature text not null,
  scanned_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.pv_evidence_objects
  drop constraint if exists pv_evidence_objects_scan_receipt_id_fkey;
alter table public.pv_evidence_objects
  add constraint pv_evidence_objects_scan_receipt_id_fkey foreign key (scan_receipt_id) references public.pv_evidence_scan_receipts(id);

create table if not exists public.pv_evidence_custody_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  evidence_id text not null references public.pv_evidence_objects(id),
  sequence integer not null check (sequence > 0),
  actor_id uuid not null,
  actor_organization text not null,
  action text not null check (action in ('uploaded','hash-verified','scan-passed','scan-failed','custody-transferred','qualified','quarantined','withdrawn','superseded')),
  occurred_at timestamptz not null default now(),
  location text not null,
  previous_event_hash text not null,
  event_hash text not null check (event_hash ~ '^sha256:[0-9a-f]{64}$'),
  object_sha256 text not null check (object_sha256 ~ '^sha256:[0-9a-f]{64}$'),
  scan_status text not null check (scan_status in ('pending','passed','failed','not-applicable')),
  history_complete boolean not null default false,
  unique (evidence_id, sequence),
  unique (event_hash)
);

create table if not exists public.pv_reviewer_decisions (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  reviewer_id uuid not null references auth.users(id),
  stage text not null check (stage in ('primary','secondary')),
  review_round integer not null default 1 check (review_round > 0),
  decision text not null check (decision in ('approve','reject')),
  independent boolean not null,
  conflict_free boolean not null,
  reason_codes text[] not null default '{}',
  decided_at timestamptz not null default now(),
  unique (review_case_id, review_round, stage),
  unique (review_case_id, review_round, reviewer_id)
);

create table if not exists public.pv_conflict_clearances (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  reviewer_id uuid not null references auth.users(id),
  review_round integer not null default 1 check (review_round > 0),
  status text not null check (status in ('clear','conflict')),
  basis jsonb not null,
  evaluated_at timestamptz not null default now(),
  evaluator text not null,
  external_receipt_id text not null unique,
  policy_version text not null,
  external_signature text not null,
  unique (review_case_id, review_round, reviewer_id)
);

create table if not exists public.pv_claim_validation_receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  review_round integer not null check (review_round > 0),
  status text not null check (status in ('pass','fail')),
  claim_set_digest text not null check (claim_set_digest ~ '^sha256:[0-9a-f]{64}$'),
  reason_codes text[] not null default '{}',
  policy_version text not null,
  external_receipt_id text not null unique,
  external_signature text not null,
  evaluated_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.pv_custos_receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  review_round integer not null default 1 check (review_round > 0),
  external_verdict_id text not null unique,
  status text not null check (status in ('pass','fail')),
  policy_version text not null,
  evaluated_digest text not null check (evaluated_digest ~ '^sha256:[0-9a-f]{64}$'),
  reason_codes text[] not null default '{}',
  evaluated_at timestamptz not null,
  received_at timestamptz not null default now(),
  external_signature text not null
);

create table if not exists public.pv_signing_receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null,
  key_id text not null,
  algorithm text not null check (algorithm in ('Ed25519','ES256')),
  payload_digest text not null check (payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  signature text not null,
  status text not null check (status in ('valid','invalid','key-inactive','unavailable')),
  signed_at timestamptz not null,
  provider_receipt text not null unique,
  non_exportable_key boolean not null check (non_exportable_key),
  created_at timestamptz not null default now()
);

create table if not exists public.pv_credentials (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null unique references public.pv_review_cases(id),
  public_id text not null unique,
  environment text not null check (environment in ('production')),
  status text not null check (status in ('prepared','active','suspended','revoked','superseded','expired','failed')),
  lifecycle text not null check (lifecycle in ('draft','active','suspended','revoked','superseded','expired')),
  tier integer not null check (tier between 1 and 4),
  payload jsonb not null,
  payload_digest text not null check (payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  signing_receipt_id uuid references public.pv_signing_receipts(id),
  registry_receipt jsonb,
  issued_at timestamptz,
  expires_at timestamptz,
  version integer not null default 1,
  successor_id uuid references public.pv_credentials(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.pv_signing_receipts
  drop constraint if exists pv_signing_receipts_credential_id_fkey;
alter table public.pv_signing_receipts
  add constraint pv_signing_receipts_credential_id_fkey foreign key (credential_id) references public.pv_credentials(id);

create table if not exists public.pv_registry_records (
  public_id text primary key,
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null unique references public.pv_credentials(id),
  credential_digest text not null,
  lifecycle text not null,
  public_projection jsonb not null,
  published_at timestamptz not null,
  registry_receipt_id text not null unique,
  revocation_capability_confirmed boolean not null check (revocation_capability_confirmed),
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_credential_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null references public.pv_credentials(id),
  action text not null check (action in ('suspend','reactivate','revoke','supersede','expire','correct')),
  from_state text not null,
  to_state text not null,
  reason text not null,
  actor_id uuid not null references auth.users(id),
  successor_id uuid references public.pv_credentials(id),
  registry_receipt_id text not null,
  occurred_at timestamptz not null default now()
);

create table if not exists public.pv_mark_authorizations (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null references public.pv_credentials(id),
  status text not null check (status in ('authorized','denied','suspended','revoked')),
  tier integer not null check (tier between 1 and 4),
  external_receipt_id text not null unique,
  reason_codes text[] not null default '{}',
  authorized_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (credential_id)
);

create table if not exists public.pv_pilot_outcomes (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  public_id text not null unique,
  outcome jsonb not null,
  custos_receipt_id uuid references public.pv_custos_receipts(id),
  visibly_non_authoritative boolean not null default true check (visibly_non_authoritative),
  production_credential_created boolean not null default false check (not production_credential_created),
  signing_performed boolean not null default false check (not signing_performed),
  mark_authorized boolean not null default false check (not mark_authorized),
  created_at timestamptz not null default now()
);

create table if not exists public.pv_authority_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  aggregate_type text not null,
  aggregate_id text not null,
  sequence bigint not null,
  event_type text not null,
  actor_id text not null,
  payload jsonb not null,
  previous_event_hash text not null,
  event_hash text not null unique check (event_hash ~ '^sha256:[0-9a-f]{64}$'),
  external_signature text,
  occurred_at timestamptz not null default now(),
  unique (aggregate_type, aggregate_id, sequence)
);

create table if not exists public.pv_webhook_endpoints (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  url text not null,
  secret_ciphertext text not null,
  event_types text[] not null,
  status text not null default 'active' check (status in ('active','disabled')),
  secret_hint text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  disabled_at timestamptz,
  disabled_by uuid references auth.users(id),
  unique (tenant_id, url)
);

create table if not exists public.pv_webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  endpoint_id uuid not null references public.pv_webhook_endpoints(id),
  authority_event_id uuid not null references public.pv_authority_events(id),
  attempt integer not null check (attempt > 0),
  status text not null check (status in ('pending','delivered','failed','dead-letter')),
  signature text not null,
  response_code integer,
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  replay_of uuid references public.pv_webhook_deliveries(id),
  unique (endpoint_id, authority_event_id, attempt)
);

create table if not exists public.pv_activation_records (
  id text primary key,
  environment text not null check (environment = 'production'),
  sha256 text not null check (sha256 ~ '^sha256:[0-9a-f]{64}$'),
  gates jsonb not null,
  accountable_authorities jsonb not null,
  signed_at timestamptz not null,
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists pv_memberships_user_idx on public.pv_memberships(user_id, status, tenant_id);
create index if not exists pv_custody_evidence_idx on public.pv_evidence_custody_events(tenant_id, evidence_id, sequence);
create index if not exists pv_reviewer_case_idx on public.pv_reviewer_decisions(tenant_id, review_case_id, stage);
create index if not exists pv_credentials_public_idx on public.pv_credentials(public_id, status, lifecycle);
create index if not exists pv_lifecycle_credential_idx on public.pv_credential_lifecycle_events(tenant_id, credential_id, occurred_at desc);
create index if not exists pv_events_aggregate_idx on public.pv_authority_events(tenant_id, aggregate_type, aggregate_id, sequence);
create index if not exists pv_webhook_queue_idx on public.pv_webhook_deliveries(status, scheduled_at);
create index if not exists pv_api_clients_tenant_idx on public.pv_api_clients(tenant_id, status, created_at desc);

create or replace function public.pv_member_of(p_tenant_id text, p_roles text[] default null)
returns boolean
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.pv_memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and (p_roles is null or m.role = any(p_roles))
  );
$$;

create or replace function public.pv_aal2()
returns boolean
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select coalesce((select auth.jwt()->>'aal') = 'aal2', false);
$$;

create or replace function public.pv_direct_tenant_scope(p_tenant_id text)
returns boolean
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select nullif(current_setting('app.tenant_id', true), '') = p_tenant_id;
$$;

-- Replace the original direct-connection-only policies with dual server/JWT tenant isolation.
do $$
declare
  t text;
  tables text[] := array[
    'pv_locations','pv_inventory_lots','pv_intake_batches','pv_assets','pv_evidence_objects','pv_attestations',
    'pv_review_cases','pv_sync_operations','pv_operational_audit_events','pv_evidence_scan_receipts','pv_evidence_custody_events',
    'pv_reviewer_decisions','pv_conflict_clearances','pv_claim_validation_receipts','pv_custos_receipts','pv_signing_receipts','pv_credentials',
    'pv_registry_records','pv_credential_lifecycle_events','pv_mark_authorizations','pv_pilot_outcomes','pv_authority_events',
    'pv_webhook_endpoints','pv_webhook_deliveries','pv_authority_operations'
  ];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists tenant_scope_%I on public.%I', replace(t, 'pv_', ''), t);
    execute format('drop policy if exists pv_tenant_select on public.%I', t);
    execute format('drop policy if exists pv_tenant_insert on public.%I', t);
    execute format('drop policy if exists pv_tenant_update on public.%I', t);
    execute format('drop policy if exists pv_tenant_delete on public.%I', t);
    execute format('create policy pv_tenant_select on public.%I for select to authenticated using (public.pv_member_of(tenant_id) or public.pv_direct_tenant_scope(tenant_id))', t);
    execute format('create policy pv_tenant_insert on public.%I for insert to authenticated with check ((public.pv_member_of(tenant_id) and public.pv_aal2()) or public.pv_direct_tenant_scope(tenant_id))', t);
    execute format('create policy pv_tenant_update on public.%I for update to authenticated using ((public.pv_member_of(tenant_id) and public.pv_aal2()) or public.pv_direct_tenant_scope(tenant_id)) with check ((public.pv_member_of(tenant_id) and public.pv_aal2()) or public.pv_direct_tenant_scope(tenant_id))', t);
    execute format('create policy pv_tenant_delete on public.%I for delete to authenticated using ((public.pv_member_of(tenant_id) and public.pv_aal2()) or public.pv_direct_tenant_scope(tenant_id))', t);
  end loop;
end $$;

alter table public.pv_tenants enable row level security;
drop policy if exists pv_tenant_directory_select on public.pv_tenants;
create policy pv_tenant_directory_select on public.pv_tenants for select to authenticated
using (public.pv_member_of(id) or public.pv_direct_tenant_scope(id));

alter table public.pv_memberships enable row level security;
drop policy if exists pv_membership_self_select on public.pv_memberships;
create policy pv_membership_self_select on public.pv_memberships for select to authenticated
using (user_id = (select auth.uid()));


drop policy if exists pv_api_clients_admin_select on public.pv_api_clients;
create policy pv_api_clients_admin_select on public.pv_api_clients for select to authenticated
using (public.pv_member_of(tenant_id, array['owner','administrator']));
drop policy if exists pv_api_clients_admin_insert on public.pv_api_clients;
create policy pv_api_clients_admin_insert on public.pv_api_clients for insert to authenticated
with check (public.pv_member_of(tenant_id, array['owner','administrator']) and public.pv_aal2());
drop policy if exists pv_api_clients_admin_update on public.pv_api_clients;
create policy pv_api_clients_admin_update on public.pv_api_clients for update to authenticated
using (public.pv_member_of(tenant_id, array['owner','administrator']) and public.pv_aal2())
with check (public.pv_member_of(tenant_id, array['owner','administrator']) and public.pv_aal2());

alter table public.pv_api_clients enable row level security;
drop policy if exists pv_tenant_select on public.pv_api_clients;
drop policy if exists pv_tenant_insert on public.pv_api_clients;
drop policy if exists pv_tenant_update on public.pv_api_clients;
drop policy if exists pv_tenant_delete on public.pv_api_clients;

alter table public.pv_environment_controls enable row level security;
drop policy if exists pv_environment_controls_read on public.pv_environment_controls;
create policy pv_environment_controls_read on public.pv_environment_controls for select to authenticated using (true);

alter table public.pv_activation_records enable row level security;
drop policy if exists pv_activation_read on public.pv_activation_records;
create policy pv_activation_read on public.pv_activation_records for select to authenticated using (active);

-- Public registry visibility is explicit and read-only.
drop policy if exists pv_registry_public_select on public.pv_registry_records;
create policy pv_registry_public_select on public.pv_registry_records for select to anon, authenticated
using (published_at is not null);

-- Immutable trust objects cannot be updated or deleted, even by authenticated application users.
create or replace function public.pv_reject_mutation()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$ begin raise exception 'APPEND_ONLY_OBJECT'; end $$;

do $$
declare t text;
begin
  foreach t in array array['pv_evidence_scan_receipts','pv_evidence_custody_events','pv_claim_validation_receipts','pv_custos_receipts','pv_signing_receipts','pv_authority_events'] loop
    execute format('drop trigger if exists %I_immutable on public.%I', t, t);
    execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function public.pv_reject_mutation()', t, t);
  end loop;
end $$;

-- Evidence storage bucket. No UPDATE policy is created: production evidence bytes cannot be replaced.
insert into storage.buckets(id, name, public, file_size_limit)
values ('pv-evidence', 'pv-evidence', false, 104857600)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists pv_evidence_storage_insert on storage.objects;
create policy pv_evidence_storage_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'pv-evidence'
  and public.pv_aal2()
  and public.pv_member_of((storage.foldername(name))[1])
);

drop policy if exists pv_evidence_storage_select on storage.objects;
create policy pv_evidence_storage_select on storage.objects for select to authenticated
using (
  bucket_id = 'pv-evidence'
  and public.pv_member_of((storage.foldername(name))[1])
);

create or replace function provenance_api.pv_session_snapshot(p_tenant_id text, p_environment text default 'production')
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  membership public.pv_memberships%rowtype;
  result jsonb;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into membership from public.pv_memberships
   where tenant_id = p_tenant_id and user_id = (select auth.uid()) and status = 'active';
  if not found then raise exception 'TENANT_MEMBERSHIP_REQUIRED'; end if;

  select jsonb_build_object(
    'session', jsonb_build_object(
      'id', coalesce((select auth.jwt()->>'session_id'), gen_random_uuid()::text),
      'tenantId', membership.tenant_id,
      'userId', membership.user_id,
      'displayName', membership.display_name,
      'role', membership.role,
      'locationIds', membership.location_ids,
      'deviceId', coalesce((select auth.jwt()->>'device_id'), 'server-authenticated'),
      'authenticatedAt', now(),
      'expiresAt', to_timestamp(coalesce((select (auth.jwt()->>'exp')::bigint), extract(epoch from now() + interval '15 minutes')::bigint)),
      'testMode', false,
      'environment', p_environment,
      'assuranceLevel', coalesce((select auth.jwt()->>'aal'), 'aal1')
    ),
    'dataset', jsonb_build_object(
      'tenants', coalesce((select jsonb_agg(to_jsonb(t)) from public.pv_tenants t where t.id = p_tenant_id), '[]'::jsonb),
      'locations', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_locations x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'sessions', jsonb_build_array(jsonb_build_object(
        'id', coalesce((select auth.jwt()->>'session_id'), gen_random_uuid()::text), 'tenantId', membership.tenant_id,
        'userId', membership.user_id, 'displayName', membership.display_name, 'role', membership.role,
        'locationIds', membership.location_ids, 'deviceId', 'server-authenticated', 'authenticatedAt', now(),
        'expiresAt', now() + interval '15 minutes', 'testMode', false, 'environment', p_environment,
        'assuranceLevel', coalesce((select auth.jwt()->>'aal'), 'aal1')
      )),
      'lots', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_inventory_lots x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'batches', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_intake_batches x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'assets', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_assets x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'evidence', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_evidence_objects x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'attestations', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_attestations x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'reviewCases', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_review_cases x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'syncOperations', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_sync_operations x where x.tenant_id = p_tenant_id), '[]'::jsonb),
      'auditEvents', coalesce((select jsonb_agg(to_jsonb(x)) from public.pv_operational_audit_events x where x.tenant_id = p_tenant_id), '[]'::jsonb)
    )
  ) into result;
  return result;
end $$;

create or replace function provenance_api.pv_record_pilot_outcome(
  p_review_case_id text,
  p_custos_receipt_id uuid,
  p_outcome jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  r public.pv_review_cases%rowtype;
  c public.pv_custos_receipts%rowtype;
  public_id text;
  result public.pv_pilot_outcomes%rowtype;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into r from public.pv_review_cases where id = p_review_case_id;
  if not found or not public.pv_member_of(r.tenant_id, array['compliance-officer']) then raise exception 'AUTHORITY_DENIED'; end if;
  select * into c from public.pv_custos_receipts where id = p_custos_receipt_id and review_case_id = r.id and status = 'pass';
  if not found then raise exception 'CUSTOS_PASS_REQUIRED'; end if;
  public_id := 'PV-PILOT-' || upper(substr(encode(extensions.digest(r.id || now()::text, 'sha256'), 'hex'), 1, 8));
  insert into public.pv_pilot_outcomes(tenant_id, review_case_id, public_id, outcome, custos_receipt_id)
  values (r.tenant_id, r.id, public_id, p_outcome || jsonb_build_object('environment','pilot','authoritative',false,'watermark','PILOT / NON-AUTHORITATIVE'), c.id)
  returning * into result;
  return to_jsonb(result);
end $$;

create or replace function provenance_api.pv_prepare_credential(
  p_review_case_id text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  r public.pv_review_cases%rowtype;
  control public.pv_environment_controls%rowtype;
  activation public.pv_activation_records%rowtype;
  custos public.pv_custos_receipts%rowtype;
  reviewer_count integer;
  conflict_count integer;
  clear_count integer;
  custody_incomplete integer;
  evidence_count integer;
  claim_validation_count integer;
  payload jsonb;
  digest_value text;
  credential public.pv_credentials%rowtype;
  next_sequence bigint;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into r from public.pv_review_cases where id = p_review_case_id;
  if not found then raise exception 'REVIEW_NOT_FOUND'; end if;
  if not public.pv_member_of(r.tenant_id, array['compliance-officer']) then raise exception 'ISSUER_PERMISSION_REQUIRED'; end if;

  select * into control from public.pv_environment_controls where environment = 'production';
  if not control.authoritative_issuance_enabled then raise exception 'PRODUCTION_ISSUANCE_DISABLED'; end if;
  if not control.registry_ready then raise exception 'REGISTRY_UNAVAILABLE'; end if;
  if not control.revocation_ready then raise exception 'REVOCATION_UNAVAILABLE'; end if;
  if control.active_signing_key_id is null then raise exception 'SIGNING_KEY_UNAVAILABLE'; end if;
  select * into activation from public.pv_activation_records where id = control.activation_record_id and active;
  if not found or activation.sha256 <> control.activation_record_sha256 then raise exception 'ACTIVATION_RECORD_INVALID'; end if;

  select count(*) into reviewer_count from public.pv_reviewer_decisions
   where review_case_id = r.id and review_round = r.current_review_round and decision = 'approve' and independent and conflict_free;
  if reviewer_count < 2 then raise exception 'TWO_INDEPENDENT_APPROVALS_REQUIRED'; end if;
  select count(*) into conflict_count from public.pv_conflict_clearances where review_case_id = r.id and review_round = r.current_review_round and status = 'conflict';
  if conflict_count > 0 then raise exception 'REVIEWER_CONFLICT'; end if;
  select count(*) into clear_count from public.pv_conflict_clearances where review_case_id = r.id and review_round = r.current_review_round and status = 'clear';
  if clear_count < 2 then raise exception 'CONFLICT_CLEARANCE_INCOMPLETE'; end if;

  select count(*) into claim_validation_count from public.pv_claim_validation_receipts
   where review_case_id = r.id and review_round = r.current_review_round and status = 'pass';
  if claim_validation_count < 1 then raise exception 'CLAIM_VALIDATION_INCOMPLETE'; end if;

  select * into custos from public.pv_custos_receipts
   where review_case_id = r.id and review_round = r.current_review_round and status = 'pass' order by evaluated_at desc limit 1;
  if not found then raise exception 'CUSTOS_PASS_REQUIRED'; end if;

  select count(*) into evidence_count from public.pv_evidence_objects e
  where e.asset_id = r.asset_id and e.status = 'active' and e.qualified;
  if evidence_count < 1 then raise exception 'QUALIFIED_EVIDENCE_REQUIRED'; end if;

  select count(*) into custody_incomplete
  from public.pv_evidence_objects e
  where e.asset_id = r.asset_id and e.status = 'active' and e.qualified
    and not exists (
      select 1 from public.pv_evidence_custody_events ce
      where ce.evidence_id = e.id and ce.history_complete and ce.scan_status = 'passed' and ce.object_sha256 = e.integrity_hash
    );
  if custody_incomplete > 0 then raise exception 'EVIDENCE_CUSTODY_INCOMPLETE'; end if;

  payload := jsonb_build_object(
    'issuer','VERITAN, INC.','platform','PROVENANCE.CX','program','Provenance Verified™',
    'reviewCaseId',r.id,'assetId',r.asset_id,'publicId',coalesce(r.registry_id, 'PV-' || upper(substr(encode(extensions.digest(r.id, 'sha256'), 'hex'),1,4)) || '-' || upper(substr(encode(extensions.digest(r.asset_id, 'sha256'), 'hex'),1,6))),
    'tier',coalesce((r.decision->>'tier')::integer, 1),'authority',jsonb_build_object('reviewers',reviewer_count,'custosVerdictId',custos.external_verdict_id),
    'preparedAt',now(),'idempotencyKey',p_idempotency_key
  );
  digest_value := 'sha256:' || encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex');

  insert into public.pv_credentials(tenant_id, review_case_id, public_id, environment, status, lifecycle, tier, payload, payload_digest)
  values (r.tenant_id, r.id, payload->>'publicId', 'production', 'prepared', 'draft', (payload->>'tier')::integer, payload, digest_value)
  on conflict (review_case_id) do update set updated_at = now()
  returning * into credential;

  select coalesce(max(sequence),0)+1 into next_sequence from public.pv_authority_events where aggregate_type='credential' and aggregate_id=credential.id::text;
  insert into public.pv_authority_events(tenant_id, aggregate_type, aggregate_id, sequence, event_type, actor_id, payload, previous_event_hash, event_hash)
  values (
    r.tenant_id,'credential',credential.id::text,next_sequence,'credential.prepared',(select auth.uid())::text,
    jsonb_build_object('payloadDigest',digest_value,'reviewCaseId',r.id),
    coalesce((select event_hash from public.pv_authority_events where aggregate_type='credential' and aggregate_id=credential.id::text order by sequence desc limit 1),'GENESIS'),
    'sha256:' || encode(extensions.digest(convert_to(credential.id::text || ':' || next_sequence::text || ':' || digest_value,'UTF8'),'sha256'),'hex')
  );

  return jsonb_build_object('credentialId',credential.id,'publicId',credential.public_id,'payload',credential.payload,'payloadDigest',credential.payload_digest,'requiredSigningKeyId',control.active_signing_key_id);
end $$;

create or replace function provenance_api.pv_finalize_credential(
  p_credential_id uuid,
  p_signing_receipt_id uuid,
  p_registry_receipt jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  c public.pv_credentials%rowtype;
  s public.pv_signing_receipts%rowtype;
  control public.pv_environment_controls%rowtype;
  record public.pv_registry_records%rowtype;
  next_sequence bigint;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into c from public.pv_credentials where id = p_credential_id for update;
  if not found then raise exception 'CREDENTIAL_NOT_FOUND'; end if;
  if not public.pv_member_of(c.tenant_id, array['compliance-officer']) then raise exception 'ISSUER_PERMISSION_REQUIRED'; end if;
  if c.status <> 'prepared' then raise exception 'CREDENTIAL_NOT_PREPARED'; end if;
  select * into control from public.pv_environment_controls where environment='production';
  if not control.registry_ready then raise exception 'REGISTRY_UNAVAILABLE'; end if;
  if not control.revocation_ready then raise exception 'REVOCATION_UNAVAILABLE'; end if;
  select * into s from public.pv_signing_receipts where id=p_signing_receipt_id and credential_id=c.id;
  if not found or s.status <> 'valid' or not s.non_exportable_key then raise exception 'VALID_NON_EXPORTABLE_SIGNATURE_REQUIRED'; end if;
  if s.payload_digest <> c.payload_digest then raise exception 'SIGNATURE_DIGEST_MISMATCH'; end if;
  if s.key_id <> control.active_signing_key_id then raise exception 'SIGNING_KEY_INACTIVE'; end if;
  if coalesce(p_registry_receipt->>'credentialDigest','') <> c.payload_digest then raise exception 'REGISTRY_DIGEST_MISMATCH'; end if;
  if coalesce((p_registry_receipt->>'revocationCapabilityConfirmed')::boolean,false) is not true then raise exception 'REVOCATION_CAPABILITY_UNCONFIRMED'; end if;
  if nullif(p_registry_receipt->>'receiptId','') is null then raise exception 'REGISTRY_RECEIPT_REQUIRED'; end if;

  update public.pv_credentials set status='active', lifecycle='active', signing_receipt_id=s.id, registry_receipt=p_registry_receipt, issued_at=now(), updated_at=now()
  where id=c.id returning * into c;

  insert into public.pv_registry_records(public_id,tenant_id,credential_id,credential_digest,lifecycle,public_projection,published_at,registry_receipt_id,revocation_capability_confirmed)
  values (c.public_id,c.tenant_id,c.id,c.payload_digest,'active',c.payload || jsonb_build_object('signature',jsonb_build_object('algorithm',s.algorithm,'keyId',s.key_id,'value',s.signature,'valid',true),'lifecycle','active','authoritative',true),now(),p_registry_receipt->>'receiptId',true)
  on conflict (public_id) do update set public_projection=excluded.public_projection,lifecycle=excluded.lifecycle,registry_receipt_id=excluded.registry_receipt_id,updated_at=now()
  returning * into record;

  select coalesce(max(sequence),0)+1 into next_sequence from public.pv_authority_events where aggregate_type='credential' and aggregate_id=c.id::text;
  insert into public.pv_authority_events(tenant_id,aggregate_type,aggregate_id,sequence,event_type,actor_id,payload,previous_event_hash,event_hash,external_signature)
  values (c.tenant_id,'credential',c.id::text,next_sequence,'credential.issued',(select auth.uid())::text,jsonb_build_object('publicId',c.public_id,'registryReceiptId',record.registry_receipt_id),coalesce((select event_hash from public.pv_authority_events where aggregate_type='credential' and aggregate_id=c.id::text order by sequence desc limit 1),'GENESIS'),'sha256:'||encode(extensions.digest(convert_to(c.id::text||':'||next_sequence::text||':'||record.registry_receipt_id,'UTF8'),'sha256'),'hex'),s.signature);

  update public.pv_review_cases set status='issued', credential_lifecycle='active', registry_status='ready', signing_key_status='active', revocation_capability=true, updated_at=now() where id=c.review_case_id;
  return jsonb_build_object('credential',to_jsonb(c),'registry',to_jsonb(record),'sealAuthorized',false);
end $$;

create or replace function provenance_api.pv_authorize_mark(
  p_credential_id uuid,
  p_external_receipt_id text,
  p_reason_codes text[] default '{}'
) returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare c public.pv_credentials%rowtype; control public.pv_environment_controls%rowtype; mark public.pv_mark_authorizations%rowtype;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into c from public.pv_credentials where id=p_credential_id;
  if not found or c.status <> 'active' or c.lifecycle <> 'active' then raise exception 'ACTIVE_CREDENTIAL_REQUIRED'; end if;
  if not public.pv_member_of(c.tenant_id,array['compliance-officer']) then raise exception 'MARK_PERMISSION_REQUIRED'; end if;
  select * into control from public.pv_environment_controls where environment='production';
  if not control.certification_marks_enabled then raise exception 'MARK_AUTHORIZATION_DISABLED'; end if;
  insert into public.pv_mark_authorizations(tenant_id,credential_id,status,tier,external_receipt_id,reason_codes,authorized_at)
  values(c.tenant_id,c.id,'authorized',c.tier,p_external_receipt_id,p_reason_codes,now())
  on conflict(credential_id) do update set status='authorized',external_receipt_id=excluded.external_receipt_id,reason_codes=excluded.reason_codes,authorized_at=now(),updated_at=now()
  returning * into mark;
  return to_jsonb(mark);
end $$;

create or replace function provenance_api.pv_lifecycle_transition(
  p_credential_id uuid,
  p_action text,
  p_reason text,
  p_registry_receipt_id text,
  p_successor_id uuid default null
) returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare c public.pv_credentials%rowtype; previous_state text; next_state text; ev public.pv_credential_lifecycle_events%rowtype;
begin
  if not public.pv_aal2() then raise exception 'MFA_REQUIRED'; end if;
  select * into c from public.pv_credentials where id=p_credential_id for update;
  if not found then raise exception 'CREDENTIAL_NOT_FOUND'; end if;
  previous_state := c.lifecycle;
  if not public.pv_member_of(c.tenant_id,array['owner','administrator','compliance-officer']) then raise exception 'LIFECYCLE_PERMISSION_REQUIRED'; end if;
  next_state := case p_action
    when 'suspend' then 'suspended' when 'reactivate' then 'active' when 'revoke' then 'revoked'
    when 'supersede' then 'superseded' when 'expire' then 'expired' else null end;
  if next_state is null then raise exception 'LIFECYCLE_ACTION_INVALID'; end if;
  if p_action='reactivate' and c.lifecycle <> 'suspended' then raise exception 'REACTIVATION_REQUIRES_SUSPENDED'; end if;
  if p_action='supersede' and p_successor_id is null then raise exception 'SUCCESSOR_REQUIRED'; end if;
  update public.pv_credentials set lifecycle=next_state,status=case when next_state='active' then 'active' else next_state end,successor_id=p_successor_id,updated_at=now(),version=version+1 where id=c.id returning * into c;
  update public.pv_registry_records set lifecycle=next_state,public_projection=public_projection||jsonb_build_object('lifecycle',next_state,'successorId',p_successor_id),registry_receipt_id=p_registry_receipt_id,updated_at=now() where credential_id=c.id;
  update public.pv_mark_authorizations set status=case when next_state='active' then status when next_state='revoked' then 'revoked' else 'suspended' end,updated_at=now() where credential_id=c.id;
  insert into public.pv_credential_lifecycle_events(tenant_id,credential_id,action,from_state,to_state,reason,actor_id,successor_id,registry_receipt_id)
  values(c.tenant_id,c.id,p_action,previous_state,next_state,p_reason,(select auth.uid()),p_successor_id,p_registry_receipt_id)
  returning * into ev;
  return jsonb_build_object('credential',to_jsonb(c),'event',to_jsonb(ev));
end $$;

create or replace view provenance_api.pv_public_registry
with (security_invoker=true)
as
select public_id, credential_digest, lifecycle, public_projection, published_at, updated_at
from public.pv_registry_records;

revoke all on schema provenance_api from public;
grant usage on schema provenance_api to anon, authenticated;
revoke all on all functions in schema provenance_api from public, anon, authenticated;
grant execute on function provenance_api.pv_session_snapshot(text,text) to authenticated;
grant execute on function provenance_api.pv_record_pilot_outcome(text,uuid,jsonb) to authenticated;
grant execute on function provenance_api.pv_prepare_credential(text,text) to authenticated;
grant execute on function provenance_api.pv_finalize_credential(uuid,uuid,jsonb) to authenticated;
grant execute on function provenance_api.pv_authorize_mark(uuid,text,text[]) to authenticated;
grant execute on function provenance_api.pv_lifecycle_transition(uuid,text,text,text,uuid) to authenticated;
grant select on provenance_api.pv_public_registry to anon, authenticated;

-- Table grants are intentionally narrow; RLS remains mandatory.
grant select on public.pv_memberships, public.pv_environment_controls to authenticated;
grant select, insert, update on public.pv_tenants, public.pv_locations, public.pv_api_clients, public.pv_authority_operations, public.pv_inventory_lots, public.pv_intake_batches, public.pv_assets, public.pv_evidence_objects, public.pv_attestations, public.pv_review_cases, public.pv_sync_operations, public.pv_operational_audit_events to authenticated;
grant select, insert on public.pv_evidence_scan_receipts, public.pv_evidence_custody_events, public.pv_reviewer_decisions, public.pv_conflict_clearances, public.pv_claim_validation_receipts to authenticated;
grant select on public.pv_custos_receipts, public.pv_signing_receipts, public.pv_credentials, public.pv_registry_records, public.pv_credential_lifecycle_events, public.pv_mark_authorizations, public.pv_pilot_outcomes, public.pv_authority_events to authenticated;
grant select on public.pv_registry_records to anon;
