-- PROVENANCE.CX Wave 1 Slice 1 ordered bootstrap
-- Repairs the frozen migration-chain dependency only. This function intentionally
-- returns NULL until migration 012 installs canonical actor/membership derivation.

begin;

create schema if not exists provenance_api;

create or replace function provenance_api.current_tenant_id()
returns text
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select null::text;
$$;

comment on function provenance_api.current_tenant_id() is
  'Wave 1 003.5 fail-closed bootstrap. Returns NULL until migration 012 replaces it with canonical tenant derivation.';

revoke all on function provenance_api.current_tenant_id() from public, anon, authenticated, service_role;
grant execute on function provenance_api.current_tenant_id() to authenticated;

commit;
