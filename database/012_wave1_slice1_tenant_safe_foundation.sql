-- PROVENANCE.CX Wave 1 Slice 1 — tenant-safe authenticated foundation
-- Contracts: W1-C01 through W1-C07 / v1-wave1 / SLICE_LOCKED.
-- W1-C10 VERIFICATION_RESULT is intentionally absent.
-- This migration does not rewrite historical migrations.

begin;

create extension if not exists pgcrypto;
create schema if not exists provenance_api;

-- -----------------------------------------------------------------------------
-- Canonical actor and authority persistence
-- -----------------------------------------------------------------------------

create table if not exists public.pv_actors (
  id uuid primary key default gen_random_uuid(),
  actor_type text not null check (actor_type in ('user','workload')),
  auth_subject_id uuid,
  workload_identity_id text references public.pv_workload_identities(id),
  status text not null default 'active' check (status in ('active','inactive','suspended','revoked')),
  authority_version bigint not null default 1 check (authority_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pv_actors_exactly_one_binding check (
    (actor_type = 'user' and auth_subject_id is not null and workload_identity_id is null)
    or
    (actor_type = 'workload' and auth_subject_id is null and workload_identity_id is not null)
  )
);

create unique index if not exists pv_actors_auth_subject_unique
  on public.pv_actors(auth_subject_id)
  where auth_subject_id is not null;

create unique index if not exists pv_actors_workload_identity_unique
  on public.pv_actors(workload_identity_id)
  where workload_identity_id is not null;

create table if not exists public.pv_role_registry (
  role text primary key,
  description text not null,
  active boolean not null default true,
  authority_version bigint not null default 1 check (authority_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pv_role_registry_wave1_roles check (
    role in ('organization_owner','organization_admin','operator','reviewer','member')
  )
);

create table if not exists public.pv_role_permissions (
  role text not null references public.pv_role_registry(role) on delete restrict,
  resource_type text not null,
  action text not null,
  active boolean not null default true,
  authority_version bigint not null default 1 check (authority_version > 0),
  created_at timestamptz not null default now(),
  primary key (role, resource_type, action),
  constraint pv_role_permissions_action_check check (action in ('read','create','update','delete','manage'))
);

insert into public.pv_role_registry(role, description)
values
  ('organization_owner','Tenant owner authority for Wave 1'),
  ('organization_admin','Tenant administration authority for Wave 1'),
  ('operator','Tenant operational authority for Wave 1'),
  ('reviewer','Tenant review authority for Wave 1'),
  ('member','Tenant member authority for Wave 1')
on conflict (role) do update
set description = excluded.description,
    active = true,
    updated_at = now();

insert into public.pv_role_permissions(role, resource_type, action)
values
  ('organization_owner','tenant_resource','read'),
  ('organization_owner','membership','read'),
  ('organization_owner','membership','manage'),
  ('organization_owner','asset','read'),
  ('organization_admin','tenant_resource','read'),
  ('organization_admin','membership','read'),
  ('organization_admin','membership','manage'),
  ('organization_admin','asset','read'),
  ('operator','tenant_resource','read'),
  ('operator','asset','read'),
  ('reviewer','tenant_resource','read'),
  ('reviewer','asset','read'),
  ('member','tenant_resource','read'),
  ('member','asset','read')
on conflict (role, resource_type, action) do update
set active = true;

-- Purchaser is deliberately not a role. A purchaser relationship has no authority.
create table if not exists public.pv_purchaser_relationships (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id) on delete cascade,
  actor_id uuid not null references public.pv_actors(id) on delete restrict,
  subject_type text not null,
  subject_id text not null,
  status text not null default 'active' check (status in ('active','inactive','revoked')),
  non_authorizing boolean not null default true check (non_authorizing),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, actor_id, subject_type, subject_id)
);

-- Extend the existing membership record without destroying the legacy source fields.
alter table public.pv_memberships
  add column if not exists actor_id uuid references public.pv_actors(id) on delete restrict,
  add column if not exists authority_role text,
  add column if not exists lifecycle_status text,
  add column if not exists granted_at timestamptz,
  add column if not exists revoked_at timestamptz,
  add column if not exists expires_at timestamptz,
  add column if not exists authority_version bigint,
  add column if not exists resource_scope jsonb;

insert into public.pv_actors(actor_type, auth_subject_id, status)
select 'user', m.user_id,
       case when bool_or(m.status = 'active') then 'active' else 'suspended' end
from public.pv_memberships m
group by m.user_id
on conflict (auth_subject_id) where auth_subject_id is not null do nothing;

update public.pv_memberships m
set actor_id = a.id
from public.pv_actors a
where m.actor_id is null
  and a.actor_type = 'user'
  and a.auth_subject_id = m.user_id;

update public.pv_memberships
set authority_role = case role
      when 'owner' then 'organization_owner'
      when 'administrator' then 'organization_admin'
      when 'intake-operator' then 'operator'
      when 'evidence-manager' then 'operator'
      when 'inventory-manager' then 'operator'
      when 'authorized-attestor' then 'operator'
      when 'reviewer' then 'reviewer'
      when 'compliance-officer' then 'reviewer'
      when 'auditor' then 'reviewer'
      else 'member'
    end,
    lifecycle_status = case status
      when 'active' then 'active'
      when 'suspended' then 'suspended'
      else 'inactive'
    end,
    granted_at = coalesce(granted_at, created_at, now()),
    authority_version = coalesce(authority_version, 1),
    resource_scope = coalesce(resource_scope, '{}'::jsonb)
where authority_role is null
   or lifecycle_status is null
   or granted_at is null
   or authority_version is null
   or resource_scope is null;

alter table public.pv_memberships
  alter column actor_id set not null,
  alter column authority_role set not null,
  alter column lifecycle_status set not null,
  alter column granted_at set not null,
  alter column authority_version set not null,
  alter column resource_scope set not null,
  alter column authority_version set default 1,
  alter column resource_scope set default '{}'::jsonb;

alter table public.pv_memberships drop constraint if exists pv_memberships_authority_role_check;
alter table public.pv_memberships add constraint pv_memberships_authority_role_check
  check (authority_role in ('organization_owner','organization_admin','operator','reviewer','member'));

alter table public.pv_memberships drop constraint if exists pv_memberships_lifecycle_status_check;
alter table public.pv_memberships add constraint pv_memberships_lifecycle_status_check
  check (lifecycle_status in ('active','inactive','suspended','revoked'));

alter table public.pv_memberships drop constraint if exists pv_memberships_authority_version_check;
alter table public.pv_memberships add constraint pv_memberships_authority_version_check
  check (authority_version > 0);

create index if not exists pv_memberships_actor_lifecycle_idx
  on public.pv_memberships(actor_id, lifecycle_status, tenant_id);

create index if not exists pv_memberships_tenant_authority_idx
  on public.pv_memberships(tenant_id, authority_role, lifecycle_status, authority_version);

-- -----------------------------------------------------------------------------
-- Append-only authorization and membership authority evidence
-- -----------------------------------------------------------------------------

create table if not exists public.pv_authorization_audit_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  occurred_at timestamptz not null default now(),
  recorded_at timestamptz not null default now(),
  actor_id uuid references public.pv_actors(id) on delete restrict,
  actor_type text,
  tenant_id text references public.pv_tenants(id) on delete restrict,
  membership_id uuid references public.pv_memberships(id) on delete restrict,
  resource_type text not null,
  resource_id text not null,
  action text not null,
  outcome text not null check (outcome in ('ALLOW','DENY')),
  reason_code text,
  authority_version bigint,
  request_id text,
  correlation_id uuid not null,
  metadata_digest text,
  schema_version text not null default 'v1-wave1',
  integrity_hash text not null,
  constraint pv_authorization_audit_digest_check check (
    metadata_digest is null or metadata_digest ~ '^sha256:[0-9a-f]{64}$'
  ),
  constraint pv_authorization_audit_integrity_check check (
    integrity_hash ~ '^sha256:[0-9a-f]{64}$'
  )
);

create index if not exists pv_authorization_audit_tenant_idx
  on public.pv_authorization_audit_events(tenant_id, recorded_at desc);
create index if not exists pv_authorization_audit_correlation_idx
  on public.pv_authorization_audit_events(correlation_id, recorded_at);

create or replace function provenance_api.reject_immutable_authority_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'PV_IMMUTABLE_AUTHORITY_EVENT';
end;
$$;

create or replace function provenance_api.reject_immutable_authority_truncate()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'PV_IMMUTABLE_AUTHORITY_EVENT';
end;
$$;

drop trigger if exists pv_authorization_audit_immutable_row on public.pv_authorization_audit_events;
create trigger pv_authorization_audit_immutable_row
before update or delete on public.pv_authorization_audit_events
for each row execute function provenance_api.reject_immutable_authority_change();

drop trigger if exists pv_authorization_audit_immutable_truncate on public.pv_authorization_audit_events;
create trigger pv_authorization_audit_immutable_truncate
before truncate on public.pv_authorization_audit_events
for each statement execute function provenance_api.reject_immutable_authority_truncate();

-- -----------------------------------------------------------------------------
-- Durable idempotency
-- -----------------------------------------------------------------------------

create table if not exists public.pv_idempotency_keys (
  tenant_id text not null references public.pv_tenants(id) on delete restrict,
  idempotency_key text not null,
  actor_id uuid not null references public.pv_actors(id) on delete restrict,
  operation text not null,
  request_digest text not null check (request_digest ~ '^sha256:[0-9a-f]{64}$'),
  status text not null default 'IN_PROGRESS' check (status in ('IN_PROGRESS','COMPLETED','FAILED')),
  result_reference text,
  first_seen_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz not null,
  correlation_id uuid not null,
  primary key (tenant_id, idempotency_key),
  constraint pv_idempotency_nonempty_key check (length(btrim(idempotency_key)) between 1 and 255),
  constraint pv_idempotency_expiry_check check (expires_at > first_seen_at)
);

create index if not exists pv_idempotency_actor_operation_idx
  on public.pv_idempotency_keys(actor_id, operation, first_seen_at desc);

-- -----------------------------------------------------------------------------
-- Canonical actor resolution helpers
-- -----------------------------------------------------------------------------

create or replace function provenance_api.resolve_actor_identity(
  p_correlation_id uuid default gen_random_uuid()
)
returns table (
  outcome text,
  reason_code text,
  actor_id uuid,
  actor_type text,
  session_id_or_workload_id text,
  authentication_strength text,
  issued_at timestamptz,
  correlation_id uuid,
  authority_version bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, provenance_api, auth
as $$
declare
  v_subject uuid := auth.uid();
  v_jwt jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  v_workload_id text := nullif(coalesce(auth.jwt(), '{}'::jsonb) -> 'app_metadata' ->> 'workload_identity_id', '');
  v_count integer;
  v_actor public.pv_actors%rowtype;
  v_workload public.pv_workload_identities%rowtype;
  v_issued_at timestamptz;
begin
  begin
    v_issued_at := to_timestamp(nullif(v_jwt->>'iat','')::double precision);
  exception when others then
    v_issued_at := null;
  end;

  if v_subject is not null and v_workload_id is not null then
    return query select 'DENY', 'ACTOR_AMBIGUOUS', null::uuid, null::text, null::text,
      null::text, v_issued_at, p_correlation_id, null::bigint;
    return;
  end if;

  if v_subject is null and v_workload_id is null then
    return query select 'DENY', 'AUTHORITY_UNAVAILABLE', null::uuid, null::text, null::text,
      null::text, v_issued_at, p_correlation_id, null::bigint;
    return;
  end if;

  if v_subject is not null then
    select count(*) into v_count
    from public.pv_actors a
    where a.actor_type = 'user' and a.auth_subject_id = v_subject;

    if v_count = 0 then
      return query select 'DENY', 'ACTOR_UNKNOWN', null::uuid, 'user'::text,
        coalesce(v_jwt->>'session_id', v_subject::text), coalesce(v_jwt->>'aal','aal1'),
        v_issued_at, p_correlation_id, null::bigint;
      return;
    elsif v_count > 1 then
      return query select 'DENY', 'ACTOR_AMBIGUOUS', null::uuid, 'user'::text,
        coalesce(v_jwt->>'session_id', v_subject::text), coalesce(v_jwt->>'aal','aal1'),
        v_issued_at, p_correlation_id, null::bigint;
      return;
    end if;

    select * into v_actor
    from public.pv_actors a
    where a.actor_type = 'user' and a.auth_subject_id = v_subject;
  else
    select count(*) into v_count
    from public.pv_actors a
    where a.actor_type = 'workload' and a.workload_identity_id = v_workload_id;

    if v_count = 0 then
      return query select 'DENY', 'ACTOR_UNKNOWN', null::uuid, 'workload'::text,
        v_workload_id, 'workload-signed', v_issued_at, p_correlation_id, null::bigint;
      return;
    elsif v_count > 1 then
      return query select 'DENY', 'ACTOR_AMBIGUOUS', null::uuid, 'workload'::text,
        v_workload_id, 'workload-signed', v_issued_at, p_correlation_id, null::bigint;
      return;
    end if;

    select * into v_actor
    from public.pv_actors a
    where a.actor_type = 'workload' and a.workload_identity_id = v_workload_id;

    select * into v_workload
    from public.pv_workload_identities w
    where w.id = v_workload_id;

    if not found or v_workload.status <> 'active' or v_workload.expires_at <= now() then
      return query select 'DENY', 'AUTHORITY_UNAVAILABLE', v_actor.id, v_actor.actor_type,
        v_workload_id, 'workload-signed', v_issued_at, p_correlation_id, v_actor.authority_version;
      return;
    end if;
  end if;

  if v_actor.status = 'inactive' then
    return query select 'DENY', 'ACTOR_INACTIVE', v_actor.id, v_actor.actor_type,
      coalesce(v_jwt->>'session_id', v_workload_id),
      case when v_actor.actor_type = 'workload' then 'workload-signed' else coalesce(v_jwt->>'aal','aal1') end,
      v_issued_at, p_correlation_id, v_actor.authority_version;
    return;
  elsif v_actor.status = 'suspended' then
    return query select 'DENY', 'ACTOR_SUSPENDED', v_actor.id, v_actor.actor_type,
      coalesce(v_jwt->>'session_id', v_workload_id),
      case when v_actor.actor_type = 'workload' then 'workload-signed' else coalesce(v_jwt->>'aal','aal1') end,
      v_issued_at, p_correlation_id, v_actor.authority_version;
    return;
  elsif v_actor.status = 'revoked' then
    return query select 'DENY', 'ACTOR_REVOKED', v_actor.id, v_actor.actor_type,
      coalesce(v_jwt->>'session_id', v_workload_id),
      case when v_actor.actor_type = 'workload' then 'workload-signed' else coalesce(v_jwt->>'aal','aal1') end,
      v_issued_at, p_correlation_id, v_actor.authority_version;
    return;
  elsif v_actor.status <> 'active' then
    return query select 'DENY', 'AUTHORITY_UNAVAILABLE', v_actor.id, v_actor.actor_type,
      coalesce(v_jwt->>'session_id', v_workload_id),
      case when v_actor.actor_type = 'workload' then 'workload-signed' else coalesce(v_jwt->>'aal','aal1') end,
      v_issued_at, p_correlation_id, v_actor.authority_version;
    return;
  end if;

  return query select 'RESOLVED', null::text, v_actor.id, v_actor.actor_type,
    coalesce(v_jwt->>'session_id', v_workload_id),
    case when v_actor.actor_type = 'workload' then 'workload-signed' else coalesce(v_jwt->>'aal','aal1') end,
    v_issued_at, p_correlation_id, v_actor.authority_version;
end;
$$;

create or replace function provenance_api.derive_tenant_context(
  p_tenant_hint text default null,
  p_correlation_id uuid default gen_random_uuid()
)
returns table (
  outcome text,
  reason_code text,
  tenant_id text,
  actor_id uuid,
  membership_id uuid,
  derivation_source text,
  derived_at timestamptz,
  correlation_id uuid,
  role text,
  membership_status text,
  authority_version bigint
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, provenance_api, auth
as $$
declare
  v_actor record;
  v_selected_claim text := nullif(coalesce(auth.jwt(), '{}'::jsonb) -> 'app_metadata' ->> 'selected_tenant_id', '');
  v_active_count integer := 0;
  v_membership public.pv_memberships%rowtype;
  v_denial_status text;
  v_workload public.pv_workload_identities%rowtype;
begin
  select * into v_actor
  from provenance_api.resolve_actor_identity(p_correlation_id);

  if v_actor.outcome <> 'RESOLVED' then
    return query select 'DENY', v_actor.reason_code, null::text, v_actor.actor_id,
      null::uuid, 'actor_resolution', now(), p_correlation_id, null::text,
      null::text, v_actor.authority_version;
    return;
  end if;

  if v_actor.actor_type = 'workload' then
    select w.* into v_workload
    from public.pv_workload_identities w
    join public.pv_actors a on a.workload_identity_id = w.id
    where a.id = v_actor.actor_id;

    if not found then
      return query select 'DENY', 'AUTHORITY_UNAVAILABLE', null::text, v_actor.actor_id,
        null::uuid, 'workload_allowlist', now(), p_correlation_id, null::text,
        null::text, v_actor.authority_version;
      return;
    end if;

    if cardinality(v_workload.tenant_ids) = 1 then
      tenant_id := (v_workload.tenant_ids)[1];
      derivation_source := 'workload_single_tenant';
    elsif v_selected_claim is not null and v_selected_claim = any(v_workload.tenant_ids) then
      tenant_id := v_selected_claim;
      derivation_source := 'verified_workload_tenant_claim';
    else
      return query select 'DENY', 'TENANT_AMBIGUOUS', null::text, v_actor.actor_id,
        null::uuid, 'workload_allowlist', now(), p_correlation_id, null::text,
        null::text, v_actor.authority_version;
      return;
    end if;

    if p_tenant_hint is not null and p_tenant_hint <> tenant_id then
      return query select 'DENY', 'TENANT_OVERRIDE_DENIED', null::text, v_actor.actor_id,
        null::uuid, derivation_source, now(), p_correlation_id, null::text,
        null::text, v_actor.authority_version;
      return;
    end if;

    if not exists (select 1 from public.pv_tenants t where t.id = tenant_id and t.status = 'active') then
      return query select 'DENY', 'TENANT_UNAUTHORIZED', null::text, v_actor.actor_id,
        null::uuid, derivation_source, now(), p_correlation_id, null::text,
        null::text, v_actor.authority_version;
      return;
    end if;

    return query select 'RESOLVED', null::text, tenant_id, v_actor.actor_id,
      null::uuid, derivation_source, now(), p_correlation_id, 'workload'::text,
      'active'::text, v_actor.authority_version;
    return;
  end if;

  select count(*) into v_active_count
  from public.pv_memberships m
  where m.actor_id = v_actor.actor_id
    and m.lifecycle_status = 'active'
    and m.revoked_at is null
    and (m.expires_at is null or m.expires_at > now());

  if v_active_count = 0 then
    select m.lifecycle_status into v_denial_status
    from public.pv_memberships m
    where m.actor_id = v_actor.actor_id
    order by case m.lifecycle_status
      when 'revoked' then 1
      when 'suspended' then 2
      when 'inactive' then 3
      else 4 end,
      m.updated_at desc
    limit 1;

    return query select 'DENY',
      case v_denial_status
        when 'revoked' then 'MEMBERSHIP_REVOKED'
        when 'suspended' then 'MEMBERSHIP_SUSPENDED'
        else 'MEMBERSHIP_INACTIVE'
      end,
      null::text, v_actor.actor_id, null::uuid, 'canonical_membership', now(),
      p_correlation_id, null::text, v_denial_status, v_actor.authority_version;
    return;
  end if;

  if v_active_count = 1 then
    select * into v_membership
    from public.pv_memberships m
    where m.actor_id = v_actor.actor_id
      and m.lifecycle_status = 'active'
      and m.revoked_at is null
      and (m.expires_at is null or m.expires_at > now());
    derivation_source := 'single_active_membership';
  elsif v_selected_claim is not null then
    select * into v_membership
    from public.pv_memberships m
    where m.actor_id = v_actor.actor_id
      and m.tenant_id = v_selected_claim
      and m.lifecycle_status = 'active'
      and m.revoked_at is null
      and (m.expires_at is null or m.expires_at > now());

    if not found then
      return query select 'DENY', 'TENANT_UNAUTHORIZED', null::text, v_actor.actor_id,
        null::uuid, 'verified_tenant_claim', now(), p_correlation_id, null::text,
        null::text, v_actor.authority_version;
      return;
    end if;
    derivation_source := 'verified_tenant_claim';
  else
    return query select 'DENY', 'TENANT_AMBIGUOUS', null::text, v_actor.actor_id,
      null::uuid, 'canonical_membership', now(), p_correlation_id, null::text,
      null::text, v_actor.authority_version;
    return;
  end if;

  if p_tenant_hint is not null and p_tenant_hint <> v_membership.tenant_id then
    return query select 'DENY', 'TENANT_OVERRIDE_DENIED', null::text, v_actor.actor_id,
      v_membership.id, derivation_source, now(), p_correlation_id,
      v_membership.authority_role, v_membership.lifecycle_status,
      greatest(v_actor.authority_version, v_membership.authority_version);
    return;
  end if;

  if not exists (
    select 1 from public.pv_tenants t
    where t.id = v_membership.tenant_id and t.status = 'active'
  ) then
    return query select 'DENY', 'TENANT_UNAUTHORIZED', null::text, v_actor.actor_id,
      v_membership.id, derivation_source, now(), p_correlation_id,
      v_membership.authority_role, v_membership.lifecycle_status,
      greatest(v_actor.authority_version, v_membership.authority_version);
    return;
  end if;

  return query select 'RESOLVED', null::text, v_membership.tenant_id, v_actor.actor_id,
    v_membership.id, derivation_source, now(), p_correlation_id,
    v_membership.authority_role, v_membership.lifecycle_status,
    greatest(v_actor.authority_version, v_membership.authority_version);
end;
$$;

-- Compatibility alias retained for the accepted A1 evidence specification.
create or replace function provenance_api.resolve_tenant_context(
  p_tenant_hint text default null,
  p_correlation_id uuid default gen_random_uuid()
)
returns table (
  outcome text,
  reason_code text,
  tenant_id text,
  actor_id uuid,
  membership_id uuid,
  derivation_source text,
  derived_at timestamptz,
  correlation_id uuid,
  role text,
  membership_status text,
  authority_version bigint
)
language sql
stable
security invoker
set search_path = pg_catalog, provenance_api
as $$
  select * from provenance_api.derive_tenant_context(p_tenant_hint, p_correlation_id);
$$;

create or replace function provenance_api.current_actor_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, provenance_api
as $$
  select r.actor_id
  from provenance_api.resolve_actor_identity(gen_random_uuid()) r
  where r.outcome = 'RESOLVED'
  limit 1;
$$;

create or replace function provenance_api.current_tenant_id()
returns text
language sql
stable
security definer
set search_path = pg_catalog, provenance_api
as $$
  select t.tenant_id
  from provenance_api.derive_tenant_context(null, gen_random_uuid()) t
  where t.outcome = 'RESOLVED'
  limit 1;
$$;

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
  select exists (
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

-- -----------------------------------------------------------------------------
-- Authorization decision + mandatory append-only audit
-- -----------------------------------------------------------------------------

create or replace function provenance_api.authorize_and_audit(
  p_action text,
  p_resource_type text,
  p_resource_id text,
  p_resource_tenant_id text,
  p_tenant_hint text default null,
  p_expected_authority_version bigint default null,
  p_correlation_id uuid default gen_random_uuid(),
  p_metadata_digest text default null
)
returns table (
  decision_id uuid,
  outcome text,
  reason_code text,
  actor_id uuid,
  tenant_id text,
  action text,
  resource_type text,
  resource_id text,
  policy_version text,
  authority_version bigint,
  decided_at timestamptz,
  correlation_id uuid
)
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, provenance_api, auth, extensions
as $$
declare
  v_context record;
  v_outcome text := 'DENY';
  v_reason text;
  v_decision_id uuid := gen_random_uuid();
  v_decided_at timestamptz := now();
  v_integrity_hash text;
  v_known_action boolean;
  v_has_permission boolean := false;
  v_actor_type text;
begin
  select * into v_context
  from provenance_api.derive_tenant_context(p_tenant_hint, p_correlation_id);

  if v_context.outcome <> 'RESOLVED' then
    v_reason := case v_context.reason_code
      when 'ACTOR_UNKNOWN' then 'DENY_ACTOR_UNKNOWN'
      when 'ACTOR_INACTIVE' then 'DENY_ACTOR_INACTIVE'
      when 'ACTOR_SUSPENDED' then 'DENY_ACTOR_SUSPENDED'
      when 'ACTOR_REVOKED' then 'DENY_ACTOR_REVOKED'
      when 'ACTOR_AMBIGUOUS' then 'DENY_ACTOR_AMBIGUOUS'
      when 'MEMBERSHIP_INACTIVE' then 'DENY_MEMBERSHIP_INACTIVE'
      when 'MEMBERSHIP_SUSPENDED' then 'DENY_MEMBERSHIP_SUSPENDED'
      when 'MEMBERSHIP_REVOKED' then 'DENY_MEMBERSHIP_REVOKED'
      when 'TENANT_AMBIGUOUS' then 'DENY_TENANT_UNAUTHORIZED'
      when 'TENANT_OVERRIDE_DENIED' then 'DENY_TENANT_UNAUTHORIZED'
      when 'TENANT_UNAUTHORIZED' then 'DENY_TENANT_UNAUTHORIZED'
      else 'DENY_AUTHORITY_UNAVAILABLE'
    end;
  elsif p_resource_tenant_id is null or p_resource_tenant_id <> v_context.tenant_id then
    v_reason := 'DENY_RESOURCE_TENANT_MISMATCH';
  elsif p_expected_authority_version is not null
    and p_expected_authority_version <> v_context.authority_version then
    v_reason := 'DENY_AUTHORITY_VERSION_CONFLICT';
  else
    select exists (
      select 1 from public.pv_role_permissions rp
      where rp.resource_type = p_resource_type
        and rp.action = p_action
        and rp.active
    ) into v_known_action;

    if not v_known_action then
      v_reason := 'DENY_ACTION';
    else
      v_has_permission := provenance_api.has_permission(
        v_context.tenant_id,
        p_resource_type,
        p_action,
        p_resource_id
      );
      if v_has_permission then
        v_outcome := 'ALLOW';
        v_reason := null;
      else
        v_reason := 'DENY_ROLE';
      end if;
    end if;
  end if;

  if v_context.actor_id is not null then
    select a.actor_type into v_actor_type
    from public.pv_actors a
    where a.id = v_context.actor_id;
  end if;

  v_integrity_hash := 'sha256:' || encode(extensions.digest(convert_to(
    concat_ws('|',
      v_decision_id::text,
      coalesce(v_context.actor_id::text,''),
      coalesce(v_context.tenant_id,''),
      coalesce(p_resource_type,''),
      coalesce(p_resource_id,''),
      coalesce(p_action,''),
      v_outcome,
      coalesce(v_reason,''),
      coalesce(v_context.authority_version::text,''),
      p_correlation_id::text,
      v_decided_at::text
    ), 'UTF8'), 'sha256'), 'hex');

  insert into public.pv_authorization_audit_events(
    event_id, event_type, occurred_at, recorded_at,
    actor_id, actor_type, tenant_id, membership_id,
    resource_type, resource_id, action, outcome, reason_code,
    authority_version, request_id, correlation_id, metadata_digest,
    schema_version, integrity_hash
  ) values (
    v_decision_id, 'AUTHORIZATION_DECISION', v_decided_at, now(),
    v_context.actor_id, v_actor_type, v_context.tenant_id, v_context.membership_id,
    coalesce(p_resource_type,'unknown'), coalesce(p_resource_id,'unknown'),
    coalesce(p_action,'unknown'), v_outcome, v_reason,
    v_context.authority_version, p_correlation_id::text, p_correlation_id, p_metadata_digest,
    'v1-wave1', v_integrity_hash
  );

  return query select v_decision_id, v_outcome, v_reason,
    v_context.actor_id, v_context.tenant_id, p_action, p_resource_type,
    p_resource_id, 'v1-wave1', v_context.authority_version,
    v_decided_at, p_correlation_id;
exception when others then
  -- Mandatory audit failure or authority-evaluation failure aborts the operation.
  raise;
end;
$$;

-- -----------------------------------------------------------------------------
-- Durable idempotency RPCs
-- -----------------------------------------------------------------------------

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
  on conflict (tenant_id, idempotency_key) do nothing;

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

create or replace function provenance_api.complete_idempotency_key(
  p_key text,
  p_operation text,
  p_request_digest text,
  p_result_reference text,
  p_tenant_hint text default null,
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
  completed_at timestamptz,
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
  v_replay boolean := false;
begin
  select * into v_context
  from provenance_api.derive_tenant_context(p_tenant_hint, p_correlation_id);

  if v_context.outcome <> 'RESOLVED' then
    return query select 'DENIED', false, coalesce(v_context.reason_code,'AUTHORITY_UNAVAILABLE'),
      p_key, v_context.actor_id, v_context.tenant_id, p_operation,
      p_request_digest, p_result_reference, null::timestamptz, p_correlation_id;
    return;
  end if;

  select * into v_row
  from public.pv_idempotency_keys i
  where i.tenant_id = v_context.tenant_id
    and i.idempotency_key = p_key
  for update;

  if not found then
    return query select 'DENIED', false, 'PV_IDEMPOTENCY_KEY_UNKNOWN',
      p_key, v_context.actor_id, v_context.tenant_id, p_operation,
      p_request_digest, p_result_reference, null::timestamptz, p_correlation_id;
    return;
  end if;

  if v_row.actor_id <> v_context.actor_id
    or v_row.operation <> p_operation
    or v_row.request_digest <> p_request_digest then
    return query select 'DENIED', false, 'PV_IDEMPOTENCY_FINGERPRINT_CONFLICT',
      p_key, v_context.actor_id, v_context.tenant_id, p_operation,
      p_request_digest, p_result_reference, v_row.completed_at, p_correlation_id;
    return;
  end if;

  if v_row.status = 'COMPLETED' then
    if v_row.result_reference is distinct from p_result_reference then
      return query select 'DENIED', true, 'PV_IDEMPOTENCY_RESULT_CONFLICT',
        p_key, v_context.actor_id, v_context.tenant_id, p_operation,
        p_request_digest, v_row.result_reference, v_row.completed_at,
        p_correlation_id;
      return;
    end if;
    v_replay := true;
  else
    update public.pv_idempotency_keys i
    set status = 'COMPLETED',
        result_reference = p_result_reference,
        completed_at = now()
    where i.tenant_id = v_context.tenant_id
      and i.idempotency_key = p_key
    returning * into v_row;
  end if;

  return query select v_row.status, v_replay, null::text,
    v_row.idempotency_key, v_row.actor_id, v_row.tenant_id,
    v_row.operation, v_row.request_digest, v_row.result_reference,
    v_row.completed_at, p_correlation_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Controlled membership authority mutation
-- -----------------------------------------------------------------------------

create or replace function provenance_api.set_membership_authority(
  p_membership_id uuid,
  p_target_role text,
  p_target_status text,
  p_expected_authority_version bigint,
  p_correlation_id uuid default gen_random_uuid()
)
returns table (
  outcome text,
  reason_code text,
  membership_id uuid,
  tenant_id text,
  role text,
  membership_status text,
  authority_version bigint,
  correlation_id uuid
)
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, provenance_api, extensions
as $$
declare
  v_target public.pv_memberships%rowtype;
  v_decision record;
  v_old_role text;
  v_old_status text;
  v_event_type text;
  v_event_id uuid;
  v_integrity_hash text;
begin
  if p_target_role not in ('organization_owner','organization_admin','operator','reviewer','member')
     or p_target_status not in ('active','inactive','suspended','revoked') then
    return query select 'DENY', 'DENY_ACTION', p_membership_id, null::text,
      p_target_role, p_target_status, null::bigint, p_correlation_id;
    return;
  end if;

  select * into v_target
  from public.pv_memberships m
  where m.id = p_membership_id
  for update;

  if not found then
    return query select 'DENY', 'DENY_AUTHORITY_UNAVAILABLE', p_membership_id,
      null::text, p_target_role, p_target_status, null::bigint, p_correlation_id;
    return;
  end if;

  select * into v_decision
  from provenance_api.authorize_and_audit(
    'manage', 'membership', p_membership_id::text, v_target.tenant_id,
    v_target.tenant_id, null, p_correlation_id, null
  );

  if v_decision.outcome <> 'ALLOW' then
    return query select 'DENY', v_decision.reason_code, p_membership_id,
      v_target.tenant_id, v_target.authority_role, v_target.lifecycle_status,
      v_target.authority_version, p_correlation_id;
    return;
  end if;

  if v_target.authority_version <> p_expected_authority_version then
    return query select 'DENY', 'DENY_AUTHORITY_VERSION_CONFLICT', p_membership_id,
      v_target.tenant_id, v_target.authority_role, v_target.lifecycle_status,
      v_target.authority_version, p_correlation_id;
    return;
  end if;

  v_old_role := v_target.authority_role;
  v_old_status := v_target.lifecycle_status;

  update public.pv_memberships m
  set authority_role = p_target_role,
      lifecycle_status = p_target_status,
      status = case when p_target_status = 'active' then 'active' else 'suspended' end,
      revoked_at = case when p_target_status = 'revoked' then now() else null end,
      authority_version = m.authority_version + 1,
      updated_at = now()
  where m.id = p_membership_id
  returning * into v_target;

  v_event_type := case
    when v_old_role is distinct from p_target_role then 'MEMBERSHIP_ROLE_CHANGED'
    when v_old_status is distinct from p_target_status then 'MEMBERSHIP_STATUS_CHANGED'
    else 'MEMBERSHIP_AUTHORITY_REFRESHED'
  end;

  v_event_id := gen_random_uuid();
  v_integrity_hash := 'sha256:' || encode(extensions.digest(convert_to(
    concat_ws('|', v_event_id::text, v_target.actor_id::text,
      v_target.tenant_id, p_membership_id::text, v_event_type,
      v_target.authority_version::text, p_correlation_id::text),
    'UTF8'), 'sha256'), 'hex');

  insert into public.pv_authorization_audit_events(
    event_id, event_type, actor_id, tenant_id, membership_id,
    resource_type, resource_id, action, outcome, reason_code,
    authority_version, request_id, correlation_id, metadata_digest,
    schema_version, integrity_hash
  ) values (
    v_event_id, v_event_type, v_decision.actor_id, v_target.tenant_id,
    v_target.id, 'membership', v_target.id::text, 'manage', 'ALLOW', null,
    v_target.authority_version, p_correlation_id::text, p_correlation_id,
    'sha256:' || encode(extensions.digest(convert_to(
      jsonb_build_object(
        'oldRole', v_old_role,
        'newRole', p_target_role,
        'oldStatus', v_old_status,
        'newStatus', p_target_status
      )::text, 'UTF8'), 'sha256'), 'hex'),
    'v1-wave1', v_integrity_hash
  );

  return query select 'ALLOW', null::text, v_target.id, v_target.tenant_id,
    v_target.authority_role, v_target.lifecycle_status,
    v_target.authority_version, p_correlation_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Row-level security: canonical authority state and Slice 1 read boundary
-- -----------------------------------------------------------------------------

alter table public.pv_actors enable row level security;
alter table public.pv_actors force row level security;
alter table public.pv_role_registry enable row level security;
alter table public.pv_role_registry force row level security;
alter table public.pv_role_permissions enable row level security;
alter table public.pv_role_permissions force row level security;
alter table public.pv_purchaser_relationships enable row level security;
alter table public.pv_purchaser_relationships force row level security;
alter table public.pv_authorization_audit_events enable row level security;
alter table public.pv_authorization_audit_events force row level security;
alter table public.pv_idempotency_keys enable row level security;
alter table public.pv_idempotency_keys force row level security;
alter table public.pv_tenants enable row level security;
alter table public.pv_tenants force row level security;
alter table public.pv_memberships enable row level security;
alter table public.pv_memberships force row level security;
alter table public.pv_assets enable row level security;
alter table public.pv_assets force row level security;

-- Remove frozen policies that trusted a client-set GUC or legacy role model.
drop policy if exists tenant_scope_assets on public.pv_assets;
drop policy if exists pv_tenant_directory_select on public.pv_tenants;
drop policy if exists pv_membership_self_select on public.pv_memberships;

-- Internal authority tables are accessible only through controlled functions.
drop policy if exists pv_actors_select_deny on public.pv_actors;
create policy pv_actors_select_deny on public.pv_actors for select to authenticated using (false);
drop policy if exists pv_actors_insert_deny on public.pv_actors;
create policy pv_actors_insert_deny on public.pv_actors for insert to authenticated with check (false);
drop policy if exists pv_actors_update_deny on public.pv_actors;
create policy pv_actors_update_deny on public.pv_actors for update to authenticated using (false) with check (false);
drop policy if exists pv_actors_delete_deny on public.pv_actors;
create policy pv_actors_delete_deny on public.pv_actors for delete to authenticated using (false);

drop policy if exists pv_role_registry_select_deny on public.pv_role_registry;
create policy pv_role_registry_select_deny on public.pv_role_registry for select to authenticated using (false);
drop policy if exists pv_role_registry_insert_deny on public.pv_role_registry;
create policy pv_role_registry_insert_deny on public.pv_role_registry for insert to authenticated with check (false);
drop policy if exists pv_role_registry_update_deny on public.pv_role_registry;
create policy pv_role_registry_update_deny on public.pv_role_registry for update to authenticated using (false) with check (false);
drop policy if exists pv_role_registry_delete_deny on public.pv_role_registry;
create policy pv_role_registry_delete_deny on public.pv_role_registry for delete to authenticated using (false);

drop policy if exists pv_role_permissions_select_deny on public.pv_role_permissions;
create policy pv_role_permissions_select_deny on public.pv_role_permissions for select to authenticated using (false);
drop policy if exists pv_role_permissions_insert_deny on public.pv_role_permissions;
create policy pv_role_permissions_insert_deny on public.pv_role_permissions for insert to authenticated with check (false);
drop policy if exists pv_role_permissions_update_deny on public.pv_role_permissions;
create policy pv_role_permissions_update_deny on public.pv_role_permissions for update to authenticated using (false) with check (false);
drop policy if exists pv_role_permissions_delete_deny on public.pv_role_permissions;
create policy pv_role_permissions_delete_deny on public.pv_role_permissions for delete to authenticated using (false);

drop policy if exists pv_authorization_audit_select_deny on public.pv_authorization_audit_events;
create policy pv_authorization_audit_select_deny on public.pv_authorization_audit_events for select to authenticated using (false);
drop policy if exists pv_authorization_audit_insert_deny on public.pv_authorization_audit_events;
create policy pv_authorization_audit_insert_deny on public.pv_authorization_audit_events for insert to authenticated with check (false);
drop policy if exists pv_authorization_audit_update_deny on public.pv_authorization_audit_events;
create policy pv_authorization_audit_update_deny on public.pv_authorization_audit_events for update to authenticated using (false) with check (false);
drop policy if exists pv_authorization_audit_delete_deny on public.pv_authorization_audit_events;
create policy pv_authorization_audit_delete_deny on public.pv_authorization_audit_events for delete to authenticated using (false);

drop policy if exists pv_idempotency_select_deny on public.pv_idempotency_keys;
create policy pv_idempotency_select_deny on public.pv_idempotency_keys for select to authenticated using (false);
drop policy if exists pv_idempotency_insert_deny on public.pv_idempotency_keys;
create policy pv_idempotency_insert_deny on public.pv_idempotency_keys for insert to authenticated with check (false);
drop policy if exists pv_idempotency_update_deny on public.pv_idempotency_keys;
create policy pv_idempotency_update_deny on public.pv_idempotency_keys for update to authenticated using (false) with check (false);
drop policy if exists pv_idempotency_delete_deny on public.pv_idempotency_keys;
create policy pv_idempotency_delete_deny on public.pv_idempotency_keys for delete to authenticated using (false);

-- Purchaser relationship is visible only to the same actor in the selected tenant.
drop policy if exists pv_purchaser_relationships_select on public.pv_purchaser_relationships;
create policy pv_purchaser_relationships_select on public.pv_purchaser_relationships
for select to authenticated
using (
  actor_id = provenance_api.current_actor_id()
  and tenant_id = provenance_api.current_tenant_id()
  and non_authorizing
);
drop policy if exists pv_purchaser_relationships_insert_deny on public.pv_purchaser_relationships;
create policy pv_purchaser_relationships_insert_deny on public.pv_purchaser_relationships for insert to authenticated with check (false);
drop policy if exists pv_purchaser_relationships_update_deny on public.pv_purchaser_relationships;
create policy pv_purchaser_relationships_update_deny on public.pv_purchaser_relationships for update to authenticated using (false) with check (false);
drop policy if exists pv_purchaser_relationships_delete_deny on public.pv_purchaser_relationships;
create policy pv_purchaser_relationships_delete_deny on public.pv_purchaser_relationships for delete to authenticated using (false);

-- Slice 1 protected resources: explicit read and explicit deny mutation policies.
drop policy if exists pv_tenants_wave1_select on public.pv_tenants;
create policy pv_tenants_wave1_select on public.pv_tenants
for select to authenticated
using (provenance_api.has_permission(id, 'tenant_resource', 'read', id));
drop policy if exists pv_tenants_wave1_insert_deny on public.pv_tenants;
create policy pv_tenants_wave1_insert_deny on public.pv_tenants for insert to authenticated with check (false);
drop policy if exists pv_tenants_wave1_update_deny on public.pv_tenants;
create policy pv_tenants_wave1_update_deny on public.pv_tenants for update to authenticated using (false) with check (false);
drop policy if exists pv_tenants_wave1_delete_deny on public.pv_tenants;
create policy pv_tenants_wave1_delete_deny on public.pv_tenants for delete to authenticated using (false);

drop policy if exists pv_memberships_wave1_select on public.pv_memberships;
create policy pv_memberships_wave1_select on public.pv_memberships
for select to authenticated
using (
  actor_id = provenance_api.current_actor_id()
  or provenance_api.has_permission(tenant_id, 'membership', 'read', id::text)
);
drop policy if exists pv_memberships_wave1_insert_deny on public.pv_memberships;
create policy pv_memberships_wave1_insert_deny on public.pv_memberships for insert to authenticated with check (false);
drop policy if exists pv_memberships_wave1_update_deny on public.pv_memberships;
create policy pv_memberships_wave1_update_deny on public.pv_memberships for update to authenticated using (false) with check (false);
drop policy if exists pv_memberships_wave1_delete_deny on public.pv_memberships;
create policy pv_memberships_wave1_delete_deny on public.pv_memberships for delete to authenticated using (false);

drop policy if exists pv_assets_wave1_select on public.pv_assets;
create policy pv_assets_wave1_select on public.pv_assets
for select to authenticated
using (provenance_api.has_permission(tenant_id, 'asset', 'read', id));
drop policy if exists pv_assets_wave1_insert_deny on public.pv_assets;
create policy pv_assets_wave1_insert_deny on public.pv_assets for insert to authenticated with check (false);
drop policy if exists pv_assets_wave1_update_deny on public.pv_assets;
create policy pv_assets_wave1_update_deny on public.pv_assets for update to authenticated using (false) with check (false);
drop policy if exists pv_assets_wave1_delete_deny on public.pv_assets;
create policy pv_assets_wave1_delete_deny on public.pv_assets for delete to authenticated using (false);

-- -----------------------------------------------------------------------------
-- Least privilege and exact RPC exposure
-- -----------------------------------------------------------------------------

revoke all on public.pv_actors, public.pv_role_registry, public.pv_role_permissions,
  public.pv_purchaser_relationships, public.pv_authorization_audit_events,
  public.pv_idempotency_keys from public, anon, authenticated, service_role;

revoke insert, update, delete on public.pv_tenants, public.pv_memberships, public.pv_assets
  from anon, authenticated, service_role;

grant select on public.pv_tenants, public.pv_memberships, public.pv_assets,
  public.pv_purchaser_relationships to authenticated;

revoke all on function provenance_api.resolve_actor_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.derive_tenant_context(text,uuid)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.resolve_tenant_context(text,uuid)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.current_actor_id()
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.current_tenant_id()
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.has_permission(text,text,text,text)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.authorize_and_audit(text,text,text,text,text,bigint,uuid,text)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.claim_idempotency_key(text,text,text,text,timestamptz,uuid)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.complete_idempotency_key(text,text,text,text,text,uuid)
  from public, anon, authenticated, service_role;
revoke all on function provenance_api.set_membership_authority(uuid,text,text,bigint,uuid)
  from public, anon, authenticated, service_role;

-- Only a verified authenticated JWT may invoke the Slice 1 RPC boundary.
grant usage on schema provenance_api to authenticated;
grant execute on function provenance_api.resolve_actor_identity(uuid) to authenticated;
grant execute on function provenance_api.derive_tenant_context(text,uuid) to authenticated;
grant execute on function provenance_api.resolve_tenant_context(text,uuid) to authenticated;
grant execute on function provenance_api.current_actor_id() to authenticated;
grant execute on function provenance_api.current_tenant_id() to authenticated;
grant execute on function provenance_api.has_permission(text,text,text,text) to authenticated;
grant execute on function provenance_api.authorize_and_audit(text,text,text,text,text,bigint,uuid,text) to authenticated;
grant execute on function provenance_api.claim_idempotency_key(text,text,text,text,timestamptz,uuid) to authenticated;
grant execute on function provenance_api.complete_idempotency_key(text,text,text,text,text,uuid) to authenticated;
grant execute on function provenance_api.set_membership_authority(uuid,text,text,bigint,uuid) to authenticated;

comment on function provenance_api.resolve_actor_identity(uuid) is 'W1-C01 v1-wave1 canonical actor resolution. Client actor values are not accepted.';
comment on function provenance_api.derive_tenant_context(text,uuid) is 'W1-C02 v1-wave1 canonical tenant derivation. Tenant hint is mismatch detection only.';
comment on function provenance_api.authorize_and_audit(text,text,text,text,text,bigint,uuid,text) is 'W1-C04/W1-C06 v1-wave1 deny-by-default authorization with mandatory append-only audit.';
comment on function provenance_api.claim_idempotency_key(text,text,text,text,timestamptz,uuid) is 'W1-C07 v1-wave1 durable idempotency claim.';
comment on function provenance_api.complete_idempotency_key(text,text,text,text,text,uuid) is 'W1-C07 v1-wave1 durable idempotency completion.';

commit;
