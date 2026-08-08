-- PROVENANCE.CX Wave 1 Slice 1 source-level database tests.
-- Runtime execution is owned by A6. This file is written and statically verified only.

begin;

-- Deterministic fixtures.
insert into public.pv_tenants(id, legal_name, display_name, status)
values
  ('w1-tenant-a','Wave 1 Tenant A LLC','Wave 1 Tenant A','active'),
  ('w1-tenant-b','Wave 1 Tenant B LLC','Wave 1 Tenant B','active')
on conflict (id) do nothing;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000001','authenticated','authenticated','owner-a@example.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000002','authenticated','authenticated','member-a@example.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000003','authenticated','authenticated','purchaser@example.invalid','',now(),'{}','{}',now(),now())
on conflict (id) do nothing;

insert into public.pv_actors(id,actor_type,auth_subject_id,status,authority_version)
values
  ('20000000-0000-0000-0000-000000000001','user','10000000-0000-0000-0000-000000000001','active',1),
  ('20000000-0000-0000-0000-000000000002','user','10000000-0000-0000-0000-000000000002','active',1),
  ('20000000-0000-0000-0000-000000000003','user','10000000-0000-0000-0000-000000000003','active',1)
on conflict (id) do nothing;

insert into public.pv_memberships(
  id,tenant_id,user_id,display_name,role,status,location_ids,conflict_domains,
  actor_id,authority_role,lifecycle_status,granted_at,authority_version,resource_scope
) values
  ('30000000-0000-0000-0000-000000000001','w1-tenant-a','10000000-0000-0000-0000-000000000001','Owner A','owner','active','{}','{}','20000000-0000-0000-0000-000000000001','organization_owner','active',now(),1,'{}'),
  ('30000000-0000-0000-0000-000000000002','w1-tenant-a','10000000-0000-0000-0000-000000000002','Member A','auditor','active','{}','{}','20000000-0000-0000-0000-000000000002','member','active',now(),1,'{}')
on conflict (tenant_id,user_id) do nothing;

insert into public.pv_locations(id,tenant_id,code,name,timezone,address,active)
values
  ('w1-location-a','w1-tenant-a','A','Location A','UTC','Test A',true),
  ('w1-location-b','w1-tenant-b','B','Location B','UTC','Test B',true)
on conflict (id) do nothing;

insert into public.pv_intake_batches(
  id,tenant_id,location_id,name,reference,status,created_by,created_at,updated_at
) values
  ('w1-batch-a','w1-tenant-a','w1-location-a','Batch A','W1-A','draft','test',now(),now()),
  ('w1-batch-b','w1-tenant-b','w1-location-b','Batch B','W1-B','draft','test',now(),now())
on conflict (id) do nothing;

insert into public.pv_assets(
  id,tenant_id,location_id,batch_id,serial,status,material,shape,
  treatment_disclosure,origin_claim,measurements,created_by,created_at,updated_at
) values
  ('w1-asset-a','w1-tenant-a','w1-location-a','w1-batch-a','W1-ASSET-A','active','stone','round','none','test','{}','test',now(),now()),
  ('w1-asset-b','w1-tenant-b','w1-location-b','w1-batch-b','W1-ASSET-B','active','stone','round','none','test','{}','test',now(),now())
on conflict (id) do nothing;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub','10000000-0000-0000-0000-000000000001',
    'role','authenticated',
    'aal','aal2',
    'session_id','w1-session-owner',
    'iat',extract(epoch from now())::bigint,
    'app_metadata',jsonb_build_object('selected_tenant_id','w1-tenant-a')
  )::text,
  true
);

-- TEST-ID: S1-AT-001 VALID ACTOR RESOLUTION
do $$
declare r record;
begin
  select * into r from provenance_api.resolve_actor_identity('40000000-0000-0000-0000-000000000001');
  if r.outcome <> 'RESOLVED' or r.actor_id <> '20000000-0000-0000-0000-000000000001'::uuid then
    raise exception 'S1-AT-001 failed';
  end if;
end $$;

-- TEST-ID: S1-AT-002 VALID TENANT DERIVATION
do $$
declare r record;
begin
  select * into r from provenance_api.derive_tenant_context(null,'40000000-0000-0000-0000-000000000002');
  if r.outcome <> 'RESOLVED' or r.tenant_id <> 'w1-tenant-a' or r.role <> 'organization_owner' then
    raise exception 'S1-AT-002 failed';
  end if;
end $$;

-- TEST-ID: S1-AT-003 VALID ROLE AUTHORIZATION
do $$
declare r record;
begin
  select * into r from provenance_api.authorize_and_audit(
    'read','asset','w1-asset-a','w1-tenant-a',null,null,
    '40000000-0000-0000-0000-000000000003',null
  );
  if r.outcome <> 'ALLOW' then raise exception 'S1-AT-003 failed'; end if;
end $$;

-- TEST-ID: S1-AT-004 AUDIT APPEND
do $$
begin
  if not exists (
    select 1 from public.pv_authorization_audit_events
    where correlation_id='40000000-0000-0000-0000-000000000003'::uuid
      and event_type='AUTHORIZATION_DECISION' and outcome='ALLOW'
  ) then raise exception 'S1-AT-004 failed'; end if;
end $$;

-- TEST-ID: S1-AT-005 VALID IDEMPOTENT REPLAY
do $$
declare a record; b record;
begin
  select * into a from provenance_api.claim_idempotency_key(
    'w1-idem-1','asset.read','sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    null,now()+interval '1 hour','40000000-0000-0000-0000-000000000005'
  );
  select * into b from provenance_api.claim_idempotency_key(
    'w1-idem-1','asset.read','sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    null,now()+interval '1 hour','40000000-0000-0000-0000-000000000006'
  );
  if a.replay or not b.replay then raise exception 'S1-AT-005 failed'; end if;
end $$;

-- TEST-ID: S1-AT-006 PURCHASER/MEMBER SEPARATION
insert into public.pv_purchaser_relationships(
  tenant_id,actor_id,subject_type,subject_id,status,non_authorizing
) values ('w1-tenant-a','20000000-0000-0000-0000-000000000003','asset','w1-asset-a','active',true)
on conflict do nothing;

do $$
begin
  if exists (
    select 1 from public.pv_memberships
    where actor_id='20000000-0000-0000-0000-000000000003'::uuid
  ) then raise exception 'S1-AT-006 failed'; end if;
end $$;

-- TEST-ID: S1-AT-007 MIGRATION TARGETS
do $$
begin
  if to_regclass('public.pv_actors') is null
     or to_regclass('public.pv_authorization_audit_events') is null
     or to_regprocedure('provenance_api.authorize_and_audit(text,text,text,text,text,bigint,uuid,text)') is null then
    raise exception 'S1-AT-007 failed';
  end if;
end $$;

-- TEST-ID: S1-AT-008 CONTROLLED MEMBERSHIP LIFECYCLE
do $$
declare r record;
begin
  select * into r from provenance_api.set_membership_authority(
    '30000000-0000-0000-0000-000000000002','reviewer','active',1,
    '40000000-0000-0000-0000-000000000008'
  );
  if r.outcome <> 'ALLOW' or r.role <> 'reviewer' or r.authority_version <> 2 then
    raise exception 'S1-AT-008 failed';
  end if;
end $$;

-- TEST-ID: S1-NT-001 UNKNOWN ACTOR DENIAL
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-0000-0000-000000000099','role','authenticated','aal','aal2',
  'session_id','w1-session-unknown','iat',extract(epoch from now())::bigint,'app_metadata','{}'::jsonb
)::text,true);
do $$ declare r record; begin
  select * into r from provenance_api.resolve_actor_identity('50000000-0000-0000-0000-000000000001');
  if r.reason_code <> 'ACTOR_UNKNOWN' then raise exception 'S1-NT-001 failed'; end if;
end $$;

-- Restore member claims for membership-state negative tests.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-0000-0000-000000000002','role','authenticated','aal','aal2',
  'session_id','w1-session-member','iat',extract(epoch from now())::bigint,
  'app_metadata',jsonb_build_object('selected_tenant_id','w1-tenant-a')
)::text,true);

-- TEST-ID: S1-NT-002 INACTIVE MEMBERSHIP DENIAL
update public.pv_memberships set lifecycle_status='inactive',status='suspended' where id='30000000-0000-0000-0000-000000000002';
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context(null,'50000000-0000-0000-0000-000000000002');
  if r.reason_code <> 'MEMBERSHIP_INACTIVE' then raise exception 'S1-NT-002 failed'; end if;
end $$;

-- TEST-ID: S1-NT-003 SUSPENDED MEMBERSHIP DENIAL
update public.pv_memberships set lifecycle_status='suspended',status='suspended' where id='30000000-0000-0000-0000-000000000002';
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context(null,'50000000-0000-0000-0000-000000000003');
  if r.reason_code <> 'MEMBERSHIP_SUSPENDED' then raise exception 'S1-NT-003 failed'; end if;
end $$;

-- TEST-ID: S1-NT-004 REVOKED MEMBERSHIP DENIAL
update public.pv_memberships set lifecycle_status='revoked',status='suspended',revoked_at=now() where id='30000000-0000-0000-0000-000000000002';
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context(null,'50000000-0000-0000-0000-000000000004');
  if r.reason_code <> 'MEMBERSHIP_REVOKED' then raise exception 'S1-NT-004 failed'; end if;
end $$;

-- Restore owner claims and create a second active membership.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-0000-0000-000000000001','role','authenticated','aal','aal2',
  'session_id','w1-session-owner','iat',extract(epoch from now())::bigint,'app_metadata','{}'::jsonb
)::text,true);
insert into public.pv_memberships(
  id,tenant_id,user_id,display_name,role,status,location_ids,conflict_domains,
  actor_id,authority_role,lifecycle_status,granted_at,authority_version,resource_scope
) values (
  '30000000-0000-0000-0000-000000000003','w1-tenant-b','10000000-0000-0000-0000-000000000001','Owner B','owner','active','{}','{}',
  '20000000-0000-0000-0000-000000000001','organization_owner','active',now(),1,'{}'
) on conflict (tenant_id,user_id) do nothing;

-- TEST-ID: S1-NT-005 AMBIGUOUS TENANT DENIAL
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context(null,'50000000-0000-0000-0000-000000000005');
  if r.reason_code <> 'TENANT_AMBIGUOUS' then raise exception 'S1-NT-005 failed'; end if;
end $$;

-- TEST-ID: S1-NT-006 CLIENT TENANT OVERRIDE DENIAL
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-0000-0000-000000000001','role','authenticated','aal','aal2',
  'session_id','w1-session-owner','iat',extract(epoch from now())::bigint,
  'app_metadata',jsonb_build_object('selected_tenant_id','w1-tenant-a')
)::text,true);
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context('w1-tenant-b','50000000-0000-0000-0000-000000000006');
  if r.reason_code <> 'TENANT_OVERRIDE_DENIED' then raise exception 'S1-NT-006 failed'; end if;
end $$;

-- TEST-ID: S1-NT-007 INVALID ROLE OR ACTION DENIAL
do $$ declare r record; begin
  select * into r from provenance_api.authorize_and_audit(
    'publish','verification_result','x','w1-tenant-a',null,null,
    '50000000-0000-0000-0000-000000000007',null
  );
  if r.outcome <> 'DENY' or r.reason_code <> 'DENY_ACTION' then raise exception 'S1-NT-007 failed'; end if;
end $$;

-- TEST-ID: S1-NT-008 CROSS-TENANT SELECT DENIAL
set local role authenticated;
do $$ begin
  if exists (select 1 from public.pv_assets where id='w1-asset-b') then
    raise exception 'S1-NT-008 failed';
  end if;
end $$;
reset role;

-- TEST-ID: S1-NT-009 CROSS-TENANT INSERT DENIAL
set local role authenticated;
do $$ begin
  begin
    insert into public.pv_assets(
      id,tenant_id,location_id,batch_id,serial,status,material,shape,
      treatment_disclosure,origin_claim,measurements,created_by,created_at,updated_at
    ) values ('w1-asset-x','w1-tenant-b','w1-location-b','w1-batch-b','W1-X','active','stone','round','none','test','{}','test',now(),now());
    raise exception 'S1-NT-009 failed: insert allowed';
  exception when insufficient_privilege or check_violation then null;
  end;
end $$;
reset role;

-- TEST-ID: S1-NT-010 CROSS-TENANT UPDATE DENIAL
set local role authenticated;
do $$ begin
  update public.pv_assets set status='blocked' where id='w1-asset-b';
  if found then raise exception 'S1-NT-010 failed'; end if;
end $$;
reset role;

-- TEST-ID: S1-NT-011 CROSS-TENANT DELETE DENIAL
set local role authenticated;
do $$ begin
  delete from public.pv_assets where id='w1-asset-b';
  if found then raise exception 'S1-NT-011 failed'; end if;
end $$;
reset role;

-- TEST-ID: S1-NT-012 SERVICE-ROLE BOUNDARY
do $$
begin
  if exists (
    select 1 from information_schema.role_table_grants
    where grantee='service_role'
      and table_schema='public'
      and table_name in ('pv_actors','pv_role_registry','pv_role_permissions','pv_authorization_audit_events','pv_idempotency_keys')
  ) then raise exception 'S1-NT-012 failed'; end if;
end $$;

-- TEST-ID: S1-NT-013 AUDIT UPDATE DENIAL
do $$ begin
  begin
    update public.pv_authorization_audit_events set outcome='DENY'
    where correlation_id='40000000-0000-0000-0000-000000000003'::uuid;
    raise exception 'S1-NT-013 failed: update allowed';
  exception when object_not_in_prerequisite_state then null;
  end;
end $$;

-- TEST-ID: S1-NT-014 AUDIT DELETE DENIAL
do $$ begin
  begin
    delete from public.pv_authorization_audit_events
    where correlation_id='40000000-0000-0000-0000-000000000003'::uuid;
    raise exception 'S1-NT-014 failed: delete allowed';
  exception when object_not_in_prerequisite_state then null;
  end;
end $$;

-- TEST-ID: S1-NT-015 IDEMPOTENCY DIGEST CONFLICT
do $$ declare r record; begin
  select * into r from provenance_api.claim_idempotency_key(
    'w1-idem-1','asset.read','sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    null,now()+interval '1 hour','50000000-0000-0000-0000-000000000015'
  );
  if r.reason_code <> 'PV_IDEMPOTENCY_FINGERPRINT_CONFLICT' then raise exception 'S1-NT-015 failed'; end if;
end $$;

-- TEST-ID: S1-NT-016 PURCHASER-ONLY ACCESS DENIAL
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','10000000-0000-0000-0000-000000000003','role','authenticated','aal','aal2',
  'session_id','w1-session-purchaser','iat',extract(epoch from now())::bigint,
  'app_metadata',jsonb_build_object('selected_tenant_id','w1-tenant-a')
)::text,true);
do $$ declare r record; begin
  select * into r from provenance_api.derive_tenant_context(null,'50000000-0000-0000-0000-000000000016');
  if r.outcome <> 'DENY' or r.reason_code <> 'MEMBERSHIP_INACTIVE' then raise exception 'S1-NT-016 failed'; end if;
end $$;

rollback;
