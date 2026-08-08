-- PROVENANCE.CX R8.1 R3 commercial, provisioning, billing, support and preference authority
-- All consequential mutations are service-role RPCs. Authenticated principals receive tenant-scoped reads only.

alter table public.pv_commercial_accounts
  add column if not exists account_name text,
  add column if not exists billing_profile_verified boolean not null default false,
  add column if not exists tenant_isolation_verified boolean not null default false,
  add column if not exists activated_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

alter table public.pv_contracts
  add column if not exists approver_identities text[] not null default '{}',
  add column if not exists approval_signatures text[] not null default '{}',
  add column if not exists product_codes text[] not null default '{}',
  add column if not exists jurisdiction text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.pv_support_cases
  add column if not exists assigned_team text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists resolved_at timestamptz;

alter table public.pv_commercial_remedies
  add column if not exists refund_id uuid,
  add column if not exists dual_control_receipt_ids text[] not null default '{}',
  add column if not exists evidence jsonb not null default '{}'::jsonb,
  add column if not exists state text not null default 'authorized',
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.pv_commercial_opportunities (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  account_id uuid,
  external_crm_id text,
  stage text not null check (stage in ('lead','qualified','proposal','contracting','won','lost')),
  product_codes text[] not null default '{}',
  estimated_value numeric(18,2) not null default 0 check (estimated_value >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  owner_identity text not null,
  next_action text,
  expected_close_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pv_contract_versions (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  contract_id uuid not null,
  version integer not null check (version > 0),
  status text not null check (status in ('draft','signed','active','terminated','expired')),
  document_digest text not null check (document_digest ~ '^sha256:[0-9a-f]{64}$'),
  approver_identities text[] not null,
  approval_signatures text[] not null,
  product_codes text[] not null,
  jurisdiction text not null,
  effective_at timestamptz,
  expires_at timestamptz,
  policy_version text not null,
  created_by text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id,contract_id,version),
  check (cardinality(approver_identities) >= 2),
  check (cardinality(approval_signatures) = cardinality(approver_identities)),
  check (cardinality(product_codes) > 0)
);

create table if not exists public.pv_entitlements (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  account_id uuid not null,
  contract_id uuid not null,
  product_code text not null,
  scope text not null,
  status text not null check (status in ('pending','active','suspended','revoked','expired')),
  starts_at timestamptz not null,
  expires_at timestamptz,
  provisioning_receipt_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,account_id,contract_id,product_code,scope)
);

create table if not exists public.pv_customer_provisioning_events (
  id bigint generated always as identity primary key,
  tenant_id text not null references public.pv_tenants(id),
  account_id uuid not null,
  contract_id uuid not null,
  event_type text not null check (event_type in ('requested','validated','provisioned','suspended','revoked','failed')),
  state text not null,
  tenant_isolation_verified boolean not null,
  billing_profile_verified boolean not null,
  entitlement_ids uuid[] not null default '{}',
  provisioning_receipt_id text not null,
  actor_identity text not null,
  evidence jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  unique (tenant_id,provisioning_receipt_id)
);

create table if not exists public.pv_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  account_id uuid not null,
  contract_id uuid not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  lines jsonb not null,
  subtotal_amount numeric(18,2) not null check (subtotal_amount >= 0),
  tax_amount numeric(18,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(18,2) not null check (total_amount >= 0),
  state text not null check (state in ('draft','issued','partially-paid','paid','void','overdue')),
  due_at timestamptz not null,
  issued_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (round(subtotal_amount + tax_amount,2) = round(total_amount,2))
);

create table if not exists public.pv_payment_references (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  invoice_id uuid not null,
  amount numeric(18,2) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  provider_reference text not null,
  settled boolean not null,
  idempotency_key text not null,
  received_at timestamptz not null default now(),
  unique (tenant_id,provider_reference),
  unique (tenant_id,idempotency_key)
);

create table if not exists public.pv_refunds (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  payment_id uuid not null,
  amount numeric(18,2) not null check (amount > 0),
  reason text not null,
  approver_identities text[] not null,
  approval_signatures text[] not null,
  state text not null check (state in ('authorized','submitted','completed','failed','cancelled')),
  provider_reference text,
  authorization_receipt_id text not null,
  created_at timestamptz not null default now(),
  check (cardinality(approver_identities) >= 2),
  check (cardinality(approval_signatures) = cardinality(approver_identities))
);

create table if not exists public.pv_billing_reconciliations (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  window_start timestamptz not null,
  window_end timestamptz not null,
  invoice_total numeric(18,2) not null,
  payment_total numeric(18,2) not null,
  refund_total numeric(18,2) not null,
  variance numeric(18,2) not null,
  state text not null check (state in ('pass','blocked','investigating','resolved')),
  evidence jsonb not null,
  signed_receipt_id text not null,
  created_at timestamptz not null default now(),
  check (window_end > window_start)
);

create table if not exists public.pv_support_case_events (
  id bigint generated always as identity primary key,
  tenant_id text not null references public.pv_tenants(id),
  support_case_id uuid not null,
  sequence integer not null check (sequence > 0),
  event_type text not null,
  from_state text not null,
  to_state text not null,
  actor_identity text not null,
  evidence jsonb not null,
  occurred_at timestamptz not null default now(),
  unique (tenant_id,support_case_id,sequence)
);

create table if not exists public.pv_preference_records (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null references public.pv_tenants(id),
  subject_reference text not null,
  jurisdiction text not null,
  purpose text not null,
  channel text not null,
  granted boolean not null,
  policy_version text not null,
  evidence_digest text not null check (evidence_digest ~ '^sha256:[0-9a-f]{64}$'),
  supersedes_id uuid references public.pv_preference_records(id),
  recorded_at timestamptz not null default now(),
  withdrawn_at timestamptz
);

-- Enforce same-tenant references at the database boundary.
do $$ begin
  if not exists (select 1 from pg_constraint where conname='pv_commercial_accounts_tenant_id_id_key') then
    alter table public.pv_commercial_accounts add constraint pv_commercial_accounts_tenant_id_id_key unique (tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_contracts_tenant_id_id_key') then
    alter table public.pv_contracts add constraint pv_contracts_tenant_id_id_key unique (tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_support_cases_tenant_id_id_key') then
    alter table public.pv_support_cases add constraint pv_support_cases_tenant_id_id_key unique (tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_invoices_tenant_id_id_key') then
    alter table public.pv_invoices add constraint pv_invoices_tenant_id_id_key unique (tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_payment_references_tenant_id_id_key') then
    alter table public.pv_payment_references add constraint pv_payment_references_tenant_id_id_key unique (tenant_id,id);
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='pv_contracts_tenant_account_fk') then
    alter table public.pv_contracts add constraint pv_contracts_tenant_account_fk foreign key (tenant_id,account_id) references public.pv_commercial_accounts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_opportunities_tenant_account_fk') then
    alter table public.pv_commercial_opportunities add constraint pv_opportunities_tenant_account_fk foreign key (tenant_id,account_id) references public.pv_commercial_accounts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_contract_versions_tenant_contract_fk') then
    alter table public.pv_contract_versions add constraint pv_contract_versions_tenant_contract_fk foreign key (tenant_id,contract_id) references public.pv_contracts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_entitlements_tenant_account_fk') then
    alter table public.pv_entitlements add constraint pv_entitlements_tenant_account_fk foreign key (tenant_id,account_id) references public.pv_commercial_accounts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_entitlements_tenant_contract_fk') then
    alter table public.pv_entitlements add constraint pv_entitlements_tenant_contract_fk foreign key (tenant_id,contract_id) references public.pv_contracts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_provisioning_tenant_account_fk') then
    alter table public.pv_customer_provisioning_events add constraint pv_provisioning_tenant_account_fk foreign key (tenant_id,account_id) references public.pv_commercial_accounts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_provisioning_tenant_contract_fk') then
    alter table public.pv_customer_provisioning_events add constraint pv_provisioning_tenant_contract_fk foreign key (tenant_id,contract_id) references public.pv_contracts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_invoices_tenant_account_fk') then
    alter table public.pv_invoices add constraint pv_invoices_tenant_account_fk foreign key (tenant_id,account_id) references public.pv_commercial_accounts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_invoices_tenant_contract_fk') then
    alter table public.pv_invoices add constraint pv_invoices_tenant_contract_fk foreign key (tenant_id,contract_id) references public.pv_contracts(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_payments_tenant_invoice_fk') then
    alter table public.pv_payment_references add constraint pv_payments_tenant_invoice_fk foreign key (tenant_id,invoice_id) references public.pv_invoices(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_refunds_tenant_payment_fk') then
    alter table public.pv_refunds add constraint pv_refunds_tenant_payment_fk foreign key (tenant_id,payment_id) references public.pv_payment_references(tenant_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pv_support_events_tenant_case_fk') then
    alter table public.pv_support_case_events add constraint pv_support_events_tenant_case_fk foreign key (tenant_id,support_case_id) references public.pv_support_cases(tenant_id,id);
  end if;
end $$;

-- Append-only commercial evidence.
do $$
declare rel text; begin
  foreach rel in array array[
    'pv_contract_versions','pv_customer_provisioning_events','pv_payment_references','pv_refunds',
    'pv_billing_reconciliations','pv_support_case_events','pv_preference_records'
  ] loop
    execute format('drop trigger if exists %I_immutable on public.%I',rel,rel);
    execute format('create trigger %I_immutable before update or delete on public.%I for each row execute function provenance_api.deny_mutation()',rel,rel);
  end loop;
end $$;

-- Tenant-scoped reads; no authenticated direct mutations.
do $$
declare rel text; begin
  foreach rel in array array[
    'pv_commercial_opportunities','pv_contract_versions','pv_entitlements','pv_customer_provisioning_events',
    'pv_invoices','pv_payment_references','pv_refunds','pv_billing_reconciliations','pv_support_case_events','pv_preference_records'
  ] loop
    execute format('alter table public.%I enable row level security',rel);
    execute format('alter table public.%I force row level security',rel);
    execute format('revoke insert, update, delete on public.%I from anon,authenticated',rel);
    execute format('drop policy if exists %I_tenant_read on public.%I',rel,rel);
    execute format('create policy %I_tenant_read on public.%I for select to authenticated using (tenant_id=provenance_api.current_tenant_id())',rel,rel);
  end loop;
end $$;

create or replace function provenance_api.pv_r3_create_contract_authority(
  p_tenant text,p_contract uuid,p_account uuid,p_status text,p_document_digest text,p_approvers text[],p_signatures text[],
  p_product_codes text[],p_jurisdiction text,p_policy_version text,p_effective_at timestamptz,p_expires_at timestamptz,p_actor text
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare c public.pv_contracts; cv public.pv_contract_versions;
begin
  if not exists(select 1 from public.pv_commercial_accounts where tenant_id=p_tenant and id=p_account) then raise exception 'PV_ACCOUNT_NOT_FOUND'; end if;
  if p_status not in ('signed','active') or p_document_digest !~ '^sha256:[0-9a-f]{64}$' then raise exception 'PV_CONTRACT_AUTHORITY_INVALID'; end if;
  if cardinality(array(select distinct x from unnest(p_approvers) x))<2 or cardinality(p_approvers)<>cardinality(p_signatures) then raise exception 'PV_CONTRACT_DUAL_CONTROL_REQUIRED'; end if;
  if coalesce(cardinality(p_product_codes),0)=0 or coalesce(trim(p_jurisdiction),'')='' or coalesce(trim(p_policy_version),'')='' then raise exception 'PV_CONTRACT_SCOPE_REQUIRED'; end if;
  if p_effective_at is null or (p_expires_at is not null and p_expires_at<=p_effective_at) then raise exception 'PV_CONTRACT_EFFECTIVE_WINDOW_INVALID'; end if;
  insert into public.pv_contracts(id,tenant_id,account_id,status,effective_at,expires_at,document_digest,approver_identities,approval_signatures,product_codes,jurisdiction,created_at,updated_at)
  values(p_contract,p_tenant,p_account,p_status,p_effective_at,p_expires_at,p_document_digest,p_approvers,p_signatures,p_product_codes,p_jurisdiction,now(),now()) returning * into c;
  insert into public.pv_contract_versions(tenant_id,contract_id,version,status,document_digest,approver_identities,approval_signatures,product_codes,jurisdiction,effective_at,expires_at,policy_version,created_by)
  values(p_tenant,p_contract,1,p_status,p_document_digest,p_approvers,p_signatures,p_product_codes,p_jurisdiction,p_effective_at,p_expires_at,p_policy_version,p_actor) returning * into cv;
  update public.pv_commercial_accounts set contract_state=p_status,updated_at=now() where tenant_id=p_tenant and id=p_account;
  return jsonb_build_object('contract',to_jsonb(c),'version',to_jsonb(cv));
end $$;

create or replace function provenance_api.pv_r3_issue_invoice(
  p_tenant text,p_invoice uuid,p_account uuid,p_contract uuid,p_currency text,p_lines jsonb,p_tax_amount numeric,p_total_amount numeric,p_due_at timestamptz
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare c public.pv_contracts; subtotal numeric; result public.pv_invoices;
begin
  select * into c from public.pv_contracts where tenant_id=p_tenant and id=p_contract and account_id=p_account;
  if not found or c.status not in ('signed','active') or c.effective_at is null or c.effective_at>now() or (c.expires_at is not null and c.expires_at<=now()) then raise exception 'PV_INVOICE_CONTRACT_NOT_AUTHORIZED'; end if;
  if p_currency !~ '^[A-Z]{3}$' or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 or p_tax_amount<0 then raise exception 'PV_INVOICE_INVALID'; end if;
  if exists(select 1 from jsonb_array_elements(p_lines) x where coalesce(trim(x->>'code'),'')='' or (x->>'quantity')::numeric<=0 or (x->>'unitAmount')::numeric<0) then raise exception 'PV_INVOICE_LINES_INVALID'; end if;
  select round(coalesce(sum((x->>'quantity')::numeric*(x->>'unitAmount')::numeric),0),2) into subtotal from jsonb_array_elements(p_lines) x;
  if abs(round(subtotal+p_tax_amount,2)-round(p_total_amount,2))>0.005 then raise exception 'PV_INVOICE_TOTAL_MISMATCH'; end if;
  insert into public.pv_invoices(id,tenant_id,account_id,contract_id,currency,lines,subtotal_amount,tax_amount,total_amount,state,due_at,issued_at)
  values(p_invoice,p_tenant,p_account,p_contract,p_currency,p_lines,subtotal,p_tax_amount,p_total_amount,'issued',p_due_at,now()) returning * into result;
  return to_jsonb(result);
end $$;

create or replace function provenance_api.pv_r3_activate_commercial_account(
  p_tenant text,p_account uuid,p_contract uuid,p_entitlements text[],p_receipt text,p_actor text,
  p_tenant_isolation_verified boolean,p_billing_profile_verified boolean,p_evidence jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare a public.pv_commercial_accounts; c public.pv_contracts; cv public.pv_contract_versions; code text; ids uuid[]:='{}'; eid uuid; event_id bigint;
begin
  if not p_tenant_isolation_verified or not p_billing_profile_verified then raise exception 'PV_PROVISIONING_PREREQUISITE_FAILED'; end if;
  if coalesce(cardinality(p_entitlements),0)=0 or coalesce(p_receipt,'')='' then raise exception 'PV_PROVISIONING_SCOPE_REQUIRED'; end if;
  select * into a from public.pv_commercial_accounts where tenant_id=p_tenant and id=p_account for update;
  if not found then raise exception 'PV_ACCOUNT_NOT_FOUND'; end if;
  select * into c from public.pv_contracts where tenant_id=p_tenant and id=p_contract and account_id=p_account for update;
  if not found then raise exception 'PV_CONTRACT_NOT_FOUND'; end if;
  select * into cv from public.pv_contract_versions where tenant_id=p_tenant and contract_id=p_contract order by version desc limit 1;
  if not found or cv.status not in ('signed','active') or cv.effective_at is null or cv.effective_at>now() or (cv.expires_at is not null and cv.expires_at<=now()) then raise exception 'PV_CONTRACT_NOT_AUTHORIZED'; end if;
  if cardinality(array(select distinct x from unnest(cv.approver_identities) x))<2 or cardinality(cv.approver_identities)<>cardinality(cv.approval_signatures) then raise exception 'PV_CONTRACT_DUAL_CONTROL_REQUIRED'; end if;
  foreach code in array p_entitlements loop
    if not code=any(cv.product_codes) then raise exception 'PV_ENTITLEMENT_OUTSIDE_CONTRACT:%',code; end if;
    insert into public.pv_entitlements(tenant_id,account_id,contract_id,product_code,scope,status,starts_at,expires_at,provisioning_receipt_id)
    values(p_tenant,p_account,p_contract,code,code,'active',greatest(now(),coalesce(cv.effective_at,now())),cv.expires_at,p_receipt)
    on conflict(tenant_id,account_id,contract_id,product_code,scope) do update set
      status='active', starts_at=excluded.starts_at, expires_at=excluded.expires_at,
      provisioning_receipt_id=excluded.provisioning_receipt_id, updated_at=now()
    returning id into eid;
    ids:=array_append(ids,eid);
  end loop;
  update public.pv_commercial_accounts set lifecycle_state='active',contract_state='active',provisioning_state='provisioned',
    billing_profile_verified=true,tenant_isolation_verified=true,activated_at=coalesce(activated_at,now()),updated_at=now() where id=p_account;
  insert into public.pv_customer_provisioning_events(tenant_id,account_id,contract_id,event_type,state,tenant_isolation_verified,billing_profile_verified,entitlement_ids,provisioning_receipt_id,actor_identity,evidence)
  values(p_tenant,p_account,p_contract,'provisioned','active',true,true,ids,p_receipt,p_actor,p_evidence) returning id into event_id;
  return jsonb_build_object('accountId',p_account,'contractId',p_contract,'state','active','entitlementIds',ids,'eventId',event_id,'receiptId',p_receipt);
end $$;

create or replace function provenance_api.pv_r3_record_payment(
  p_tenant text,p_invoice uuid,p_payment uuid,p_amount numeric,p_currency text,p_provider_reference text,p_idempotency_key text
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare inv public.pv_invoices; existing public.pv_payment_references; paid numeric; next_state text;
begin
  select * into existing from public.pv_payment_references where tenant_id=p_tenant and idempotency_key=p_idempotency_key;
  if found then return to_jsonb(existing); end if;
  select * into inv from public.pv_invoices where tenant_id=p_tenant and id=p_invoice for update;
  if not found then raise exception 'PV_INVOICE_NOT_FOUND'; end if;
  if inv.state in ('draft','void') then raise exception 'PV_INVOICE_NOT_PAYABLE'; end if;
  if inv.currency<>p_currency or p_amount<=0 then raise exception 'PV_PAYMENT_INVALID'; end if;
  select coalesce(sum(amount),0) into paid from public.pv_payment_references where tenant_id=p_tenant and invoice_id=p_invoice and settled;
  if paid+p_amount>inv.total_amount then raise exception 'PV_PAYMENT_EXCEEDS_BALANCE'; end if;
  insert into public.pv_payment_references(id,tenant_id,invoice_id,amount,currency,provider_reference,settled,idempotency_key)
  values(p_payment,p_tenant,p_invoice,p_amount,p_currency,p_provider_reference,true,p_idempotency_key) returning * into existing;
  next_state:=case when paid+p_amount=inv.total_amount then 'paid' else 'partially-paid' end;
  update public.pv_invoices set state=next_state,updated_at=now() where id=p_invoice;
  return jsonb_build_object('payment',to_jsonb(existing),'invoiceState',next_state,'remaining',inv.total_amount-paid-p_amount);
end $$;

create or replace function provenance_api.pv_r3_authorize_refund(
  p_tenant text,p_refund uuid,p_payment uuid,p_amount numeric,p_reason text,p_approvers text[],p_signatures text[],p_receipt text
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare pay public.pv_payment_references; refunded numeric; result public.pv_refunds;
begin
  select * into pay from public.pv_payment_references where tenant_id=p_tenant and id=p_payment and settled for update;
  if not found then raise exception 'PV_SETTLED_PAYMENT_NOT_FOUND'; end if;
  if p_amount<=0 or coalesce(trim(p_reason),'')='' or coalesce(trim(p_receipt),'')='' then raise exception 'PV_REFUND_INVALID'; end if;
  if cardinality(array(select distinct x from unnest(p_approvers) x))<2 or cardinality(p_approvers)<>cardinality(p_signatures) then raise exception 'PV_REFUND_DUAL_CONTROL_REQUIRED'; end if;
  select coalesce(sum(amount),0) into refunded from public.pv_refunds where tenant_id=p_tenant and payment_id=p_payment and state in ('authorized','submitted','completed');
  if refunded+p_amount>pay.amount then raise exception 'PV_REFUND_EXCEEDS_PAYMENT'; end if;
  insert into public.pv_refunds(id,tenant_id,payment_id,amount,reason,approver_identities,approval_signatures,state,authorization_receipt_id)
  values(p_refund,p_tenant,p_payment,p_amount,p_reason,p_approvers,p_signatures,'authorized',p_receipt) returning * into result;
  return to_jsonb(result);
end $$;

create or replace function provenance_api.pv_r3_transition_support_case(
  p_tenant text,p_case uuid,p_to_state text,p_actor text,p_evidence jsonb
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare c public.pv_support_cases; seq integer; allowed boolean:=false; event_id bigint;
begin
  select * into c from public.pv_support_cases where tenant_id=p_tenant and id=p_case for update;
  if not found then raise exception 'PV_SUPPORT_CASE_NOT_FOUND'; end if;
  allowed:=case c.state
    when 'open' then p_to_state in ('triaged','escalated','resolved')
    when 'triaged' then p_to_state in ('investigating','escalated','resolved')
    when 'investigating' then p_to_state in ('escalated','resolved')
    when 'escalated' then p_to_state in ('investigating','resolved')
    when 'resolved' then p_to_state in ('closed','reopened')
    when 'closed' then p_to_state='reopened'
    when 'reopened' then p_to_state in ('triaged','escalated')
    else false end;
  if not allowed then raise exception 'PV_SUPPORT_TRANSITION_INVALID:%->%',c.state,p_to_state; end if;
  select coalesce(max(sequence),0)+1 into seq from public.pv_support_case_events where tenant_id=p_tenant and support_case_id=p_case;
  insert into public.pv_support_case_events(tenant_id,support_case_id,sequence,event_type,from_state,to_state,actor_identity,evidence)
  values(p_tenant,p_case,seq,'state-transition',c.state,p_to_state,p_actor,p_evidence) returning id into event_id;
  update public.pv_support_cases set state=p_to_state,updated_at=now(),resolved_at=case when p_to_state in ('resolved','closed') then now() else null end where id=p_case;
  return jsonb_build_object('caseId',p_case,'fromState',c.state,'toState',p_to_state,'sequence',seq,'eventId',event_id);
end $$;

create or replace function provenance_api.pv_r3_record_commercial_remedy(
  p_tenant text,p_remedy uuid,p_support_case uuid,p_refund uuid,p_remedy_type text,p_financial_state text,
  p_credential_action text,p_credential_reason text,p_dual_receipts text[],p_evidence jsonb
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare result public.pv_commercial_remedies;
begin
  if cardinality(array(select distinct x from unnest(p_dual_receipts) x))<2 then raise exception 'PV_REMEDY_DUAL_CONTROL_REQUIRED'; end if;
  if p_credential_action not in ('none','investigate','suspend','reactivate','revoke','correct') then raise exception 'PV_REMEDY_CREDENTIAL_ACTION_INVALID'; end if;
  if p_financial_state not in ('not-required','pending','approved','completed','denied') then raise exception 'PV_REMEDY_FINANCIAL_STATE_INVALID'; end if;
  if p_credential_action<>'none' and coalesce(trim(p_credential_reason),'')='' then raise exception 'PV_REMEDY_CREDENTIAL_REASON_REQUIRED'; end if;
  if not exists(select 1 from public.pv_support_cases where tenant_id=p_tenant and id=p_support_case) then raise exception 'PV_SUPPORT_CASE_NOT_FOUND'; end if;
  if p_refund is not null and not exists(select 1 from public.pv_refunds where tenant_id=p_tenant and id=p_refund) then raise exception 'PV_REFUND_NOT_FOUND'; end if;
  insert into public.pv_commercial_remedies(id,tenant_id,support_case_id,refund_id,remedy_type,financial_state,credential_action,credential_action_reason,dual_control_receipt_ids,evidence,state)
  values(p_remedy,p_tenant,p_support_case,p_refund,p_remedy_type,p_financial_state,p_credential_action,p_credential_reason,p_dual_receipts,p_evidence,'authorized') returning * into result;
  return to_jsonb(result);
end $$;

create or replace function provenance_api.pv_r3_record_billing_reconciliation(
  p_tenant text,p_id uuid,p_window_start timestamptz,p_window_end timestamptz,p_invoice_total numeric,
  p_payment_total numeric,p_refund_total numeric,p_evidence jsonb,p_receipt text
) returns jsonb language plpgsql security definer set search_path=public,provenance_api,pg_temp as $$
declare variance numeric; state text; result public.pv_billing_reconciliations;
begin
  if p_window_end<=p_window_start or coalesce(trim(p_receipt),'')='' then raise exception 'PV_RECONCILIATION_INVALID'; end if;
  variance:=round(p_invoice_total-(p_payment_total-p_refund_total),2);
  state:=case when variance=0 then 'pass' else 'blocked' end;
  insert into public.pv_billing_reconciliations(id,tenant_id,window_start,window_end,invoice_total,payment_total,refund_total,variance,state,evidence,signed_receipt_id)
  values(p_id,p_tenant,p_window_start,p_window_end,p_invoice_total,p_payment_total,p_refund_total,variance,state,p_evidence,p_receipt) returning * into result;
  return to_jsonb(result);
end $$;

revoke all on function provenance_api.pv_r3_create_contract_authority(text,uuid,uuid,text,text,text[],text[],text[],text,text,timestamptz,timestamptz,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_issue_invoice(text,uuid,uuid,uuid,text,jsonb,numeric,numeric,timestamptz) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_activate_commercial_account(text,uuid,uuid,text[],text,text,boolean,boolean,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_payment(text,uuid,uuid,numeric,text,text,text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_authorize_refund(text,uuid,uuid,numeric,text,text[],text[],text) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_transition_support_case(text,uuid,text,text,jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_commercial_remedy(text,uuid,uuid,uuid,text,text,text,text,text[],jsonb) from public,anon,authenticated;
revoke all on function provenance_api.pv_r3_record_billing_reconciliation(text,uuid,timestamptz,timestamptz,numeric,numeric,numeric,jsonb,text) from public,anon,authenticated;

grant execute on function provenance_api.pv_r3_create_contract_authority(text,uuid,uuid,text,text,text[],text[],text[],text,text,timestamptz,timestamptz,text) to service_role;
grant execute on function provenance_api.pv_r3_issue_invoice(text,uuid,uuid,uuid,text,jsonb,numeric,numeric,timestamptz) to service_role;
grant execute on function provenance_api.pv_r3_activate_commercial_account(text,uuid,uuid,text[],text,text,boolean,boolean,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_payment(text,uuid,uuid,numeric,text,text,text) to service_role;
grant execute on function provenance_api.pv_r3_authorize_refund(text,uuid,uuid,numeric,text,text[],text[],text) to service_role;
grant execute on function provenance_api.pv_r3_transition_support_case(text,uuid,text,text,jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_commercial_remedy(text,uuid,uuid,uuid,text,text,text,text,text[],jsonb) to service_role;
grant execute on function provenance_api.pv_r3_record_billing_reconciliation(text,uuid,timestamptz,timestamptz,numeric,numeric,numeric,jsonb,text) to service_role;
