# signing incident runbook

1. Confirm the signed alert receipt and trace ID.
2. Set the service to degraded or blocked; never report ready while a critical dependency is unavailable.
3. Stop consequential writes when identity, evidence custody, CUSTOS, signing, registry, revocation, or audit integrity is impaired.
4. Preserve logs, traces, queue state, database state, object versions, and authority receipts.
5. Open an incident command record with commander, timeline, customer impact, and evidence links.
6. Execute the service-specific rollback or replay only through approved, idempotent commands.
7. Verify canonical state, projection state, event-chain integrity, tenant isolation, and mark suppression before recovery.
8. Close only with postmortem evidence and signed remediation acceptance.
