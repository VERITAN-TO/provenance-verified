const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.argv[2];
if (!root) throw new Error('compiled module directory required');
const contracts = require(path.join(root, 'authority-contracts.js'));
const states = require(path.join(root, 'authority-state.js'));
let passed = 0;
const test = (name, fn) => { fn(); passed += 1; process.stdout.write(`PASS ${name}\n`); };
const canonical = {
  ok: true,
  data: {
    actor: { actorId: 'actor-1', actorType: 'user', displayName: 'member@example.test', authenticationStrength: 'aal2' },
    tenant: { tenantId: 'tenant-1', displayName: 'Tenant One' },
    membership: { membershipId: 'membership-1', status: 'active', role: 'organization_admin' },
    authorization: { decision: 'ALLOW', authorityVersion: '7', decisionId: 'decision-1', policyVersion: 'v1-wave1' },
    session: { sessionId: 'session-1', expiresAt: '2099-01-01T00:00:00.000Z' },
    eligibleTenants: [{ tenantId: 'tenant-1', displayName: 'Tenant One', role: 'organization_admin' }],
    correlationId: '00000000-0000-4000-8000-000000000001',
  },
};

test('canonical A5 response parses', () => assert(contracts.parseAuthorityContext(canonical)));
test('actor binding preserved', () => assert.equal(contracts.parseAuthorityContext(canonical).actor.actorId, 'actor-1'));
test('tenant binding preserved', () => assert.equal(contracts.parseAuthorityContext(canonical).tenant.tenantId, 'tenant-1'));
test('role binding preserved', () => assert.equal(contracts.parseAuthorityContext(canonical).membership.role, 'organization_admin'));
test('authority version preserved', () => assert.equal(contracts.parseAuthorityContext(canonical).authorization.authorityVersion, '7'));
test('missing actor denied', () => assert.equal(contracts.parseAuthorityContext({ data: { ...canonical.data, actor: {} } }), null));
test('inactive membership denied', () => assert.equal(contracts.parseAuthorityContext({ data: { ...canonical.data, membership: { ...canonical.data.membership, status: 'suspended' } } }), null));
test('non-ALLOW denied', () => assert.equal(contracts.parseAuthorityContext({ data: { ...canonical.data, authorization: { ...canonical.data.authorization, decision: 'DENY' } } }), null));
test('invalid expiry denied', () => assert.equal(contracts.parseAuthorityContext({ data: { ...canonical.data, session: { ...canonical.data.session, expiresAt: 'not-a-date' } } }), null));
test('eligible tenants parsed', () => assert.equal(contracts.parseEligibleTenants(canonical.data.eligibleTenants).length, 1));
test('ambiguous tenant maps safely', () => assert.equal(contracts.denialFromEnvelope({ code: 'DENY_TENANT_AMBIGUOUS', retryable: false }, 409).code, 'DENY_TENANT_AMBIGUOUS'));
test('MFA required maps safely', () => assert.equal(contracts.denialFromEnvelope({ code: 'DENY_MFA_REQUIRED', retryable: false }, 403).code, 'DENY_MFA_REQUIRED'));
test('rate limit retry remains bounded', () => assert.equal(contracts.denialFromEnvelope({ code: 'DENY_RATE_LIMITED', retryable: true }, 429).retryable, true));
test('raw provider message ignored', () => assert(!contracts.denialFromEnvelope({ code: 'DENY_ACTOR_UNKNOWN', message: 'SQL secret token' }, 403).message.includes('SQL secret')));
test('initial state withholds content', () => assert.equal(states.initialAuthorityState.status, 'BOOTING'));
test('valid resolving transition', () => assert.equal(states.transitionAuthorityState({ status: 'BOOTING' }, { status: 'RESOLVING_SESSION' }).status, 'RESOLVING_SESSION'));
test('authenticated requires context', () => assert.equal(states.transitionAuthorityState({ status: 'RESOLVING_SESSION' }, { status: 'AUTHENTICATED' }).status, 'RESOLVING_SESSION'));
test('authenticated accepts canonical context', () => assert.equal(states.transitionAuthorityState({ status: 'RESOLVING_SESSION' }, { status: 'AUTHENTICATED', context: contracts.parseAuthorityContext(canonical) }).status, 'AUTHENTICATED'));
test('terminal role denial cannot retry', () => assert.equal(states.canRetryState(states.stateForDenial(contracts.safeDenial('DENY_ROLE'))), false));
test('authority unavailable may retry', () => assert.equal(states.canRetryState(states.stateForDenial(contracts.safeDenial('DENY_AUTHORITY_UNAVAILABLE'))), true));
console.log(JSON.stringify({ passed, failed: 0 }, null, 2));
