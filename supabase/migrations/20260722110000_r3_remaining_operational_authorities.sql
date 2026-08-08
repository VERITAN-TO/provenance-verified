-- PROVENANCE.CX R8.1 R3 remaining local operational authorities.

create table if not exists public.pv_vulnerability_disclosures (
  id uuid primary key default gen_random_uuid(),
  reporter_reference text not null,
  encrypted_report text not null,
  encryption_key_id text not null,
  severity text not null check (severity in ('unknown','low','medium','high','critical')) default 'unknown',
  state text not null check (state in ('received','triaged','validated','remediating','resolved','duplicate','rejected')) default 'received',
  disclosure_policy_version text not null,
  acknowledgement_reference text not null unique,
  sla_due_at timestamptz not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create table if not exists public.pv_legal_localizations (
  id uuid primary key default gen_random_uuid(),
  document_key text not null,
  locale text not null,
  jurisdiction text not null,
  version text not null,
  governing_source_digest text not null check (governing_source_digest ~ '^sha256:[0-9a-f]{64}$'),
  legal_approver_identity text not null,
  approval_signature text not null,
  effective_at timestamptz not null,
  expires_at timestamptz not null,
  state text not null check (state in ('draft','approved','published','expired','withdrawn')),
  body jsonb not null,
  created_at timestamptz not null default now(),
  unique(document_key,locale,jurisdiction,version)
);
create table if not exists public.pv_trust_assertions (
  id uuid primary key default gen_random_uuid(),
  assertion_key text not null,
  environment text not null check (environment in ('sandbox','pilot','production')),
  statement text not null,
  evidence_ids text[] not null,
  owner_identity text not null,
  observed_at timestamptz not null,
  expires_at timestamptz not null,
  state text not null check (state in ('verified','stale','blocked','withdrawn')),
  public boolean not null default false,
  created_at timestamptz not null default now(),
  unique(assertion_key,environment,observed_at)
);

insert into public.pv_denial_taxonomy(code,severity,description,remediation_requirements,resubmission_allowed,policy_version,active) values
('IDENTITY_REQUIRED','P0','Authenticated actor and active tenant membership are required',array['authenticate','select-active-tenant'],true,'denial-r3.1',true),
('EVIDENCE_INELIGIBLE','P0','Evidence failed byte, custody, scanner, freshness or protocol eligibility',array['replace-or-remediate-evidence','rerun-eligibility'],true,'denial-r3.1',true),
('REVIEW_INDEPENDENCE_FAILED','P0','Reviewer independence or conflict clearance failed',array['assign-independent-reviewer','rerun-conflict-clearance'],true,'denial-r3.1',true),
('CUSTOS_DENIED','P0','Independent CUSTOS did not authorize the consequential action',array['resolve-reason-codes','submit-new-authority-request'],true,'denial-r3.1',true),
('ACTIVATION_REQUIRED','P0','Production activation record is missing, invalid, expired or mismatched',array['complete-g1-g5','obtain-signed-activation'],false,'denial-r3.1',true),
('REGISTRY_UNAVAILABLE','P0','Registry publication or revocation readiness is unavailable',array['restore-registry','reconcile-projection'],true,'denial-r3.1',true),
('MARK_SUPPRESSED','P1','Certification mark authority is unavailable or ineligible',array['restore-credential-and-license-eligibility'],true,'denial-r3.1',true)
on conflict(code) do update set severity=excluded.severity,description=excluded.description,remediation_requirements=excluded.remediation_requirements,resubmission_allowed=excluded.resubmission_allowed,policy_version=excluded.policy_version,active=true;

create trigger pv_vulnerability_disclosures_immutable before update or delete on public.pv_vulnerability_disclosures for each row execute function provenance_api.deny_mutation();
create trigger pv_legal_localizations_immutable before update or delete on public.pv_legal_localizations for each row execute function provenance_api.deny_mutation();
create trigger pv_trust_assertions_immutable before update or delete on public.pv_trust_assertions for each row execute function provenance_api.deny_mutation();

revoke all on public.pv_vulnerability_disclosures,public.pv_legal_localizations,public.pv_trust_assertions from anon,authenticated;

create or replace function provenance_api.pv_r3_grant_evidence_access(
 p_tenant text,p_evidence uuid,p_principal text,p_purpose text,p_expires_at timestamptz,p_signed_reference text
) returns public.pv_evidence_access_grants language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_evidence_access_grants; begin
 if p_expires_at<=now() or p_purpose='' or length(p_signed_reference)<16 then raise exception 'PV_EVIDENCE_ACCESS_INVALID'; end if;
 insert into public.pv_evidence_access_grants(tenant_id,evidence_id,principal_identity,purpose,expires_at,signed_access_reference)
 values(p_tenant,p_evidence,p_principal,p_purpose,p_expires_at,p_signed_reference) returning * into result;
 return result;
end $$;

create or replace function provenance_api.pv_r3_create_portable_bundle(
 p_tenant text,p_credential uuid,p_version int,p_public_key_reference text,p_protocol_version text,p_payload jsonb
) returns public.pv_portable_verification_bundles language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare result public.pv_portable_verification_bundles; digest text; begin
 if p_version<1 or p_public_key_reference='' or p_protocol_version='' or jsonb_array_length(coalesce(p_payload->'lifecycleEvents','[]'::jsonb))<1 then raise exception 'PV_PORTABLE_BUNDLE_INVALID'; end if;
 digest:='sha256:'||encode(extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256'),'hex');
 insert into public.pv_portable_verification_bundles(tenant_id,credential_id,credential_version,bundle_digest,public_key_reference,protocol_version,generated_at,bundle_payload)
 values(p_tenant,p_credential,p_version,digest,p_public_key_reference,p_protocol_version,now(),p_payload)
 on conflict(credential_id,credential_version) do nothing returning * into result;
 if result.id is null then select * into result from public.pv_portable_verification_bundles where credential_id=p_credential and credential_version=p_version; end if;
 return result;
end $$;

create or replace function provenance_api.pv_r3_publish_status_list(
 p_tenant text,p_version bigint,p_effective_at timestamptz,p_snapshot jsonb,p_signature text,p_key_id text
) returns public.pv_status_lists language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare result public.pv_status_lists; digest text; latest bigint; begin
 perform pg_advisory_xact_lock(hashtextextended('status-list:'||p_tenant,0));
 select coalesce(max(version),0) into latest from public.pv_status_lists where tenant_id=p_tenant;
 if p_version<>latest+1 or p_effective_at>now()+interval '5 minutes' or length(p_signature)<16 or p_key_id='' then raise exception 'PV_STATUS_LIST_INVALID'; end if;
 digest:='sha256:'||encode(extensions.digest(convert_to(p_snapshot::text,'UTF8'),'sha256'),'hex');
 insert into public.pv_status_lists(tenant_id,version,effective_at,list_digest,signature,key_id,snapshot) values(p_tenant,p_version,p_effective_at,digest,p_signature,p_key_id,p_snapshot) returning * into result;
 return result;
end $$;

create or replace function provenance_api.pv_r3_record_consent(
 p_subject text,p_jurisdiction text,p_purpose text,p_granted boolean,p_policy_version text,p_evidence jsonb
) returns public.pv_consent_records language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_consent_records; begin
 if p_subject='' or p_jurisdiction='' or p_purpose='' or p_policy_version='' or p_evidence='{}'::jsonb then raise exception 'PV_CONSENT_INVALID'; end if;
 insert into public.pv_consent_records(subject_reference,jurisdiction,purpose,granted,policy_version,evidence) values(p_subject,p_jurisdiction,p_purpose,p_granted,p_policy_version,p_evidence) returning * into result;
 return result;
end $$;

create or replace function provenance_api.pv_r3_record_task_event(
 p_tenant text,p_task text,p_attempt text,p_actor text,p_event_type text,p_payload jsonb
) returns public.pv_task_execution_events language plpgsql security definer set search_path=public,provenance_api,extensions,pg_temp as $$
declare previous text; digest text; result public.pv_task_execution_events; begin
 perform pg_advisory_xact_lock(hashtextextended(p_tenant||':'||p_task,0));
 select event_digest into previous from public.pv_task_execution_events where tenant_id=p_tenant and task_id=p_task order by id desc limit 1;
 previous:=coalesce(previous,'GENESIS');
 digest:='sha256:'||encode(extensions.digest(convert_to(jsonb_build_object('tenant',p_tenant,'task',p_task,'attempt',p_attempt,'actor',p_actor,'eventType',p_event_type,'payload',p_payload,'previous',previous)::text,'UTF8'),'sha256'),'hex');
 insert into public.pv_task_execution_events(tenant_id,task_id,attempt_id,actor_identity,event_type,payload,previous_event_digest,event_digest)
 values(p_tenant,p_task,p_attempt,p_actor,p_event_type,p_payload,previous,digest) returning * into result;
 return result;
end $$;

create or replace function provenance_api.pv_r3_record_launch_communication(
 p_tenant text,p_claim uuid,p_channel text,p_state text,p_embargo timestamptz,p_external_message text
) returns public.pv_launch_communications language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare claim public.pv_public_claims; result public.pv_launch_communications; begin
 select * into claim from public.pv_public_claims where id=p_claim and (tenant_id=p_tenant or tenant_id is null);
 if not found or claim.state not in ('approved','published') or claim.expires_at<=now() or claim.withdrawn_at is not null then raise exception 'PV_LAUNCH_CLAIM_NOT_AUTHORIZED'; end if;
 if p_state not in ('draft','approved','scheduled','published','withdrawn') then raise exception 'PV_LAUNCH_COMMUNICATION_STATE_INVALID'; end if;
 insert into public.pv_launch_communications(tenant_id,public_claim_id,channel,embargo_until,state,external_message_id)
 values(p_tenant,p_claim,p_channel,p_embargo,p_state,p_external_message) returning * into result;
 return result;
end $$;

revoke all on function provenance_api.pv_r3_grant_evidence_access(text,uuid,text,text,timestamptz,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_create_portable_bundle(text,uuid,int,text,text,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_publish_status_list(text,bigint,timestamptz,jsonb,text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_consent(text,text,text,boolean,text,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_task_event(text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_launch_communication(text,uuid,text,text,timestamptz,text) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_grant_evidence_access(text,uuid,text,text,timestamptz,text) to service_role;
grant execute on function provenance_api.pv_r3_create_portable_bundle(text,uuid,int,text,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_publish_status_list(text,bigint,timestamptz,jsonb,text,text) to service_role;
grant execute on function provenance_api.pv_r3_record_consent(text,text,text,boolean,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_task_event(text,text,text,text,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_launch_communication(text,uuid,text,text,timestamptz,text) to service_role;
