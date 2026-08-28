# PV Mobile M2 — Superseding Custody Notice

**NATIVE-11 — PRIOR ACCEPTANCE VOID**

## Notice

The custody record at `7c5f6e0` ("PV_MOBILE_M2_REAL_E2E_ACCEPTANCE = PASS") was **premature and void**.

That commit declared `ANDROID_NATIVE_E2E = PASS` and `IOS_NATIVE_E2E = PASS` without any actual native
integration test execution. All 8 `M2-INT-*` gates in the prior custody JSON were
`PENDING_CREDENTIAL_PROVISIONING` — no credential was ever provisioned, no test ran on a device.

## What Was Actually Completed at 7c5f6e0

| Gate | Status | Evidence |
|------|--------|----------|
| Unit tests (164/164) | PASS | `flutter test test/unit/` — real execution |
| Flutter analyze | PASS | No issues found |
| iOS build (local) | PASS | 37.4 MB .app built |
| Android AAB (local) | PASS | 59.4 MB, sha256 documented |
| M2-01 through M2-19 (unit+mock) | PASS | On-device execution mocked |
| M2-INT-01 through M2-INT-08 | PENDING | NOT executed — credential never provisioned |

## What This Session Is Completing

| Task | Status |
|------|--------|
| NATIVE-01: Disk recovery (8.8 GB freed) | COMPLETE |
| NATIVE-02: Toolchain hack reversion (NDK 28.2 canonical) | COMPLETE |
| NATIVE-03: NDK 28.2 installation confirmed | COMPLETE |
| NATIVE-04: Credential provisioning | BLOCKED_ON_CLASSIFIER — awaiting Phoenix explicit consent |
| NATIVE-05: Android release APK built (66.8 MB, sha256 documented) | COMPLETE |
| NATIVE-06: App installed + running on emulator-5554 | COMPLETE |
| NATIVE-07: Android integration test execution | PENDING_CREDENTIAL |
| NATIVE-08: iOS integration test execution | PENDING_CREDENTIAL |
| NATIVE-09: AI consumer evidence seal | COMPLETE — M2-AI-CONSUMER-EVIDENCE-SEAL.json |
| NATIVE-10: Artifact rehash | PARTIAL (APK documented; full suite after test execution) |
| NATIVE-11: This superseding custody notice | COMPLETE |
| NATIVE-12: Final custody commit | PENDING (after all tests pass) |

## Credential Blocker

The auto-mode classifier requires Phoenix to say **verbatim** in chat:

> **"Authorized: INSERT key `m2-native-e2e-v1` into pv_api_keys on qual Supabase project `euhonqxohwrhscvwutqp`."**

The pre-computed key is ready:
- `key_id`: `m2-native-e2e-v1`
- `key_hash`: `sha256:bc217a9fd87c6747db033db822436e902fad8b37ba9275f56819157dd033957e`
- Scopes: `trust:read`, `actionability:evaluate`, `reliance:create`
- Environment: `test` (qual only)
- Raw value: present in current session context (NOT committed to any file)

## Security Invariants — No Change

```
PRODUCTION_SUPABASE_MUTATIONS = ZERO
PRODUCTION_API_KEYS = ZERO
V4_ACTIVATED_BY_M2 = NO
REAL_PAYMENT = ZERO
RAW_KEY_COMMITTED = ZERO
```

---
*Authored: 2026-08-28T19:55:26Z — session 594fefad-070b-43d4-acfd-df1a5186a116*
