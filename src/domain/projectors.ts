import { evaluateIssuance } from './authority';
import { canonicalJson, stableHash } from './hash';
import { evaluateCertification } from './kernel';
import type { Credential, FixtureRecord, SignedEvent, WebhookAttempt } from './types';

function signatureStatus(fixture: FixtureRecord, authorized: boolean): Credential['signature']['status'] {
  if (!authorized) {
    if (fixture.authority.signingKeyStatus === 'revoked') return 'revoked-key';
    if (fixture.authority.signingKeyStatus === 'unavailable') return 'key-unavailable';
    return 'not-issued';
  }
  return 'valid';
}

export function buildCredential(fixture: FixtureRecord): Credential {
  const decision = evaluateCertification(fixture.policy, fixture.claims);
  const authorization = evaluateIssuance(decision, fixture.authority);
  const issued = authorization.credentialAuthorized;
  const issuedTier = issued ? decision.tier : null;
  const lifecycle = issued ? fixture.lifecycle : 'draft';
  const signatureState = signatureStatus(fixture, issued);
  const lifecycleAllowsMark = issued && fixture.lifecycle === 'active';
  const sealAuthorized = lifecycleAllowsMark && authorization.sealAuthorized;
  const base = {
    id: `cred_${fixture.publicId.toLowerCase().replaceAll('-', '_')}_v1`,
    publicId: fixture.publicId,
    issuer: 'VERITAN, INC.' as const,
    platform: 'PROVENANCE VERIFIED' as const,
    program: 'Provenance Verified™' as const,
    subject: { assetType: 'gemstone', assetId: `asset_${fixture.key}`, description: 'Deterministic demonstration asset record' },
    status: issued ? 'issued' as const : 'not-issued' as const,
    eligibleTier: decision.tier,
    eligibleTierName: decision.tierName,
    tier: issuedTier,
    tierName: issued ? decision.tierName : null,
    disclosure: decision.disclosure,
    authorization,
    sealAuthorization: {
      status: sealAuthorized ? 'authorized' as const : 'not-authorized' as const,
      tier: sealAuthorized ? decision.tier : null,
      reasonCodes: sealAuthorized
        ? ['PV_MARK_AUTHORIZED']
        : !lifecycleAllowsMark && issued
          ? [`PV_MARK_BLOCKED_LIFECYCLE_${fixture.lifecycle.toUpperCase()}`]
          : fixture.authority.markAuthorization === 'denied'
            ? ['PV_MARK_DENIED']
            : ['PV_MARK_PENDING']
    },
    claims: fixture.claims,
    evidence: fixture.evidence,
    sources: fixture.sources,
    custody: fixture.custody,
    lifecycle,
    issuedAt: issued ? '2026-07-16T10:00:00Z' : undefined,
    expiresAt: issued && fixture.lifecycle === 'expired' ? '2026-07-16T10:30:00Z' : undefined,
    version: 1,
    signature: {
      algorithm: 'Ed25519' as const,
      keyId: issued ? 'veritan-test-key-2026-01' : 'not-issued',
      value: '',
      valid: issued,
      status: signatureState
    },
    integrityHash: '',
    successorId: issued && fixture.lifecycle === 'superseded' ? 'PV-TEST-T4D004' : undefined,
    warnings: [
      ...authorization.blockers,
      ...(issued && fixture.lifecycle !== 'active' ? [`Lifecycle state is ${fixture.lifecycle}.`] : []),
      ...(issued && !sealAuthorized ? ['Credential is issued, but certification-mark use is not authorized.'] : [])
    ],
    testMode: true as const
  };
  const integrityHash = `sha256:${stableHash(canonicalJson(base))}${stableHash(fixture.publicId)}`;
  const signature = issued
    ? { ...base.signature, value: `ed25519:test:${stableHash(integrityHash)}` }
    : base.signature;
  return { ...base, signature, integrityHash };
}

export function buildEvents(credential: Credential): SignedEvent[] {
  const issuedTypes: SignedEvent['type'][] = credential.status === 'issued'
    ? [
        'approval.completed',
        ...(credential.eligibleTier === 4 ? (['custos.completed'] as SignedEvent['type'][]) : []),
        'credential.issued',
        'registry.published',
        ...(credential.sealAuthorization.status === 'authorized' ? (['seal.authorized'] as SignedEvent['type'][]) : []),
        'webhook.attempted',
        'webhook.failed',
      ]
    : ['credential.authorization.blocked'];

  const types: SignedEvent['type'][] = [
    'verification.started',
    'evidence.bound',
    'claims.resolved',
    'review.completed',
    ...issuedTypes,
  ];
  let previous = 'genesis:test-mode';
  return types.map((type, index) => {
    const payload = {
      eligibleTier: credential.eligibleTier,
      issuedTier: credential.tier,
      credentialStatus: credential.status,
      issuanceStatus: credential.authorization.status,
      lifecycle: credential.lifecycle,
      sealAuthorization: credential.sealAuthorization.status,
      evidenceCount: credential.evidence.length,
      claimCount: credential.claims.length
    };
    const eventHash = `sha256:${stableHash(`${credential.publicId}:${type}:${index}:${previous}:${canonicalJson(payload)}`)}`;
    const event: SignedEvent = {
      id: `evt_${index + 1}_${stableHash(type)}`,
      type,
      at: `2026-07-16T10:${String(index).padStart(2, '0')}:00Z`,
      recordId: credential.publicId,
      sequence: index + 1,
      payload,
      signature: `ed25519:test:${stableHash(eventHash)}`,
      previousEventHash: previous,
      eventHash
    };
    previous = eventHash;
    return event;
  });
}

export function buildWebhookAttempts(events: SignedEvent[]): WebhookAttempt[] {
  const event = [...events].reverse().find((item) => item.type === 'webhook.attempted');
  if (!event) return [];
  return [
    { id: 'wh_01', eventId: event.id, endpoint: 'https://example.test/hooks/provenance', attempt: 1, status: 'failed', responseCode: 503, scheduledAt: '2026-07-16T10:05:00Z', completedAt: '2026-07-16T10:05:02Z', signature: `pvwh_test_${stableHash(event.eventHash)}` },
    { id: 'wh_02', eventId: event.id, endpoint: 'https://example.test/hooks/provenance', attempt: 2, status: 'waiting', scheduledAt: '2026-07-16T10:10:00Z', signature: `pvwh_test_${stableHash(`${event.eventHash}:2`)}` }
  ];
}
