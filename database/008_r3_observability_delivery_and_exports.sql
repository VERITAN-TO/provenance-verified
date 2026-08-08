-- PROVENANCE.CX R8.1 R3 observability, notification delivery, and governed audit export runtime.
-- Mutable projections are service-role RPC only; every delivery/export action has immutable attempt/event evidence.

create table if not exists public.pv_service_health_samples (
  id bigint generated always as identity primary key,
  service_id text not null references public.pv_service_catalog(service_id),
  environment text not null check (environment in ('sandbox','pilot','production')),
  readiness text not null check (readiness in ('ready','degraded','blocked')),
  dependency_state jsonb not null,
  latency_ms integer not null check (latency_ms >= 0),
  receipt_id text not null,
  trace_id text not null,
  sampled_at timestamptz not null default now(),
  unique(service_id, environment, receipt_id)
);

create table if not exists public.pv_alert_events (
  id bigint generated always as identity primary key,
  service_id text not null references public.pv_service_catalog(service_id),
  alert_key text not null,
  severity text not null check (severity in ('info','warning','critical')),
  state text not null check (state in ('open','acknowledged','resolved')),
  source_receipt_id text not null,
  trace_id text not null,
  payload jsonb not null,
  occurred_at timestamptz not null default now(),
  unique(alert_key, source_receipt_id, state)
);

create table if not exists public.pv_notification_attempts (
  id bigint generated always as identity primary key,
  notification_id uuid not null references public.pv_notifications(id),
  tenant_id text not null references public.pv_tenants(id),
  worker_id text not null,
  attempt integer not null check (attempt > 0),
  request_digest text not null check (request_digest ~ '^sha256:[0-9a-f]{64}$'),
  provider_receipt jsonb,
  outcome text not null check (outcome in ('delivered','retry','dead-letter','suppressed')),
  error_code text,
  started_at timestamptz not null,
  completed_at timestamptz not null default now(),
  unique(notification_id, attempt)
);

alter table public.pv_audit_exports
  add column if not exists state text not null default 'queued' check (state in ('queued','building','available','failed','revoked','expired')),
  add column if not exists request_digest text check (request_digest is null or request_digest ~ '^sha256:[0-9a-f]{64}$'),
  add column if not exists export_digest text check (export_digest is null or export_digest ~ '^sha256:[0-9a-f]{64}$'),
  add column if not exists encryption_key_id text,
  add column if not exists worker_id text,
  add column if not exists claimed_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists failure_code text;

create table if not exists public.pv_audit_export_events (
  id bigint generated always as identity primary key,
  export_id uuid not null references public.pv_audit_exports(id),
  tenant_id text not null references public.pv_tenants(id),
  event_type text not null check (event_type in ('requested','claimed','completed','failed','revoked','expired','accessed')),
  actor_identity text not null,
  payload jsonb not null,
  event_digest text not null check (event_digest ~ '^sha256:[0-9a-f]{64}$'),
  previous_event_digest text not null,
  occurred_at timestamptz not null default now(),
  unique(export_id, id),
  unique(export_id, event_digest)
);

create or replace function provenance_api.pv_r3_claim_notifications(p_worker_id text, p_limit integer default 20)
returns setof public.pv_notifications
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
begin
  if p_worker_id is null or length(trim(p_worker_id)) < 3 then raise exception 'PV_NOTIFICATION_WORKER_REQUIRED'; end if;
  if p_limit < 1 or p_limit > 100 then raise exception 'PV_NOTIFICATION_CLAIM_LIMIT_INVALID'; end if;
  return query
  with candidates as (
    select id from public.pv_notifications
    where state in ('queued','failed') and coalesce(next_attempt_at,now()) <= now() and attempt_count < 5
    order by created_at asc
    for update skip locked limit p_limit
  )
  update public.pv_notifications n
  set state='sending', attempt_count=n.attempt_count+1, next_attempt_at=null
  from candidates c where n.id=c.id
  returning n.*;
end $$;

create or replace function provenance_api.pv_r3_complete_notification(
  p_notification_id uuid,p_worker_id text,p_request_digest text,p_outcome text,p_provider_receipt jsonb,p_error_code text default null
) returns public.pv_notifications
language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare n public.pv_notifications; v_state text; v_next timestamptz; begin
  if p_request_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_NOTIFICATION_REQUEST_DIGEST_INVALID'; end if;
  select * into n from public.pv_notifications where id=p_notification_id for update;
  if not found then raise exception 'PV_NOTIFICATION_NOT_FOUND'; end if;
  if n.state <> 'sending' then raise exception 'PV_NOTIFICATION_NOT_CLAIMED'; end if;
  if p_outcome='delivered' then v_state:='delivered'; v_next:=null;
  elsif p_outcome='suppressed' then v_state:='suppressed'; v_next:=null;
  elsif p_outcome='retry' and n.attempt_count < 5 then v_state:='failed'; v_next:=now()+make_interval(secs => least(3600,30*(2^greatest(0,n.attempt_count-1))));
  else v_state:='dead-letter'; v_next:=null; end if;
  insert into public.pv_notification_attempts(notification_id,tenant_id,worker_id,attempt,request_digest,provider_receipt,outcome,error_code,started_at)
  values(n.id,n.tenant_id,p_worker_id,n.attempt_count,p_request_digest,coalesce(p_provider_receipt,'{}'::jsonb),case when v_state='failed' then 'retry' else v_state end,p_error_code,now());
  update public.pv_notifications set state=v_state,next_attempt_at=v_next,delivery_receipt=case when v_state='delivered' then p_provider_receipt else delivery_receipt end
  where id=n.id returning * into n;
  return n;
end $$;

create or replace function provenance_api.pv_r3_request_audit_export(
  p_tenant_id text,p_requester_identity text,p_approved_by text[],p_scope jsonb,p_policy_version text,p_watermark text,p_expires_at timestamptz
) returns public.pv_audit_exports
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare e public.pv_audit_exports; v_payload jsonb; v_digest text; begin
  if cardinality(p_approved_by) < 2 or p_requester_identity = any(p_approved_by) then raise exception 'PV_AUDIT_EXPORT_DUAL_CONTROL_REQUIRED'; end if;
  if p_expires_at <= now() or p_expires_at > now()+interval '7 days' then raise exception 'PV_AUDIT_EXPORT_EXPIRY_INVALID'; end if;
  if p_scope is null or p_scope='{}'::jsonb then raise exception 'PV_AUDIT_EXPORT_SCOPE_REQUIRED'; end if;
  v_payload:=jsonb_build_object('tenantId',p_tenant_id,'requester',p_requester_identity,'approvedBy',p_approved_by,'scope',p_scope,'policyVersion',p_policy_version,'watermark',p_watermark,'expiresAt',p_expires_at);
  v_digest:='sha256:'||encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_audit_exports(tenant_id,requester_identity,approved_by,scope,disclosure_policy_version,watermark,expires_at,state,request_digest)
  values(p_tenant_id,p_requester_identity,p_approved_by,p_scope,p_policy_version,p_watermark,p_expires_at,'queued',v_digest) returning * into e;
  insert into public.pv_audit_export_events(export_id,tenant_id,event_type,actor_identity,payload,event_digest,previous_event_digest)
  values(e.id,e.tenant_id,'requested',p_requester_identity,v_payload,v_digest,'GENESIS');
  return e;
end $$;

create or replace function provenance_api.pv_r3_claim_audit_exports(p_worker_id text,p_limit integer default 5)
returns setof public.pv_audit_exports
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
begin
  if p_worker_id is null or length(trim(p_worker_id))<3 then raise exception 'PV_AUDIT_EXPORT_WORKER_REQUIRED'; end if;
  return query
  with candidates as (
    select id from public.pv_audit_exports where state='queued' and revoked_at is null and expires_at>now()
    order by created_at asc for update skip locked limit greatest(1,least(p_limit,20))
  )
  update public.pv_audit_exports e set state='building',worker_id=p_worker_id,claimed_at=now()
  from candidates c where e.id=c.id returning e.*;
end $$;

create or replace function provenance_api.pv_r3_complete_audit_export(
  p_export_id uuid,p_worker_id text,p_encrypted_reference text,p_export_digest text,p_encryption_key_id text,p_evidence jsonb
) returns public.pv_audit_exports
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare e public.pv_audit_exports; v_prev text; v_event jsonb; v_event_digest text; begin
  if p_export_digest !~ '^sha256:[0-9a-f]{64}$' or length(coalesce(p_encrypted_reference,''))<8 or length(coalesce(p_encryption_key_id,''))<3 then raise exception 'PV_AUDIT_EXPORT_COMPLETION_INVALID'; end if;
  select * into e from public.pv_audit_exports where id=p_export_id for update;
  if not found or e.state<>'building' or e.worker_id<>p_worker_id then raise exception 'PV_AUDIT_EXPORT_NOT_CLAIMED'; end if;
  if e.revoked_at is not null or e.expires_at<=now() then raise exception 'PV_AUDIT_EXPORT_NO_LONGER_ELIGIBLE'; end if;
  select coalesce(event_digest,'GENESIS') into v_prev from public.pv_audit_export_events where export_id=e.id order by id desc limit 1;
  v_event:=jsonb_build_object('exportId',e.id,'reference',p_encrypted_reference,'digest',p_export_digest,'keyId',p_encryption_key_id,'evidence',p_evidence);
  v_event_digest:='sha256:'||encode(extensions.digest(convert_to(v_prev||v_event::text,'UTF8'),'sha256'),'hex');
  update public.pv_audit_exports set state='available',encrypted_object_reference=p_encrypted_reference,export_digest=p_export_digest,encryption_key_id=p_encryption_key_id,completed_at=now(),failure_code=null where id=e.id returning * into e;
  insert into public.pv_audit_export_events(export_id,tenant_id,event_type,actor_identity,payload,event_digest,previous_event_digest)
  values(e.id,e.tenant_id,'completed',p_worker_id,v_event,v_event_digest,v_prev);
  return e;
end $$;

create or replace function provenance_api.pv_r3_revoke_audit_export(p_export_id uuid,p_actor_identity text,p_reason text)
returns public.pv_audit_exports
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare e public.pv_audit_exports; v_prev text; v_payload jsonb; v_digest text; begin
  select * into e from public.pv_audit_exports where id=p_export_id for update;
  if not found then raise exception 'PV_AUDIT_EXPORT_NOT_FOUND'; end if;
  select coalesce(event_digest,'GENESIS') into v_prev from public.pv_audit_export_events where export_id=e.id order by id desc limit 1;
  v_payload:=jsonb_build_object('reason',p_reason,'revokedAt',now());
  v_digest:='sha256:'||encode(extensions.digest(convert_to(v_prev||v_payload::text,'UTF8'),'sha256'),'hex');
  update public.pv_audit_exports set state='revoked',revoked_at=now() where id=e.id returning * into e;
  insert into public.pv_audit_export_events(export_id,tenant_id,event_type,actor_identity,payload,event_digest,previous_event_digest)
  values(e.id,e.tenant_id,'revoked',p_actor_identity,v_payload,v_digest,v_prev);
  return e;
end $$;

create trigger pv_notification_attempts_immutable before update or delete on public.pv_notification_attempts for each row execute function provenance_api.deny_mutation();
create trigger pv_audit_export_events_immutable before update or delete on public.pv_audit_export_events for each row execute function provenance_api.deny_mutation();
create trigger pv_service_health_samples_immutable before update or delete on public.pv_service_health_samples for each row execute function provenance_api.deny_mutation();
create trigger pv_alert_events_immutable before update or delete on public.pv_alert_events for each row execute function provenance_api.deny_mutation();

alter table public.pv_notification_attempts enable row level security;
alter table public.pv_notification_attempts force row level security;
alter table public.pv_audit_export_events enable row level security;
alter table public.pv_audit_export_events force row level security;
revoke insert,update,delete on public.pv_notification_attempts,public.pv_audit_export_events,public.pv_service_health_samples,public.pv_alert_events from anon,authenticated;
create policy pv_notification_attempts_tenant_read on public.pv_notification_attempts for select to authenticated using(tenant_id=provenance_api.current_tenant_id());
create policy pv_audit_export_events_tenant_read on public.pv_audit_export_events for select to authenticated using(tenant_id=provenance_api.current_tenant_id());

revoke all on function provenance_api.pv_r3_claim_notifications(text,integer) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_complete_notification(uuid,text,text,text,jsonb,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_request_audit_export(text,text,text[],jsonb,text,text,timestamptz) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_claim_audit_exports(text,integer) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_complete_audit_export(uuid,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_revoke_audit_export(uuid,text,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_claim_notifications(text,integer) to service_role;
grant execute on function provenance_api.pv_r3_complete_notification(uuid,text,text,text,jsonb,text) to service_role;
grant execute on function provenance_api.pv_r3_request_audit_export(text,text,text[],jsonb,text,text,timestamptz) to service_role;
grant execute on function provenance_api.pv_r3_claim_audit_exports(text,integer) to service_role;
grant execute on function provenance_api.pv_r3_complete_audit_export(uuid,text,text,text,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_revoke_audit_export(uuid,text,text) to service_role;
