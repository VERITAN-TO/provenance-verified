# Security and Authority Plane

## Boundaries

- The browser never receives service-role credentials, provider tokens, signing keys, CUSTOS authority, registry write authority, or mark authority.
- Supabase Auth establishes identity. Production requires AAL2.
- `pv_memberships` establishes tenant, role and location scope.
- RLS and the authority API both enforce tenant scope.
- The service-role key is restricted to the separate authority API and never enters the Next.js browser bundle.
- Production signing is accepted only when the signer independently verifies the canonical authorization receipt, active non-exportable key, payload digest, policy, activation authorization, nonce and workload identity.

## Evidence custody

Evidence bytes enter an S3 Object Lock custody service through version-bound upload leases. The custody service recomputes the full SHA-256 from stored bytes, verifies size/MIME/version/retention/legal-hold state and issues a signed custody receipt. Separate scanner and eligibility authorities verify the immutable object version and signed upstream receipts. Browser storage is never the production custody authority.

## Reviewer governance

Each review round allows one primary and one secondary decision. Unique constraints prevent the same reviewer from occupying both stages. Conflict clearance is recorded independently. A correction creates a new attestation and increments the review round, so prior approvals cannot authorize the corrected claim set.

## Consequential writes

Credential preparation requires two independent approvals, two conflict clearances, complete evidence custody, a current CUSTOS pass, active activation record, registry readiness, revocation readiness and an active signing key. Finalization requires the matching non-exportable signing receipt and registry receipt. Certification marks require a distinct provider receipt after the credential is active.

## Failure behavior

Provider absence or invalid receipts are errors, never Sandbox fallbacks. Registry or revocation unavailability prevents issuance. Mark-authority failure suppresses the seal but does not falsify credential issuance. Audit and authority event ledgers remain attributable.

## Independent CUSTOS control plane

CUSTOS is absent from the primary provider Terraform service map and API routes. It has a separate AWS account, Terraform state, OIDC orchestrator role, private VPC, service role, verdict store, request/replay store, KMS receipt key, logs, backup vault, release authority and incident authority. Its Lambda can read only authoritative canonical facts and is explicitly denied all canonical writes. The primary canonical-authority and registry roles may verify CUSTOS receipts but cannot create or alter CUSTOS verdicts.
