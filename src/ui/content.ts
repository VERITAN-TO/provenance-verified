export const docsContent: Record<string, { title: string; lede: string; sections: { heading: string; body: string }[] }> = {
  quickstart: { title: 'Quickstart', lede: 'Run a deterministic verification, inspect the credential, resolve the public record, and verify the signed-event trail.', sections: [
    { heading: '1. Choose Test Mode', body: 'Use a test API key and a deterministic fixture public ID. Test responses are non-authoritative and are never production credentials.' },
    { heading: '2. Verify a public ID', body: 'POST /api/v1/verify with a publicId. The response includes the canonical credential, policy result, claim scope, lifecycle, signature, and integrity hash.' },
    { heading: '3. Resolve the registry projection', body: 'GET /api/v1/registry/{publicId}. Compare publicId, tier, disclosure, lifecycle, signature, integrityHash, and claim count with the verification response.' },
    { heading: '4. Observe events and webhooks', body: 'GET /api/v1/events?publicId={publicId}. Every event contains a stable sequence, previous-event hash, event hash, and deterministic test signature.' },
    { heading: '5. Handle lifecycle', body: 'Do not treat a successful lookup as permission to rely. Inspect active, suspended, superseded, revoked, or expired state and follow any successor record.' }
  ]},
  api: { title: 'API reference', lede: 'Schema-validated Test Mode endpoints backed by separate evidence-eligibility and issuer-authority decisions with canonical projections.', sections: [
    { heading: 'POST /api/v1/verify', body: 'Request: { publicId, fixtureKey? }. Response: canonical credential in data and explicit Test Mode metadata. Invalid requests return 400. Unknown records return 404.' },
    { heading: 'GET /api/v1/registry/{publicId}', body: 'Returns the public registry projection. Human and machine fields are tested for parity after every supported public action.' },
    { heading: 'GET /api/v1/events', body: 'Returns deterministic signed events for a public ID. Event chaining uses previousEventHash and eventHash fields.' },
    { heading: 'POST /api/v1/webhooks/replay', body: 'Creates a deterministic manual replay linked to an original attempt ID. Replay requires an operator reason.' },
    { heading: 'Errors', body: 'Errors are structured as { error: { code, message or details }, meta }. Negative states remain inspectable and do not impersonate live production outcomes.' }
  ]},
  sdk: { title: 'SDKs', lede: 'Typed integration patterns for TypeScript and Python using the same public contract.', sections: [
    { heading: 'TypeScript', body: 'Initialize with mode: test and a test API key. Use verify, registry.resolve, webhooks.replay, and credentials.changeLifecycle operations.' },
    { heading: 'Python', body: 'Initialize Provenance(mode="test"). Methods return canonical credential objects with typed claim, evidence, source, event, and lifecycle fields.' },
    { heading: 'Idempotency', body: 'Write operations accept an idempotency key. Repeating the same deterministic request does not create a second logical operation.' },
    { heading: 'Verification', body: 'Verify the response integrity hash, signature key ID, lifecycle state, and registry parity before relying on a result.' }
  ]},
  mcp: { title: 'MCP tools', lede: 'Machine-callable operations expose scoped proof without allowing an AI system to invent evidence or authority.', sections: [
    { heading: 'provenance_verify', body: 'Inputs: mode, public_id. Returns credential, registry projection, signed event references, and explicit Test Mode metadata.' },
    { heading: 'provenance_registry_resolve', body: 'Resolves a public ID and returns claim scope, lifecycle, signature state, and successor information.' },
    { heading: 'provenance_webhook_replay', body: 'Requires attempt_id and operator reason. The replay remains linked to the original event and attempt chain.' },
    { heading: 'AI boundary', body: 'AI may classify, summarize, compare, and flag. AI does not create evidence, invent source independence, issue without authority, or convert uncertainty into certainty.' }
  ]},
  webhooks: { title: 'Webhooks', lede: 'Signed event delivery with inspectable attempts, deterministic retry schedules, and manual replay.', sections: [
    { heading: 'Event signature', body: 'Each attempt includes a signature derived from the displayed event. Verify the signature before processing the body.' },
    { heading: 'Retry schedule', body: 'Failed Test Mode attempts expose their response code, scheduled retry, and final delivery state. No connector animation runs without a displayed event.' },
    { heading: 'Manual replay', body: 'Manual replay requires an operator reason and creates a new attempt linked through replayOf.' },
    { heading: 'Idempotent consumers', body: 'Use event ID and sequence to prevent duplicate side effects. Preserve the original event timestamp and lifecycle context.' }
  ]},
  events: { title: 'Signed events', lede: 'Append-only deterministic events connect verification, evidence binding, claim resolution, issuance, registry publication, webhook delivery, and lifecycle control.', sections: [
    { heading: 'Event chain', body: 'Each event includes sequence, previousEventHash, eventHash, and signature. A consumer can detect missing or reordered events.' },
    { heading: 'Event types', body: 'verification.started, evidence.bound, claims.resolved, credential.issued, registry.published, webhook.attempted, webhook.delivered, webhook.failed, webhook.replayed, and credential.lifecycle.changed.' },
    { heading: 'Payload discipline', body: 'Payloads reference canonical state. They do not calculate an independent tier or lifecycle result.' },
    { heading: 'Replay', body: 'Replay emits a new delivery attempt, not a rewritten historical event.' }
  ]},
  'test-mode': { title: 'Test Mode', lede: 'Deterministic fixtures exercise the production contract without representing live customers, production metrics, or authoritative credentials.', sections: [
    { heading: 'Visible boundary', body: 'Every fixture-driven experience displays TEST MODE, NON-AUTHORITATIVE, and NOT A PRODUCTION CREDENTIAL.' },
    { heading: 'Determinism', body: 'Stable IDs, timestamps, hashes, event sequences, and expected policy results make every demonstration reproducible.' },
    { heading: 'Negative fixtures', body: 'Invalid signature, conflicting evidence, suspended, superseded, revoked, expired, and not-found records are first-class test scenarios.' },
    { heading: 'Production transition', body: 'Production access requires authorized issuer credentials, approved evidence integrations, live key management, and production policy controls.' }
  ]}
};

export const legalContent: Record<string, { title: string; lede: string; sections: { heading: string; body: string }[] }> = {
  privacy: { title: 'Privacy policy', lede: 'How PROVENANCE VERIFIED™ limits, processes, and protects information in this demonstration build.', sections: [
    { heading: 'Test data', body: 'The demonstration uses deterministic fixtures and does not contain real customer records. Do not submit personal, confidential, or production evidence.' },
    { heading: 'Operational data', body: 'A production service would collect account, security, request, evidence, and audit data necessary to operate the requested workflow under an applicable agreement.' },
    { heading: 'Minimization', body: 'Collect only the information required for identity, evidence, claim, custody, credential, registry, security, and lifecycle functions.' },
    { heading: 'Contact', body: 'Privacy inquiries route through the contact surface and the applicable production agreement.' }
  ]},
  terms: { title: 'Terms of use', lede: 'Boundaries for using the public demonstration, documentation, API examples, and deterministic fixtures.', sections: [
    { heading: 'Demonstration only', body: 'This build is a non-authoritative demonstration. It does not issue a production credential or authorize reliance on a fixture.' },
    { heading: 'Acceptable use', body: 'Do not attempt to misrepresent fixture outputs as real certification, production status, or customer evidence.' },
    { heading: 'No unsupported reliance', body: 'A certification result is always limited by its disclosed claim scope, evidence basis, lifecycle state, and applicable policy.' },
    { heading: 'Intellectual property', body: 'PROVENANCE VERIFIED™, Provenance Verified™, identity assets, documentation, and software are subject to applicable ownership and license terms.' }
  ]},
  'certification-policy': { title: 'Certification policy', lede: 'The four-tier evidence standard and the separate issuer controls required before a Provenance Verified™ credential may be issued.', sections: [
    { heading: 'Tier 1 — Self-Reported', body: 'Requires submitter identity, self-declared origin or provenance claims, photographs, weight and dimensions where applicable, timestamp, and registry ID. Disclosure: SELF-REPORTED RECORD — Origin information has not been independently corroborated.' },
    { heading: 'Tier 2 — Bronze', body: 'Tier 1 plus structured signed attestation, identified attesting party, legal declaration, electronic or cryptographic signature, signature timestamp, attestation version, append-only registry event, and integrity hash.' },
    { heading: 'Tier 3 — Silver', body: 'Tier 2 plus at least one qualifying independent source confirming a material claim with claim-level correspondence, source identity, evidence reference, date, review, and integrity hash.' },
    { heading: 'Tier 4 — Gold', body: 'Evidence eligibility requires verified origin, physical fingerprint, qualifying laboratory evidence, complete applicable transfer and custody history, at least two qualifying independent sources, and claim-level correspondence. Issuance additionally requires dual independent approval, conflict clearance, CUSTOS, an active issuer signing key, registry readiness, and revocation capability. Certification-mark use remains separately controlled.' },
    { heading: 'Corporate mark separation', body: 'The corporate PROVENANCE VERIFIED™ master mark remains machined silver, smoked glass, deep carbon, and controlled cyan. It never becomes a Bronze, Silver, or Gold certification-tier seal.' }
  ]},
  'evidence-policy': { title: 'Evidence policy', lede: 'Qualification, independence, integrity, custody, and claim-level correspondence requirements.', sections: [
    { heading: 'Evidence objects', body: 'Every evidence object carries a stable ID, type, source, integrity hash, captured timestamp, qualification state, independence state, and linked claim IDs.' },
    { heading: 'Source independence', body: 'Independence is an explicit source property. Interface styling or AI classification cannot create independence.' },
    { heading: 'Claim correspondence', body: 'A source supports only the claims to which its evidence is explicitly linked. A credential must not generalize one corroborated claim into universal verification.' },
    { heading: 'Custody', body: 'Applicable custody events identify actor, action, time, location, and integrity hash. Missing custody remains visible in failed requirements and upgrade path.' }
  ]},
  'revocation-policy': { title: 'Lifecycle and revocation policy', lede: 'How active, suspended, superseded, revoked, expired, and not-found states remain public and machine-readable.', sections: [
    { heading: 'Active', body: 'The record is resolvable and may be relied upon only within its disclosed claim scope and applicable agreement.' },
    { heading: 'Suspended', body: 'Reliance is paused while the record remains resolvable with a signed reason and timestamp.' },
    { heading: 'Superseded', body: 'A newer credential replaces the current version. The historical record remains resolvable and links to its successor.' },
    { heading: 'Revoked', body: 'The credential is no longer valid for reliance. It remains resolvable with explicit revoked state and transition history.' },
    { heading: 'Expired and not found', body: 'Expired records preserve historical truth with time-bounded status. Not-found responses are stable negative results and do not leak unrelated record data.' }
  ]}
};
