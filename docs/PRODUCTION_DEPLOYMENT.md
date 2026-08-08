# PROVENANCE VERIFIED™ R8.1 Production Deployment

## Deployment law

Production is disabled by default. A deployment is not production authority until the canonical database, evidence storage, identity, independent providers, registry, revocation control, recovery, browser/device acceptance, and signed activation record are all live and verified.

## Environments

| Environment | Real identity/data | Credential signing | Registry authority | Certification marks |
|---|---:|---:|---:|---:|
| Sandbox | No; deterministic fixtures | No | No | Demonstration only |
| Pilot | Yes | Disabled | Non-authoritative projections only | Disabled |
| Production | Yes | HSM/KMS only | Live | Separate authorization only |

Use separate Supabase projects and separate provider endpoints for pilot and production. Do not reuse production keys, service-role keys, buckets, registry tables, or webhook secrets in lower environments.

## 1. Deploy canonical persistence

1. Create a dedicated PROVENANCE VERIFIED™ Supabase project for each non-sandbox environment.
2. Apply `database/001_phase4_operations.sql`.
3. Apply `supabase/migrations/20260722000000_r8_1_production_authority.sql`.
4. Run the Supabase security and performance advisors.
5. Confirm RLS is enabled on every exposed table and that the `pv-evidence` bucket is private.
6. Create organization memberships in `pv_memberships`; authorization roles belong in canonical membership rows, never user-editable metadata.
7. Enable TOTP MFA and require AAL2 for production users.

## 2. Deploy the independent authority providers

Provision separate network identities and credentials for:

- evidence malware scanner;
- evidence eligibility service;
- independent claim-validation service;
- independent reviewer-conflict service;
- organization-attestation signer;
- independent CUSTOS decision service;
- production credential signer backed by a non-exportable HSM/KMS key;
- live registry with revocation capability;
- certification-mark authority.
- KMS webhook-secret vault.

Each provider must authenticate the authority API, enforce idempotency, return an attributable receipt and signature, and expose a health/readiness endpoint. Provider credentials are server-only secrets.

The primary authority providers are provisioned from `infra/terraform/provider-boundaries`. Independent CUSTOS is provisioned from `infra/terraform/custos-independent` in a different AWS account, with a separate encrypted Terraform backend, service role, datastore, KMS receipt key, release authority, monitoring and incident authority. The primary stack grants the deterministic CUSTOS service role read-only `GetItem` access to canonical facts and explicitly denies canonical writes.

All provider invocation uses AWS_IAM API Gateway, SigV4, short-lived OIDC-to-STS workload credentials, signed request digests, timestamps, nonces, replay controls, WAF and rate limits. Static provider bearer tokens and public unauthenticated Lambda Function URLs are prohibited.

## 3. Deploy the authority API

Deploy `supabase/functions/authority-api` with the configuration listed in `.env.example`. The function validates Supabase user identity, AAL2, tenant membership and role for private routes, then assumes separate short-lived AWS roles for the primary authority plane and independent CUSTOS. CUSTOS requests use `PV_CUSTOS_PROVIDER_API_URL` and `PV_CUSTOS_AWS_ROLE_ARN`; they never transit the primary provider API or role.

Set `PV_ENVIRONMENT=pilot` first. Do not set it to production during infrastructure bring-up.

## 4. Deploy the accepted Next.js shell

Deploy this repository without changing the protected visual files. Configure:

- `NEXT_PUBLIC_PV_ENVIRONMENT` and `PV_ENVIRONMENT` identically;
- the environment-specific Supabase URL and publishable key;
- `PV_AUTHORITY_API_URL` to the authority Edge Function endpoint;
- canonical domain and TLS;
- CSP, HSTS, clickjacking, MIME-sniffing, and referrer headers from `next.config.ts`.

## 5. Pilot acceptance

Pilot must prove real identity, tenancy, evidence storage, scanning, eligibility, reviewer independence, CUSTOS, audit events, registry infrastructure, webhook delivery, backup and restore. The pilot RPC prevents production credentials, production signing and certification marks.

## 6. Production activation

1. Complete all fifteen production gates and security acceptance.
2. Create a signed `pv_activation_records` row containing gate evidence and accountable authorities.
3. Set the production `pv_environment_controls` row only after independent approval:
   - `registry_ready=true`;
   - `revocation_ready=true`;
   - `active_signing_key_id=<live non-exportable key>`;
   - `activation_record_id` and matching SHA-256;
   - `authoritative_issuance_enabled=true`;
   - `certification_marks_enabled=true` only after separate mark acceptance.
4. Set the Next.js production activation environment variables to the same activation record.
5. Redeploy and execute one controlled acceptance credential through the full chain.

## Rollback

Application rollback does not revoke issued credentials. Roll back code through the deployment platform, disable `authoritative_issuance_enabled`, preserve the registry and lifecycle services, and use governed lifecycle actions for any credential impact. Never roll back the append-only evidence, CUSTOS, signing, authority-event, or lifecycle ledgers.
