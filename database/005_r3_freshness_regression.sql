-- PROVENANCE.CX R8.1 R3 automatic freshness regression and launch prevention.
-- Evaluations are append-only; governed source records are never silently rewritten.

create table if not exists public.pv_freshness_runs (
  id uuid primary key,
  actor_identity text not null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  open_count integer,
  resolved_count integer,
  result_digest text check (result_digest is null or result_digest ~ '^sha256:[0-9a-f]{64}$')
);

create table if not exists public.pv_freshness_findings (
  id bigint generated always as identity primary key,
  run_id uuid not null references public.pv_freshness_runs(id),
  tenant_id text references public.pv_tenants(id),
  fingerprint text not null check (fingerprint ~ '^sha256:[0-9a-f]{64}$'),
  subject_type text not null,
  subject_id text not null,
  severity text not null check (severity in ('hard','soft')),
  reason_code text not null,
  state text not null check (state in ('open','resolved')),
  resolves_finding_id bigint references public.pv_freshness_findings(id),
  observed_at timestamptz not null default now(),
  evidence jsonb not null default '{}'::jsonb,
  unique(run_id,fingerprint,state)
);

create or replace view public.pv_current_freshness_findings
with (security_invoker=true) as
select latest.* from (
  select distinct on (fingerprint) *
  from public.pv_freshness_findings
  order by fingerprint,id desc
) latest
where latest.state='open';

create or replace function provenance_api.pv_r3_run_freshness_regression(
  p_run_id uuid,
  p_actor_identity text,
  p_observed_at timestamptz default now()
) returns jsonb
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp
as $$
declare v_open integer; v_resolved integer; v_digest text;
begin
  if p_actor_identity is null or length(trim(p_actor_identity))<3 then raise exception 'PV_FRESHNESS_ACTOR_REQUIRED'; end if;
  if abs(extract(epoch from (now()-p_observed_at)))>120 then raise exception 'PV_FRESHNESS_TIMESTAMP_INVALID'; end if;
  insert into public.pv_freshness_runs(id,actor_identity,started_at) values(p_run_id,p_actor_identity,p_observed_at);

  create temporary table current_conditions(
    tenant_id text, fingerprint text primary key, subject_type text, subject_id text,
    severity text, reason_code text, evidence jsonb
  ) on commit drop;

  insert into current_conditions
  select c.tenant_id,
    'sha256:'||encode(extensions.digest(convert_to(c.tenant_id::text||':runtime-claim:'||c.id::text||':expired','UTF8'),'sha256'),'hex'),
    'runtime-claim',c.id::text,'hard','CLAIM_OR_EVIDENCE_NOT_CURRENT',
    jsonb_build_object('claimExpiresAt',c.expires_at,'evidenceIssue',exists(select 1 from public.pv_runtime_claim_evidence e where e.claim_id=c.id and (e.expires_at<=p_observed_at or e.revoked_at is not null or e.contradicted_at is not null)))
  from public.pv_runtime_claims c
  where c.superseded_by is null and (
    c.expires_at<=p_observed_at or not exists(select 1 from public.pv_runtime_claim_evidence e where e.claim_id=c.id)
    or exists(select 1 from public.pv_runtime_claim_evidence e where e.claim_id=c.id and (e.expires_at<=p_observed_at or e.revoked_at is not null or e.contradicted_at is not null))
  ) on conflict do nothing;

  insert into current_conditions
  select w.tenant_id,'sha256:'||encode(extensions.digest(convert_to(w.tenant_id::text||':waiver:'||w.id::text||':expired','UTF8'),'sha256'),'hex'),
    'waiver',w.id::text,'hard',case when w.revoked_at is not null then 'WAIVER_REVOKED' else 'WAIVER_EXPIRED' end,
    jsonb_build_object('expiresAt',w.expires_at,'revokedAt',w.revoked_at)
  from public.pv_readiness_waivers w where w.revoked_at is not null or w.expires_at<=p_observed_at on conflict do nothing;

  insert into current_conditions
  select k.tenant_id,'sha256:'||encode(extensions.digest(convert_to(k.tenant_id::text||':key:'||k.id::text||':invalid','UTF8'),'sha256'),'hex'),
    'authority-key',k.id::text,'hard','AUTHORITY_KEY_NOT_ELIGIBLE',jsonb_build_object('status',k.status,'notBefore',k.not_before,'notAfter',k.not_after)
  from public.pv_authority_key_lifecycle k where k.status='active' and (k.not_before>p_observed_at or k.not_after<=p_observed_at) on conflict do nothing;

  insert into current_conditions
  select a.tenant_id,'sha256:'||encode(extensions.digest(convert_to(a.tenant_id::text||':access-review:'||a.id::text||':overdue','UTF8'),'sha256'),'hex'),
    'access-review',a.id::text,'hard','ACCESS_REVIEW_OVERDUE',jsonb_build_object('dueAt',a.due_at)
  from public.pv_access_reviews a where a.completed_at is null and a.due_at<=p_observed_at on conflict do nothing;

  insert into current_conditions
  select c.tenant_id,'sha256:'||encode(extensions.digest(convert_to(coalesce(c.tenant_id::text,'global')||':public-claim:'||c.id::text||':expired','UTF8'),'sha256'),'hex'),
    'public-claim',c.id::text,'hard','PUBLIC_CLAIM_EXPIRED',jsonb_build_object('expiresAt',c.expires_at,'state',c.state)
  from public.pv_public_claims c where c.state in ('approved','published') and (c.expires_at<=p_observed_at or cardinality(c.source_ids)=0 or cardinality(c.approver_ids)=0) on conflict do nothing;

  insert into current_conditions
  select null,'sha256:'||encode(extensions.digest(convert_to('knowledge-block:'||k.id::text||':stale','UTF8'),'sha256'),'hex'),
    'knowledge-block',k.id::text,'soft','KNOWLEDGE_REVIEW_OR_EXPIRY_DUE',jsonb_build_object('reviewAt',k.review_at,'expiresAt',k.expires_at)
  from public.pv_knowledge_blocks k where k.state='published' and (k.review_at<=p_observed_at or k.expires_at<=p_observed_at) on conflict do nothing;

  insert into current_conditions
  select c.tenant_id,'sha256:'||encode(extensions.digest(convert_to(c.tenant_id::text||':contract:'||c.id::text||':expired','UTF8'),'sha256'),'hex'),
    'contract',c.id::text,'hard','CONTRACT_AUTHORITY_EXPIRED',jsonb_build_object('expiresAt',c.expires_at,'status',c.status)
  from public.pv_contracts c where c.status='active' and c.expires_at is not null and c.expires_at<=p_observed_at on conflict do nothing;

  insert into current_conditions
  select b.tenant_id,'sha256:'||encode(extensions.digest(convert_to(b.tenant_id::text||':break-glass:'||b.id::text||':expired','UTF8'),'sha256'),'hex'),
    'break-glass',b.id::text,'hard','BREAK_GLASS_LEASE_EXPIRED',jsonb_build_object('expiresAt',b.expires_at)
  from public.pv_break_glass_leases b where b.revoked_at is null and b.expires_at<=p_observed_at on conflict do nothing;

  insert into public.pv_freshness_findings(run_id,tenant_id,fingerprint,subject_type,subject_id,severity,reason_code,state,evidence)
  select p_run_id,c.tenant_id,c.fingerprint,c.subject_type,c.subject_id,c.severity,c.reason_code,'open',c.evidence
  from current_conditions c
  where not exists(select 1 from public.pv_current_freshness_findings f where f.fingerprint=c.fingerprint);
  get diagnostics v_open = row_count;

  insert into public.pv_freshness_findings(run_id,tenant_id,fingerprint,subject_type,subject_id,severity,reason_code,state,resolves_finding_id,evidence)
  select p_run_id,f.tenant_id,f.fingerprint,f.subject_type,f.subject_id,f.severity,'FRESHNESS_RESTORED','resolved',f.id,
    jsonb_build_object('resolvedAt',p_observed_at,'priorReasonCode',f.reason_code)
  from public.pv_current_freshness_findings f
  where not exists(select 1 from current_conditions c where c.fingerprint=f.fingerprint);
  get diagnostics v_resolved = row_count;

  v_digest:='sha256:'||encode(extensions.digest(convert_to(jsonb_build_object('runId',p_run_id,'openInserted',v_open,'resolvedInserted',v_resolved,
    'currentOpen',(select count(*) from public.pv_current_freshness_findings),'observedAt',p_observed_at)::text,'UTF8'),'sha256'),'hex');
  update public.pv_freshness_runs set completed_at=now(),open_count=v_open,resolved_count=v_resolved,result_digest=v_digest where id=p_run_id;
  return jsonb_build_object('runId',p_run_id,'openInserted',v_open,'resolvedInserted',v_resolved,'currentOpen',(select count(*) from public.pv_current_freshness_findings),'resultDigest',v_digest);
end $$;

create or replace function provenance_api.pv_r3_launch_freshness_guard() returns trigger
language plpgsql set search_path=public,provenance_api,pg_temp as $$
begin
  if new.state='approved' and exists(select 1 from public.pv_current_freshness_findings where severity='hard') then
    raise exception 'PV_LAUNCH_BLOCKED_BY_STALE_EVIDENCE';
  end if;
  return new;
end $$;
drop trigger if exists pv_launch_gates_freshness_guard on public.pv_launch_gates;
create trigger pv_launch_gates_freshness_guard before insert or update on public.pv_launch_gates
for each row execute function provenance_api.pv_r3_launch_freshness_guard();

create trigger pv_freshness_findings_immutable before update or delete on public.pv_freshness_findings
for each row execute function provenance_api.deny_mutation();

revoke all on public.pv_freshness_runs,public.pv_freshness_findings from anon,authenticated;
revoke all on function provenance_api.pv_r3_run_freshness_regression(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_run_freshness_regression(uuid,text,timestamptz) to service_role;
