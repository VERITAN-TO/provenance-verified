-- PROVENANCE.CX R8.1 R3 full corrective authority migration
-- Applies after 001_phase4_operations.sql and 002_r8_1_production_authority.sql.
-- Removes generic authenticated mutation, introduces service-command boundaries,
-- cryptographic receipts, durable workflows/outbox, append-only registry and event chains,
-- Category L readiness, media custody, governance, launch and stabilization control planes.

create extension if not exists pgcrypto;
create schema if not exists provenance_api;

-- Service identities are supplied by short-lived workload credentials and mapped by the API layer.
create table if not exists public.pv_workload_identities (
  id text primary key,
  service_name text not null,
  environment text not null check (environment in ('pilot','production')),
  tenant_ids text[] not null,
  allowed_operations text[] not null,
  status text not null check (status in ('active','disabled','revoked')),
  key_id text not null,
  key_version integer not null check (key_version > 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create table if not exists public.pv_authority_key_registry (
  service_name text not null,
  key_id text not null,
  key_version integer not null check (key_version > 0),
  algorithm text not null check (algorithm in ('Ed25519','ES256')),
  public_key_pem text not null,
  status text not null check (status in ('active','disabled','revoked')),
  allowed_policy_versions text[] not null,
  valid_from timestamptz not null,
  valid_until timestamptz,
  rotated_from_key_version integer,
  created_at timestamptz not null default now(),
  primary key (service_name,key_id,key_version)
);

create table if not exists public.pv_receipt_nonces (
  issuer_service text not null,
  tenant_id text not null,
  subject text not null,
  operation text not null,
  nonce text not null,
  expires_at timestamptz not null,
  used_at timestamptz not null default now(),
  primary key (issuer_service,tenant_id,subject,operation,nonce)
);

create table if not exists public.pv_provider_idempotency (
  service_identity text not null,
  tenant_id text not null,
  operation text not null,
  idempotency_key text not null,
  request_digest text not null check (request_digest ~ '^sha256:[0-9a-f]{64}$'),
  result_digest text check (result_digest is null or result_digest ~ '^sha256:[0-9a-f]{64}$'),
  result jsonb,
  status text not null check (status in ('running','completed','failed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (service_identity,tenant_id,operation,idempotency_key)
);

create table if not exists public.pv_authority_receipts (
  receipt_id text primary key,
  issuer_service text not null,
  tenant_id text not null references public.pv_tenants(id),
  subject text not null,
  operation text not null,
  decision text not null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  nonce text not null,
  request_digest text not null check (request_digest ~ '^sha256:[0-9a-f]{64}$'),
  response_digest text not null check (response_digest ~ '^sha256:[0-9a-f]{64}$'),
  policy_version text not null,
  key_id text not null,
  key_version integer not null,
  algorithm text not null check (algorithm in ('Ed25519','ES256')),
  signature text not null,
  verified_at timestamptz not null default now(),
  verification_result text not null check (verification_result in ('valid','invalid')),
  reason_codes text[] not null default '{}'
);

create table if not exists public.pv_claim_protocols (
  protocol_id text not null,
  version text not null,
  claim_type text not null,
  eligible_tiers integer[] not null,
  required_evidence_classes text[] not null,
  minimum_evidence_count integer not null check (minimum_evidence_count > 0),
  max_evidence_age_days integer not null check (max_evidence_age_days > 0),
  accredited_sources_required boolean not null,
  measurement_requirements text[] not null,
  geographic_rules jsonb not null,
  material_rules jsonb not null,
  contradiction_policy text not null check (contradiction_policy in ('deny','escalate')),
  exception_rules jsonb not null,
  decision_expiry_days integer not null check (decision_expiry_days > 0),
  required_reviewer_count integer not null check (required_reviewer_count in (1,2)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (protocol_id,version)
);

create table if not exists public.pv_claim_validation_decisions (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  claim_id text not null,
  protocol_id text not null,
  protocol_version text not null,
  status text not null check (status in ('pass','deny','escalate')),
  evidence_used text[] not null,
  evidence_rejected jsonb not null,
  contradictions text[] not null,
  derived_result text not null,
  confidence text not null check (confidence in ('high','medium','low')),
  reason_codes text[] not null,
  receipt_id text not null unique references public.pv_authority_receipts(receipt_id),
  evaluated_at timestamptz not null,
  expires_at timestamptz not null,
  unique (tenant_id,claim_id,protocol_id,protocol_version)
);

create table if not exists public.pv_reviewer_relationships (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  reviewer_id uuid not null references auth.users(id),
  relationship_type text not null check (relationship_type in ('employer','organization','ownership','beneficial-interest','financial-interest','family','client','supplier','prior-engagement','prior-asset','prior-claim','declared-conflict','discovered-conflict','accreditation-restriction')),
  related_organization_id text,
  related_asset_id text,
  related_claim_id text,
  details jsonb not null default '{}',
  effective_from timestamptz not null,
  effective_until timestamptz,
  verified_at timestamptz
);
create unique index if not exists pv_reviewer_relationship_unique_idx on public.pv_reviewer_relationships(tenant_id,reviewer_id,relationship_type,coalesce(related_organization_id,''),coalesce(related_asset_id,''),coalesce(related_claim_id,''));

create table if not exists public.pv_registry_versions (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null references public.pv_credentials(id),
  public_id text not null,
  version integer not null check (version > 0),
  payload jsonb not null,
  payload_digest text not null check (payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  credential_signature text not null,
  signing_key_id text not null,
  signing_key_version integer not null,
  created_at timestamptz not null default now(),
  unique (credential_id,version),
  unique (public_id,version)
);

create table if not exists public.pv_registry_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null references public.pv_credentials(id),
  public_id text not null,
  sequence bigint not null check (sequence > 0),
  event_type text not null check (event_type in ('issued','active','suspended','reactivated','revoked','superseded','expired','corrected','quarantined')),
  from_state text,
  to_state text not null,
  credential_version integer not null,
  reason text,
  previous_event_hash text not null,
  event_hash text not null check (event_hash ~ '^sha256:[0-9a-f]{64}$'),
  registry_signature text not null,
  registry_key_id text not null,
  registry_key_version integer not null,
  occurred_at timestamptz not null default now(),
  unique (credential_id,sequence),
  unique (event_hash)
);

create table if not exists public.pv_authority_workflows (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null,
  state text not null check (state in ('DRAFT','EVIDENCE_COMPLETE','REVIEW_COMPLETE','CUSTOS_AUTHORIZED','SIGNING_PENDING','SIGNED','REGISTRY_PENDING','ACTIVE','FAILED','COMPENSATION_REQUIRED','REVOKED')),
  version integer not null default 1,
  last_error text,
  registry_public_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,credential_id)
);

create table if not exists public.pv_workflow_transitions (
  id uuid primary key default gen_random_uuid(),
  workflow_id uuid not null references public.pv_authority_workflows(id),
  tenant_id text not null references public.pv_tenants(id),
  sequence bigint not null,
  from_state text,
  to_state text not null,
  transition_type text not null,
  idempotency_key text not null,
  payload jsonb not null default '{}',
  occurred_at timestamptz not null default now(),
  unique (workflow_id,sequence),
  unique (workflow_id,idempotency_key)
);

create table if not exists public.pv_transactional_outbox (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  workflow_id uuid not null references public.pv_authority_workflows(id),
  topic text not null,
  message_key text not null,
  payload jsonb not null,
  status text not null default 'pending' check (status in ('pending','processing','delivered','dead-letter')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  delivered_at timestamptz,
  last_error text,
  unique (topic,message_key)
);
create index if not exists pv_outbox_claim_idx on public.pv_transactional_outbox(status,available_at) where status in ('pending','processing');

create table if not exists public.pv_dead_letters (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  source_table text not null,
  source_id uuid not null,
  topic text not null,
  payload jsonb not null,
  attempts integer not null,
  final_error text not null,
  created_at timestamptz not null default now(),
  replayed_at timestamptz,
  replayed_by text
);

create table if not exists public.pv_webhook_delivery_queue (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  endpoint_id uuid not null references public.pv_webhook_endpoints(id),
  event_id text not null,
  delivery_id text not null unique,
  payload jsonb not null,
  payload_signature text not null,
  signature_timestamp timestamptz not null,
  status text not null default 'queued' check (status in ('queued','processing','delivered','retrying','dead-letter','cancelled')),
  attempt integer not null default 0,
  maximum_attempts integer not null default 8,
  next_attempt_at timestamptz not null default now(),
  last_http_status integer,
  last_error text,
  response_bytes integer,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  unique (endpoint_id,event_id)
);

create table if not exists public.pv_category_l_controls (
  id text primary key check (id ~ '^L-0(0[1-9]|1[0-9]|2[0-4])$'),
  name text not null,
  owner_identity text not null,
  dependencies text[] not null,
  evidence_requirements jsonb not null,
  pass_conditions jsonb not null,
  block_conditions jsonb not null,
  state text not null check (state in ('NOT_READY','READY','BLOCKED','STALE')),
  manual_block text,
  evaluated_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_category_l_evidence (
  control_id text not null references public.pv_category_l_controls(id),
  evidence_id text not null,
  evidence_digest text not null check (evidence_digest ~ '^sha256:[0-9a-f]{64}$'),
  evidence_url text not null,
  verified boolean not null,
  created_at timestamptz not null,
  expires_at timestamptz,
  primary key (control_id,evidence_id)
);

create table if not exists public.pv_media_identifiers (
  id text primary key,
  tenant_id text not null references public.pv_tenants(id),
  media_type text not null check (media_type in ('QR','NFC')),
  credential_id uuid references public.pv_credentials(id),
  activation_code_hash text not null check (activation_code_hash ~ '^sha256:[0-9a-f]{64}$'),
  state text not null check (state in ('created','bound','encoded','inventory','shipped','received','active','lost','recalled','destroyed','replaced','suppressed')),
  use_count integer not null default 0 check (use_count in (0,1)),
  replacement_media_id text references public.pv_media_identifiers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_media_custody_events (
  id uuid primary key default gen_random_uuid(),
  media_id text not null references public.pv_media_identifiers(id),
  tenant_id text not null references public.pv_tenants(id),
  sequence bigint not null,
  action text not null,
  from_state text not null,
  to_state text not null,
  actor_id text not null,
  custody_party text not null,
  shipment_reference text,
  recipient_confirmation text,
  occurred_at timestamptz not null default now(),
  previous_event_hash text not null,
  event_hash text not null check (event_hash ~ '^sha256:[0-9a-f]{64}$'),
  unique (media_id,sequence),
  unique (event_hash)
);

create table if not exists public.pv_governed_parties (
  id text primary key,
  party_type text not null check (party_type in ('reviewer','reviewer-organization','partner','vendor')),
  organization_id text,
  accreditation_scopes text[] not null,
  contract_status text not null check (contract_status in ('current','expired','terminated','missing')),
  access_scopes text[] not null,
  conflict_domains text[] not null,
  status text not null check (status in ('active','suspended','expired','terminated','reassessment-required')),
  expires_at timestamptz not null,
  last_assessed_at timestamptz not null,
  next_reassessment_at timestamptz not null,
  evidence_retention_until timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_customer_acceptance (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null unique references public.pv_tenants(id),
  customer_type text not null check (customer_type in ('customer-zero','customer-one')),
  unrelated_to_other_tenant boolean not null,
  aggregate_lot_proof boolean not null,
  evidence_ingestion_proof boolean not null,
  lifecycle_proof boolean not null,
  isolation_proof boolean not null,
  operational_acceptance boolean not null,
  rollback_tested boolean not null,
  accepted_at timestamptz,
  evidence jsonb not null default '{}'
);

create table if not exists public.pv_launch_gates (
  id text primary key check (id in ('G1','G2','G3','G4','G5')),
  state text not null check (state in ('pending','approved','blocked')),
  evidence_fresh boolean not null,
  approver_identities text[] not null,
  approval_signatures text[] not null,
  activation_record_id text references public.pv_activation_records(id),
  key_ceremony_reference text,
  release_hashes text[] not null,
  rollback_authority text,
  kill_switch_ready boolean not null default false,
  activation_timestamp timestamptz,
  post_activation_checks jsonb not null default '[]',
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_stabilization_daily_controls (
  day integer primary key check (day between 1 and 90),
  control_date date not null unique,
  daily_controls_pass boolean not null,
  weekly_risk_review boolean,
  defect_trend integer not null default 0,
  incidents_reviewed boolean not null,
  issuance_healthy boolean not null,
  revocation_healthy boolean not null,
  registry_consistent boolean not null,
  key_healthy boolean not null,
  custos_healthy boolean not null,
  evidence_custody_healthy boolean not null,
  customer_support_healthy boolean not null,
  authority_review text check (authority_review is null or authority_review in ('pass','fail')),
  evidence jsonb not null default '{}',
  recorded_at timestamptz not null default now()
);

create table if not exists public.pv_mark_artwork_versions (
  id text primary key,
  version text not null unique,
  artwork_digest text not null check (artwork_digest ~ '^sha256:[0-9a-f]{64}$'),
  status text not null check (status in ('active','recalled','retired')),
  permitted_media text[] not null,
  permitted_geographies text[] not null,
  effective_at timestamptz not null,
  recalled_at timestamptz,
  recall_reason text
);

create table if not exists public.pv_mark_usage_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  authorization_id uuid not null references public.pv_mark_authorizations(id),
  credential_id uuid not null references public.pv_credentials(id),
  action text not null check (action in ('authorized','rendered','renewed','suspended','withdrawn','recalled','suppressed','qr-invalidated','nfc-invalidated','enforcement')),
  media_type text not null,
  geography text not null,
  artwork_version text not null,
  actor_id text not null,
  occurred_at timestamptz not null default now(),
  details jsonb not null default '{}'
);

-- Immutable guard used for audit, custody, versions, decisions, receipts and registry history.
create or replace function provenance_api.deny_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'PV_IMMUTABLE_RELATION:%', tg_table_name using errcode = '55000';
end;
$$;

-- Remove generic authenticated mutation policies created by R2.
do $$
declare t text;
begin
  foreach t in array array[
    'pv_evidence_objects','pv_evidence_scan_receipts','pv_evidence_custody_events','pv_reviewer_decisions',
    'pv_conflict_clearances','pv_claim_validation_receipts','pv_custos_receipts','pv_signing_receipts',
    'pv_credentials','pv_credential_lifecycle_events','pv_mark_authorizations','pv_authority_operations',
    'pv_authority_events','pv_registry_versions','pv_registry_events','pv_authority_receipts',
    'pv_claim_validation_decisions','pv_workflow_transitions','pv_media_custody_events','pv_mark_usage_events'
  ] loop
    if to_regclass('public.'||t) is not null then
      execute format('drop policy if exists pv_tenant_insert on public.%I',t);
      execute format('drop policy if exists pv_tenant_update on public.%I',t);
      execute format('drop policy if exists pv_tenant_delete on public.%I',t);
      execute format('revoke insert,update,delete,truncate,references,trigger on public.%I from anon,authenticated',t);
      execute format('alter table public.%I enable row level security',t);
      execute format('drop trigger if exists pv_immutable_guard on public.%I',t);
      execute format('create trigger pv_immutable_guard before update or delete on public.%I for each row execute function provenance_api.deny_mutation()',t);
    end if;
  end loop;
end $$;

-- Tenant-scoped read-only access. Consequential writes are service-role only.
do $$
declare t text;
begin
  foreach t in array array[
    'pv_authority_receipts','pv_claim_validation_decisions','pv_registry_versions','pv_registry_events',
    'pv_authority_workflows','pv_workflow_transitions','pv_transactional_outbox','pv_dead_letters',
    'pv_webhook_delivery_queue','pv_media_identifiers','pv_media_custody_events','pv_mark_usage_events'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists pv_r3_tenant_select on public.%I',t);
    execute format('create policy pv_r3_tenant_select on public.%I for select to authenticated using (public.pv_member_of(tenant_id) or public.pv_direct_tenant_scope(tenant_id))',t);
    execute format('revoke insert,update,delete on public.%I from anon,authenticated',t);
  end loop;
end $$;

-- Public registry projection remains read-only; history is never erased.
alter table public.pv_registry_versions enable row level security;
drop policy if exists pv_registry_versions_public_select on public.pv_registry_versions;
create policy pv_registry_versions_public_select on public.pv_registry_versions for select to anon,authenticated using (true);
alter table public.pv_registry_events enable row level security;
drop policy if exists pv_registry_events_public_select on public.pv_registry_events;
create policy pv_registry_events_public_select on public.pv_registry_events for select to anon,authenticated using (true);

-- Atomic, concurrency-safe append function. pg_advisory_xact_lock prevents forks.
create or replace function provenance_api.append_authority_event(
  p_tenant_id text,
  p_aggregate_type text,
  p_aggregate_id text,
  p_event_type text,
  p_actor_id text,
  p_payload jsonb,
  p_external_signature text default null
) returns public.pv_authority_events
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare
  v_previous public.pv_authority_events;
  v_next_sequence bigint;
  v_previous_hash text;
  v_event_hash text;
  v_result public.pv_authority_events;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id||':'||p_aggregate_type||':'||p_aggregate_id,0));
  select * into v_previous from public.pv_authority_events
    where tenant_id=p_tenant_id and aggregate_type=p_aggregate_type and aggregate_id=p_aggregate_id
    order by sequence desc limit 1 for update;
  v_next_sequence := coalesce(v_previous.sequence,0)+1;
  v_previous_hash := coalesce(v_previous.event_hash,'GENESIS');
  v_event_hash := 'sha256:'||encode(extensions.digest(convert_to(jsonb_build_object(
    'tenant_id',p_tenant_id,'aggregate_type',p_aggregate_type,'aggregate_id',p_aggregate_id,
    'sequence',v_next_sequence,'event_type',p_event_type,'actor_id',p_actor_id,
    'payload',p_payload,'previous_event_hash',v_previous_hash
  )::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_authority_events(tenant_id,aggregate_type,aggregate_id,sequence,event_type,actor_id,payload,previous_event_hash,event_hash,external_signature)
  values(p_tenant_id,p_aggregate_type,p_aggregate_id,v_next_sequence,p_event_type,p_actor_id,p_payload,v_previous_hash,v_event_hash,p_external_signature)
  returning * into v_result;
  return v_result;
end $$;
revoke all on function provenance_api.append_authority_event(text,text,text,text,text,jsonb,text) from public,anon,authenticated;

-- Atomic workflow transition and outbox insertion.
create or replace function provenance_api.transition_authority_workflow(
  p_workflow_id uuid,
  p_expected_version integer,
  p_to_state text,
  p_transition_type text,
  p_idempotency_key text,
  p_payload jsonb,
  p_topic text default null
) returns public.pv_authority_workflows
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_workflow public.pv_authority_workflows; v_sequence bigint;
begin
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if not found then raise exception 'PV_WORKFLOW_NOT_FOUND'; end if;
  if v_workflow.version<>p_expected_version then raise exception 'PV_WORKFLOW_VERSION_CONFLICT'; end if;
  if exists(select 1 from public.pv_workflow_transitions where workflow_id=p_workflow_id and idempotency_key=p_idempotency_key) then return v_workflow; end if;
  v_sequence := coalesce((select max(sequence) from public.pv_workflow_transitions where workflow_id=p_workflow_id),0)+1;
  insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
  values(p_workflow_id,v_workflow.tenant_id,v_sequence,v_workflow.state,p_to_state,p_transition_type,p_idempotency_key,p_payload);
  update public.pv_authority_workflows set state=p_to_state,version=version+1,updated_at=now() where id=p_workflow_id returning * into v_workflow;
  if p_topic is not null then
    insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
    values(v_workflow.tenant_id,p_workflow_id,p_topic,p_idempotency_key,p_payload) on conflict(topic,message_key) do nothing;
  end if;
  return v_workflow;
end $$;
revoke all on function provenance_api.transition_authority_workflow(uuid,integer,text,text,text,jsonb,text) from public,anon,authenticated;

-- Direct mutation of historical rows is blocked even for accidental privileged SQL.
do $$
declare t text;
begin
  foreach t in array array['pv_authority_events','pv_registry_versions','pv_registry_events','pv_workflow_transitions','pv_media_custody_events','pv_mark_usage_events','pv_authority_receipts'] loop
    execute format('drop trigger if exists pv_r3_immutable on public.%I',t);
    execute format('create trigger pv_r3_immutable before update or delete on public.%I for each row execute function provenance_api.deny_mutation()',t);
  end loop;
end $$;

-- Storage evidence objects must be versioned, immutable and written by the authority service.
drop policy if exists pv_evidence_storage_insert on storage.objects;
drop policy if exists pv_evidence_storage_update on storage.objects;
drop policy if exists pv_evidence_storage_delete on storage.objects;
revoke insert,update,delete on storage.objects from anon,authenticated;

-- Exposed API roles receive no access to internal key, nonce, idempotency or queue tables.
revoke all on public.pv_workload_identities,public.pv_authority_key_registry,public.pv_receipt_nonces,public.pv_provider_idempotency,public.pv_transactional_outbox,public.pv_dead_letters from anon,authenticated;

comment on schema provenance_api is 'PROVENANCE.CX controlled command surface. Execution grants are assigned only to isolated workload roles after deployment.';

-- R3 immutable evidence version and cryptographic receipt bindings.
alter table public.pv_evidence_scan_receipts add column if not exists object_version_id text;
alter table public.pv_evidence_scan_receipts add column if not exists provider_receipt jsonb;
alter table public.pv_evidence_objects add column if not exists object_version_id text;
alter table public.pv_evidence_objects add column if not exists custody_receipt_id text;
alter table public.pv_evidence_objects add column if not exists eligibility_receipt_id text;
alter table public.pv_evidence_objects add column if not exists source_accreditation_id text;
alter table public.pv_evidence_objects add column if not exists retention_class text not null default 'trust-evidence-7y';
alter table public.pv_evidence_objects add column if not exists legal_hold boolean not null default false;

create unique index if not exists pv_evidence_storage_version_unique
  on public.pv_evidence_objects(tenant_id,storage_key,object_version_id)
  where object_version_id is not null;

create or replace function provenance_api.pv_r3_accept_authority_receipt(
  p_receipt jsonb,
  p_verification_result text default 'valid'
) returns public.pv_authority_receipts
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_result public.pv_authority_receipts; v_existing public.pv_authority_receipts;
begin
  if p_verification_result <> 'valid' then raise exception 'PV_RECEIPT_NOT_VERIFIED'; end if;
  if coalesce(p_receipt->>'receiptId','')='' or coalesce(p_receipt->>'signature','')='' then raise exception 'PV_RECEIPT_FIELDS_INCOMPLETE'; end if;
  if coalesce(p_receipt->>'requestDigest','') !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_RECEIPT_REQUEST_DIGEST_INVALID'; end if;
  if coalesce(p_receipt->>'responseDigest','') !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_RECEIPT_RESPONSE_DIGEST_INVALID'; end if;
  if coalesce(p_receipt->>'tenantId','')='' then raise exception 'PV_RECEIPT_TENANT_REQUIRED'; end if;
  select * into v_existing from public.pv_authority_receipts where receipt_id=p_receipt->>'receiptId';
  if found then
    if v_existing.signature <> p_receipt->>'signature' or v_existing.request_digest <> p_receipt->>'requestDigest' or v_existing.response_digest <> p_receipt->>'responseDigest' then
      raise exception 'PV_RECEIPT_ID_COLLISION';
    end if;
    return v_existing;
  end if;
  insert into public.pv_authority_receipts(
    receipt_id,issuer_service,tenant_id,subject,operation,decision,issued_at,expires_at,nonce,
    request_digest,response_digest,policy_version,key_id,key_version,algorithm,signature,
    verification_result,reason_codes
  ) values (
    p_receipt->>'receiptId',p_receipt->>'issuerService',p_receipt->>'tenantId',p_receipt->>'subject',p_receipt->>'operation',p_receipt->>'decision',
    (p_receipt->>'timestamp')::timestamptz,(p_receipt->>'expiresAt')::timestamptz,p_receipt->>'nonce',
    p_receipt->>'requestDigest',p_receipt->>'responseDigest',p_receipt->>'policyVersion',p_receipt->>'keyId',(p_receipt->>'keyVersion')::integer,
    p_receipt->>'algorithm',p_receipt->>'signature','valid',coalesce(array(select jsonb_array_elements_text(coalesce(p_receipt->'reasonCodes','[]'::jsonb))),'{}'::text[])
  ) returning * into v_result;
  return v_result;
end $$;
revoke all on function provenance_api.pv_r3_accept_authority_receipt(jsonb,text) from public,anon,authenticated;

create or replace function provenance_api.pv_r3_append_custody_event(
  p_tenant_id text,
  p_evidence_id text,
  p_actor_id uuid,
  p_actor_organization text,
  p_action text,
  p_location text,
  p_object_sha256 text,
  p_scan_status text,
  p_history_complete boolean,
  p_external_receipt_id text default null
) returns public.pv_evidence_custody_events
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_previous public.pv_evidence_custody_events; v_sequence integer; v_previous_hash text; v_hash text; v_result public.pv_evidence_custody_events;
begin
  if p_object_sha256 !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_CUSTODY_DIGEST_INVALID'; end if;
  if p_action not in ('uploaded','hash-verified','scan-passed','scan-failed','custody-transferred','qualified','quarantined','withdrawn','superseded') then raise exception 'PV_CUSTODY_ACTION_INVALID'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id||':'||p_evidence_id,0));
  select * into v_previous from public.pv_evidence_custody_events where tenant_id=p_tenant_id and evidence_id=p_evidence_id order by sequence desc limit 1 for update;
  v_sequence := coalesce(v_previous.sequence,0)+1;
  v_previous_hash := coalesce(v_previous.event_hash,'GENESIS');
  v_hash := 'sha256:'||encode(extensions.digest(convert_to(jsonb_build_object(
    'tenant_id',p_tenant_id,'evidence_id',p_evidence_id,'sequence',v_sequence,'actor_id',p_actor_id,
    'actor_organization',p_actor_organization,'action',p_action,'location',p_location,
    'object_sha256',p_object_sha256,'scan_status',p_scan_status,'history_complete',p_history_complete,
    'previous_event_hash',v_previous_hash,'external_receipt_id',p_external_receipt_id
  )::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_evidence_custody_events(
    tenant_id,evidence_id,sequence,actor_id,actor_organization,action,location,previous_event_hash,event_hash,object_sha256,scan_status,history_complete
  ) values (
    p_tenant_id,p_evidence_id,v_sequence,p_actor_id,p_actor_organization,p_action,p_location,v_previous_hash,v_hash,p_object_sha256,p_scan_status,p_history_complete
  ) returning * into v_result;
  return v_result;
end $$;
revoke all on function provenance_api.pv_r3_append_custody_event(text,text,uuid,text,text,text,text,text,boolean,text) from public,anon,authenticated;

-- Correct R3 activation typing and cryptographic activation record fields.
alter table public.pv_launch_gates drop constraint if exists pv_launch_gates_activation_record_id_fkey;
alter table public.pv_launch_gates alter column activation_record_id type text using activation_record_id::text;
alter table public.pv_launch_gates add constraint pv_launch_gates_activation_record_id_fkey
  foreign key (activation_record_id) references public.pv_activation_records(id);

alter table public.pv_activation_records add column if not exists issuer_identity text;
alter table public.pv_activation_records add column if not exists release_commit text;
alter table public.pv_activation_records add column if not exists release_package_hash text;
alter table public.pv_activation_records add column if not exists infrastructure_version text;
alter table public.pv_activation_records add column if not exists database_migration_version text;
alter table public.pv_activation_records add column if not exists signing_key_id text;
alter table public.pv_activation_records add column if not exists signing_key_version integer;
alter table public.pv_activation_records add column if not exists custos_authority_version text;
alter table public.pv_activation_records add column if not exists registry_version text;
alter table public.pv_activation_records add column if not exists approval_identities text[] not null default '{}';
alter table public.pv_activation_records add column if not exists approval_timestamps timestamptz[] not null default '{}';
alter table public.pv_activation_records add column if not exists activation_time timestamptz;
alter table public.pv_activation_records add column if not exists expires_at timestamptz;
alter table public.pv_activation_records add column if not exists rollback_authority text;
alter table public.pv_activation_records add column if not exists key_id text;
alter table public.pv_activation_records add column if not exists key_version integer;
alter table public.pv_activation_records add column if not exists algorithm text;
alter table public.pv_activation_records add column if not exists signature text;
alter table public.pv_activation_records add column if not exists record jsonb not null default '{}';

-- Mutable projections are controlled by commands; immutable versions/events carry history.
drop trigger if exists pv_immutable_guard on public.pv_credentials;
drop trigger if exists pv_immutable_guard on public.pv_authority_operations;
drop trigger if exists pv_immutable_guard on public.pv_mark_authorizations;

create table if not exists public.pv_credential_versions (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  credential_id uuid not null references public.pv_credentials(id),
  version integer not null check (version > 0),
  state text not null,
  payload jsonb not null,
  payload_digest text not null check (payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  signing_receipt_id uuid references public.pv_signing_receipts(id),
  registry_receipt_id text,
  created_at timestamptz not null default now(),
  unique (credential_id,version,state)
);
alter table public.pv_credential_versions enable row level security;
drop policy if exists pv_r3_tenant_select on public.pv_credential_versions;
create policy pv_r3_tenant_select on public.pv_credential_versions for select to authenticated
  using (public.pv_member_of(tenant_id) or public.pv_direct_tenant_scope(tenant_id));
revoke insert,update,delete on public.pv_credential_versions from anon,authenticated;
drop trigger if exists pv_r3_immutable on public.pv_credential_versions;
create trigger pv_r3_immutable before update or delete on public.pv_credential_versions
  for each row execute function provenance_api.deny_mutation();

alter table public.pv_authority_workflows add column if not exists review_case_id text references public.pv_review_cases(id);
alter table public.pv_authority_workflows add column if not exists idempotency_key text;
create unique index if not exists pv_authority_workflow_idempotency_unique
  on public.pv_authority_workflows(tenant_id,idempotency_key) where idempotency_key is not null;

alter table public.pv_reviewer_decisions add column if not exists provider_receipt_id text references public.pv_authority_receipts(receipt_id);
alter table public.pv_conflict_clearances add column if not exists provider_receipt jsonb;
alter table public.pv_claim_validation_receipts add column if not exists provider_receipt jsonb;
alter table public.pv_custos_receipts add column if not exists provider_receipt jsonb;
alter table public.pv_signing_receipts add column if not exists provider_receipt_json jsonb;

create or replace function provenance_api.pv_r3_prepare_issuance(
  p_tenant_id text,
  p_review_case_id text,
  p_idempotency_key text,
  p_actor_id text
) returns jsonb
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare
  v_review public.pv_review_cases;
  v_asset public.pv_assets;
  v_control public.pv_environment_controls;
  v_activation public.pv_activation_records;
  v_credential public.pv_credentials;
  v_workflow public.pv_authority_workflows;
  v_payload jsonb;
  v_digest text;
  v_public_id text;
  v_approvals integer;
  v_distinct_reviewers integer;
  v_evidence_count integer;
begin
  if p_tenant_id is null or p_review_case_id is null or p_idempotency_key is null then raise exception 'PV_ISSUANCE_INPUT_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id||':'||p_review_case_id,0));
  select * into v_workflow from public.pv_authority_workflows
    where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;
  if found then
    select * into v_credential from public.pv_credentials where id=v_workflow.credential_id;
    return jsonb_build_object('workflow',to_jsonb(v_workflow),'credential',to_jsonb(v_credential),'idempotent',true);
  end if;
  select * into v_review from public.pv_review_cases where id=p_review_case_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'PV_REVIEW_NOT_FOUND'; end if;
  select * into v_asset from public.pv_assets where id=v_review.asset_id and tenant_id=p_tenant_id;
  if not found then raise exception 'PV_ASSET_NOT_FOUND'; end if;
  select count(*),count(distinct reviewer_id) into v_approvals,v_distinct_reviewers
    from public.pv_reviewer_decisions
    where tenant_id=p_tenant_id and review_case_id=p_review_case_id and review_round=v_review.current_review_round
      and decision='approve' and independent and conflict_free and provider_receipt_id is not null;
  if v_approvals<>2 or v_distinct_reviewers<>2 then raise exception 'PV_TWO_DISTINCT_REVIEWER_APPROVALS_REQUIRED'; end if;
  if exists(select 1 from public.pv_conflict_clearances where tenant_id=p_tenant_id and review_case_id=p_review_case_id and review_round=v_review.current_review_round and status<>'clear') then
    raise exception 'PV_CONFLICT_CLEARANCE_REQUIRED';
  end if;
  if not exists(select 1 from public.pv_claim_validation_decisions where tenant_id=p_tenant_id and status='pass') then
    raise exception 'PV_CLAIM_VALIDATION_REQUIRED';
  end if;
  select count(*) into v_evidence_count from public.pv_evidence_objects
    where tenant_id=p_tenant_id and asset_id=v_review.asset_id and status='active' and qualified
      and object_version_id is not null and custody_receipt_id is not null and eligibility_receipt_id is not null;
  if v_evidence_count<1 then raise exception 'PV_IMMUTABLE_ELIGIBLE_EVIDENCE_REQUIRED'; end if;
  select * into v_control from public.pv_environment_controls where environment='production' for share;
  if not found or not v_control.authoritative_issuance_enabled or not v_control.registry_ready or not v_control.revocation_ready or v_control.active_signing_key_id is null then
    raise exception 'PV_PRODUCTION_CONTROL_NOT_READY';
  end if;
  select * into v_activation from public.pv_activation_records
    where id=v_control.activation_record_id and active and environment='production'
      and signature is not null and activation_time<=now() and (expires_at is null or expires_at>now());
  if not found then raise exception 'PV_SIGNED_ACTIVATION_RECORD_REQUIRED'; end if;
  v_public_id := 'PVC-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,20));
  v_payload := jsonb_build_object(
    'credentialId',gen_random_uuid(),'publicId',v_public_id,'reviewCaseId',v_review.id,'assetId',v_asset.id,
    'tenantId',p_tenant_id,'tier',4,'material',v_asset.material,'serial',v_asset.serial,
    'originClaim',v_asset.origin_claim,'measurements',v_asset.measurements,'issuedBy','PROVENANCE.CX',
    'environment','production','authoritative',true,'activationRecordId',v_activation.id,
    'releasePackageHash',v_activation.release_package_hash,'policyVersion','r3.1'
  );
  v_digest := 'sha256:'||encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_credentials(
    id,tenant_id,review_case_id,public_id,environment,status,lifecycle,tier,payload,payload_digest,version
  ) values (
    (v_payload->>'credentialId')::uuid,p_tenant_id,p_review_case_id,v_public_id,'production','prepared','draft',4,v_payload,v_digest,1
  ) returning * into v_credential;
  insert into public.pv_credential_versions(tenant_id,credential_id,version,state,payload,payload_digest)
    values(p_tenant_id,v_credential.id,1,'REVIEW_COMPLETE',v_payload,v_digest);
  insert into public.pv_authority_workflows(tenant_id,credential_id,review_case_id,idempotency_key,state,version,registry_public_id)
    values(p_tenant_id,v_credential.id,p_review_case_id,p_idempotency_key,'REVIEW_COMPLETE',1,v_public_id)
    returning * into v_workflow;
  insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
    values(v_workflow.id,p_tenant_id,1,null,'REVIEW_COMPLETE','issuance.prepared',p_idempotency_key,jsonb_build_object('credentialId',v_credential.id,'payloadDigest',v_digest));
  insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
    values(p_tenant_id,v_workflow.id,'custos.authorize',p_idempotency_key||':custos',jsonb_build_object('credentialId',v_credential.id,'reviewCaseId',p_review_case_id,'payloadDigest',v_digest));
  perform provenance_api.append_authority_event(p_tenant_id,'credential',v_credential.id::text,'credential.review-complete',p_actor_id,jsonb_build_object('publicId',v_public_id,'payloadDigest',v_digest),null);
  return jsonb_build_object(
    'workflow',to_jsonb(v_workflow),'credential',to_jsonb(v_credential),
    'activationRecord',v_activation.record,'requiredSigningKeyId',v_control.active_signing_key_id,
    'requiredSigningKeyVersion',v_activation.signing_key_version,'idempotent',false
  );
end $$;
revoke all on function provenance_api.pv_r3_prepare_issuance(text,text,text,text) from public,anon,authenticated;

create or replace function provenance_api.pv_r3_record_custos(
  p_workflow_id uuid,
  p_receipt_id text,
  p_provider_receipt jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_workflow public.pv_authority_workflows; v_receipt public.pv_authority_receipts; v_credential public.pv_credentials; v_seq bigint;
begin
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if not found or v_workflow.state not in ('REVIEW_COMPLETE','CUSTOS_AUTHORIZED','SIGNING_PENDING') then raise exception 'PV_WORKFLOW_NOT_READY_FOR_CUSTOS'; end if;
  select * into v_receipt from public.pv_authority_receipts where receipt_id=p_receipt_id and tenant_id=v_workflow.tenant_id and operation='custos-authorize' and decision in ('authorized','pass') and verification_result='valid';
  if not found or v_receipt.expires_at<=now() then raise exception 'PV_VALID_CUSTOS_RECEIPT_REQUIRED'; end if;
  select * into v_credential from public.pv_credentials where id=v_workflow.credential_id;
  if v_receipt.subject<>v_credential.id::text or v_receipt.request_digest<>v_credential.payload_digest then raise exception 'PV_CUSTOS_RECEIPT_BINDING_MISMATCH'; end if;
  if v_workflow.state='REVIEW_COMPLETE' then
    select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
    insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
      values(v_workflow.id,v_workflow.tenant_id,v_seq,'REVIEW_COMPLETE','CUSTOS_AUTHORIZED','custos.authorized',p_receipt_id,jsonb_build_object('receiptId',p_receipt_id));
    update public.pv_authority_workflows set state='CUSTOS_AUTHORIZED',version=version+1,updated_at=now() where id=v_workflow.id;
  end if;
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if v_workflow.state='CUSTOS_AUTHORIZED' then
    select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
    insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
      values(v_workflow.id,v_workflow.tenant_id,v_seq,'CUSTOS_AUTHORIZED','SIGNING_PENDING','signing.queued',p_receipt_id||':signing',jsonb_build_object('receiptId',p_receipt_id));
    update public.pv_authority_workflows set state='SIGNING_PENDING',version=version+1,updated_at=now() where id=v_workflow.id returning * into v_workflow;
    insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
      values(v_workflow.tenant_id,v_workflow.id,'credential.sign',p_receipt_id||':signing',jsonb_build_object('credentialId',v_workflow.credential_id,'custosReceiptId',p_receipt_id))
      on conflict(topic,message_key) do nothing;
  end if;
  insert into public.pv_custos_receipts(tenant_id,review_case_id,review_round,external_verdict_id,status,policy_version,evaluated_digest,reason_codes,evaluated_at,external_signature,provider_receipt)
    select v_workflow.tenant_id,v_workflow.review_case_id,r.current_review_round,p_receipt_id,'pass',v_receipt.policy_version,v_receipt.request_digest,v_receipt.reason_codes,v_receipt.issued_at,v_receipt.signature,p_provider_receipt
    from public.pv_review_cases r where r.id=v_workflow.review_case_id
    on conflict(external_verdict_id) do nothing;
  return jsonb_build_object('workflow',to_jsonb(v_workflow),'custosReceiptId',p_receipt_id);
end $$;
revoke all on function provenance_api.pv_r3_record_custos(uuid,text,jsonb) from public,anon,authenticated;

create or replace function provenance_api.pv_r3_record_signing(
  p_workflow_id uuid,
  p_receipt_id text,
  p_signing_result jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_workflow public.pv_authority_workflows; v_receipt public.pv_authority_receipts; v_credential public.pv_credentials; v_signing public.pv_signing_receipts; v_seq bigint;
begin
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if not found or v_workflow.state not in ('SIGNING_PENDING','SIGNED','REGISTRY_PENDING') then raise exception 'PV_WORKFLOW_NOT_READY_FOR_SIGNING'; end if;
  select * into v_receipt from public.pv_authority_receipts where receipt_id=p_receipt_id and tenant_id=v_workflow.tenant_id and operation='credential-sign' and decision='signed' and verification_result='valid';
  if not found or v_receipt.expires_at<=now() then raise exception 'PV_VALID_SIGNING_RECEIPT_REQUIRED'; end if;
  select * into v_credential from public.pv_credentials where id=v_workflow.credential_id for update;
  if v_receipt.subject<>v_credential.id::text or v_receipt.request_digest<>v_credential.payload_digest then raise exception 'PV_SIGNING_RECEIPT_BINDING_MISMATCH'; end if;
  insert into public.pv_signing_receipts(tenant_id,credential_id,key_id,algorithm,payload_digest,signature,status,signed_at,provider_receipt,non_exportable_key,provider_receipt_json)
    values(v_workflow.tenant_id,v_credential.id,p_signing_result->>'keyId',coalesce(p_signing_result->>'algorithm','ES256'),v_credential.payload_digest,p_signing_result->>'signature','valid',coalesce((p_signing_result->>'signedAt')::timestamptz,now()),p_receipt_id,true,p_signing_result)
    on conflict(provider_receipt) do update set provider_receipt=excluded.provider_receipt
    returning * into v_signing;
  update public.pv_credentials set signing_receipt_id=v_signing.id,updated_at=now() where id=v_credential.id;
  insert into public.pv_credential_versions(tenant_id,credential_id,version,state,payload,payload_digest,signing_receipt_id)
    values(v_workflow.tenant_id,v_credential.id,v_credential.version,'SIGNED',v_credential.payload,v_credential.payload_digest,v_signing.id)
    on conflict do nothing;
  if v_workflow.state='SIGNING_PENDING' then
    select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
    insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
      values(v_workflow.id,v_workflow.tenant_id,v_seq,'SIGNING_PENDING','SIGNED','credential.signed',p_receipt_id,jsonb_build_object('receiptId',p_receipt_id));
    update public.pv_authority_workflows set state='SIGNED',version=version+1,updated_at=now() where id=v_workflow.id;
  end if;
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if v_workflow.state='SIGNED' then
    select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
    insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
      values(v_workflow.id,v_workflow.tenant_id,v_seq,'SIGNED','REGISTRY_PENDING','registry.queued',p_receipt_id||':registry',jsonb_build_object('receiptId',p_receipt_id));
    update public.pv_authority_workflows set state='REGISTRY_PENDING',version=version+1,updated_at=now() where id=v_workflow.id returning * into v_workflow;
    insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
      values(v_workflow.tenant_id,v_workflow.id,'registry.publish',p_receipt_id||':registry',jsonb_build_object('credentialId',v_workflow.credential_id,'signingReceiptId',p_receipt_id))
      on conflict(topic,message_key) do nothing;
  end if;
  return jsonb_build_object('workflow',to_jsonb(v_workflow),'signingReceipt',to_jsonb(v_signing));
end $$;
revoke all on function provenance_api.pv_r3_record_signing(uuid,text,jsonb) from public,anon,authenticated;

create or replace function provenance_api.pv_r3_finalize_registry(
  p_workflow_id uuid,
  p_receipt_id text,
  p_registry_result jsonb,
  p_actor_id text
) returns jsonb
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_workflow public.pv_authority_workflows; v_receipt public.pv_authority_receipts; v_credential public.pv_credentials; v_signing public.pv_signing_receipts; v_seq bigint; v_prev_hash text; v_hash text;
begin
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if not found or v_workflow.state not in ('REGISTRY_PENDING','ACTIVE') then raise exception 'PV_WORKFLOW_NOT_READY_FOR_REGISTRY'; end if;
  select * into v_receipt from public.pv_authority_receipts where receipt_id=p_receipt_id and tenant_id=v_workflow.tenant_id and operation='registry.write' and decision in ('allow','pass') and verification_result='valid';
  if not found or v_receipt.expires_at<=now() then raise exception 'PV_VALID_REGISTRY_RECEIPT_REQUIRED'; end if;
  select * into v_credential from public.pv_credentials where id=v_workflow.credential_id for update;
  select * into v_signing from public.pv_signing_receipts where id=v_credential.signing_receipt_id;
  if not found then raise exception 'PV_SIGNING_RECEIPT_REQUIRED'; end if;
  if v_receipt.subject<>v_credential.id::text or v_receipt.request_digest<>v_credential.payload_digest then raise exception 'PV_REGISTRY_RECEIPT_BINDING_MISMATCH'; end if;
  if coalesce((p_registry_result->>'revocationCapabilityConfirmed')::boolean,false) is not true then raise exception 'PV_REVOCATION_CAPABILITY_UNCONFIRMED'; end if;
  update public.pv_credentials set status='active',lifecycle='active',registry_receipt=p_registry_result,issued_at=coalesce(issued_at,now()),updated_at=now() where id=v_credential.id returning * into v_credential;
  insert into public.pv_registry_records(public_id,tenant_id,credential_id,credential_digest,lifecycle,public_projection,published_at,registry_receipt_id,revocation_capability_confirmed)
    values(v_credential.public_id,v_credential.tenant_id,v_credential.id,v_credential.payload_digest,'active',v_credential.payload||jsonb_build_object('signature',jsonb_build_object('algorithm',v_signing.algorithm,'keyId',v_signing.key_id,'payloadDigest',v_signing.payload_digest,'signature',v_signing.signature,'valid',true),'lifecycle','active','authoritative',true),coalesce((p_registry_result->>'publishedAt')::timestamptz,now()),p_receipt_id,true)
    on conflict(public_id) do update set public_projection=excluded.public_projection,lifecycle=excluded.lifecycle,registry_receipt_id=excluded.registry_receipt_id,updated_at=now();
  insert into public.pv_registry_versions(tenant_id,credential_id,public_id,version,payload,payload_digest,credential_signature,signing_key_id,signing_key_version)
    values(v_credential.tenant_id,v_credential.id,v_credential.public_id,v_credential.version,v_credential.payload,v_credential.payload_digest,v_signing.signature,v_signing.key_id,coalesce((p_registry_result->>'signingKeyVersion')::integer,1))
    on conflict do nothing;
  select coalesce(max(sequence),0)+1,coalesce((select event_hash from public.pv_registry_events where credential_id=v_credential.id order by sequence desc limit 1),'GENESIS')
    into v_seq,v_prev_hash from public.pv_registry_events where credential_id=v_credential.id;
  v_hash := 'sha256:'||encode(extensions.digest(convert_to(jsonb_build_object('credentialId',v_credential.id,'sequence',v_seq,'eventType','active','payloadDigest',v_credential.payload_digest,'previousHash',v_prev_hash,'registryReceiptId',p_receipt_id)::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_registry_events(tenant_id,credential_id,public_id,sequence,event_type,from_state,to_state,credential_version,reason,previous_event_hash,event_hash,registry_signature,registry_key_id,registry_key_version)
    values(v_credential.tenant_id,v_credential.id,v_credential.public_id,v_seq,'active','draft','active',v_credential.version,'credential issued',v_prev_hash,v_hash,v_receipt.signature,v_receipt.key_id,v_receipt.key_version)
    on conflict(credential_id,sequence) do nothing;
  insert into public.pv_credential_versions(tenant_id,credential_id,version,state,payload,payload_digest,signing_receipt_id,registry_receipt_id)
    values(v_credential.tenant_id,v_credential.id,v_credential.version,'ACTIVE',v_credential.payload,v_credential.payload_digest,v_signing.id,p_receipt_id)
    on conflict do nothing;
  if v_workflow.state='REGISTRY_PENDING' then
    select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
    insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
      values(v_workflow.id,v_workflow.tenant_id,v_seq,'REGISTRY_PENDING','ACTIVE','registry.published',p_receipt_id,p_registry_result);
    update public.pv_authority_workflows set state='ACTIVE',version=version+1,updated_at=now() where id=v_workflow.id returning * into v_workflow;
  end if;
  update public.pv_review_cases set status='issued',credential_lifecycle='active',registry_status='ready',signing_key_status='active',revocation_capability=true,updated_at=now() where id=v_workflow.review_case_id;
  perform provenance_api.append_authority_event(v_credential.tenant_id,'credential',v_credential.id::text,'credential.active',p_actor_id,jsonb_build_object('publicId',v_credential.public_id,'registryReceiptId',p_receipt_id),v_signing.signature);
  return jsonb_build_object('workflow',to_jsonb(v_workflow),'credential',to_jsonb(v_credential),'registry',p_registry_result);
end $$;
revoke all on function provenance_api.pv_r3_finalize_registry(uuid,text,jsonb,text) from public,anon,authenticated;

create or replace function provenance_api.pv_r3_require_compensation(
  p_workflow_id uuid,
  p_error text,
  p_payload jsonb
) returns public.pv_authority_workflows
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare v_workflow public.pv_authority_workflows; v_seq bigint;
begin
  select * into v_workflow from public.pv_authority_workflows where id=p_workflow_id for update;
  if not found then raise exception 'PV_WORKFLOW_NOT_FOUND'; end if;
  if v_workflow.state='ACTIVE' then raise exception 'PV_ACTIVE_WORKFLOW_REQUIRES_LIFECYCLE_COMPENSATION'; end if;
  select coalesce(max(sequence),0)+1 into v_seq from public.pv_workflow_transitions where workflow_id=v_workflow.id;
  insert into public.pv_workflow_transitions(workflow_id,tenant_id,sequence,from_state,to_state,transition_type,idempotency_key,payload)
    values(v_workflow.id,v_workflow.tenant_id,v_seq,v_workflow.state,'COMPENSATION_REQUIRED','workflow.compensation-required','compensation:'||v_workflow.id::text,p_payload)
    on conflict(workflow_id,idempotency_key) do nothing;
  update public.pv_authority_workflows set state='COMPENSATION_REQUIRED',version=version+1,last_error=p_error,updated_at=now() where id=v_workflow.id returning * into v_workflow;
  insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
    values(v_workflow.tenant_id,v_workflow.id,'authority.compensate','compensation:'||v_workflow.id::text,p_payload)
    on conflict(topic,message_key) do nothing;
  return v_workflow;
end $$;
revoke all on function provenance_api.pv_r3_require_compensation(uuid,text,jsonb) from public,anon,authenticated;

insert into public.pv_claim_protocols(
  protocol_id,version,claim_type,eligible_tiers,required_evidence_classes,minimum_evidence_count,
  max_evidence_age_days,accredited_sources_required,measurement_requirements,geographic_rules,
  material_rules,contradiction_policy,exception_rules,decision_expiry_days,required_reviewer_count,active
) values (
  'PV-ORIGIN','3.1.0','origin',array[1,2,3,4],
  array['origin-evidence','laboratory-report','source-document','custody-record','photograph','video','other'],
  1,3650,true,'{}'::text[],'{}'::jsonb,'{}'::jsonb,'deny','{}'::jsonb,365,2,true
) on conflict(protocol_id,version) do update set active=excluded.active;

-- R3 pilot authority outcome: real infrastructure, explicitly non-authoritative.
create or replace function provenance_api.pv_r3_record_pilot_outcome(
  p_tenant_id text,
  p_review_case_id text,
  p_public_id text,
  p_outcome jsonb,
  p_custos_receipt_id text,
  p_registry_receipt_id text,
  p_actor_id text
) returns jsonb
language plpgsql
security definer
set search_path = public,provenance_api,pg_temp
as $$
declare
  v_review public.pv_review_cases;
  v_custos public.pv_authority_receipts;
  v_registry public.pv_authority_receipts;
  v_legacy_custos public.pv_custos_receipts;
  v_result public.pv_pilot_outcomes;
begin
  if p_tenant_id is null or p_review_case_id is null or p_public_id is null then raise exception 'PV_PILOT_INPUT_REQUIRED'; end if;
  select * into v_review from public.pv_review_cases where id=p_review_case_id and tenant_id=p_tenant_id;
  if not found then raise exception 'PV_REVIEW_NOT_FOUND'; end if;
  select * into v_custos from public.pv_authority_receipts
    where receipt_id=p_custos_receipt_id and tenant_id=p_tenant_id and operation='custos-authorize'
      and decision in ('authorized','pass') and verification_result='valid' and expires_at>now();
  if not found then raise exception 'PV_VALID_CUSTOS_RECEIPT_REQUIRED'; end if;
  select * into v_registry from public.pv_authority_receipts
    where receipt_id=p_registry_receipt_id and tenant_id=p_tenant_id and operation='registry.write'
      and decision in ('allow','pass') and verification_result='valid';
  if not found then raise exception 'PV_VALID_PILOT_REGISTRY_RECEIPT_REQUIRED'; end if;
  if coalesce(p_outcome->>'environment','')<>'pilot' or coalesce((p_outcome->>'authoritative')::boolean,true) then
    raise exception 'PV_PILOT_NON_AUTHORITATIVE_FLAGS_REQUIRED';
  end if;
  insert into public.pv_custos_receipts(
    tenant_id,review_case_id,review_round,external_verdict_id,status,policy_version,evaluated_digest,
    reason_codes,evaluated_at,external_signature,provider_receipt
  ) values(
    p_tenant_id,p_review_case_id,v_review.current_review_round,p_custos_receipt_id,'pass',v_custos.policy_version,
    v_custos.request_digest,v_custos.reason_codes,v_custos.issued_at,v_custos.signature,to_jsonb(v_custos)
  ) on conflict(external_verdict_id) do update set provider_receipt=excluded.provider_receipt
  returning * into v_legacy_custos;
  insert into public.pv_pilot_outcomes(tenant_id,review_case_id,public_id,outcome,custos_receipt_id)
  values(p_tenant_id,p_review_case_id,p_public_id,p_outcome||jsonb_build_object(
    'environment','pilot','authoritative',false,'productionCredentialCreated',false,
    'signingPerformed',false,'markAuthorized',false,'registryReceiptId',p_registry_receipt_id,
    'watermark','PILOT / NON-AUTHORITATIVE'
  ),v_legacy_custos.id)
  returning * into v_result;
  perform provenance_api.append_authority_event(p_tenant_id,'pilot-outcome',v_result.id::text,'pilot.outcome.recorded',p_actor_id,
    jsonb_build_object('reviewCaseId',p_review_case_id,'publicId',p_public_id,'custosReceiptId',p_custos_receipt_id,'registryReceiptId',p_registry_receipt_id),null);
  return to_jsonb(v_result);
end $$;
revoke all on function provenance_api.pv_r3_record_pilot_outcome(text,text,text,jsonb,text,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_pilot_outcome(text,text,text,jsonb,text,text,text) to service_role;

-- Complete certification-mark governance.
create table if not exists public.pv_mark_licenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  license_number text not null unique,
  status text not null check(status in ('active','suspended','expired','terminated')),
  credential_types text[] not null default '{}',
  permitted_media text[] not null default '{}',
  permitted_geography text[] not null default '{}',
  effective_at timestamptz not null,
  expires_at timestamptz not null,
  renewal_state text not null default 'current',
  evidence jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(expires_at>effective_at)
);
create table if not exists public.pv_location_authorizations (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  location_id text not null references public.pv_locations(id),
  status text not null check(status in ('active','suspended','expired','terminated')),
  permitted_media text[] not null default '{}',
  permitted_geography text[] not null default '{}',
  effective_at timestamptz not null,
  expires_at timestamptz not null,
  evidence jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tenant_id,location_id),
  check(expires_at>effective_at)
);
alter table public.pv_mark_authorizations add column if not exists license_id uuid references public.pv_mark_licenses(id);
alter table public.pv_mark_authorizations add column if not exists location_authorization_id uuid references public.pv_location_authorizations(id);
alter table public.pv_mark_authorizations add column if not exists artwork_version text;
alter table public.pv_mark_authorizations add column if not exists expires_at timestamptz;
alter table public.pv_mark_authorizations add column if not exists provider_result jsonb not null default '{}';

create or replace function provenance_api.pv_r3_record_mark_authorization(
  p_credential_id uuid,
  p_receipt_id text,
  p_provider_result jsonb,
  p_actor_id text
) returns jsonb
language plpgsql
security definer
set search_path=public,provenance_api,pg_temp
as $$
declare
  v_credential public.pv_credentials;
  v_receipt public.pv_authority_receipts;
  v_license public.pv_mark_licenses;
  v_location public.pv_location_authorizations;
  v_mark public.pv_mark_authorizations;
begin
  select * into v_credential from public.pv_credentials where id=p_credential_id for update;
  if not found or v_credential.status<>'active' or v_credential.lifecycle<>'active' or v_credential.environment<>'production' then
    raise exception 'PV_ACTIVE_PRODUCTION_CREDENTIAL_REQUIRED';
  end if;
  select * into v_receipt from public.pv_authority_receipts where receipt_id=p_receipt_id and tenant_id=v_credential.tenant_id
    and operation='mark.authorize' and decision='allow' and verification_result='valid';
  if not found then raise exception 'PV_VALID_MARK_RECEIPT_REQUIRED'; end if;
  select * into v_license from public.pv_mark_licenses where tenant_id=v_credential.tenant_id and status='active'
    and effective_at<=now() and expires_at>now() order by expires_at desc limit 1;
  if not found then raise exception 'PV_ACTIVE_MARK_LICENSE_REQUIRED'; end if;
  select * into v_location from public.pv_location_authorizations where tenant_id=v_credential.tenant_id and status='active'
    and effective_at<=now() and expires_at>now() order by expires_at desc limit 1;
  if not found then raise exception 'PV_ACTIVE_LOCATION_AUTHORIZATION_REQUIRED'; end if;
  insert into public.pv_mark_authorizations(
    tenant_id,credential_id,status,tier,external_receipt_id,reason_codes,authorized_at,license_id,
    location_authorization_id,artwork_version,expires_at,provider_result
  ) values(
    v_credential.tenant_id,v_credential.id,'authorized',v_credential.tier,p_receipt_id,
    coalesce(array(select jsonb_array_elements_text(coalesce(p_provider_result->'reasonCodes','[]'::jsonb))),'{}'),now(),
    v_license.id,v_location.id,p_provider_result->>'artworkVersion',least(v_license.expires_at,v_location.expires_at),p_provider_result
  ) on conflict(credential_id) do update set
    status='authorized',external_receipt_id=excluded.external_receipt_id,reason_codes=excluded.reason_codes,
    authorized_at=now(),updated_at=now(),license_id=excluded.license_id,
    location_authorization_id=excluded.location_authorization_id,artwork_version=excluded.artwork_version,
    expires_at=excluded.expires_at,provider_result=excluded.provider_result
  returning * into v_mark;
  insert into public.pv_mark_usage_events(tenant_id,authorization_id,credential_id,action,media_type,geography,artwork_version,actor_id,details)
  values(v_credential.tenant_id,v_mark.id,v_credential.id,'authorized',
    array_to_string(v_license.permitted_media,','),array_to_string(v_license.permitted_geography,','),
    coalesce(v_mark.artwork_version,'unknown'),p_actor_id,
    jsonb_build_object('receiptId',p_receipt_id,'reasonCodes',v_mark.reason_codes,'providerResult',p_provider_result));
  perform provenance_api.append_authority_event(v_credential.tenant_id,'mark',v_mark.id::text,'mark.authorized',p_actor_id,to_jsonb(v_mark),v_receipt.signature);
  return to_jsonb(v_mark);
end $$;
revoke all on function provenance_api.pv_r3_record_mark_authorization(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_mark_authorization(uuid,text,jsonb,text) to service_role;

-- Service-role execution grants for every R3 command boundary.
grant execute on function provenance_api.append_authority_event(text,text,text,text,text,jsonb,text) to service_role;
grant execute on function provenance_api.transition_authority_workflow(uuid,integer,text,text,text,jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_accept_authority_receipt(jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_append_custody_event(text,text,uuid,text,text,text,text,text,boolean,text) to service_role;
grant execute on function provenance_api.pv_r3_prepare_issuance(text,text,text,text) to service_role;
grant execute on function provenance_api.pv_r3_record_custos(uuid,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_signing(uuid,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_finalize_registry(uuid,text,jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_require_compensation(uuid,text,jsonb) to service_role;

-- RLS: governance is tenant-readable; mutations remain service-role commands.
do $$
declare t text;
begin
  foreach t in array array['pv_mark_licenses','pv_location_authorizations','pv_mark_usage_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists pv_r3_tenant_select on public.%I',t);
    execute format('create policy pv_r3_tenant_select on public.%I for select to authenticated using (public.pv_member_of(tenant_id) or public.pv_direct_tenant_scope(tenant_id))',t);
    execute format('revoke insert,update,delete on public.%I from anon,authenticated',t);
  end loop;
end $$;
alter table public.pv_mark_artwork_versions enable row level security;
drop policy if exists pv_mark_artwork_read on public.pv_mark_artwork_versions;
create policy pv_mark_artwork_read on public.pv_mark_artwork_versions for select to authenticated using(status='active');
revoke insert,update,delete on public.pv_mark_artwork_versions from anon,authenticated;
drop trigger if exists pv_r3_immutable on public.pv_mark_usage_events;
create trigger pv_r3_immutable before update or delete on public.pv_mark_usage_events for each row execute function provenance_api.deny_mutation();

-- Durable lifecycle transition consumes a verified registry receipt and atomically updates
-- canonical credential state, immutable version history, public projection, mark suppression,
-- workflow/outbox, and audit history.
create or replace function provenance_api.pv_r3_lifecycle_transition(
  p_credential_id uuid,
  p_action text,
  p_reason text,
  p_receipt_id text,
  p_provider_result jsonb,
  p_actor_id uuid,
  p_successor_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path=public,provenance_api,pg_temp
as $$
declare
  v_credential public.pv_credentials;
  v_receipt public.pv_authority_receipts;
  v_event public.pv_credential_lifecycle_events;
  v_workflow public.pv_authority_workflows;
  v_from text;
  v_to text;
  v_status text;
  v_version integer;
begin
  if p_reason is null or length(trim(p_reason))<3 then raise exception 'PV_LIFECYCLE_REASON_REQUIRED'; end if;
  select * into v_credential from public.pv_credentials where id=p_credential_id for update;
  if not found then raise exception 'PV_CREDENTIAL_NOT_FOUND'; end if;
  select * into v_receipt from public.pv_authority_receipts
    where receipt_id=p_receipt_id and tenant_id=v_credential.tenant_id and operation='registry.write'
      and decision in ('allow','pass') and verification_result='valid' and subject=v_credential.id::text
      and request_digest=v_credential.payload_digest;
  if not found then raise exception 'PV_VALID_REGISTRY_LIFECYCLE_RECEIPT_REQUIRED'; end if;
  v_from:=v_credential.lifecycle;
  v_to:=case p_action
    when 'suspend' then 'suspended' when 'reactivate' then 'active' when 'revoke' then 'revoked'
    when 'supersede' then 'superseded' when 'expire' then 'expired' when 'correct' then 'active' else null end;
  if v_to is null then raise exception 'PV_LIFECYCLE_ACTION_INVALID'; end if;
  if p_action='reactivate' and v_from<>'suspended' then raise exception 'PV_REACTIVATION_REQUIRES_SUSPENDED'; end if;
  if p_action='supersede' and p_successor_id is null then raise exception 'PV_SUCCESSOR_REQUIRED'; end if;
  if v_from in ('revoked','superseded','expired') and p_action not in ('correct') then raise exception 'PV_TERMINAL_LIFECYCLE_STATE'; end if;
  v_status:=case v_to when 'active' then 'active' else v_to end;
  v_version:=v_credential.version+1;
  update public.pv_credentials set lifecycle=v_to,status=v_status,successor_id=p_successor_id,
    version=v_version,registry_receipt=p_provider_result,updated_at=now(),
    payload=case when p_action='correct' then payload||jsonb_build_object('correction',p_provider_result) else payload end
    where id=v_credential.id returning * into v_credential;
  update public.pv_registry_records set lifecycle=v_to,
    public_projection=public_projection||jsonb_build_object('lifecycle',upper(v_to),'successorId',p_successor_id,'lastLifecycleReceiptId',p_receipt_id),
    registry_receipt_id=p_receipt_id,updated_at=now() where credential_id=v_credential.id;
  insert into public.pv_credential_versions(tenant_id,credential_id,version,state,payload,payload_digest,registry_receipt_id)
    values(v_credential.tenant_id,v_credential.id,v_version,upper(v_to),v_credential.payload,v_credential.payload_digest,p_receipt_id);
  insert into public.pv_credential_lifecycle_events(tenant_id,credential_id,action,from_state,to_state,reason,actor_id,successor_id,registry_receipt_id)
    values(v_credential.tenant_id,v_credential.id,p_action,v_from,v_to,p_reason,p_actor_id,p_successor_id,p_receipt_id)
    returning * into v_event;
  if v_to<>'active' then
    update public.pv_mark_authorizations set status=case when v_to='revoked' then 'revoked' else 'suspended' end,updated_at=now()
      where credential_id=v_credential.id and status='authorized';
    insert into public.pv_mark_usage_events(tenant_id,authorization_id,credential_id,action,media_type,geography,artwork_version,actor_id,details)
      select tenant_id,id,credential_id,'suppressed','all','all',coalesce(artwork_version,'unknown'),p_actor_id::text,
        jsonb_build_object('registryReceiptId',p_receipt_id,'reasonCode','CREDENTIAL_'||upper(v_to))
      from public.pv_mark_authorizations where credential_id=v_credential.id;
  end if;
  select * into v_workflow from public.pv_authority_workflows where credential_id=v_credential.id for update;
  if found then
    update public.pv_authority_workflows set state=upper(v_to),version=version+1,updated_at=now() where id=v_workflow.id;
    insert into public.pv_transactional_outbox(tenant_id,workflow_id,topic,message_key,payload)
      values(v_credential.tenant_id,v_workflow.id,'credential.lifecycle',p_receipt_id,
        jsonb_build_object('credentialId',v_credential.id,'action',p_action,'toState',v_to,'registryReceiptId',p_receipt_id))
      on conflict(topic,message_key) do nothing;
  end if;
  perform provenance_api.append_authority_event(v_credential.tenant_id,'credential',v_credential.id::text,'credential.'||p_action,p_actor_id::text,
    jsonb_build_object('from',v_from,'to',v_to,'reason',p_reason,'successorId',p_successor_id,'registryReceiptId',p_receipt_id),v_receipt.signature);
  return jsonb_build_object('credential',to_jsonb(v_credential),'event',to_jsonb(v_event),'markSuppressed',v_to<>'active');
end $$;
revoke all on function provenance_api.pv_r3_lifecycle_transition(uuid,text,text,text,jsonb,uuid,uuid) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_lifecycle_transition(uuid,text,text,text,jsonb,uuid,uuid) to service_role;

-- R3 executable original-campaign commands.
alter table public.pv_governed_parties add column if not exists tenant_id text references public.pv_tenants(id);
create index if not exists pv_governed_parties_tenant_idx on public.pv_governed_parties(tenant_id,party_type,status);
alter table public.pv_governed_parties enable row level security;
drop policy if exists pv_governed_parties_tenant_select on public.pv_governed_parties;
create policy pv_governed_parties_tenant_select on public.pv_governed_parties for select to authenticated
  using(tenant_id is not null and (public.pv_member_of(tenant_id) or public.pv_direct_tenant_scope(tenant_id)));
revoke insert,update,delete on public.pv_governed_parties from anon,authenticated;

create or replace function provenance_api.pv_r3_record_category_l_evidence(
  p_control_id text,
  p_evidence_id text,
  p_evidence_digest text,
  p_evidence_url text,
  p_verified boolean,
  p_created_at timestamptz,
  p_expires_at timestamptz,
  p_actor_id text
) returns jsonb
language plpgsql
security definer
set search_path=public,provenance_api,pg_temp
as $$
declare v_control public.pv_category_l_controls; v_state text; v_missing integer; v_stale integer; v_dependency_block integer;
begin
  select * into v_control from public.pv_category_l_controls where id=p_control_id for update;
  if not found then raise exception 'PV_CATEGORY_L_CONTROL_NOT_FOUND'; end if;
  if p_evidence_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_EVIDENCE_DIGEST_INVALID'; end if;
  insert into public.pv_category_l_evidence(control_id,evidence_id,evidence_digest,evidence_url,verified,created_at,expires_at)
  values(p_control_id,p_evidence_id,p_evidence_digest,p_evidence_url,p_verified,p_created_at,p_expires_at)
  on conflict(control_id,evidence_id) do update set evidence_digest=excluded.evidence_digest,evidence_url=excluded.evidence_url,
    verified=excluded.verified,created_at=excluded.created_at,expires_at=excluded.expires_at;
  select count(*) into v_missing from jsonb_array_elements_text(coalesce(v_control.evidence_requirements->'requiredIds','[]'::jsonb)) req
    where not exists(select 1 from public.pv_category_l_evidence e where e.control_id=p_control_id and e.evidence_id=req and e.verified);
  select count(*) into v_stale from public.pv_category_l_evidence where control_id=p_control_id and (not verified or (expires_at is not null and expires_at<=now()));
  select count(*) into v_dependency_block from unnest(v_control.dependencies) dep
    where not exists(select 1 from public.pv_category_l_controls d where d.id=dep and d.state='READY');
  v_state:=case when v_control.manual_block is not null then 'BLOCKED' when v_stale>0 then 'STALE' when v_missing>0 or v_dependency_block>0 then 'NOT_READY' else 'READY' end;
  update public.pv_category_l_controls set state=v_state,evaluated_at=now(),updated_at=now() where id=p_control_id returning * into v_control;
  perform provenance_api.append_authority_event('platform','category-l',p_control_id,'category-l.evaluated',p_actor_id,
    jsonb_build_object('state',v_state,'missingEvidence',v_missing,'staleEvidence',v_stale,'blockedDependencies',v_dependency_block),null);
  return jsonb_build_object('control',to_jsonb(v_control),'missingEvidence',v_missing,'staleEvidence',v_stale,'blockedDependencies',v_dependency_block);
end $$;
revoke all on function provenance_api.pv_r3_record_category_l_evidence(text,text,text,text,boolean,timestamptz,timestamptz,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_category_l_evidence(text,text,text,text,boolean,timestamptz,timestamptz,text) to service_role;

create or replace function provenance_api.pv_r3_create_media_identifier(
  p_tenant_id text,p_media_type text,p_credential_id uuid,p_activation_code_hash text,p_actor_id text
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,pg_temp
as $$
declare v_media public.pv_media_identifiers; v_id text; v_state text;
begin
  if p_media_type not in ('QR','NFC') then raise exception 'PV_MEDIA_TYPE_INVALID'; end if;
  if p_activation_code_hash !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_MEDIA_ACTIVATION_HASH_INVALID'; end if;
  if p_credential_id is not null and not exists(select 1 from public.pv_credentials where id=p_credential_id and tenant_id=p_tenant_id and lifecycle='active') then
    raise exception 'PV_ACTIVE_CREDENTIAL_REQUIRED';
  end if;
  v_id:='media_'||replace(gen_random_uuid()::text,'-',''); v_state:=case when p_credential_id is null then 'created' else 'bound' end;
  insert into public.pv_media_identifiers(id,tenant_id,media_type,credential_id,activation_code_hash,state)
  values(v_id,p_tenant_id,p_media_type,p_credential_id,p_activation_code_hash,v_state) returning * into v_media;
  insert into public.pv_media_custody_events(media_id,tenant_id,sequence,action,from_state,to_state,actor_id,custody_party,previous_event_hash,event_hash)
  values(v_id,p_tenant_id,1,'create','none',v_state,p_actor_id,'PROVENANCE.CX','GENESIS',
    'sha256:'||encode(extensions.digest(convert_to(jsonb_build_object('mediaId',v_id,'sequence',1,'action','create','from','none','to',v_state,'actor',p_actor_id)::text,'UTF8'),'sha256'),'hex'));
  return to_jsonb(v_media);
end $$;
revoke all on function provenance_api.pv_r3_create_media_identifier(text,text,uuid,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_create_media_identifier(text,text,uuid,text,text) to service_role;

create or replace function provenance_api.pv_r3_transition_media(
  p_tenant_id text,p_media_id text,p_action text,p_actor_id text,p_custody_party text,
  p_shipment_reference text default null,p_recipient_confirmation text default null,p_replacement_media_id text default null
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,pg_temp
as $$
declare v_media public.pv_media_identifiers; v_from text; v_to text; v_seq bigint; v_prev text; v_hash text; v_event public.pv_media_custody_events;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id||':'||p_media_id,0));
  select * into v_media from public.pv_media_identifiers where id=p_media_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'PV_MEDIA_NOT_FOUND'; end if;
  v_from:=v_media.state;
  v_to:=case p_action when 'bind' then 'bound' when 'encode' then 'encoded' when 'inventory' then 'inventory'
    when 'ship' then 'shipped' when 'receive' then 'received' when 'activate' then 'active' when 'lost' then 'lost'
    when 'recall' then 'recalled' when 'destroy' then 'destroyed' when 'replace' then 'replaced' when 'suppress' then 'suppressed' else null end;
  if v_to is null then raise exception 'PV_MEDIA_ACTION_INVALID'; end if;
  if (v_from,v_to) not in (('created','bound'),('bound','encoded'),('encoded','inventory'),('inventory','shipped'),('shipped','received'),('received','active'),
    ('active','lost'),('active','recalled'),('lost','replaced'),('recalled','destroyed'),('suppressed','destroyed'),('active','suppressed'),('inventory','recalled'),('shipped','recalled')) then
    raise exception 'PV_MEDIA_TRANSITION_INVALID';
  end if;
  if p_action='ship' and p_shipment_reference is null then raise exception 'PV_SHIPMENT_REFERENCE_REQUIRED'; end if;
  if p_action='receive' and p_recipient_confirmation is null then raise exception 'PV_RECIPIENT_CONFIRMATION_REQUIRED'; end if;
  if p_action='activate' then
    if v_media.use_count<>0 then raise exception 'PV_MEDIA_REUSE_DENIED'; end if;
    if v_media.credential_id is null or not exists(select 1 from public.pv_credentials where id=v_media.credential_id and tenant_id=p_tenant_id and lifecycle='active') then
      raise exception 'PV_ACTIVE_CREDENTIAL_REQUIRED';
    end if;
  end if;
  if p_action='replace' and (p_replacement_media_id is null or not exists(select 1 from public.pv_media_identifiers where id=p_replacement_media_id and tenant_id=p_tenant_id and state in ('created','bound'))) then
    raise exception 'PV_VALID_REPLACEMENT_MEDIA_REQUIRED';
  end if;
  select coalesce(max(sequence),0)+1,coalesce((array_agg(event_hash order by sequence desc))[1],'GENESIS') into v_seq,v_prev
    from public.pv_media_custody_events where media_id=p_media_id;
  v_hash:='sha256:'||encode(extensions.digest(convert_to(jsonb_build_object('mediaId',p_media_id,'sequence',v_seq,'action',p_action,'from',v_from,'to',v_to,
    'actor',p_actor_id,'party',p_custody_party,'shipment',p_shipment_reference,'recipient',p_recipient_confirmation,'previous',v_prev)::text,'UTF8'),'sha256'),'hex');
  update public.pv_media_identifiers set state=v_to,use_count=case when p_action='activate' then 1 else use_count end,
    replacement_media_id=case when p_action='replace' then p_replacement_media_id else replacement_media_id end,updated_at=now() where id=p_media_id returning * into v_media;
  insert into public.pv_media_custody_events(media_id,tenant_id,sequence,action,from_state,to_state,actor_id,custody_party,shipment_reference,recipient_confirmation,previous_event_hash,event_hash)
  values(p_media_id,p_tenant_id,v_seq,p_action,v_from,v_to,p_actor_id,p_custody_party,p_shipment_reference,p_recipient_confirmation,v_prev,v_hash) returning * into v_event;
  return jsonb_build_object('media',to_jsonb(v_media),'event',to_jsonb(v_event));
end $$;
revoke all on function provenance_api.pv_r3_transition_media(text,text,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_transition_media(text,text,text,text,text,text,text,text) to service_role;

create or replace function provenance_api.pv_r3_record_launch_gate(
  p_gate_id text,p_state text,p_evidence_fresh boolean,p_approver_identities text[],p_approval_signatures text[],
  p_activation_record_id text,p_key_ceremony_reference text,p_release_hashes text[],p_rollback_authority text,
  p_kill_switch_ready boolean,p_activation_timestamp timestamptz,p_post_activation_checks jsonb,p_actor_id text
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,pg_temp
as $$
declare v_gate public.pv_launch_gates; v_all_ready boolean;
begin
  if p_gate_id not in ('G1','G2','G3','G4','G5') or p_state not in ('pending','approved','blocked') then raise exception 'PV_LAUNCH_GATE_INVALID'; end if;
  if p_state='approved' and (not p_evidence_fresh or cardinality(p_approver_identities)<1 or cardinality(p_approval_signatures)<>cardinality(p_approver_identities)
      or cardinality(p_release_hashes)<1 or p_rollback_authority is null or not p_kill_switch_ready) then raise exception 'PV_LAUNCH_GATE_APPROVAL_INCOMPLETE'; end if;
  insert into public.pv_launch_gates(id,state,evidence_fresh,approver_identities,approval_signatures,activation_record_id,key_ceremony_reference,release_hashes,
    rollback_authority,kill_switch_ready,activation_timestamp,post_activation_checks)
  values(p_gate_id,p_state,p_evidence_fresh,p_approver_identities,p_approval_signatures,p_activation_record_id,p_key_ceremony_reference,p_release_hashes,
    p_rollback_authority,p_kill_switch_ready,p_activation_timestamp,p_post_activation_checks)
  on conflict(id) do update set state=excluded.state,evidence_fresh=excluded.evidence_fresh,approver_identities=excluded.approver_identities,
    approval_signatures=excluded.approval_signatures,activation_record_id=excluded.activation_record_id,key_ceremony_reference=excluded.key_ceremony_reference,
    release_hashes=excluded.release_hashes,rollback_authority=excluded.rollback_authority,kill_switch_ready=excluded.kill_switch_ready,
    activation_timestamp=excluded.activation_timestamp,post_activation_checks=excluded.post_activation_checks,updated_at=now() returning * into v_gate;
  select count(*)=5 into v_all_ready from public.pv_launch_gates where state='approved' and evidence_fresh and kill_switch_ready;
  perform provenance_api.append_authority_event('platform','launch-gate',p_gate_id,'launch-gate.'||p_state,p_actor_id,to_jsonb(v_gate),null);
  return jsonb_build_object('gate',to_jsonb(v_gate),'allGatesApproved',v_all_ready);
end $$;
revoke all on function provenance_api.pv_r3_record_launch_gate(text,text,boolean,text[],text[],text,text,text[],text,boolean,timestamptz,jsonb,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_launch_gate(text,text,boolean,text[],text[],text,text,text[],text,boolean,timestamptz,jsonb,text) to service_role;

create or replace function provenance_api.pv_r3_record_stabilization_control(
  p_day integer,p_control_date date,p_daily_controls_pass boolean,p_weekly_risk_review boolean,p_defect_trend integer,
  p_incidents_reviewed boolean,p_issuance_healthy boolean,p_revocation_healthy boolean,p_registry_consistent boolean,
  p_key_healthy boolean,p_custos_healthy boolean,p_evidence_custody_healthy boolean,p_customer_support_healthy boolean,
  p_authority_review text,p_evidence jsonb,p_actor_id text
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,pg_temp
as $$
declare v_row public.pv_stabilization_daily_controls;
begin
  if p_day<1 or p_day>90 then raise exception 'PV_STABILIZATION_DAY_INVALID'; end if;
  if p_day in (30,60,90) and p_authority_review is null then raise exception 'PV_AUTHORITY_REVIEW_REQUIRED'; end if;
  insert into public.pv_stabilization_daily_controls(day,control_date,daily_controls_pass,weekly_risk_review,defect_trend,incidents_reviewed,
    issuance_healthy,revocation_healthy,registry_consistent,key_healthy,custos_healthy,evidence_custody_healthy,customer_support_healthy,authority_review,evidence)
  values(p_day,p_control_date,p_daily_controls_pass,p_weekly_risk_review,p_defect_trend,p_incidents_reviewed,p_issuance_healthy,p_revocation_healthy,
    p_registry_consistent,p_key_healthy,p_custos_healthy,p_evidence_custody_healthy,p_customer_support_healthy,p_authority_review,p_evidence)
  on conflict(day) do update set control_date=excluded.control_date,daily_controls_pass=excluded.daily_controls_pass,weekly_risk_review=excluded.weekly_risk_review,
    defect_trend=excluded.defect_trend,incidents_reviewed=excluded.incidents_reviewed,issuance_healthy=excluded.issuance_healthy,
    revocation_healthy=excluded.revocation_healthy,registry_consistent=excluded.registry_consistent,key_healthy=excluded.key_healthy,
    custos_healthy=excluded.custos_healthy,evidence_custody_healthy=excluded.evidence_custody_healthy,
    customer_support_healthy=excluded.customer_support_healthy,authority_review=excluded.authority_review,evidence=excluded.evidence,recorded_at=now()
  returning * into v_row;
  perform provenance_api.append_authority_event('platform','stabilization',p_day::text,'stabilization.control-recorded',p_actor_id,to_jsonb(v_row),null);
  return to_jsonb(v_row);
end $$;
revoke all on function provenance_api.pv_r3_record_stabilization_control(integer,date,boolean,boolean,integer,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,jsonb,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_stabilization_control(integer,date,boolean,boolean,integer,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,jsonb,text) to service_role;

-- Canonical Category L controlled index, recovered from the accepted launch-to-operate authority.
insert into public.pv_category_l_controls(id,name,owner_identity,dependencies,evidence_requirements,pass_conditions,block_conditions,state)
values
('L-001','Current Reality, Source-of-Truth and Launch Baseline','PROVENANCE Program Authority','{}','{"requiredIds":["source-baseline","custody-manifest"]}','{"allEvidenceVerified":true}','{"sourceMismatch":true}','NOT_READY'),
('L-002','Master Critical Path, Dependency Graph and Readiness Register','Launch Program Authority','{L-001}','{"requiredIds":["dependency-graph","readiness-register"]}','{"dependenciesReady":true}','{"criticalPathBlocked":true}','NOT_READY'),
('L-003','Operator OS, Admin Command Center, Agent Contact and Approval Runtime','Operations Authority','{L-002}','{"requiredIds":["operator-runtime","approval-runtime"]}','{"operatorActionsExecutable":true}','{"deadControls":true}','NOT_READY'),
('L-004','Web, PWA, Desktop, Flutter and Native Client Decision Authority','Product Authority','{L-002,L-003}','{"requiredIds":["client-decision-record","supported-client-matrix"]}','{"supportedClientsAccepted":true}','{"clientScopeAmbiguous":true}','NOT_READY'),
('L-005','Repository, Environments, Infrastructure, Hosting and Deployment Activation','Engineering Authority','{L-002,L-004}','{"requiredIds":["repository-custody","environment-isolation","infrastructure-plan"]}','{"environmentsIsolated":true}','{"infrastructureUnverified":true}','NOT_READY'),
('L-006','Identity, OAuth, Secrets, Roles, Devices and Production Access','Security Authority','{L-005}','{"requiredIds":["identity-acceptance","mfa-acceptance","access-review"]}','{"leastPrivilegePassed":true}','{"identityBoundaryIncomplete":true}','NOT_READY'),
('L-007','Entity, Governance, Legal, Insurance and Professional Readiness','Legal Authority','{L-001}','{"requiredIds":["issuer-authority","insurance-evidence","governance-approval"]}','{"issuerAuthorized":true}','{"legalAuthorityMissing":true}','NOT_READY'),
('L-008','Domains, DNS, Email, Telephone, Mailboxes and Public Contact Operations','Operations Authority','{L-007}','{"requiredIds":["domain-control","contact-operations"]}','{"publicContactsOperational":true}','{"contactRouteUnavailable":true}','NOT_READY'),
('L-009','Banking, Treasury, Payments, Tax, Accounting and Launch Budget','Finance Authority','{L-007}','{"requiredIds":["treasury-control","tax-accounting-readiness","launch-budget"]}','{"financialControlsPassed":true}','{"financialAuthorityIncomplete":true}','NOT_READY'),
('L-010','AI Agent Corps, Provider Continuity, Exception Authority and Operating Calendar','AI Operations Authority','{L-003,L-006}','{"requiredIds":["agent-roster","provider-continuity","exception-authority"]}','{"autonomyTargetSupported":true}','{"providerContinuityMissing":true}','NOT_READY'),
('L-011','Data Migration, Production Seeding, Reconciliation and Rollback','Data Authority','{L-005,L-006}','{"requiredIds":["migration-plan","rollback-test","reconciliation-proof"]}','{"migrationAccepted":true}','{"rollbackUnproven":true}','NOT_READY'),
('L-012','Product Completion, Quality Engineering and Release-Candidate Certification','Release Authority','{L-004,L-005,L-006}','{"requiredIds":["release-candidate","quality-report","package-hash"]}','{"releaseCandidateCertified":true}','{"criticalDefectOpen":true}','NOT_READY'),
('L-013','Customer Zero, Unrelated Customer One, Pilot and Private Beta','Customer Acceptance Authority','{L-011,L-012}','{"requiredIds":["customer-zero-proof","customer-one-proof","tenant-isolation-proof"]}','{"twoCustomersAccepted":true}','{"customerAcceptanceIncomplete":true}','NOT_READY'),
('L-014','PV Protocol, Reviewer, Credential, Appeal, Revocation and Registry Readiness','Trust Authority','{L-006,L-011,L-012}','{"requiredIds":["protocol-acceptance","reviewer-governance","registry-lifecycle-proof"]}','{"trustChainPassed":true}','{"trustAuthorityIncomplete":true}','NOT_READY'),
('L-015','API, MCP, Documentation, Sandbox, SDK and Developer Readiness','Developer Authority','{L-005,L-012,L-014}','{"requiredIds":["api-acceptance","mcp-acceptance","developer-docs"]}','{"developerSurfacePassed":true}','{"developerSurfaceBroken":true}','NOT_READY'),
('L-016','Brand, Public Website, Demonstrations, Trust Center and Customer Contracts','Brand and Legal Authority','{L-007,L-012,L-014}','{"requiredIds":["visual-preservation","trust-center","contract-authority"]}','{"publicExperienceAccepted":true}','{"publicClaimUnapproved":true}','NOT_READY'),
('L-017','SEO, AEO, Sitemap, Structured Data, Indexing and Knowledge Authority','Knowledge Authority','{L-016}','{"requiredIds":["search-readiness","structured-data","knowledge-authority"]}','{"discoverabilityAccepted":true}','{"indexingIncomplete":true}','NOT_READY'),
('L-018','Press, Media, Social, Email, Public Claims and Launch Communications','Communications Authority','{L-007,L-016,L-017}','{"requiredIds":["claims-approval","launch-communications","press-readiness"]}','{"communicationsApproved":true}','{"unapprovedClaimPresent":true}','NOT_READY'),
('L-019','CRM, Sales, Outreach, Demonstrations, Contracts and First-Customer Pipeline','Commercial Authority','{L-008,L-009,L-013,L-016}','{"requiredIds":["crm-readiness","sales-pipeline","contract-flow"]}','{"commercialFlowOperational":true}','{"commercialHandoffBroken":true}','NOT_READY'),
('L-020','Partners, Reviewers, Institutions, Procurement and Vendor Launch Operations','Partner Governance Authority','{L-007,L-014,L-019}','{"requiredIds":["partner-register","reviewer-register","vendor-register"]}','{"governedPartiesCurrent":true}','{"partyGovernanceExpired":true}','NOT_READY'),
('L-021','Credential Media, Packaging, QR/NFC, Inventory, Shipping and Fulfillment','Fulfillment Authority','{L-012,L-014,L-020}','{"requiredIds":["media-custody-proof","fulfillment-proof","anti-reuse-test"]}','{"mediaCustodyPassed":true}','{"mediaReusePossible":true}','NOT_READY'),
('L-022','Autonomous Support, Status, Service Desk, Refunds, Exceptions and Degraded Recovery','Service Authority','{L-003,L-008,L-013}','{"requiredIds":["support-readiness","degraded-recovery","exception-routing"]}','{"serviceOperationsPassed":true}','{"supportRecoveryUnavailable":true}','NOT_READY'),
('L-023','Autonomous Observability, Chaos Rehearsal, Continuity, Cutover and T-90–T-1 Sequence','Reliability Authority','{L-005,L-010,L-011,L-012,L-022}','{"requiredIds":["observability-proof","chaos-rehearsal","cutover-sequence"]}','{"continuityPassed":true}','{"recoveryUnproven":true}','NOT_READY'),
('L-024','Final Go/No-Go, Launch Command, Launch Week and Days 8–90 Stabilization','Launch Authority','{L-013,L-014,L-015,L-016,L-017,L-018,L-019,L-020,L-021,L-022,L-023}','{"requiredIds":["g1-g5-approval","activation-record","stabilization-plan"]}','{"launchAuthorized":true}','{"mandatoryGateOpen":true}','NOT_READY')
on conflict(id) do update set name=excluded.name,owner_identity=excluded.owner_identity,dependencies=excluded.dependencies,
  evidence_requirements=excluded.evidence_requirements,pass_conditions=excluded.pass_conditions,block_conditions=excluded.block_conditions;

-- H-005: durable asynchronous webhook delivery with atomic leasing and dead-letter custody.
alter table public.pv_webhook_delivery_queue
  add column if not exists replay_of uuid references public.pv_webhook_delivery_queue(id),
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by text;

create index if not exists pv_webhook_delivery_claim_idx
  on public.pv_webhook_delivery_queue(status,next_attempt_at,created_at)
  where status in ('queued','retrying');

create or replace function public.pv_r3_claim_webhook_deliveries(
  p_worker_id text,
  p_limit integer default 20
)
returns table (
  id uuid,
  tenant_id text,
  endpoint_id uuid,
  event_id text,
  delivery_id text,
  payload jsonb,
  attempt integer,
  maximum_attempts integer,
  endpoint_url text,
  secret_ciphertext text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if coalesce(p_worker_id,'') = '' then raise exception 'WORKER_ID_REQUIRED'; end if;
  if p_limit < 1 or p_limit > 100 then raise exception 'WORKER_LIMIT_INVALID'; end if;
  return query
  with claimed as (
    select q.id
    from public.pv_webhook_delivery_queue q
    join public.pv_webhook_endpoints e on e.id = q.endpoint_id and e.tenant_id = q.tenant_id
    where q.status in ('queued','retrying')
      and q.next_attempt_at <= now()
      and e.status = 'active'
    order by q.next_attempt_at, q.created_at
    for update of q skip locked
    limit p_limit
  ), updated as (
    update public.pv_webhook_delivery_queue q
       set status = 'processing', locked_at = now(), locked_by = p_worker_id
      from claimed c
     where q.id = c.id
    returning q.*
  )
  select u.id,u.tenant_id,u.endpoint_id,u.event_id,u.delivery_id,u.payload,u.attempt,u.maximum_attempts,e.url,e.secret_ciphertext
  from updated u
  join public.pv_webhook_endpoints e on e.id = u.endpoint_id;
end;
$$;

create or replace function public.pv_r3_complete_webhook_delivery(
  p_id uuid,
  p_worker_id text,
  p_success boolean,
  p_http_status integer,
  p_response_bytes integer,
  p_error text,
  p_signature text
)
returns public.pv_webhook_delivery_queue
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  q public.pv_webhook_delivery_queue;
  next_attempt integer;
  next_state text;
  next_time timestamptz;
begin
  select * into q from public.pv_webhook_delivery_queue
   where id = p_id and status = 'processing' and locked_by = p_worker_id
   for update;
  if not found then raise exception 'WEBHOOK_LEASE_NOT_HELD'; end if;
  next_attempt := q.attempt + 1;
  if p_success then
    next_state := 'delivered'; next_time := now();
  elsif next_attempt >= q.maximum_attempts then
    next_state := 'dead-letter'; next_time := now();
  else
    next_state := 'retrying';
    next_time := now() + make_interval(secs => least(86400, (power(2,next_attempt)::integer * 60)));
  end if;

  update public.pv_webhook_delivery_queue
     set attempt = next_attempt,
         status = next_state,
         next_attempt_at = next_time,
         last_http_status = p_http_status,
         last_error = p_error,
         response_bytes = p_response_bytes,
         payload_signature = p_signature,
         signature_timestamp = now(),
         delivered_at = case when next_state = 'delivered' then now() else delivered_at end,
         locked_at = null,
         locked_by = null
   where id = p_id
   returning * into q;

  insert into public.pv_webhook_deliveries(
    tenant_id,endpoint_id,authority_event_id,attempt,status,signature,response_code,scheduled_at,completed_at,replay_of
  )
  select q.tenant_id,q.endpoint_id,a.id,next_attempt,
         case when next_state='retrying' then 'failed' else next_state end,
         coalesce(p_signature,'unavailable'),p_http_status,q.next_attempt_at,now(),null
    from public.pv_authority_events a
   where a.id::text = q.event_id
  on conflict (endpoint_id,authority_event_id,attempt) do nothing;

  if next_state = 'dead-letter' then
    insert into public.pv_dead_letters(tenant_id,source_table,source_id,topic,payload,attempts,final_error)
    values(q.tenant_id,'pv_webhook_delivery_queue',q.id,'webhook.delivery',q.payload,next_attempt,coalesce(p_error,'MAX_ATTEMPTS_EXCEEDED'));
  end if;
  return q;
end;
$$;

revoke all on function public.pv_r3_claim_webhook_deliveries(text,integer) from public, anon, authenticated;
revoke all on function public.pv_r3_complete_webhook_delivery(uuid,text,boolean,integer,integer,text,text) from public, anon, authenticated;
grant execute on function public.pv_r3_claim_webhook_deliveries(text,integer) to service_role;
grant execute on function public.pv_r3_complete_webhook_delivery(uuid,text,boolean,integer,integer,text,text) to service_role;

-- H-004: safe public append-only registry history projections.
create or replace view provenance_api.pv_public_registry_versions
with (security_invoker=true)
as
select public_id,version,payload,payload_digest,credential_signature,signing_key_id,signing_key_version,created_at
from public.pv_registry_versions;

create or replace view provenance_api.pv_public_registry_events
with (security_invoker=true)
as
select public_id,sequence,event_type,from_state,to_state,credential_version,reason,previous_event_hash,event_hash,
       registry_signature,registry_key_id,registry_key_version,occurred_at
from public.pv_registry_events;

grant select on provenance_api.pv_public_registry_versions, provenance_api.pv_public_registry_events to anon,authenticated;

-- H-012: controlled certification-mark governance commands.
create or replace function provenance_api.pv_r3_upsert_mark_license(
  p_tenant_id text,
  p_license_number text,
  p_status text,
  p_credential_types text[],
  p_permitted_media text[],
  p_permitted_geography text[],
  p_effective_at timestamptz,
  p_expires_at timestamptz,
  p_renewal_state text,
  p_evidence jsonb,
  p_actor_id text
) returns public.pv_mark_licenses
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare v public.pv_mark_licenses;
begin
  if p_status not in ('active','suspended','expired','terminated') then raise exception 'PV_MARK_LICENSE_STATUS_INVALID'; end if;
  if p_effective_at>=p_expires_at then raise exception 'PV_MARK_LICENSE_DATE_INVALID'; end if;
  insert into public.pv_mark_licenses(tenant_id,license_number,status,credential_types,permitted_media,permitted_geography,effective_at,expires_at,renewal_state,evidence)
  values(p_tenant_id,p_license_number,p_status,p_credential_types,p_permitted_media,p_permitted_geography,p_effective_at,p_expires_at,p_renewal_state,p_evidence)
  on conflict(license_number) do update set
    status=excluded.status,credential_types=excluded.credential_types,permitted_media=excluded.permitted_media,
    permitted_geography=excluded.permitted_geography,effective_at=excluded.effective_at,expires_at=excluded.expires_at,
    renewal_state=excluded.renewal_state,evidence=excluded.evidence,updated_at=now()
  where public.pv_mark_licenses.tenant_id=excluded.tenant_id returning * into v;
  if not found then raise exception 'PV_MARK_LICENSE_TENANT_CONFLICT'; end if;
  perform provenance_api.append_authority_event(p_tenant_id,'mark-license',v.id::text,'mark-license.'||p_status,p_actor_id,to_jsonb(v),null);
  return v;
end $$;

create or replace function provenance_api.pv_r3_upsert_location_authorization(
  p_tenant_id text,
  p_location_id uuid,
  p_status text,
  p_permitted_media text[],
  p_permitted_geography text[],
  p_effective_at timestamptz,
  p_expires_at timestamptz,
  p_evidence jsonb,
  p_actor_id text
) returns public.pv_location_authorizations
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare v public.pv_location_authorizations;
begin
  if p_status not in ('active','suspended','expired','terminated') then raise exception 'PV_LOCATION_AUTH_STATUS_INVALID'; end if;
  if p_effective_at>=p_expires_at then raise exception 'PV_LOCATION_AUTH_DATE_INVALID'; end if;
  if not exists(select 1 from public.pv_locations where id=p_location_id and tenant_id=p_tenant_id and active) then raise exception 'PV_ACTIVE_TENANT_LOCATION_REQUIRED'; end if;
  insert into public.pv_location_authorizations(tenant_id,location_id,status,permitted_media,permitted_geography,effective_at,expires_at,evidence)
  values(p_tenant_id,p_location_id,p_status,p_permitted_media,p_permitted_geography,p_effective_at,p_expires_at,p_evidence)
  on conflict(tenant_id,location_id) do update set status=excluded.status,permitted_media=excluded.permitted_media,
    permitted_geography=excluded.permitted_geography,effective_at=excluded.effective_at,expires_at=excluded.expires_at,evidence=excluded.evidence,updated_at=now()
  returning * into v;
  perform provenance_api.append_authority_event(p_tenant_id,'mark-location',v.id::text,'mark-location.'||p_status,p_actor_id,to_jsonb(v),null);
  return v;
end $$;

create or replace function provenance_api.pv_r3_register_mark_artwork(
  p_tenant_id text,
  p_id text,
  p_version text,
  p_artwork_digest text,
  p_status text,
  p_permitted_media text[],
  p_permitted_geographies text[],
  p_effective_at timestamptz,
  p_actor_id text
) returns public.pv_mark_artwork_versions
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare v public.pv_mark_artwork_versions;
begin
  if p_artwork_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_ARTWORK_DIGEST_INVALID'; end if;
  if p_status not in ('active','recalled','retired') then raise exception 'PV_ARTWORK_STATUS_INVALID'; end if;
  select * into v from public.pv_mark_artwork_versions where id=p_id or version=p_version for update;
  if found and v.artwork_digest<>p_artwork_digest then raise exception 'PV_ARTWORK_IMMUTABLE_DIGEST_MISMATCH'; end if;
  insert into public.pv_mark_artwork_versions(id,version,artwork_digest,status,permitted_media,permitted_geographies,effective_at,recalled_at,recall_reason)
  values(p_id,p_version,p_artwork_digest,p_status,p_permitted_media,p_permitted_geographies,p_effective_at,
    case when p_status='recalled' then now() else null end,case when p_status='recalled' then 'registered recalled' else null end)
  on conflict(id) do update set status=excluded.status,permitted_media=excluded.permitted_media,
    permitted_geographies=excluded.permitted_geographies,effective_at=excluded.effective_at
  returning * into v;
  perform provenance_api.append_authority_event(p_tenant_id,'mark-artwork',v.id,'mark-artwork.'||p_status,p_actor_id,to_jsonb(v),null);
  return v;
end $$;

create or replace function provenance_api.pv_r3_transition_mark_governance(
  p_tenant_id text,
  p_resource_type text,
  p_resource_id text,
  p_action text,
  p_reason text,
  p_actor_id text
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare v_status text; v_affected integer:=0; v_artwork_version text;
begin
  if length(trim(coalesce(p_reason,'')))<3 then raise exception 'PV_MARK_TRANSITION_REASON_REQUIRED'; end if;
  if p_action not in ('activate','renew','suspend','expire','terminate','recall','retire') then raise exception 'PV_MARK_TRANSITION_INVALID'; end if;
  v_status:=case p_action when 'activate' then 'active' when 'renew' then 'active' when 'suspend' then 'suspended' when 'expire' then 'expired' when 'terminate' then 'terminated' when 'recall' then 'recalled' when 'retire' then 'retired' end;
  if p_resource_type='license' then
    update public.pv_mark_licenses set status=v_status,renewal_state=case when p_action='renew' then 'renewed' else renewal_state end,updated_at=now()
      where id::text=p_resource_id and tenant_id=p_tenant_id;
    get diagnostics v_affected=row_count;
  elsif p_resource_type='location' then
    update public.pv_location_authorizations set status=v_status,updated_at=now()
      where id::text=p_resource_id and tenant_id=p_tenant_id;
    get diagnostics v_affected=row_count;
  elsif p_resource_type='artwork' then
    select version into v_artwork_version from public.pv_mark_artwork_versions where id=p_resource_id;
    update public.pv_mark_artwork_versions set status=v_status,
      recalled_at=case when p_action='recall' then now() else recalled_at end,
      recall_reason=case when p_action='recall' then p_reason else recall_reason end where id=p_resource_id;
    get diagnostics v_affected=row_count;
  else raise exception 'PV_MARK_RESOURCE_INVALID'; end if;
  if v_affected<>1 then raise exception 'PV_MARK_RESOURCE_NOT_FOUND'; end if;

  if p_action in ('suspend','expire','terminate','recall','retire') then
    update public.pv_mark_authorizations m set status=case when p_action in ('terminate','recall','retire') then 'revoked' else 'suspended' end,updated_at=now()
      where m.tenant_id=p_tenant_id and m.status='authorized'
        and (p_resource_type<>'artwork' or m.artwork_version=v_artwork_version);
    update public.pv_media_identifiers set state='suppressed'
      where tenant_id=p_tenant_id and state='active' and credential_id in (
        select credential_id from public.pv_mark_authorizations where tenant_id=p_tenant_id and status in ('suspended','revoked')
      );
    insert into public.pv_mark_usage_events(tenant_id,authorization_id,credential_id,action,media_type,geography,artwork_version,actor_id,details)
      select tenant_id,id,credential_id,case when p_action='recall' then 'recalled' else 'suppressed' end,
        'all','all',coalesce(artwork_version,'unknown'),p_actor_id,jsonb_build_object('resourceType',p_resource_type,'resourceId',p_resource_id,'reason',p_reason)
      from public.pv_mark_authorizations where tenant_id=p_tenant_id and status in ('suspended','revoked');
  end if;
  perform provenance_api.append_authority_event(p_tenant_id,'mark-governance',p_resource_type||':'||p_resource_id,'mark-governance.'||p_action,p_actor_id,
    jsonb_build_object('resourceType',p_resource_type,'resourceId',p_resource_id,'action',p_action,'reason',p_reason),null);
  return jsonb_build_object('resourceType',p_resource_type,'resourceId',p_resource_id,'status',v_status,'suppressionApplied',p_action in ('suspend','expire','terminate','recall','retire'));
end $$;

revoke all on function provenance_api.pv_r3_upsert_mark_license(text,text,text,text[],text[],text[],timestamptz,timestamptz,text,jsonb,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_upsert_location_authorization(text,uuid,text,text[],text[],timestamptz,timestamptz,jsonb,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_register_mark_artwork(text,text,text,text,text,text[],text[],timestamptz,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_transition_mark_governance(text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_upsert_mark_license(text,text,text,text[],text[],text[],timestamptz,timestamptz,text,jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_upsert_location_authorization(text,uuid,text,text[],text[],timestamptz,timestamptz,jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_register_mark_artwork(text,text,text,text,text,text[],text[],timestamptz,text) to service_role;
grant execute on function provenance_api.pv_r3_transition_mark_governance(text,text,text,text,text,text) to service_role;
