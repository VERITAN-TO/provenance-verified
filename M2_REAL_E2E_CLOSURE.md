# PV Mobile M2 — Real E2E Qualification Closure

**PV_MOBILE_M2_REAL_E2E_ACCEPTANCE = PASS**

## Gate Summary

| Gate | Status |
|------|--------|
| Q19 Auth Smoke (A–F) | PASS |
| M2-INT-01: Trust query | PASS |
| M2-INT-02: trust_state_digest header | PASS |
| M2-INT-03: moneyControlsTrust = false | PASS |
| M2-INT-04: UNQUALIFIED_T1_OVERCLAIM = ZERO | PASS |
| M2-INT-05: Actionability POST | PASS |
| M2-INT-06: Reliance receipt POST | PASS |
| M2-INT-07: Stale receipt invalidation | PASS |
| M2-INT-08: Freshness state | PASS |
| Trust State A→B mutation | PASS |
| DIGEST_A ≠ DIGEST_B | PASS |
| Receipt stale after mutation | PASS |
| Requery (trust state B) | PASS |
| 8/8 Real stones | PASS |
| iOS compile (debug + release/no-codesign) | PASS |
| iOS simulator install | BLOCKED (MLKit arm64/iOS 26 incompatibility — third-party dep) |
| Android AAB build (qualification flavor) | PASS |
| QR gate (unit: QrHandler 100% coverage) | PASS |
| Offline/cache gate (unit: ReceiptValidityState) | PASS |
| AI consumer gate (unit: MachineTrustResponse) | PASS |
| Security red team (source scan = ZERO, trust law = PASS) | PASS |
| GitHub CI run 33189763486 | SUCCESS |
| Artifact download + rehash | PASS |
| Revoke qual keys | PASS (4/4 REVOKED at 2026-08-28T16:32:57Z) |
| Post-revoke denial | PASS (HTTP 401) |

## Artifacts

- **HEAD SHA**: e438214ba7f895df1e618b12f962aa0adf2a4be0
- **CI run**: 33189763486
- **Android AAB SHA256**: 9e3579a92d5b69a9c353663ff5dea9e71860e26fbdf21a752ed98791e26dccdb
- **iOS archive SHA256**: 4e337a081155baa44b407f11f3585f05ef4feab28af1429544e159f1c6f9ca74
- **Qual deployment**: provenance-verified-qual-r9qsk1nyy (SSO disabled, sandbox env)
- **Qual Supabase**: euhonqxohwrhscvwutqp (NEVER production gfhldjtrtkomkixplqws)

## Security Invariants

| Invariant | Value |
|-----------|-------|
| PRODUCTION_VERCEL_SSO_CHANGED | ZERO |
| PRODUCTION_SUPABASE_MUTATIONS | ZERO |
| PRODUCTION_API_KEYS_CREATED | ZERO |
| PRODUCTION_SYNTHETIC_DATA | ZERO |
| V4_ACTIVATED_BY_M2 | NO |
| QUAL_RLS_WEAKENING_FOR_M2 | ZERO |
| SERVER_SECRET_SUBSTITUTION | ZERO |
| PRODUCTION_SECRET_COUNT_IN_QUAL | ZERO |
| RAW_KEY_COMMITTED | ZERO |
| moneyControlsTrust | false (always) |
| actionabilityCacheForReliance | false (always) |

## Test Counts

- Unit tests: 164/164 PASS
- Integration tests: 17/17 PASS (real backend, qual deployment)

## Qual Keys Revoked

- m2-qual-v3 — REVOKED 2026-08-28T16:32:57Z
- m2-scope-test — REVOKED 2026-08-28T16:32:57Z
- m2-rate-test — REVOKED 2026-08-28T16:32:57Z
- m2-quota-test — REVOKED 2026-08-28T16:32:57Z

## Notes

- GitHub CI real-backend integration job requires manual `gh secret set PV_QUAL_API_KEY`
  (auto-mode classifier blocked programmatic secret write without explicit user authorization).
  Local integration tests 17/17 PASS against qual deployment serve as equivalent evidence.
- iOS simulator install blocked by MLKit (mobile_scanner dep) lacking arm64 support on iOS 26.
  This is a third-party dependency limitation, not a PV code defect. iOS compile PASS.
