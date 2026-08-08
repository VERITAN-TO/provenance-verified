# Production API, Async Events, SDK and MCP Surface

All private operations use the same authority kernel: verified identity, AAL2, tenant membership, purpose/scope, persisted API quota, idempotency, typed errors and attributable audit evidence. Browser requests cross the Next.js BFF from HttpOnly cookies; machine clients use scoped credentials. Crown-jewel provider calls use short-lived IAM/SigV4 workload identity.

## Public reads

- `POST /api/v1/verify`
- `GET /api/v1/registry`
- `GET /api/v1/registry/:publicId`
- `GET /api/v1/registry/:publicId/history`
- `GET /api/v1/events?publicId=`

## Authority commands

The operator and SDK surfaces cover organization administration, Category L evidence, QR/NFC custody, partner/reviewer/vendor governance, Customer Zero/One acceptance, G1–G5, stabilization, runtime claims, waivers, devices, access reviews, break-glass, key lifecycle, retention, derivatives, appeals, calibration, status lists, batch previews, public claims, incidents, SLO evidence and integrity findings.

## MCP parity

`POST /api/v1/mcp` supports:

- `provenance_verify`
- `provenance_registry_lookup`
- `provenance_collection_state`
- `provenance_authority_control_center`
- `provenance_operational_controls`
- `provenance_category_l_record_evidence`
- `provenance_media_transition`
- `provenance_launch_gate_record`
- `provenance_public_claim_record`
- `provenance_incident_record`

Mutation tools call the same command functions as REST and cannot bypass role, tenant, evidence, CUSTOS, signing, registry, revocation, quota or mark controls.

## Contracts

- REST: `docs/OPENAPI_PRODUCTION.yaml`
- Events: `docs/ASYNCAPI_PRODUCTION.yaml`
- TypeScript SDK: `sdk/typescript`
- Python SDK: `sdk/python`
