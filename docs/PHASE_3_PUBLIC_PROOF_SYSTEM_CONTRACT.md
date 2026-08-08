# Phase 3 public proof system contract

## Authority

- Application spine: Phase 2 Victory R1 visual foundation.
- Authority kernel: `docs/PHASE_1_AUTHORITY_CONTRACT.md`.
- Visual foundation: `docs/PHASE_2_VISUAL_FOUNDATION_CONTRACT.md`.
- Public proof architecture: Phase 0 donor decision and preservation ledger.
- Policy version: `PV-POLICY-2026.07-R2`.

## Authorized Phase 3 boundary

Phase 3 builds the public proof system that follows the CORE010 first viewport. It does not replace the Phase 1 authority kernel or the Phase 2 R5/CORE010 visual foundation.

The maintained chapter sequence is:

1. four-tier education chamber;
2. canonical verification transaction;
3. claims and evidence workbench;
4. credential and registry projection;
5. signed-event and lifecycle continuity;
6. developer contract presentation;
7. operability and human-authority boundary;
8. public issuer, policy, access, and institutional footer.

Phase 3 also upgrades the public verifier, registry index, and registry-record route so they project the same canonical state as the homepage.

## Donor authority

| Responsibility | Donor | SHA-256 |
|---|---|---|
| Editorial authority and sequence | V25 Authority Machine | `cbbfcd6c869084b319dcd1e7c614b50ef49b539402c4acb6d610f2c988527594` |
| One-request/every-consequence transaction | V24 Operational Proof | `49e52e017998b35def0298c1954c90ee180eec64728cab7dc4ffc97eda6328dd` |
| Evidence continuity | V22 Proof OS | `e3b1ed7db1ea10624052cc12a0b1617ac937bce278f4497e57e831d32632392d` |
| Lifecycle continuity | V23 Continuum | `96249f230893c2684a454798dcfe60a104a15ace44ff0a83dd10eaec3d831bac` |
| Verification and record inspection | R4 Authority Complete | `edbdf90655d6689c6322c1300a427b42083d8a64da9de80dd6b7cde9de38110f` |
| Broad public narrative and tier education | Ultimate V11 | `13a63cb0019ad632eddc359fff12ae8cb40fdf3a6e8ba776da24f736d4d0d73e` |

Donors provide bounded responsibilities. They are not mounted, concatenated, iframed, or treated as independent state authorities.

## Canonical-state law

The homepage, verifier, registry index, registry record, REST projections, signed events, webhook fixtures, QR destination, and future MCP tools must resolve from the Phase 1 credential state.

The following concepts remain separate:

- evidence eligibility;
- reviewer determination;
- issuer authorization;
- credential issuance;
- registry publication;
- lifecycle state;
- certification-mark authorization.

An eligible but unissued record must not appear as issued, published, signed, lifecycle-mutable, or seal-authorized.

## Public chapter requirements

### Tier education

- Tier switching is explicitly educational.
- Selecting a tier never mutates the active credential.
- Tier 1 carries the required independent-corroboration disclosure.
- A controlled tier seal appears for the active case only when credential status is `issued` and mark authorization is `authorized`.

### Verification transaction

- Fixture selection changes the canonical store.
- One execution exposes evidence eligibility, authority gates, credential result, registry result, mark result, event result, and webhook result.
- Blocked cases preserve blockers and negative projections.
- The interface must not claim production issuance.

### Claims and evidence

- Claims, evidence objects, source qualification, source independence, correspondence, and scope remain inspectable.
- Private raw evidence is not exposed by the public record.
- Phone-image capture is not represented as laboratory authentication.

### Registry projection

- Human and machine views display the same public ID, tier, lifecycle, issuer, integrity hash, and mark status.
- Unissued records do not enter the public registry.
- Issued records with withheld mark authorization remain resolvable but do not display a controlled certification seal.

### Lifecycle and events

- Events preserve sequence, type, timestamp, actor, hash, and consequence.
- Lifecycle actions are unavailable for unissued credentials.
- Suspension, supersession, revocation, and expiry remain resolvable negative states.
- Webhook retry and replay are fixture demonstrations only.

### Developer contract

- The public site may demonstrate implemented REST fixture operations.
- MCP is labeled as a documented contract, not a deployed runtime.
- Code examples must preserve negative states and Test Mode boundaries.
- No unsupported lifecycle mutation, production key, or production OAuth claim is permitted.

## Visual-system law

- Phase 3 extends `phase2.css`; it must not override the CORE010 first viewport or R5 asset authority.
- Chapters use one shared spacing, border, type, code/data, state-pill, and responsive system.
- Dense technical surfaces collapse without horizontal overflow at mobile widths.
- Color communicates state; it is not decorative tier issuance.
- Code, JSON, IDs, hashes, timestamps, and metrics use the maintained mono treatment.
- No second Three.js runtime is introduced below the hero.

## Route requirements

The following route surfaces must remain functional and canonical:

- `/`
- `/verify`
- `/registry`
- `/registry/[publicId]`
- `/api/v1/verify`
- `/api/v1/registry/[publicId]`
- `/api/v1/events`
- `/api/v1/webhooks/replay`
- `/docs/api`
- `/docs/mcp`
- `/docs/webhooks`

## Acceptance gates

Phase 3 code acceptance requires:

- all six donor hashes recorded;
- eight maintained public-proof chapters;
- no iframe donor integration;
- no duplicate state store;
- one spatial runtime preserved from Phase 2;
- tier education cannot issue a credential;
- blocked Tier 4 cases remain unpublished and seal-withheld;
- registry filtering is functional;
- public records expose claims, evidence summary, event history, and machine projection;
- MCP described as not deployed;
- unit, integration, security, typecheck, lint, link, continuity, HTTP, and production-build gates pass;
- browser rendering and interaction acceptance performed in an unblocked browser environment.

Browser-policy failure remains `BLOCKED`, not `PASSED`.

## Excluded from Phase 3

- production persistence;
- production signing and key custody;
- production reviewer workspace;
- field jeweler PWA;
- OAuth and tenant administration;
- live MCP server;
- external webhook delivery;
- production billing;
- independent production authorization.
