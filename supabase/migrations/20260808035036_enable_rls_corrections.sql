-- enable-rls-corrections: forward-only extraction from production-preparation-hardening
--
-- CUSTODY NOTE: This migration was extracted from section G of
-- 20260807235900_production_preparation_hardening.sql, which was appended to
-- that file after its original application. Per forward-only migration doctrine,
-- post-application mutations to an already-applied migration are prohibited.
-- Section G is extracted here as a new independent forward migration.
--
-- These 42 tables received RLS policies through production corrections applied
-- during initial reconciliation (corrections B/E of hardening migration) but
-- were not explicitly given ENABLE ROW LEVEL SECURITY in the canonical source
-- migrations. This migration closes the source-replay gap so canonical local
-- replay produces 136/136 RLS coverage matching production.
--
-- All statements are idempotent (safe to run on tables already enabled).
-- Applied to production via supabase db push after extraction.

begin;

-- =============================================================================
-- G: Enable row level security on operational tables missing ENABLE from source
-- =============================================================================

alter table public.pv_accessibility_cases enable row level security;
alter table public.pv_alert_events enable row level security;
alter table public.pv_authority_key_registry enable row level security;
alter table public.pv_capacity_tests enable row level security;
alter table public.pv_category_l_controls enable row level security;
alter table public.pv_category_l_evidence enable row level security;
alter table public.pv_claim_protocols enable row level security;
alter table public.pv_consent_records enable row level security;
alter table public.pv_customer_acceptance enable row level security;
alter table public.pv_custos_reproductions enable row level security;
alter table public.pv_custos_runs enable row level security;
alter table public.pv_custos_samples enable row level security;
alter table public.pv_custos_verdict_events enable row level security;
alter table public.pv_denial_taxonomy enable row level security;
alter table public.pv_evidence_content_index enable row level security;
alter table public.pv_evidence_redaction_reviews enable row level security;
alter table public.pv_freshness_findings enable row level security;
alter table public.pv_freshness_runs enable row level security;
alter table public.pv_incidents enable row level security;
alter table public.pv_integrity_findings enable row level security;
alter table public.pv_knowledge_blocks enable row level security;
alter table public.pv_launch_communications enable row level security;
alter table public.pv_launch_gates enable row level security;
alter table public.pv_legal_localizations enable row level security;
alter table public.pv_provider_idempotency enable row level security;
alter table public.pv_public_claims enable row level security;
alter table public.pv_public_inquiries enable row level security;
alter table public.pv_public_inquiry_rate_windows enable row level security;
alter table public.pv_receipt_nonces enable row level security;
alter table public.pv_reviewer_assignments enable row level security;
alter table public.pv_reviewer_relationships enable row level security;
alter table public.pv_sandbox_tenants enable row level security;
alter table public.pv_service_catalog enable row level security;
alter table public.pv_service_health_samples enable row level security;
alter table public.pv_slo_measurements enable row level security;
alter table public.pv_slos enable row level security;
alter table public.pv_stabilization_daily_controls enable row level security;
alter table public.pv_status_incidents enable row level security;
alter table public.pv_synthetic_runs enable row level security;
alter table public.pv_trust_assertions enable row level security;
alter table public.pv_vulnerability_disclosures enable row level security;
alter table public.pv_workload_identities enable row level security;

commit;
