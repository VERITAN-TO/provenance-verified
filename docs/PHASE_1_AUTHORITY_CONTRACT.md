# Phase 1 Authority Contract

## Binding separation

PROVENANCE VERIFIED™ evaluates evidence eligibility separately from credential issuance.

1. `evaluateCertification()` calculates the highest evidence tier supported by the submitted record.
2. `evaluateIssuance()` applies reviewer, conflict, CUSTOS, signing, registry, revocation, and mark-control gates.
3. `buildCredential()` emits either an issued credential or a non-issued eligibility case.
4. The public registry publishes issued credentials only.
5. A certification seal is available only when the credential is issued and mark control is authorized.

Evidence eligibility never creates a credential, registry record, signature, or certification mark by itself.

## Tier 4 issuance gates

A Tier 4 credential requires all of the following:

- Tier 4 evidence eligibility;
- two approvals from distinct independent reviewers;
- no reviewer conflict;
- explicit conflict clearance;
- passing CUSTOS verdict;
- active issuer signing key;
- registry publication readiness;
- revocation and supersession capability.

Certification-mark use is a separate authorization. A Tier 4 credential may be issued while the Gold seal remains unavailable.

## Fail-closed precedence

Authority defects are reported in this order:

1. evidence not eligible;
2. reviewer rejection;
3. reviewer conflict;
4. missing reviewer approval;
5. missing independent review;
6. missing second Tier 4 approval;
7. missing Tier 4 conflict clearance;
8. missing or failed CUSTOS verdict;
9. unavailable or revoked signing key;
10. unavailable registry;
11. missing revocation control.

A known conflict is never downgraded to a generic missing-approval result.

## Public behavior

- Issued credential: HTTP 200 from verification and a resolvable registry projection.
- Eligible but not issued: HTTP 409 with eligibility, authority status, blockers, and no registry record.
- Unknown record: HTTP 404.
- Minimum Tier 1 evidence incomplete: HTTP 422 in the interactive product flow.
- No issued credential means no lifecycle transition and no webhook publication event.

## Test-mode boundary

All current credentials, signatures, events, registry projections, and webhooks are deterministic fixtures.

They are:

- non-authoritative;
- not production credentials;
- not backed by production cryptographic keys;
- not backed by a production registry or evidence database.
