-- PROVENANCE.CX R8.1 R3 reviewer workload, independent CUSTOS reproduction, and evidence quality controls.

create table if not exists public.pv_reviewer_assignments (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  reviewer_identity text not null,
  governed_party_id text not null references public.pv_governed_parties(id),
  review_round integer not null check (review_round > 0),
  stage text not null check (stage in ('primary','secondary')),
  protocol_version text not null,
  accreditation_scope text not null,
  claim_receipt_id text not null,
  conflict_receipt_id text not null,
  priority integer not null default 100,
  state text not null check (state in ('queued','claimed','completed','expired','cancelled')) default 'queued',
  assigned_at timestamptz not null default now(),
  due_at timestamptz not null,
  claimed_at timestamptz,
  completed_at timestamptz,
  worker_identity text,
  decision_receipt_id text,
  assignment_digest text not null check (assignment_digest ~ '^sha256:[0-9a-f]{64}$'),
  unique(review_case_id,review_round,stage),
  unique(review_case_id,review_round,reviewer_identity)
);
create index if not exists pv_reviewer_assignments_queue_idx on public.pv_reviewer_assignments(state,priority,due_at);

create table if not exists public.pv_custos_runs (
  id uuid primary key,
  tenant_id text not null references public.pv_tenants(id),
  review_case_id text not null references public.pv_review_cases(id),
  credential_id text not null,
  policy_version text not null,
  sampling_seed_digest text not null check (sampling_seed_digest ~ '^sha256:[0-9a-f]{64}$'),
  authoritative_facts_digest text not null check (authoritative_facts_digest ~ '^sha256:[0-9a-f]{64}$'),
  canonical_payload_digest text not null check (canonical_payload_digest ~ '^sha256:[0-9a-f]{64}$'),
  state text not null check (state in ('started','sampled','reproduced','passed','denied','failed')),
  started_at timestamptz not null default now(),
  completed_at timestamptz
);
create table if not exists public.pv_custos_samples (
  id bigint generated always as identity primary key,
  run_id uuid not null references public.pv_custos_runs(id),
  sample_sequence integer not null,
  evidence_reference text not null,
  selection_digest text not null check (selection_digest ~ '^sha256:[0-9a-f]{64}$'),
  sampled_at timestamptz not null default now(),
  unique(run_id,sample_sequence),
  unique(run_id,evidence_reference)
);
create table if not exists public.pv_custos_reproductions (
  id bigint generated always as identity primary key,
  run_id uuid not null references public.pv_custos_runs(id),
  check_name text not null,
  expected_digest text not null check (expected_digest ~ '^sha256:[0-9a-f]{64}$'),
  reproduced_digest text not null check (reproduced_digest ~ '^sha256:[0-9a-f]{64}$'),
  pass boolean not null,
  evidence jsonb not null,
  reproduced_at timestamptz not null default now(),
  unique(run_id,check_name)
);
create table if not exists public.pv_custos_verdict_events (
  id bigint generated always as identity primary key,
  run_id uuid not null references public.pv_custos_runs(id),
  tenant_id text not null references public.pv_tenants(id),
  decision text not null check (decision in ('pass','deny')),
  reason_codes text[] not null,
  receipt_id text not null unique,
  receipt_digest text not null check (receipt_digest ~ '^sha256:[0-9a-f]{64}$'),
  occurred_at timestamptz not null default now()
);

create table if not exists public.pv_evidence_content_index (
  tenant_id text not null references public.pv_tenants(id),
  object_digest text not null check (object_digest ~ '^sha256:[0-9a-f]{64}$'),
  evidence_ids text[] not null,
  byte_size bigint not null check (byte_size > 0),
  mime_type text not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key(tenant_id,object_digest)
);
create table if not exists public.pv_evidence_redaction_reviews (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  original_evidence_id text not null,
  derivative_id uuid not null references public.pv_evidence_derivatives(id),
  redaction_profile text not null,
  reviewer_identities text[] not null,
  approval_receipt_ids text[] not null,
  public_projection_allowed boolean not null,
  reason_codes text[] not null,
  reviewed_at timestamptz not null default now(),
  check (cardinality(reviewer_identities)>=2 and cardinality(reviewer_identities)=cardinality(approval_receipt_ids))
);

create or replace function provenance_api.pv_r3_assign_reviewer(
  p_tenant text,p_review_case text,p_reviewer text,p_governed_party text,p_round integer,p_stage text,
  p_protocol_version text,p_scope text,p_claim_receipt text,p_conflict_receipt text,p_due_at timestamptz,p_priority integer default 100
) returns public.pv_reviewer_assignments
language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare party public.pv_governed_parties; active_count integer; other_reviewer text; result public.pv_reviewer_assignments; payload jsonb; digest text; begin
  if p_stage not in ('primary','secondary') or p_round<1 or p_due_at<=now() then raise exception 'PV_REVIEW_ASSIGNMENT_INVALID'; end if;
  select * into result from public.pv_reviewer_assignments where review_case_id=p_review_case and review_round=p_round and stage=p_stage;
  if found then
    if result.reviewer_identity<>p_reviewer or result.tenant_id<>p_tenant then raise exception 'PV_REVIEW_ASSIGNMENT_CONFLICT'; end if;
    return result;
  end if;
  select * into party from public.pv_governed_parties where id=p_governed_party for update;
  if not found or party.party_type<>'reviewer' or party.status<>'active' or party.contract_status<>'current' or party.expires_at<=now() or not (p_scope=any(party.accreditation_scopes)) then raise exception 'PV_REVIEWER_NOT_ELIGIBLE'; end if;
  select reviewer_identity into other_reviewer from public.pv_reviewer_assignments where review_case_id=p_review_case and review_round=p_round and stage<>p_stage and state not in ('expired','cancelled') limit 1;
  if other_reviewer=p_reviewer then raise exception 'PV_DISTINCT_REVIEWER_REQUIRED'; end if;
  select count(*) into active_count from public.pv_reviewer_assignments where reviewer_identity=p_reviewer and state in ('queued','claimed');
  if active_count>=20 then raise exception 'PV_REVIEWER_WORKLOAD_LIMIT'; end if;
  payload:=jsonb_build_object('tenantId',p_tenant,'reviewCaseId',p_review_case,'reviewer',p_reviewer,'round',p_round,'stage',p_stage,'protocolVersion',p_protocol_version,'scope',p_scope,'claimReceiptId',p_claim_receipt,'conflictReceiptId',p_conflict_receipt,'dueAt',p_due_at);
  digest:='sha256:'||encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex');
  insert into public.pv_reviewer_assignments(tenant_id,review_case_id,reviewer_identity,governed_party_id,review_round,stage,protocol_version,accreditation_scope,claim_receipt_id,conflict_receipt_id,priority,due_at,assignment_digest)
  values(p_tenant,p_review_case,p_reviewer,p_governed_party,p_round,p_stage,p_protocol_version,p_scope,p_claim_receipt,p_conflict_receipt,p_priority,p_due_at,digest) returning * into result;
  return result;
end $$;

create or replace function provenance_api.pv_r3_claim_reviewer_assignment(p_worker text,p_reviewer text)
returns public.pv_reviewer_assignments language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_reviewer_assignments; begin
  select * into result from public.pv_reviewer_assignments where reviewer_identity=p_reviewer and state='queued' and due_at>now()
  order by priority asc,due_at asc for update skip locked limit 1;
  if not found then raise exception 'PV_REVIEW_ASSIGNMENT_UNAVAILABLE'; end if;
  update public.pv_reviewer_assignments set state='claimed',worker_identity=p_worker,claimed_at=now() where id=result.id returning * into result;
  return result;
end $$;

create or replace function provenance_api.pv_r3_complete_reviewer_assignment(p_assignment uuid,p_reviewer text,p_receipt text)
returns public.pv_reviewer_assignments language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_reviewer_assignments; begin
  select * into result from public.pv_reviewer_assignments where id=p_assignment for update;
  if not found then raise exception 'PV_REVIEW_ASSIGNMENT_NOT_FOUND'; end if;
  if result.reviewer_identity<>p_reviewer or result.state<>'claimed' then raise exception 'PV_REVIEW_ASSIGNMENT_COMPLETION_DENIED'; end if;
  if p_receipt is null or length(p_receipt)<8 then raise exception 'PV_REVIEW_DECISION_RECEIPT_REQUIRED'; end if;
  update public.pv_reviewer_assignments set state='completed',completed_at=now(),decision_receipt_id=p_receipt where id=p_assignment returning * into result;
  return result;
end $$;

create or replace function provenance_api.pv_r3_register_evidence_content(p_tenant text,p_evidence_id text,p_digest text,p_byte_size bigint,p_mime text)
returns public.pv_evidence_content_index language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_evidence_content_index; begin
  if p_digest !~ '^sha256:[0-9a-f]{64}$' or p_byte_size<=0 then raise exception 'PV_EVIDENCE_CONTENT_INVALID'; end if;
  insert into public.pv_evidence_content_index(tenant_id,object_digest,evidence_ids,byte_size,mime_type)
  values(p_tenant,p_digest,array[p_evidence_id],p_byte_size,p_mime)
  on conflict(tenant_id,object_digest) do update set evidence_ids=(select array_agg(distinct x) from unnest(public.pv_evidence_content_index.evidence_ids||excluded.evidence_ids) x),last_seen_at=now()
  returning * into result;
  return result;
end $$;

create or replace function provenance_api.pv_r3_record_redaction_review(
 p_tenant text,p_original text,p_derivative uuid,p_profile text,p_reviewers text[],p_receipts text[],p_allowed boolean,p_reasons text[]
) returns public.pv_evidence_redaction_reviews language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_evidence_redaction_reviews; derivative public.pv_evidence_derivatives; begin
  select * into derivative from public.pv_evidence_derivatives where id=p_derivative and tenant_id=p_tenant;
  if not found or derivative.original_evidence_id::text<>p_original then raise exception 'PV_REDACTION_DERIVATIVE_LINEAGE_INVALID'; end if;
  if cardinality(array(select distinct unnest(p_reviewers)))<2 or cardinality(p_reviewers)<>cardinality(p_receipts) then raise exception 'PV_REDACTION_DUAL_CONTROL_REQUIRED'; end if;
  insert into public.pv_evidence_redaction_reviews(tenant_id,original_evidence_id,derivative_id,redaction_profile,reviewer_identities,approval_receipt_ids,public_projection_allowed,reason_codes)
  values(p_tenant,p_original,p_derivative,p_profile,p_reviewers,p_receipts,p_allowed,p_reasons) returning * into result;
  return result;
end $$;

create trigger pv_reviewer_assignments_immutable before update or delete on public.pv_reviewer_assignments for each row when (old.state in ('completed','expired','cancelled')) execute function provenance_api.deny_mutation();
create trigger pv_custos_runs_immutable before update or delete on public.pv_custos_runs for each row when (old.state in ('passed','denied','failed')) execute function provenance_api.deny_mutation();
create trigger pv_custos_samples_immutable before update or delete on public.pv_custos_samples for each row execute function provenance_api.deny_mutation();
create trigger pv_custos_reproductions_immutable before update or delete on public.pv_custos_reproductions for each row execute function provenance_api.deny_mutation();
create trigger pv_custos_verdict_events_immutable before update or delete on public.pv_custos_verdict_events for each row execute function provenance_api.deny_mutation();
create trigger pv_evidence_redaction_reviews_immutable before update or delete on public.pv_evidence_redaction_reviews for each row execute function provenance_api.deny_mutation();

revoke all on public.pv_reviewer_assignments,public.pv_custos_runs,public.pv_custos_samples,public.pv_custos_reproductions,public.pv_custos_verdict_events,public.pv_evidence_content_index,public.pv_evidence_redaction_reviews from anon,authenticated;
revoke all on function provenance_api.pv_r3_assign_reviewer(text,text,text,text,integer,text,text,text,text,text,timestamptz,integer) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_claim_reviewer_assignment(text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_complete_reviewer_assignment(uuid,text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_register_evidence_content(text,text,text,bigint,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_redaction_review(text,text,uuid,text,text[],text[],boolean,text[]) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_assign_reviewer(text,text,text,text,integer,text,text,text,text,text,timestamptz,integer) to service_role;
grant execute on function provenance_api.pv_r3_claim_reviewer_assignment(text,text) to service_role;
grant execute on function provenance_api.pv_r3_complete_reviewer_assignment(uuid,text,text) to service_role;
grant execute on function provenance_api.pv_r3_register_evidence_content(text,text,text,bigint,text) to service_role;
grant execute on function provenance_api.pv_r3_record_redaction_review(text,text,uuid,text,text[],text[],boolean,text[]) to service_role;
