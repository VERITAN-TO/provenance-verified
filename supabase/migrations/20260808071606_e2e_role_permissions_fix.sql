begin;

-- Seed operator role permissions required for the E2E pilot workflow.
-- asset.create: authorize_and_audit check inside pv_e2e_create_asset.
-- review_case.update: authorize_and_audit check inside pv_e2e_evaluate_review.
-- 'evaluate' is not in the action CHECK constraint (read/create/update/delete/manage),
-- so pv_e2e_evaluate_review is updated below to use action='update' instead.
insert into public.pv_role_permissions (role, resource_type, action, active)
values
    ('operator', 'asset',       'create', true),
    ('operator', 'review_case', 'update', true)
on conflict (role, resource_type, action) do nothing;

-- Update pv_e2e_evaluate_review: use action='update' (not 'evaluate') so the
-- authorize_and_audit v_known_action check passes and the FK to pv_role_permissions
-- is satisfiable. Semantically correct: evaluation updates the review case record.
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
        p_action             := 'update',
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

grant execute on function public.pv_e2e_evaluate_review to authenticated;

commit;
