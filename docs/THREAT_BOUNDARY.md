# Security and trust boundary

## Enforced in source

- tenant scope on every operational repository path;
- role-permission checks on all sensitive APIs and client actions;
- session-bound reviewer identity;
- distinct Tier 4 reviewer enforcement;
- no direct client credential issuance;
- no seal or label before credential and mark authorization;
- Zod validation for JSON, CSV, sync, evidence, review, and label inputs;
- 5 MB CSV limit, 5,000-row/request limit, and 1,000-operation sync API limit;
- 500-operation client sync chunks;
- optimistic concurrency and explicit conflicts;
- encrypted local snapshots and media;
- immutable versioned attestations;
- content hashes for local evidence;
- tenant-scoped search and audit history;
- PostgreSQL RLS contract;
- CSP, frame denial, MIME sniff prevention, strict referrer policy, and camera restricted to self;
- zero known npm vulnerabilities in the packaged offline audit.

## Fail-closed cases tested

- cross-tenant record access;
- unauthorized lot receiving;
- intake user accessing review queues;
- reviewer identity spoofing;
- same reviewer attempting both Tier 4 approvals;
- stale offline write;
- invalid CSV and duplicate serial;
- submission with unsynchronized work;
- label generation before issuance or mark authorization.

## External production security not claimed

- identity provider, MFA, provisioning, session revocation, and device trust;
- live PostgreSQL, backups, replicas, and restore;
- object storage, multipart upload, malware scanning, and media retention;
- hardware- or identity-bound offline key custody;
- HSM/KMS/PKI signing and key ceremony;
- external CUSTOS and registry publication;
- production queues, telemetry, alerts, dead letters, and incident response;
- external penetration test;
- physical browser/device and printer/NFC acceptance.
