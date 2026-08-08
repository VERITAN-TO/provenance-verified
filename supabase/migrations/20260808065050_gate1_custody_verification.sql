-- Gate 1: Migration Custody Verification
-- Applied via Supabase Management API (MCP apply_migration tool = supported tooling)
-- Verifies all 15 canonical source migration versions are present in ledger.
-- FAILS with exception if any are missing — cannot produce fake-pass.
-- This migration, once applied, is an auditable record that supported tooling
-- verified the migration ledger state on 2026-08-08.

begin;

do $$
declare
  v_missing int;
  v_present int;
begin
  -- Count how many of the 15 canonical source versions are MISSING from ledger
  select count(*) into v_missing
  from (values
    ('20260721000000'), ('20260722000000'), ('20260722030000'),
    ('20260722035000'), ('20260722040000'), ('20260722050000'),
    ('20260722060000'), ('20260722070000'), ('20260722080000'),
    ('20260722090000'), ('20260722100000'), ('20260722110000'),
    ('20260725050000'), ('20260807235900'), ('20260808035036')
  ) as sv(v)
  left join supabase_migrations.schema_migrations sm on sm.version = sv.v
  where sm.version is null;

  -- Abort with clear error if any source version is missing
  if v_missing > 0 then
    raise exception
      'GATE1 CUSTODY FAILURE: % of 15 canonical source migrations are missing from remote ledger. '
      'Run supabase migration repair --status applied for each missing version.',
      v_missing
    using errcode = 'P0001';
  end if;

  -- Count total present (must equal 15)
  select count(*) into v_present
  from (values
    ('20260721000000'), ('20260722000000'), ('20260722030000'),
    ('20260722035000'), ('20260722040000'), ('20260722050000'),
    ('20260722060000'), ('20260722070000'), ('20260722080000'),
    ('20260722090000'), ('20260722100000'), ('20260722110000'),
    ('20260725050000'), ('20260807235900'), ('20260808035036')
  ) as sv(v)
  join supabase_migrations.schema_migrations sm on sm.version = sv.v;

  if v_present != 15 then
    raise exception
      'GATE1 CUSTODY ASSERTION: expected 15 present, found %', v_present
    using errcode = 'P0001';
  end if;

  raise notice 'GATE1 CUSTODY VERIFIED: % / 15 canonical source migrations present in remote ledger.',
    v_present;
end;
$$;

commit;
