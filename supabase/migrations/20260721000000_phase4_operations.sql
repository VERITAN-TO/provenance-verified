-- PROVENANCE.CX Phase 4 operational schema contract (PostgreSQL 16+)
-- The application release still uses deterministic Test Mode adapters. This migration is the production persistence contract.

create extension if not exists pgcrypto;

create table pv_tenants (
  id text primary key,
  legal_name text not null,
  display_name text not null,
  status text not null check (status in ('active','suspended')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table pv_locations (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  code text not null,
  name text not null,
  timezone text not null,
  address text not null,
  active boolean not null default true,
  unique (tenant_id, code)
);

create table pv_inventory_lots (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  location_id text not null references pv_locations(id),
  supplier_reference text not null,
  description text not null,
  declared_quantity integer not null check (declared_quantity >= 0),
  identified_unit_count integer not null default 0 check (identified_unit_count >= 0),
  status text not null,
  received_at timestamptz not null,
  notes text not null default ''
);

create table pv_intake_batches (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  location_id text not null references pv_locations(id),
  name text not null,
  reference text not null,
  status text not null,
  validation_errors jsonb not null default '[]'::jsonb,
  created_by text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  submitted_at timestamptz,
  attestation_id text,
  version integer not null default 1,
  unique (tenant_id, reference)
);

create table pv_assets (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  location_id text not null references pv_locations(id),
  batch_id text not null references pv_intake_batches(id),
  lot_id text references pv_inventory_lots(id),
  serial text not null,
  status text not null,
  material text not null,
  shape text not null,
  cut text not null default '',
  color_description text not null default '',
  clarity_description text not null default '',
  treatment_disclosure text not null,
  origin_claim text not null,
  measurements jsonb not null,
  identifying_features jsonb not null default '[]'::jsonb,
  supplier_reference text not null default '',
  laboratory_report_reference text not null default '',
  created_by text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  version integer not null default 1,
  unique (tenant_id, serial)
);

create table pv_evidence_objects (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  asset_id text not null references pv_assets(id),
  type text not null,
  label text not null,
  source_organization text not null,
  source_type text not null,
  acquisition_method text not null,
  issue_date timestamptz not null,
  expires_at timestamptz,
  claim_ids jsonb not null default '[]'::jsonb,
  independent boolean not null default false,
  qualified boolean not null default false,
  integrity_hash text not null,
  storage_key text not null,
  visibility text not null,
  status text not null,
  created_by text not null,
  created_at timestamptz not null
);

create table pv_attestations (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  batch_id text not null references pv_intake_batches(id),
  signer_id text not null,
  signer_role text not null,
  organization_name text not null,
  asset_ids jsonb not null,
  claim_summary text not null,
  evidence_summary text not null,
  limitations jsonb not null,
  declaration text not null,
  version integer not null,
  signed_at timestamptz not null,
  signature text not null,
  supersedes_id text references pv_attestations(id),
  unique (batch_id, version)
);

create table pv_review_cases (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  batch_id text not null references pv_intake_batches(id),
  asset_id text not null references pv_assets(id),
  status text not null,
  assigned_reviewer_ids jsonb not null default '[]'::jsonb,
  approvals jsonb not null default '[]'::jsonb,
  conflict_clearance text not null,
  custos_verdict jsonb not null,
  signing_key_status text not null,
  registry_status text not null,
  revocation_capability boolean not null default false,
  mark_authorization text not null,
  correction_request text,
  decision jsonb,
  credential jsonb,
  opened_at timestamptz not null,
  updated_at timestamptz not null,
  service_level_due_at timestamptz not null,
  unique (tenant_id, asset_id)
);

create table pv_sync_operations (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  device_id text not null,
  entity_type text not null,
  entity_id text not null,
  operation text not null,
  expected_version integer not null,
  payload jsonb not null,
  status text not null,
  attempts integer not null default 0,
  created_at timestamptz not null,
  last_attempt_at timestamptz,
  error text
);

create table pv_operational_audit_events (
  id text primary key,
  tenant_id text not null references pv_tenants(id),
  actor_id text not null,
  actor_role text not null,
  action text not null,
  target_type text not null,
  target_id text not null,
  previous_state jsonb,
  resulting_state jsonb,
  reason text,
  request_id text not null,
  at timestamptz not null
);

create index pv_assets_tenant_batch_idx on pv_assets (tenant_id, batch_id, updated_at desc);
create index pv_assets_tenant_serial_idx on pv_assets (tenant_id, serial);
create index pv_evidence_asset_idx on pv_evidence_objects (tenant_id, asset_id, status);
create index pv_review_queue_idx on pv_review_cases (tenant_id, status, service_level_due_at);
create index pv_sync_queue_idx on pv_sync_operations (tenant_id, device_id, status, created_at);
create index pv_audit_target_idx on pv_operational_audit_events (tenant_id, target_type, target_id, at desc);

-- Application transactions must execute SET LOCAL app.tenant_id = '<tenant-id>'.
alter table pv_locations enable row level security;
alter table pv_inventory_lots enable row level security;
alter table pv_intake_batches enable row level security;
alter table pv_assets enable row level security;
alter table pv_evidence_objects enable row level security;
alter table pv_attestations enable row level security;
alter table pv_review_cases enable row level security;
alter table pv_sync_operations enable row level security;
alter table pv_operational_audit_events enable row level security;

create policy tenant_scope_locations on pv_locations using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_lots on pv_inventory_lots using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_batches on pv_intake_batches using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_assets on pv_assets using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_evidence on pv_evidence_objects using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_attestations on pv_attestations using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_reviews on pv_review_cases using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_sync on pv_sync_operations using (tenant_id = current_setting('app.tenant_id', true));
create policy tenant_scope_audit on pv_operational_audit_events using (tenant_id = current_setting('app.tenant_id', true));
