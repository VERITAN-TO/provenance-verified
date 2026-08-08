-- Remove PUBLIC EXECUTE grant from 5 pilot SECURITY DEFINER RPCs.
-- PostgreSQL grants EXECUTE to PUBLIC by default on function creation.
-- anon inherits from PUBLIC; revoking anon directly is insufficient.
-- authenticated and service_role retain their explicit grants (already in ACL).
-- Addresses Supabase advisor 0028_anon_security_definer_function_executable.

revoke execute on function public.pv_e2e_create_asset(text, text, text, text)    from public;
revoke execute on function public.pv_e2e_create_claim(text, text, text, text)    from public;
revoke execute on function public.pv_e2e_evaluate_review(text, text, text)       from public;
revoke execute on function public.pv_e2e_open_review(text, text, text, text, uuid) from public;
revoke execute on function public.pv_e2e_submit_evidence(text, text, text)       from public;
