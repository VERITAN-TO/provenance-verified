import fs from 'node:fs';
import path from 'node:path';
import { fixtures, fixtureList } from '../src/domain/fixtures';
import { evaluateCertification } from '../src/domain/kernel';
import { buildCredential, buildEvents, buildWebhookAttempts } from '../src/domain/projectors';

const outputDir = path.resolve('fixtures/authority');
fs.mkdirSync(outputDir, { recursive: true });

const filenameByKey: Record<string, string> = {
  t1: 'tier-1-self-reported.json',
  t2: 'tier-2-bronze.json',
  t3: 'tier-3-silver.json',
  t4: 'tier-4-gold.json',
  conflicting: 'blocked-conflicting-evidence.json',
  invalidSignature: 'tier-1-invalid-attestation-fallback.json',
  t4MissingSecondApproval: 'blocked-t4-second-approval.json',
  t4ReviewerConflict: 'blocked-t4-reviewer-conflict.json',
  t4CustosPending: 'blocked-t4-custos-pending.json',
  t4SigningUnavailable: 'blocked-t4-signing-unavailable.json',
  t4RegistryUnavailable: 'blocked-t4-registry-unavailable.json',
  t4MarkPending: 'issued-t4-mark-pending.json',
  t4ConflictClearancePending: 'blocked-t4-conflict-clearance-pending.json',
  t4CustosFailed: 'blocked-t4-custos-failed.json',
  t4SigningRevoked: 'blocked-t4-signing-key-revoked.json',
  t4RevocationUnavailable: 'blocked-t4-revocation-control.json',
  t4MarkDenied: 'issued-t4-mark-denied.json',
  suspended: 'lifecycle-suspended.json',
  revoked: 'lifecycle-revoked.json',
  superseded: 'lifecycle-superseded.json',
  expired: 'lifecycle-expired.json',
  notFound: 'not-found.json',
};

for (const entry of fs.readdirSync(outputDir)) {
  if (entry.endsWith('.json')) fs.rmSync(path.join(outputDir, entry));
}

const manifest = fixtureList.map((fixture) => {
  const decision = evaluateCertification(fixture.policy, fixture.claims);
  const credential = buildCredential(fixture);
  const events = buildEvents(credential);
  const webhooks = buildWebhookAttempts(events);
  const filename = filenameByKey[fixture.key] ?? `${fixture.key}.json`;
  const snapshot = {
    fixtureKey: fixture.key,
    name: fixture.name,
    description: fixture.description,
    publicId: fixture.publicId,
    policyVersion: decision.policyVersion,
    eligibility: decision,
    authorityInput: fixture.authority,
    credential,
    registry: credential.status === 'issued' ? {
      publicId: credential.publicId,
      url: `/registry/${credential.publicId}`,
      issuer: credential.issuer,
      program: credential.program,
      subject: credential.subject,
      published: true,
      credentialStatus: credential.status,
      eligibility: { tier: credential.eligibleTier, name: credential.eligibleTierName },
      certification: { tier: credential.tier, name: credential.tierName, disclosure: credential.disclosure },
      authorization: credential.authorization,
      sealAuthorization: credential.sealAuthorization,
      claimScope: credential.claims.map(({ id, label, value, status, scopeNote }) => ({ id, label, value, status, scopeNote })),
      evidenceSummary: {
        count: credential.evidence.length,
        qualifiedSources: credential.sources.filter((source) => source.qualified).length,
        independentSources: credential.sources.filter((source) => source.independent && source.qualified).length,
      },
      lifecycle: credential.lifecycle,
      version: credential.version,
      issuedAt: credential.issuedAt ?? null,
      signature: credential.signature,
      integrityHash: credential.integrityHash,
      successorId: credential.successorId,
      warnings: credential.warnings,
      testMode: credential.testMode,
    } : null,
    events,
    webhooks,
    mode: 'TEST MODE / NON-AUTHORITATIVE / NOT A PRODUCTION CREDENTIAL',
  };
  fs.writeFileSync(path.join(outputDir, filename), `${JSON.stringify(snapshot, null, 2)}\n`);
  return {
    key: fixture.key,
    file: `authority/${filename}`,
    publicId: fixture.publicId,
    expectedEligibleTier: fixture.expectedTier,
    expectedIssuanceStatus: fixture.expectedIssuanceStatus,
    expectedCredentialStatus: fixture.expectedIssued ? 'issued' : 'not-issued',
    expectedRegistryPublished: fixture.expectedIssued,
    expectedSealAuthorized: fixture.expectedIssued && fixture.lifecycle === 'active' && fixture.authority.markAuthorization === 'authorized',
  };
});

fs.writeFileSync(path.resolve('fixtures/fixture-manifest.json'), `${JSON.stringify({
  schemaVersion: '2.0.0',
  policyVersion: evaluateCertification(fixtures.t4.policy, fixtures.t4.claims).policyVersion,
  mode: 'TEST MODE / NON-AUTHORITATIVE / NOT A PRODUCTION CREDENTIAL',
  generatedBy: 'scripts/export-authority-fixtures.ts',
  fixtures: manifest,
}, null, 2)}\n`);
