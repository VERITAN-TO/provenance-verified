#!/usr/bin/env python3
"""Dependency-free static verification for A1 Wave 1 Slice 1 source recovery."""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "database/012_wave1_slice1_tenant_safe_foundation.sql"
BOOT = ROOT / "database/003_5_wave1_tenant_context_bootstrap.sql"
MIRROR_MAIN = ROOT / "supabase/migrations/20260725050000_wave1_slice1_tenant_safe_foundation.sql"
MIRROR_BOOT = ROOT / "supabase/migrations/20260722035000_wave1_tenant_context_bootstrap.sql"
TYPES = ROOT / "database/generated/wave1-slice1-database.types.ts"
TESTS = ROOT / "database/tests/012_wave1_slice1_foundation.sql"
ROLLBACK_MAIN = ROOT / "ROLLBACK/012_wave1_slice1_tenant_safe_foundation.down.sql"
ROLLBACK_BOOT = ROOT / "ROLLBACK/003_5_wave1_tenant_context_bootstrap.down.sql"

EXPECTED_BASE = "10d95ebbd90f1e489efd859987cfaeafb3a5a6fc"
EXPECTED_BRANCH = "a1/wave1-slice1-foundation-r1"
EXPECTED_LOCK = "c313eedd8a9695b27f2bfff37c0834b64fd32263e653fbf073b1900f112053da"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def check(name: str, ok: bool, detail: str, results: list[dict[str, object]]) -> None:
    results.append({"name": name, "pass": bool(ok), "detail": detail})


def main() -> int:
    results: list[dict[str, object]] = []
    main_sql = MAIN.read_text()
    boot_sql = BOOT.read_text()
    tests_sql = TESTS.read_text()
    types = TYPES.read_text()

    check("base-commit", git("merge-base", "HEAD", EXPECTED_BASE) == EXPECTED_BASE, EXPECTED_BASE, results)
    check("branch", git("branch", "--show-current") == EXPECTED_BRANCH, EXPECTED_BRANCH, results)
    check("lockfile", sha(ROOT / "package-lock.json") == EXPECTED_LOCK, EXPECTED_LOCK, results)
    check("bootstrap-mirror", BOOT.read_bytes() == MIRROR_BOOT.read_bytes(), sha(BOOT), results)
    check("main-mirror", MAIN.read_bytes() == MIRROR_MAIN.read_bytes(), sha(MAIN), results)
    check("migration-order", "20260722035000" < "20260722040000" < "20260725050000", "003.5 before frozen 004; 012 after 011", results)

    changed = git("diff", "--name-only", EXPECTED_BASE).splitlines()
    allowed = (
        "database/", "supabase/migrations/", "ROLLBACK/",
    )
    check("path-ownership", all(p.startswith(allowed) for p in changed), json.dumps(changed), results)

    for table in [
        "pv_actors", "pv_role_registry", "pv_role_permissions",
        "pv_purchaser_relationships", "pv_authorization_audit_events",
        "pv_idempotency_keys",
    ]:
        check(f"table:{table}", f"create table if not exists public.{table}" in main_sql, table, results)

    signatures = {
        "resolve_actor_identity": r"create or replace function provenance_api\.resolve_actor_identity\(\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)",
        "derive_tenant_context": r"create or replace function provenance_api\.derive_tenant_context\(\s*p_tenant_hint text default null,\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)",
        "authorize_and_audit": r"create or replace function provenance_api\.authorize_and_audit\(\s*p_action text,\s*p_resource_type text,\s*p_resource_id text,\s*p_resource_tenant_id text,\s*p_tenant_hint text default null,\s*p_expected_authority_version bigint default null,\s*p_correlation_id uuid default gen_random_uuid\(\),\s*p_metadata_digest text default null\s*\)",
        "claim_idempotency_key": r"create or replace function provenance_api\.claim_idempotency_key\(\s*p_key text,\s*p_operation text,\s*p_request_digest text,\s*p_tenant_hint text default null,\s*p_expires_at timestamptz default \(now\(\) \+ interval '24 hours'\),\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)",
        "complete_idempotency_key": r"create or replace function provenance_api\.complete_idempotency_key\(\s*p_key text,\s*p_operation text,\s*p_request_digest text,\s*p_result_reference text,\s*p_tenant_hint text default null,\s*p_correlation_id uuid default gen_random_uuid\(\)\s*\)",
    }
    for name, pattern in signatures.items():
        check(f"rpc:{name}", bool(re.search(pattern, main_sql, re.S | re.I)), name, results)

    for role in ["organization_owner", "organization_admin", "operator", "reviewer", "member"]:
        check(f"role:{role}", f"('{role}'" in main_sql, role, results)
    check("purchaser-not-role", "('purchaser'" not in main_sql, "purchaser excluded", results)
    check("no-provisional", "VERIFICATION_RESULT" not in main_sql or "intentionally absent" in main_sql, "W1-C10 absent", results)
    check("no-user-metadata", "raw_user_meta_data" not in main_sql and "user_metadata" not in main_sql, "no user-editable auth authority", results)
    check("no-client-guc", "current_setting('app.tenant_id'" not in main_sql, "no client tenant GUC in 012", results)

    for table in [
        "pv_actors", "pv_role_registry", "pv_role_permissions",
        "pv_purchaser_relationships", "pv_authorization_audit_events",
        "pv_idempotency_keys", "pv_tenants", "pv_memberships", "pv_assets",
    ]:
        check(f"force-rls:{table}", f"alter table public.{table} force row level security" in main_sql, table, results)

    check("explicit-asset-crud", all(f"pv_assets_wave1_{op}" in main_sql for op in ["select","insert_deny","update_deny","delete_deny"]), "four policies", results)
    check("no-permissive-true", "using (true)" not in main_sql.lower() and "with check (true)" not in main_sql.lower(), "no broad policy", results)
    check("service-role-revoked", "from public, anon, authenticated, service_role" in main_sql, "explicit RPC/table revocation", results)
    check("audit-row-guard", "before update or delete on public.pv_authorization_audit_events" in main_sql, "row guard", results)
    check("audit-truncate-guard", "before truncate on public.pv_authorization_audit_events" in main_sql, "truncate guard", results)
    check("idempotency-persistent", "create table if not exists public.pv_idempotency_keys" in main_sql and "primary key (tenant_id, idempotency_key)" in main_sql, "durable tenant key", results)
    check("rollback-main", "PV_WAVE1_ROLLBACK_DURABLE_DATA_PRESENT" in ROLLBACK_MAIN.read_text(), "fail-closed durable-data guard", results)
    check("rollback-bootstrap", "PV_BOOTSTRAP_ROLLBACK_DEPENDENCY_PRESENT" in ROLLBACK_BOOT.read_text(), "dependency guard", results)
    check("generated-types", all(name in types for name in signatures), "five RPC types", results)

    acceptance = sorted(set(re.findall(r"TEST-ID:\s*(S1-AT-\d{3})", tests_sql)))
    negative = sorted(set(re.findall(r"TEST-ID:\s*(S1-NT-\d{3})", tests_sql)))
    check("acceptance-tests", len(acceptance) >= 8, json.dumps(acceptance), results)
    check("negative-tests", len(negative) >= 16, json.dumps(negative), results)

    for denial in [
        "ACTOR_UNKNOWN", "MEMBERSHIP_INACTIVE", "MEMBERSHIP_SUSPENDED",
        "MEMBERSHIP_REVOKED", "TENANT_AMBIGUOUS", "TENANT_OVERRIDE_DENIED",
        "DENY_RESOURCE_TENANT_MISMATCH", "DENY_AUTHORITY_VERSION_CONFLICT",
        "PV_IDEMPOTENCY_FINGERPRINT_CONFLICT",
    ]:
        check(f"denial:{denial}", denial in main_sql or denial in tests_sql, denial, results)

    failed = [r for r in results if not r["pass"]]
    payload = {
        "verdict": "PASS" if not failed else "FAIL",
        "checks": len(results),
        "passed": len(results) - len(failed),
        "failed": len(failed),
        "acceptance_tests": len(acceptance),
        "negative_tests": len(negative),
        "bootstrap_sha256": sha(BOOT),
        "migration_sha256": sha(MAIN),
        "results": results,
    }
    print(json.dumps(payload, indent=2))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
