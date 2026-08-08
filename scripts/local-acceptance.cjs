'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const Module = require('node:module');
const assert = require('node:assert/strict');

const projectRoot = path.resolve(__dirname, '..');
const buildRoot = path.join(projectRoot, '.local-build', 'src');
const originalResolve = Module._resolveFilename;
Module._resolveFilename = function(request, parent, isMain, options) {
  if (request.startsWith('@/')) {
    const target = path.join(buildRoot, request.slice(2));
    return originalResolve.call(this, target, parent, isMain, options);
  }
  return originalResolve.call(this, request, parent, isMain, options);
};

const report = { generatedAt: new Date().toISOString(), suite: 'local-no-deployment-acceptance', tests: [], passed: 0, failed: 0 };
async function test(name, fn) {
  const started = Date.now();
  try {
    await fn();
    report.tests.push({ name, status: 'pass', durationMs: Date.now() - started });
    report.passed += 1;
  } catch (error) {
    report.tests.push({ name, status: 'fail', durationMs: Date.now() - started, error: String(error && error.stack || error) });
    report.failed += 1;
  }
}
function clone(value) { return structuredClone(value); }
function expectThrows(fn, pattern) {
  let thrown = null;
  try { fn(); } catch (error) { thrown = error; }
  assert.ok(thrown, 'Expected function to throw');
  if (pattern) assert.match(String(thrown.message || thrown), pattern);
}

(async () => {
  const { fixtures, fixtureList } = require(path.join(buildRoot, 'domain', 'fixtures.js'));
  const { evaluateCertification, summarizeClaims } = require(path.join(buildRoot, 'domain', 'kernel.js'));
  const { evaluateIssuance } = require(path.join(buildRoot, 'domain', 'authority.js'));
  const { buildCredential, buildEvents, buildWebhookAttempts } = require(path.join(buildRoot, 'domain', 'projectors.js'));
  const { stableHash, canonicalJson } = require(path.join(buildRoot, 'domain', 'hash.js'));
  const { operationalDataset } = require(path.join(buildRoot, 'operations', 'fixtures.js'));
  const { OperationalRepository } = require(path.join(buildRoot, 'operations', 'repository.js'));
  const {
    assertTenantScope, assertPermission, createAssetId, validateBatch, isBatchSubmittable,
    signAttestation, validateStructuredAttestation, applySyncOperation, createOperationalEventReceipt,
    credentialForOperationalAsset,
  } = require(path.join(buildRoot, 'operations', 'kernel.js'));
  const { applyCredentialLifecycleTransition } = require(path.join(buildRoot, 'operations', 'lifecycle.js'));
  const { requestCorrection, rejectCorrection, resolveCorrection } = require(path.join(buildRoot, 'operations', 'corrections.js'));
  const { can } = require(path.join(buildRoot, 'operations', 'permissions.js'));
  const { authenticateTestModeToken } = require(path.join(buildRoot, 'operations', 'auth.js'));
  const { getAuthorityRuntimeConfig } = require(path.join(buildRoot, 'authority', 'config.js'));
  const { decodeJwtClaims } = require(path.join(buildRoot, 'authority', 'cookies.js'));

  await test('stableHash is deterministic and input-sensitive', () => {
    assert.equal(stableHash('abc'), stableHash('abc'));
    assert.notEqual(stableHash('abc'), stableHash('abcd'));
  });
  await test('canonicalJson is key-order stable', () => {
    assert.equal(canonicalJson({ b: 2, a: 1 }), canonicalJson({ a: 1, b: 2 }));
  });
  for (const key of ['t1','t2','t3','t4']) {
    await test(`eligibility kernel evaluates exact ${key.toUpperCase()} tier`, () => {
      const fixture = fixtures[key];
      const decision = evaluateCertification(fixture.policy, fixture.claims);
      assert.equal(decision.tier, fixture.expectedTier);
      assert.equal(decision.ringCount, fixture.expectedTier);
      assert.equal(decision.policyVersion, 'PV-POLICY-2026.07-R2');
    });
  }
  await test('invalid attestation falls back to Tier 1', () => {
    assert.equal(evaluateCertification(fixtures.invalidSignature.policy, fixtures.invalidSignature.claims).tier, 1);
  });
  await test('Tier 4 requires two independent sources', () => {
    const decision = evaluateCertification({ ...fixtures.t4.policy, qualifyingIndependentSources: 1 }, fixtures.t4.claims);
    assert.equal(decision.tier, 3);
    assert.ok(decision.upgradePath.includes('At least two qualifying independent sources'));
  });
  await test('material conflict caps independently corroborated tiers', () => {
    const decision = evaluateCertification(fixtures.conflicting.policy, fixtures.conflicting.claims);
    assert.equal(decision.tier, 2);
    assert.ok(decision.reasonCodes.includes('PV_MATERIAL_CONFLICT_CAP'));
  });
  await test('claim summary counts every supported status', () => {
    const summary = summarizeClaims(fixtures.conflicting.claims);
    assert.equal(Object.values(summary).reduce((a,b)=>a+b,0), fixtures.conflicting.claims.length);
    assert.ok(summary.conflicting >= 1);
  });

  for (const fixture of fixtureList) {
    await test(`fixture ${fixture.key} matches expected issuance`, () => {
      const decision = evaluateCertification(fixture.policy, fixture.claims);
      const issuance = evaluateIssuance(decision, fixture.authority);
      const credential = buildCredential(fixture);
      assert.equal(issuance.status, fixture.expectedIssuanceStatus);
      assert.equal(credential.status === 'issued', fixture.expectedIssued);
      assert.equal(credential.publicId, fixture.publicId);
      assert.match(credential.integrityHash, /^sha256:[a-f0-9]+$/i);
      if (!fixture.expectedIssued) assert.equal(credential.sealAuthorization.status, 'not-authorized');
    });
  }

  await test('signed event chain is contiguous and attributable', () => {
    const credential = buildCredential(fixtures.t4);
    const events = buildEvents(credential);
    assert.ok(events.length >= 7);
    let previous = 'genesis:test-mode';
    for (const [index, event] of events.entries()) {
      assert.equal(event.sequence, index + 1);
      assert.equal(event.previousEventHash, previous);
      assert.match(event.eventHash, /^sha256:/);
      assert.match(event.signature, /^ed25519:test:/);
      previous = event.eventHash;
    }
  });
  await test('webhook retries preserve event lineage', () => {
    const attempts = buildWebhookAttempts(buildEvents(buildCredential(fixtures.t4)));
    assert.equal(attempts.length, 2);
    assert.equal(attempts[0].eventId, attempts[1].eventId);
    assert.equal(attempts[0].status, 'failed');
    assert.equal(attempts[1].status, 'waiting');
  });

  const seed = clone(operationalDataset);
  const repository = new OperationalRepository(seed);
  const sessionIntake = seed.sessions.find((s) => s.id === 'session_intake');
  const sessionAttestor = seed.sessions.find((s) => s.id === 'session_attestor');
  const sessionReviewer = seed.sessions.find((s) => s.id === 'session_reviewer');
  const sessionCompliance = seed.sessions.find((s) => s.id === 'session_compliance');
  const sessionOther = seed.sessions.find((s) => s.id === 'session_other_tenant');
  assert.ok(sessionIntake && sessionAttestor && sessionReviewer && sessionCompliance && sessionOther);

  await test('tenant isolation denies cross-tenant asset access', () => {
    const asset = seed.assets.find((a) => a.tenantId === sessionIntake.tenantId);
    assert.ok(asset);
    expectThrows(() => repository.getAsset(sessionOther, asset.id), /TENANT_SCOPE_VIOLATION/);
    expectThrows(() => assertTenantScope(sessionOther, asset.tenantId), /TENANT_SCOPE_VIOLATION/);
  });
  await test('permissions deny intake operator review decisions', () => {
    assert.equal(can(sessionIntake.role, 'review.decide'), false);
    expectThrows(() => assertPermission(sessionIntake, 'review.decide'), /PERMISSION_DENIED/);
    assert.equal(can(sessionReviewer.role, 'review.decide'), true);
  });
  await test('asset IDs are deterministic and tenant-bound', () => {
    const a = createAssetId('tenant-a','SERIAL-1');
    const b = createAssetId('tenant-a','serial-1');
    const c = createAssetId('tenant-b','SERIAL-1');
    assert.equal(a,b); assert.notEqual(a,c);
  });
  await test('batch validation detects missing evidence and duplicate serials', () => {
    const batch = clone(seed.batches[0]);
    const assets = clone(seed.assets.filter((a)=>a.batchId===batch.id).slice(0,2));
    assets[1].serial = assets[0].serial;
    const evidence = clone(seed.evidence.filter((e)=>e.assetId===assets[0].id));
    const issues = validateBatch(batch, assets, evidence);
    assert.ok(issues.some((i)=>i.code==='PV_DUPLICATE_SERIAL'));
    assert.ok(issues.some((i)=>i.code==='PV_ASSET_PHOTO_REQUIRED' && i.assetId===assets[1].id));
    assert.equal(isBatchSubmittable(issues), false);
  });
  await test('structured attestation is immutable, signed, and verifiable', () => {
    const batch = clone(seed.batches[0]);
    const assets = clone(seed.assets.filter((a)=>a.batchId===batch.id));
    const att = signAttestation(sessionAttestor, batch, assets, 'Claims', 'Evidence', ['Limit']);
    const review = clone(seed.reviewCases.find((r)=>r.assetId===assets[0].id));
    review.attestationId = att.id;
    assert.equal(validateStructuredAttestation(att, assets[0], review), true);
    assert.equal(validateStructuredAttestation({ ...att, signature: 'tampered' }, assets[0], review), false);
  });
  await test('append-only attestation storage rejects duplicate IDs', () => {
    const batch = clone(seed.batches[0]);
    const assets = clone(seed.assets.filter((a)=>a.batchId===batch.id));
    const att = signAttestation(sessionAttestor, batch, assets, 'Claims2', 'Evidence2', []);
    repository.appendAttestation(sessionAttestor, att);
    expectThrows(() => repository.appendAttestation(sessionAttestor, att), /ATTESTATION_IMMUTABLE/);
  });
  await test('sync applies valid version and fails closed on conflict', () => {
    const asset = clone(seed.assets[0]);
    const valid = applySyncOperation({ id:'sync-valid', tenantId:asset.tenantId, deviceId:sessionIntake.deviceId, entityType:'asset', entityId:asset.id, operation:'update', expectedVersion:asset.version, payload:{colorDescription:'Updated'}, status:'queued', attempts:0, createdAt:new Date().toISOString() }, asset);
    assert.equal(valid.operation.status, 'applied');
    assert.equal(valid.entity.version, asset.version + 1);
    const conflict = applySyncOperation({ ...valid.operation, id:'sync-conflict', status:'queued', expectedVersion:0, attempts:0, payload:{colorDescription:'Bad'} }, asset);
    assert.equal(conflict.operation.status, 'conflict');
    assert.match(conflict.operation.error, /VERSION_CONFLICT/);
  });
  await test('event receipts chain deterministically', () => {
    const r1 = createOperationalEventReceipt([], 'attestation.recorded', 'x', sessionAttestor.userId, '2026-07-20T00:00:00Z');
    const r2 = createOperationalEventReceipt([r1], 'review.primary-recorded', 'x', sessionReviewer.userId, '2026-07-20T00:01:00Z');
    assert.equal(r1.sequence,1); assert.equal(r2.sequence,2); assert.equal(r2.previousEventHash,r1.eventHash);
  });

  function issuedReview() {
    const review = clone(seed.reviewCases[0]);
    review.credential = buildCredential(fixtures.t4);
    review.registryStatus = 'ready';
    review.registryPublication = { publicId: review.registryId, receiptId: 'registry-local', publishedAt: '2026-07-20T00:00:00Z', integrityHash: 'sha256:local' };
    review.revocationCapability = true;
    review.credentialLifecycle = 'active';
    review.markAuthorization = 'authorized';
    review.corrections = [];
    return review;
  }

  await test('credential lifecycle denies invalid transition', () => {
    const review = issuedReview();
    review.credentialLifecycle = 'revoked';
    expectThrows(() => applyCredentialLifecycleTransition(review,{action:'reactivate',reason:'bad',actorId:sessionCompliance.userId,at:'2026-07-20T10:00:00Z'}), /INVALID_LIFECYCLE_TRANSITION/);
  });
  await test('credential suspension suppresses mark authorization', () => {
    const review = issuedReview();
    review.credentialLifecycle='active'; review.markAuthorization='authorized';
    const updated = applyCredentialLifecycleTransition(review,{action:'suspend',reason:'investigation',actorId:sessionCompliance.userId,at:'2026-07-20T10:01:00Z'});
    assert.equal(updated.credentialLifecycle,'suspended');
    assert.equal(updated.markAuthorization,'denied');
  });
  await test('reactivation never silently restores mark authorization', () => {
    const review = issuedReview();
    review.credentialLifecycle='suspended'; review.markAuthorization='denied';
    const updated = applyCredentialLifecycleTransition(review,{action:'reactivate',reason:'cleared',actorId:sessionCompliance.userId,at:'2026-07-20T10:02:00Z'});
    assert.equal(updated.credentialLifecycle,'active');
    assert.equal(updated.markAuthorization,'pending');
  });
  await test('supersession requires successor ID', () => {
    const review = issuedReview();
    review.credentialLifecycle='active';
    expectThrows(() => applyCredentialLifecycleTransition(review,{action:'supersede',reason:'new version',actorId:sessionCompliance.userId,at:'2026-07-20T10:03:00Z'}), /SUCCESSOR_ID_REQUIRED/);
  });

  await test('open correction suspends active issued credential and blocks marks', () => {
    const review = issuedReview();
    review.corrections=[]; review.credentialLifecycle='active'; review.markAuthorization='authorized';
    const updated = requestCorrection(review, sessionCompliance, {reason:'Evidence mismatch',fields:['originClaim','evidence'],at:'2026-07-20T11:00:00Z'});
    assert.equal(updated.status,'correction-requested');
    assert.equal(updated.credentialLifecycle,'suspended');
    assert.equal(updated.markAuthorization,'denied');
    expectThrows(() => requestCorrection(updated, sessionCompliance, {reason:'Second',fields:['x'],at:'2026-07-20T11:01:00Z'}), /OPEN_CORRECTION_EXISTS/);
  });
  await test('correction rejection closes request without creating authority', () => {
    const review = issuedReview();
    review.corrections=[];
    const requested = requestCorrection(review, sessionCompliance, {reason:'Check',fields:['originClaim'],at:'2026-07-20T11:02:00Z'});
    const rejected = rejectCorrection(requested, sessionCompliance, {correctionId:requested.corrections[0].id,resolution:'No change supported',at:'2026-07-20T11:03:00Z'});
    assert.equal(rejected.corrections[0].status,'rejected');
    assert.equal(rejected.correctionRequest, undefined);
  });

  await test('authorization parser denies missing and malformed session tokens', () => {
    expectThrows(() => authenticateTestModeToken(null, seed.sessions), /SESSION_REQUIRED/);
    expectThrows(() => authenticateTestModeToken('Bearer invalid', seed.sessions), /SESSION_TOKEN_INVALID/);
  });
  await test('authority config fails closed when production activation is incomplete', () => {
    const original = { ...process.env };
    try {
      process.env.PV_ENVIRONMENT='production';
      process.env.PV_AUTHORITY_API_URL='https://authority.invalid';
      process.env.PV_SUPABASE_URL='https://example.supabase.co';
      process.env.PV_SUPABASE_PUBLISHABLE_KEY='sb_publishable_test';
      delete process.env.PV_PRODUCTION_AUTHORITY_ENABLED;
      expectThrows(() => getAuthorityRuntimeConfig(), /PRODUCTION_ACTIVATION_INCOMPLETE/);
    } finally {
      for (const key of Object.keys(process.env)) if (!(key in original)) delete process.env[key];
      Object.assign(process.env, original);
    }
  });
  await test('JWT decoder rejects malformed payloads', () => {
    expectThrows(() => decodeJwtClaims('bad'), /JWT_MALFORMED/);
    const payload = Buffer.from(JSON.stringify({sub:'u',exp:9999999999})).toString('base64url');
    const decoded = decodeJwtClaims(`x.${payload}.y`);
    assert.equal(decoded.sub,'u');
  });

  const reportPath = path.join(projectRoot, 'evidence', 'local-acceptance.json');
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
  process.exitCode = report.failed ? 1 : 0;
})();
