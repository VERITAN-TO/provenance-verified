# Production Activation Gates

Production remains fail-closed until one signed activation record references evidence for every gate below.

1. R8.1 shell preservation and visual regression acceptance.
2. Production identity, MFA and active-session validation.
3. Tenant isolation and cross-tenant denial tests.
4. Canonical database migration and security-advisor acceptance.
5. Immutable evidence storage, scanner and custody acceptance.
6. Claim validation, reviewer independence and conflict-control acceptance.
7. Independent CUSTOS availability and denial tests.
8. Non-exportable signing key readiness and rotation procedure.
9. Registry publication and consistent-read acceptance.
10. Revocation and full lifecycle acceptance.
11. Separate certification-mark authorization and suppression tests.
12. API, webhook and MCP scope/replay acceptance.
13. Observability, incident response and alert routing acceptance.
14. Backup, restore and disaster-recovery drill acceptance.
15. Cross-browser, accessibility and physical-device acceptance.

Activation requires:

- `pv_activation_records.status = 'approved'`;
- accountable authorities and evidence digest recorded;
- `registry_ready = true` and `revocation_ready = true`;
- an active KMS signing key ID;
- `authoritative_issuance_enabled = true` only after gates 1–15 pass;
- `certification_marks_enabled = true` only after the separate mark gate passes;
- matching `PV_PRODUCTION_ACTIVATION_RECORD_ID` and `PV_PRODUCTION_ACTIVATION_RECORD_SHA256` in the application deployment.
