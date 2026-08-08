# Recovery and Incident Runbook

## Immediate containment

1. Disable `authoritative_issuance_enabled` in `pv_environment_controls`.
2. Disable certification marks independently when mark integrity is uncertain.
3. Keep public registry and revocation endpoints available whenever safely possible.
4. Rotate compromised browser, service-role, provider and webhook credentials according to their independent scopes.
5. Preserve logs and append an incident authority event; do not mutate custody evidence.

## Database recovery

- Restore into a new isolated project first.
- Apply migrations to the same version.
- Verify row counts and SHA-256 event-chain continuity for evidence and authority events.
- Reconcile active credentials against the external registry by `public_id`, credential digest and lifecycle.
- Reconcile signing receipts against KMS audit logs and provider receipt IDs.
- Reconcile mark authorizations only after active credential and registry agreement.

## Interrupted issuance

A prepared credential is not an issued credential. If signing or registry publication fails, keep it non-public and retry with the same idempotency key after the dependency is healthy. Before retrying, compare the prepared payload digest, signer receipt and registry state. Never generate a second payload under the same credential ID.

## Registry disagreement

Fail closed. Disable issuance. The registry lifecycle is public authority and must be reconciled before new credentials or marks. Do not hide disagreement with frontend state.

## Evidence disagreement

Quarantine the evidence object and dependent review cases. Preserve the original bytes and custody events. Add a superseding object and custody chain rather than replacing bytes.

## Acceptance before reopening

Re-run tenant isolation, authorization, scanner, evidence eligibility, CUSTOS, signer, registry, revocation, mark, webhook, backup, restore, browser/device, accessibility, and visual regression gates. Reopening production requires an updated signed activation record when a trust-critical boundary changed.
