# PROVENANCE VERIFIED™

This repository preserves the accepted R8.1 four-layer website and adds a deployable, fail-closed production authority plane behind stable contracts.

## Product layers

1. Public authority website
2. Public verification and live-registry projection
3. Authenticated multi-tenant operator workspace
4. Production API, signed webhooks and authenticated MCP

## Permanent environments

- **Sandbox** — deterministic Test Mode, isolated fixtures, no real authority.
- **Pilot** — real identity, tenancy, evidence custody, reviewers, CUSTOS, registry infrastructure and audit; authoritative signing, credentials and certification marks remain disabled.
- **Production** — requires a signed activation record, all provider boundaries, live registry/revocation, non-exportable KMS signing and all fifteen activation gates.

## Implemented authority boundaries

- Supabase Auth password identity, TOTP MFA and AAL2 enforcement
- HttpOnly session and tenant cookies
- canonical tenant memberships, roles, locations and organization administration
- tenant RLS and scoped machine API clients
- immutable private evidence storage, SHA-256 integrity, malware scan and custody history
- independent evidence eligibility, claim validation and conflict evaluation
- distinct primary/secondary reviewers and correction review rounds
- independent CUSTOS receipts
- AWS KMS ES256 credential and attestation signing
- live registry publication, revocation readiness and lifecycle transitions
- separate certification-mark authorization
- signed webhooks with KMS-encrypted secrets, retry, dead-letter and replay lineage
- authenticated MCP through the same authority handler
- recoverable issuance checkpoints, audit history, status, logs, alarms and restore procedures

## Main implementation surfaces

- `supabase/migrations/20260722000000_r8_1_production_authority.sql`
- `supabase/functions/authority-api/index.ts`
- `services/provider-boundaries/`
- `infra/terraform/provider-boundaries/`
- `src/services/adapters.ts`
- `src/app/api/v1/auth/`
- `src/ui/operations/OrganizationAdmin.tsx`
- `docs/WORK_ORDER_BUILD_LEDGER.md`
- `docs/ACTIVATION_GATES.md`

## Verification

```bash
npm ci --ignore-scripts
npm run lint
npm run typecheck
npm run test:unit
npm run test:integration
npm run test:security
npm run build
npm run verify:production
npm run audit:links
npm run audit:continuity
npm run audit:phase3
npm run audit:phase4
npm run audit:caliber
```

The application also builds as a non-root standalone container using `Dockerfile`. CI blocks promotion until lint, types, tests, production compilation, static audits, migration mirroring and container construction pass.

Production authority is intentionally disabled by default. Deployment is not activation; follow `docs/PRODUCTION_DEPLOYMENT.md`, `docs/ACTIVATION_GATES.md` and `docs/RECOVERY_RUNBOOK.md`.
