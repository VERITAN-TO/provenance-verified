-- PROVENANCE.CX R8.1 R3 isolated developer sandbox lifecycle.
alter table public.pv_sandbox_tenants
  add column if not exists environment text not null default 'sandbox' check (environment='sandbox'),
  add column if not exists namespace text,
  add column if not exists seed_profile text not null default 'claim-review-lifecycle-v1',
  add column if not exists seed_digest text check (seed_digest is null or seed_digest ~ '^sha256:[0-9a-f]{64}$'),
  add column if not exists reset_count integer not null default 0,
  add column if not exists expires_at timestamptz,
  add column if not exists deletion_receipt jsonb;

create unique index if not exists pv_sandbox_namespace_unique on public.pv_sandbox_tenants(namespace) where namespace is not null;

create or replace function provenance_api.pv_r3_create_sandbox(
  p_owner_identity text,p_limits jsonb,p_seed_profile text,p_seed_digest text,p_expires_at timestamptz
) returns public.pv_sandbox_tenants
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare s public.pv_sandbox_tenants; begin
  if p_owner_identity is null or length(trim(p_owner_identity))<3 then raise exception 'PV_SANDBOX_OWNER_REQUIRED'; end if;
  if p_seed_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_SANDBOX_SEED_DIGEST_INVALID'; end if;
  if p_expires_at<=now() or p_expires_at>now()+interval '30 days' then raise exception 'PV_SANDBOX_EXPIRY_INVALID'; end if;
  insert into public.pv_sandbox_tenants(owner_identity,status,limits,environment,namespace,seed_profile,seed_digest,seeded_at,expires_at)
  values(p_owner_identity,'active',p_limits,'sandbox','sbx-'||replace(gen_random_uuid()::text,'-',''),p_seed_profile,p_seed_digest,now(),p_expires_at)
  returning * into s;
  return s;
end $$;

create or replace function provenance_api.pv_r3_reset_sandbox(p_id uuid,p_owner_identity text,p_seed_digest text)
returns public.pv_sandbox_tenants language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare s public.pv_sandbox_tenants; begin
  select * into s from public.pv_sandbox_tenants where id=p_id for update;
  if not found then raise exception 'PV_SANDBOX_NOT_FOUND'; end if;
  if s.owner_identity<>p_owner_identity then raise exception 'PV_SANDBOX_OWNER_DENIED'; end if;
  if s.status='deleted' then raise exception 'PV_SANDBOX_DELETED'; end if;
  if p_seed_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_SANDBOX_SEED_DIGEST_INVALID'; end if;
  update public.pv_sandbox_tenants set status='active',seed_digest=p_seed_digest,seeded_at=now(),reset_at=now(),reset_count=reset_count+1
  where id=p_id returning * into s;
  return s;
end $$;

create or replace function provenance_api.pv_r3_delete_sandbox(p_id uuid,p_owner_identity text,p_receipt jsonb)
returns public.pv_sandbox_tenants language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare s public.pv_sandbox_tenants; begin
  select * into s from public.pv_sandbox_tenants where id=p_id for update;
  if not found then raise exception 'PV_SANDBOX_NOT_FOUND'; end if;
  if s.owner_identity<>p_owner_identity then raise exception 'PV_SANDBOX_OWNER_DENIED'; end if;
  if p_receipt is null or not (p_receipt ? 'receiptId') then raise exception 'PV_SANDBOX_DELETION_RECEIPT_REQUIRED'; end if;
  update public.pv_sandbox_tenants set status='deleted',deleted_at=now(),deletion_receipt=p_receipt where id=p_id returning * into s;
  return s;
end $$;

revoke all on function provenance_api.pv_r3_create_sandbox(text,jsonb,text,text,timestamptz) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_reset_sandbox(uuid,text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_delete_sandbox(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_create_sandbox(text,jsonb,text,text,timestamptz) to service_role;
grant execute on function provenance_api.pv_r3_reset_sandbox(uuid,text,text) to service_role;
grant execute on function provenance_api.pv_r3_delete_sandbox(uuid,text,jsonb) to service_role;
