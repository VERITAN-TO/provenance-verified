# Architecture

## Four-layer system

1. Public authority and product narrative.
2. Public verification and registry.
3. Authenticated jeweler operations, review, labels, exceptions, and audit.
4. Public API contracts and developer surfaces.

All layers preserve the same Phase 1 authority model. The operational application does not own a competing tier or issuance algorithm.

## Authority graph

`src/domain/kernel.ts` owns evidence-tier eligibility.

`src/domain/authority.ts` owns issuer authorization: reviewer independence, conflict clearance, CUSTOS, signing readiness, registry readiness, revocation capability, and mark authorization.

`src/operations/kernel.ts` projects operational assets and evidence into those existing authority inputs.

```text
tenant/location
      |
aggregate lot
      |  real serialization only
identified unit
      |
evidence + immutable attestation
      |
review case
      |
eligibility -> independent approvals -> conflict -> CUSTOS
      -> signing -> registry -> revocation control -> mark authorization
```

## State ownership

- `src/store/useProvenanceStore.ts`: public deterministic verification/registry state.
- `src/operations/useOperationsStore.ts`: authenticated field and reviewer workflow state.
- `src/operations/repository.ts`: tenant-enforced repository contract and deterministic adapter.
- `database/001_phase4_operations.sql`: production PostgreSQL/RLS persistence contract.

The public and operational stores have different interface responsibilities, but both use the same domain authority kernel and credential projection types. No client store may issue a credential independently.

## Operational modules

- `src/operations/types.ts`: tenant, location, lot, asset, evidence, attestation, review, sync, audit.
- `src/operations/permissions.ts`: role-permission matrix.
- `src/operations/schemas.ts`: request validation.
- `src/operations/kernel.ts`: validation, attestation, authority projection, scale indexing, optimistic conflict logic.
- `src/operations/repository.ts`: tenant-scoped repository boundary.
- `src/operations/offline`: encrypted IndexedDB snapshot and media adapters.
- `src/app/api/v1/operations`: 14 tenant-scoped route handlers.
- `src/ui/operations`: command, lots, intake, batches, search, review, labels, exceptions, and audit.

## Local-first synchronization

Local operations remain queued until server confirmation. Sendable records are synchronized in batches of 500 operations under the API maximum of 1,000. Media with local encrypted blobs remains queued until a production upload adapter returns a canonical storage key.

Optimistic-version conflicts are visible and do not overwrite canonical records.

## Lot and unit law

A lot records aggregate quantity. It is not a collection of assumed asset identities. Unit records are created only by explicit entry, validated API/CSV import, scan, or another real serialization event.

## Evidence and media law

Camera images are hashed, encrypted locally, and classified as supporting fingerprint evidence. They are not laboratory authentication. Production object storage, scanning, normalization, retention, and signed URL adapters remain deployment concerns.

## Physical projection law

QR and certification labels are generated only for issued credentials with active mark authorization. They point to the canonical registry and remain non-authoritative physical carriers.

## Rendering strategy

The public site retains one Three.js environment. Operations pages use the shared R5 visual system without adding a second WebGL runtime. Route pages remain server components unless browser state or field-device APIs are required.
