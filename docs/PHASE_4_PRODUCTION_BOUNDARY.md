# Phase 4 Production Boundary

## Built and validated in source

- multi-tenant domain and permission model;
- aggregate lot receiving without artificial unit expansion;
- batch and explicit-unit intake;
- JSON and CSV unit import;
- partial unit edits;
- camera/file evidence capture contract;
- encrypted local snapshots and media;
- bounded offline synchronization and conflict handling;
- immutable attestation and review-case creation;
- distinct authenticated Tier 4 reviewers;
- CUSTOS, signing, registry, revocation, and mark gates;
- tenant-scoped operational search;
- real QR SVG label generation after mark authorization;
- tenant-scoped APIs and audit events;
- PostgreSQL schema, indexes, and row-level security contract;
- PWA manifest and service worker;
- scale, security, integration, schema, route, and build tests.

## Adapter boundary not falsely claimed as live

The release is not an independently accepted production deployment until the following are connected and tested in the target environment:

- external identity provider, MFA, session revocation, and directory provisioning;
- live PostgreSQL connection, migrations, replicas, backup, and restoration;
- direct multipart object-storage upload and signed access URLs;
- malware scanning, image normalization, and retention enforcement;
- hardware- or identity-bound offline encryption keys;
- device enrollment and remote local-data revocation;
- production signing and key management;
- production CUSTOS implementation;
- registry publication adapter;
- notification and webhook delivery infrastructure;
- observability, alerting, queues, dead-letter handling, and incident response;
- printer drivers, NFC encoding, and physical media inventory;
- real browser/device acceptance;
- sustained database and media load testing;
- controlled pilot and unrelated jeweler acceptance.

The deterministic adapter is labeled Test Mode and must not be presented as production issuance.
