# Canary and Rollback Authority

A release begins with no more than 5% traffic and may never exceed 25% before an
explicit promotion record. Critical invariants include identity denial, tenant
isolation, evidence custody, CUSTOS availability, signing correctness, registry
consistency, revocation readiness, mark suppression, audit durability, and error
rate. A critical breach, unavailable kill switch, or missing rollback authority
forces automatic rollback. Rollback records bind source/target commits, package
hashes, evidence, authority identity, timestamp, and post-rollback reconciliation.
