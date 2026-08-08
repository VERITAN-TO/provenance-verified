# Security Implementation Report

The production authority plane enforces server-authenticated identity, AAL2 MFA, canonical tenant membership, role and scope checks, tenant RLS, immutable evidence bytes, append-only custody and authority receipts, independent reviewer rounds, independent conflict and claim validation, separate CUSTOS, KMS-only signing, registry-before-issuance, revocation readiness, and separate mark authorization.

Secrets are handled as follows:

- browser receives only publishable Supabase configuration;
- Supabase service-role and provider tokens remain server-only;
- API client secrets are generated once and stored only as SHA-256 hashes;
- webhook secrets are shown once and stored as KMS envelope ciphertext;
- signing private material is never exported from KMS;
- production activation requires a signed record and matching application/database controls.

Consequential writes deny on missing identity, tenant, MFA, membership, role, evidence, scanner, custody, claim validation, reviewer independence, conflict clearance, CUSTOS, signer, active key, registry, revocation or mark authority.
