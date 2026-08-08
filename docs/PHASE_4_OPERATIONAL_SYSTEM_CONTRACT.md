# Phase 4 Operational System Contract

## Scope

Phase 4 builds the authenticated PROVENANCE operating surface used by jewelry organizations, authorized evidence providers, reviewers, compliance operators, and auditors.

It does not build an external commerce business. It does not introduce catalog, cart, checkout, retail fulfillment, or unrelated brand operations.

## Canonical operating chain

`tenant → location → aggregate lot → individually identified asset → evidence → immutable attestation → review case → Phase 1 authority gates → credential → registry → controlled mark projection`

A lot quantity is aggregate inventory. It does not create physical-unit identities. A gemstone asset exists only after a real unit identifier or serialization event.

## Implemented operational surfaces

- `/app` command center
- `/app/lots` aggregate lot and parcel receiving
- `/app/intake` field intake, camera/file capture, CSV import, and offline queue
- `/app/batches` tenant-scoped batch index
- `/app/batches/[batchId]` batch record
- `/app/search` cross-operational search
- `/app/review` authority review workspace
- `/app/labels` controlled QR and certification-mark projections
- `/app/exceptions` validation, synchronization, and authority blockers
- `/app/audit` operational activity

## Implemented APIs

- `GET|POST /api/v1/operations/lots`
- `GET|POST /api/v1/operations/batches`
- `GET /api/v1/operations/batches/{batchId}`
- `POST /api/v1/operations/batches/{batchId}/assets`
- `POST /api/v1/operations/batches/{batchId}/csv`
- `POST /api/v1/operations/batches/{batchId}/submit`
- `PATCH /api/v1/operations/assets/{assetId}`
- `POST /api/v1/operations/assets/{assetId}/evidence`
- `POST /api/v1/operations/sync`
- `GET /api/v1/operations/search`
- `GET /api/v1/operations/review`
- `POST /api/v1/operations/review/{caseId}/decision`
- `POST /api/v1/operations/labels`
- `GET /api/v1/operations/audit`

Every route resolves a session and tenant before data access. Cross-tenant direct access fails closed. Reviewer identity is bound to the authenticated session and cannot be supplied as a different actor in the request body.

## Real intake capacity

The product has no 20-unit limit. It supports:

- explicit unit entry;
- 1,000-unit local batch generation and bounded synchronization;
- JSON bulk import up to 5,000 explicit units per request;
- CSV import up to 5,000 validated rows and 5 MB;
- 100,000-asset in-memory indexing tests;
- 500-operation synchronization chunks under the 1,000-operation API ceiling;
- tenant duplicate-serial rejection;
- partial unit measurement edits;
- search across assets, batches, evidence, reviews, and credentials.

These are system and algorithm acceptance tests, not commercial capacity limits or production database benchmarks.

## Role boundaries

The runtime includes owner, administrator, intake, evidence, inventory, attestor, reviewer, compliance, and auditor permissions.

- Inventory managers receive aggregate lots.
- Intake operators identify units and capture evidence.
- Authorized attestors submit immutable batch attestations.
- Reviewers perform independent review.
- Tier 4 requires two distinct authenticated reviewers.
- Compliance controls CUSTOS, signing authority, and mark authorization.
- Ordinary reviewers and intake users cannot issue credentials or authorize marks.

## Offline and local-first model

The field surface supports:

- encrypted IndexedDB snapshots;
- encrypted local media;
- queued local mutations;
- explicit online/offline status;
- bounded sync requests;
- optimistic version checks;
- visible conflict and failed states;
- service-worker app-shell caching;
- restart recovery.

Unsynchronized work is never represented as submitted, issued, published, or registry-active. Offline media remains queued until a production direct-upload adapter returns a canonical storage key.

## Evidence and media law

Phone and browser camera images are physical-fingerprint evidence. They do not perform laboratory authentication. Evidence retains source, acquisition method, qualification, independence, integrity hash, visibility, and lifecycle status.

## Attestation and authority integration

Attestations are immutable and versioned. Corrections require a new attestation linked to the prior version.

Operational evidence is projected into the Phase 1 authority kernel. The Phase 4 interface cannot issue a credential directly. Tier 4 continues to require distinct independent approvals, conflict clearance, CUSTOS, active signing authority, registry readiness, revocation control, and separate mark authorization.

## QR and physical carrier law

The label endpoint emits a standards-based QR SVG only after credential issuance and mark authorization. The QR resolves the canonical registry. The physical label, QR, NFC carrier, or seal is a projection and is never the authority.

## Production persistence contract

`database/001_phase4_operations.sql` defines the PostgreSQL persistence boundary, indexes, and row-level tenant policies. The delivered runtime uses a deterministic repository adapter because no production database, authentication provider, object storage, malware scanner, signing service, or deployment credentials were supplied.
