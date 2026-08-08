-- Revoke anon EXECUTE from all 5 pilot/E2E SECURITY DEFINER RPCs.
-- These functions enforce AAL2 + tenant membership internally, but anon EXECUTE
-- is unnecessary privileged attack surface (Supabase advisor 0028).
-- authenticated EXECUTE is retained: pilot workflow requires it.
-- Function bodies, search_path, and grants are otherwise unchanged.

revoke execute on function public.pv_e2e_create_asset(text, text, text, text) from anon;
revoke execute on function public.pv_e2e_create_claim(text, text, text, text) from anon;
revoke execute on function public.pv_e2e_evaluate_review(text, text, text) from anon;
revoke execute on function public.pv_e2e_open_review(text, text, text, text, uuid) from anon;
revoke execute on function public.pv_e2e_submit_evidence(text, text, text) from anon;
