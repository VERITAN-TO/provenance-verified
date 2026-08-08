-- PROVENANCE.CX R8.1 R3 durable privacy-preserving public inquiry intake.
create table if not exists public.pv_public_inquiry_rate_windows (
  source_hash text not null check (source_hash ~ '^sha256:[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  used_value integer not null default 0,
  primary key(source_hash,window_started_at)
);
create table if not exists public.pv_public_inquiries (
  id uuid primary key default gen_random_uuid(),
  platform_tenant_id text not null references public.pv_tenants(id),
  mode text not null check (mode in ('contact','access')),
  contact_hash text not null check (contact_hash ~ '^sha256:[0-9a-f]{64}$'),
  organization_hash text not null check (organization_hash ~ '^sha256:[0-9a-f]{64}$'),
  encrypted_payload text not null,
  encryption_key_id text not null,
  vault_receipt_id text not null,
  consent_policy_version text not null,
  source_hash text not null check (source_hash ~ '^sha256:[0-9a-f]{64}$'),
  state text not null check (state in ('recorded','routed','acknowledged','closed','suppressed')) default 'recorded',
  case_reference text not null unique,
  created_at timestamptz not null default now()
);
create trigger pv_public_inquiries_immutable before update or delete on public.pv_public_inquiries
for each row execute function provenance_api.deny_mutation();
revoke all on public.pv_public_inquiries,public.pv_public_inquiry_rate_windows from anon,authenticated;

create or replace function provenance_api.pv_r3_record_public_inquiry(
  p_platform_tenant uuid,p_mode text,p_contact_hash text,p_organization_hash text,p_encrypted_payload text,
  p_encryption_key_id text,p_vault_receipt_id text,p_consent_policy_version text,p_source_hash text,p_limit integer default 5
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare v_window timestamptz; v_used int; v_inquiry public.pv_public_inquiries; v_notification public.pv_notifications; begin
  if p_mode not in ('contact','access') then raise exception 'PV_INQUIRY_MODE_INVALID'; end if;
  if p_contact_hash !~ '^sha256:[0-9a-f]{64}$' or p_organization_hash !~ '^sha256:[0-9a-f]{64}$' or p_source_hash !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_INQUIRY_DIGEST_INVALID'; end if;
  if length(p_encrypted_payload)<48 or p_encryption_key_id is null or p_vault_receipt_id is null then raise exception 'PV_INQUIRY_ENCRYPTION_REQUIRED'; end if;
  v_window:=date_trunc('hour',now());
  insert into public.pv_public_inquiry_rate_windows(source_hash,window_started_at,used_value) values(p_source_hash,v_window,1)
  on conflict(source_hash,window_started_at) do update set used_value=public.pv_public_inquiry_rate_windows.used_value+1 returning used_value into v_used;
  if v_used>p_limit then raise exception 'PV_INQUIRY_RATE_LIMITED'; end if;
  insert into public.pv_public_inquiries(platform_tenant_id,mode,contact_hash,organization_hash,encrypted_payload,encryption_key_id,vault_receipt_id,consent_policy_version,source_hash,case_reference)
  values(p_platform_tenant,p_mode,p_contact_hash,p_organization_hash,p_encrypted_payload,p_encryption_key_id,p_vault_receipt_id,p_consent_policy_version,p_source_hash,
    'INQ-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,16))) returning * into v_inquiry;
  insert into public.pv_notifications(tenant_id,event_id,channel,recipient,template_version,consent_reference,state,attempt_count,next_attempt_at)
  values(p_platform_tenant,'public-inquiry:'||v_inquiry.id,'webhook','inquiry-routing','public-inquiry-r3.1',p_consent_policy_version,'queued',0,now()) returning * into v_notification;
  return jsonb_build_object('inquiryId',v_inquiry.id,'caseReference',v_inquiry.case_reference,'state',v_inquiry.state,'notificationId',v_notification.id,'recordedAt',v_inquiry.created_at);
end $$;
revoke all on function provenance_api.pv_r3_record_public_inquiry(uuid,text,text,text,text,text,text,text,text,integer) from public,anon,authenticated;
grant execute on function provenance_api.pv_r3_record_public_inquiry(uuid,text,text,text,text,text,text,text,text,integer) to service_role;
