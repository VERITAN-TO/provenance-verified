-- E2E Workflow RPC Functions for Private Pilot
-- Exposes minimal correct private workflow boundary via PostgREST authenticated RPC.
-- All functions: public schema, SECURITY DEFINER, enforce pv_member_of + pv_aal2.
-- Calls real domain logic (provenance_api.authorize_and_audit) for audit trail.
-- SECURITY DEFINER runs as postgres superuser, which bypasses pv_assets WITH CHECK(false)
-- and pv_evidence_objects no-INSERT-policy per PostgreSQL FORCE RLS semantics:
-- FORCE RLS restricts table owners, not superusers with BYPASSRLS privilege.

begin;

-- W4: Create new pilot asset
-- pv_assets has WITH CHECK(false) blocking all authenticated user inserts.
create or replace function public.pv_e2e_create_asset(
    p_execution_id text,
    p_tenant_id    text,
    p_location_id  text,
    p_batch_id     text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
    v_asset_id     text        := p_execution_id || '-asset';
    v_actor_id     uuid;
    v_now          timestamptz := now();
    v_auth_outcome text;
    v_decision_id  uuid;
begin
    if not (pv_member_of(p_tenant_id) and pv_aal2()) then
        raise exception 'UNAUTHORIZED: requires active tenant membership and aal2 authentication'
            using errcode = '42501';
    end if;

    select m.actor_id into strict v_actor_id
    from pv_memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'active';

    select a.outcome, a.decision_id
      into v_auth_outcome, v_decision_id
    from provenance_api.authorize_and_audit(
        p_action             := 'create',
        p_resource_type      := 'asset',
        p_resource_id        := v_asset_id,
        p_resource_tenant_id := p_tenant_id
    ) a;

    if v_auth_outcome is distinct from 'ALLOW' then
        raise exception 'AUTHORIZATION_DENIED: outcome=%, decision=%',
            coalesce(v_auth_outcome, 'null'), v_decision_id
            using errcode = '42501';
    end if;

    insert into pv_assets (
        id, tenant_id, location_id, batch_id,
        serial, status, material, shape,
        treatment_disclosure, origin_claim, measurements,
        created_by, created_at, updated_at
    ) values (
        v_asset_id, p_tenant_id, p_location_id, p_batch_id,
        p_execution_id || '-SN001', 'pending', 'pilot-material', 'pilot-shape',
        'none', 'pilot-e2e-origin',
        '{"weight_ct": "1.0", "pilot": true}'::jsonb,
        v_actor_id::text, v_now, v_now
    );

    return jsonb_build_object(
        'asset_id',              v_asset_id,
        'tenant_id',             p_tenant_id,
        'actor_id',              v_actor_id,
        'authorization_outcome', v_auth_outcome,
        'decision_id',           v_decision_id,
        'execution_id',          p_execution_id
    );
end;
$$;

-- W5: Submit new evidence object for asset
-- pv_evidence_objects has no INSERT policy (INSERT blocked for all authenticated users).
create or replace function public.pv_e2e_submit_evidence(
    p_execution_id text,
    p_tenant_id    text,
    p_asset_id     text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
    v_evidence_id text        := p_execution_id || '-evidence';
    v_actor_id    uuid;
    v_now         timestamptz := now();
begin
    if not (pv_member_of(p_tenant_id) and pv_aal2()) then
        raise exception 'UNAUTHORIZED: requires active tenant membership and aal2 authentication'
            using errcode = '42501';
    end if;

    select m.actor_id into strict v_actor_id
    from pv_memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'active';

    insert into pv_evidence_objects (
        id, tenant_id, asset_id,
        type, label,
        source_organization, source_type, acquisition_method,
        issue_date, integrity_hash, storage_key, visibility, status,
        created_by, created_at
    ) values (
        v_evidence_id, p_tenant_id, p_asset_id,
        'pilot-origin',
        'Pilot E2E Evidence for ' || p_execution_id,
        'PILOT_TENANT_ALPHA', 'direct', 'pilot',
        v_now,
        'sha256:' || encode(sha256((p_execution_id || '-evidence-content')::bytea), 'hex'),
        'pilot/' || p_execution_id || '/evidence.dat',
        'internal', 'active',
        v_actor_id::text, v_now
    );

    return jsonb_build_object(
        'evidence_id',  v_evidence_id,
        'tenant_id',    p_tenant_id,
        'asset_id',     p_asset_id,
        'actor_id',     v_actor_id,
        'execution_id', p_execution_id
    );
end;
$$;

-- W6: Create new runtime claim
-- source_authority_id FK → pv_source_authorities; resolves tenant governing authority.
-- payload_digest must satisfy CHECK(payload_digest ~ '^sha256:[0-9a-f]{64}$').
create or replace function public.pv_e2e_create_claim(
    p_execution_id text,
    p_tenant_id    text,
    p_asset_id     text,
    p_evidence_id  text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
    v_claim_id            uuid;
    v_actor_id            uuid;
    v_source_authority_id uuid;
    v_now                 timestamptz := now();
    v_digest              text;
begin
    if not (pv_member_of(p_tenant_id) and pv_aal2()) then
        raise exception 'UNAUTHORIZED: requires active tenant membership and aal2 authentication'
            using errcode = '42501';
    end if;

    select m.actor_id into strict v_actor_id
    from pv_memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'active';

    select sa.id into strict v_source_authority_id
    from pv_source_authorities sa
    where sa.tenant_id = p_tenant_id
    order by sa.created_at
    limit 1;

    v_digest := 'sha256:' || encode(
        sha256((p_execution_id || ':' || p_asset_id || ':' || p_evidence_id)::bytea),
        'hex'
    );

    insert into pv_runtime_claims (
        tenant_id, source_authority_id,
        claim_key, claim_class, environment,
        owner_identity, state,
        observed_at, expires_at,
        payload, payload_digest
    ) values (
        p_tenant_id, v_source_authority_id,
        p_execution_id || '-claim-key',
        'UNVERIFIED', 'pilot',
        p_tenant_id || ':' || p_asset_id,
        'LIVE',
        v_now, v_now + interval '90 days',
        jsonb_build_object(
            'execution_id', p_execution_id,
            'asset_id',     p_asset_id,
            'evidence_id',  p_evidence_id,
            'pilot',        true
        ),
        v_digest
    ) returning id into v_claim_id;

    return jsonb_build_object(
        'claim_id',     v_claim_id,
        'tenant_id',    p_tenant_id,
        'asset_id',     p_asset_id,
        'evidence_id',  p_evidence_id,
        'claim_class',  'UNVERIFIED',
        'state',        'LIVE',
        'execution_id', p_execution_id
    );
end;
$$;

-- W7: Open new review case
-- pv_review_cases has many NOT NULL columns without defaults requiring application-layer creation.
create or replace function public.pv_e2e_open_review(
    p_execution_id text,
    p_tenant_id    text,
    p_asset_id     text,
    p_batch_id     text,
    p_claim_id     uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
    v_case_id text        := p_execution_id || '-review';
    v_now     timestamptz := now();
begin
    if not (pv_member_of(p_tenant_id) and pv_aal2()) then
        raise exception 'UNAUTHORIZED: requires active tenant membership and aal2 authentication'
            using errcode = '42501';
    end if;

    insert into pv_review_cases (
        id, tenant_id, batch_id, asset_id, status,
        conflict_clearance, custos_verdict,
        signing_key_status, registry_status, mark_authorization,
        opened_at, updated_at, service_level_due_at
    ) values (
        v_case_id, p_tenant_id, p_batch_id, p_asset_id, 'open',
        'pending',
        jsonb_build_object(
            'pilot',              true,
            'execution_id',       p_execution_id,
            'claim_id',           p_claim_id,
            'pending_evaluation', true
        ),
        'unavailable', 'pending', 'not_authorized',
        v_now, v_now, v_now + interval '7 days'
    );

    return jsonb_build_object(
        'review_case_id', v_case_id,
        'tenant_id',      p_tenant_id,
        'asset_id',       p_asset_id,
        'batch_id',       p_batch_id,
        'claim_id',       p_claim_id,
        'status',         'open',
        'execution_id',   p_execution_id
    );
end;
$$;

-- W8: Execute pilot review evaluation
-- Calls real domain authorization + audit trail via provenance_api.authorize_and_audit.
-- Records non-authoritative evaluation in custos_verdict (authoritative_issuance=false).
create or replace function public.pv_e2e_evaluate_review(
    p_execution_id text,
    p_tenant_id    text,
    p_case_id      text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, provenance_api
as $$
declare
    v_actor_id     uuid;
    v_now          timestamptz := now();
    v_auth_outcome text;
    v_decision_id  uuid;
begin
    if not (pv_member_of(p_tenant_id) and pv_aal2()) then
        raise exception 'UNAUTHORIZED: requires active tenant membership and aal2 authentication'
            using errcode = '42501';
    end if;

    select m.actor_id into strict v_actor_id
    from pv_memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.status = 'active';

    select a.outcome, a.decision_id
      into v_auth_outcome, v_decision_id
    from provenance_api.authorize_and_audit(
        p_action             := 'evaluate',
        p_resource_type      := 'review_case',
        p_resource_id        := p_case_id,
        p_resource_tenant_id := p_tenant_id
    ) a;

    if v_auth_outcome is distinct from 'ALLOW' then
        raise exception 'AUTHORIZATION_DENIED: outcome=%, decision=%',
            coalesce(v_auth_outcome, 'null'), v_decision_id
            using errcode = '42501';
    end if;

    update pv_review_cases set
        custos_verdict = custos_verdict || jsonb_build_object(
            'pilot_evaluation',          true,
            'authorization_decision_id', v_decision_id,
            'authorization_outcome',     v_auth_outcome,
            'pilot_verdict',             'UNVERIFIED',
            'authoritative_issuance',    false,
            'evaluated_at',              v_now::text,
            'actor_id',                  v_actor_id::text
        ),
        updated_at = v_now
    where id = p_case_id
      and tenant_id = p_tenant_id;

    return jsonb_build_object(
        'review_case_id',          p_case_id,
        'authorization_outcome',   v_auth_outcome,
        'decision_id',             v_decision_id,
        'pilot_verdict',           'UNVERIFIED',
        'authoritative_issuance',  false,
        'actor_id',                v_actor_id,
        'execution_id',            p_execution_id
    );
end;
$$;

grant execute on function public.pv_e2e_create_asset    to authenticated;
grant execute on function public.pv_e2e_submit_evidence to authenticated;
grant execute on function public.pv_e2e_create_claim    to authenticated;
grant execute on function public.pv_e2e_open_review     to authenticated;
grant execute on function public.pv_e2e_evaluate_review to authenticated;

commit;
