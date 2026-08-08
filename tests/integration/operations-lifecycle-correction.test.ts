import { beforeEach, describe, expect, it } from 'vitest';
import { NextRequest } from 'next/server';
import { OperationalRepository } from '@/operations/repository';
import { operationalDataset } from '@/operations/fixtures';
import { authorizationHeaders } from '@/operations/auth';
import { POST as decision } from '@/app/api/v1/operations/review/[caseId]/decision/route';
import { POST as lifecycle } from '@/app/api/v1/operations/review/[caseId]/lifecycle/route';
import { POST as correction } from '@/app/api/v1/operations/review/[caseId]/corrections/route';
import { POST as labels } from '@/app/api/v1/operations/labels/route';
import { GET as sessionState } from '@/app/api/v1/operations/session/route';

const getSession = (id: string) => operationalDataset.sessions.find((item) => item.id === id)!;
const headers = (id: string) => authorizationHeaders(getSession(id), 'application/json');
const caseId = `review_${operationalDataset.assets[0].id}`;

async function authorityAction(sessionId: string, action: string, role: 'primary' | 'secondary' = 'primary', decisionValue: 'approve' | 'pending' = 'pending') {
  const session = getSession(sessionId);
  return decision(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/decision`, {
    method: 'POST', headers: headers(sessionId), body: JSON.stringify({ reviewerId: session.userId, role, decision: decisionValue, independent: true, conflictFree: true, reasonCodes: [`PV_${action.toUpperCase().replaceAll('-', '_')}`], action }),
  }), { params: Promise.resolve({ caseId }) });
}

async function issueAndAuthorizeMark() {
  const steps: Array<[string, string, 'primary' | 'secondary', 'approve' | 'pending']> = [
    ['session_reviewer_secondary', 'review', 'secondary', 'approve'],
    ['session_compliance', 'custos-pass', 'primary', 'pending'],
    ['session_compliance', 'authorize-signing', 'primary', 'pending'],
    ['session_compliance', 'publish-registry', 'primary', 'pending'],
    ['session_compliance', 'enable-revocation-control', 'primary', 'pending'],
    ['session_compliance', 'authorize-mark', 'primary', 'pending'],
  ];
  for (const [sessionId, action, role, decisionValue] of steps) {
    const response = await authorityAction(sessionId, action, role, decisionValue);
    expect(response.status).toBe(200);
  }
}

describe('operational lifecycle and correction authority', () => {
  beforeEach(() => { globalThis.__pvOperationalRepository = new OperationalRepository(operationalDataset); });

  it('requires a signed test token and rejects missing or tampered sessions', async () => {
    const missing = await sessionState(new NextRequest('http://localhost/api/v1/operations/session'));
    expect(missing.status).toBe(503); // wave1 session boundary is unavailable in sandbox
    const tampered = await sessionState(new NextRequest('http://localhost/api/v1/operations/session', { headers: { authorization: 'Bearer pv_test_v1.session_intake.tampered' } }));
    expect(tampered.status).toBe(503); // wave1 session boundary is unavailable in sandbox
    const accepted = await sessionState(new NextRequest('http://localhost/api/v1/operations/session', { headers: authorizationHeaders(getSession('session_intake')) }));
    expect(accepted.status).toBe(503); // wave1 requires real supabase session, not test tokens
  });

  it('executes lifecycle transitions and suppresses marks in negative states', async () => {
    await issueAndAuthorizeMark();
    const assetId = operationalDataset.assets[0].id;
    const before = await labels(new NextRequest('http://localhost/api/v1/operations/labels', { method: 'POST', headers: headers('session_attestor'), body: JSON.stringify({ assetIds: [assetId], format: 'svg' }) }));
    expect(before.status).toBe(200);

    const suspended = await lifecycle(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: headers('session_compliance'), body: JSON.stringify({ action: 'suspend', reason: 'Compliance hold pending independent document confirmation.' }) }), { params: Promise.resolve({ caseId }) });
    const suspendedBody = await suspended.json();
    expect(suspended.status).toBe(200);
    expect(suspendedBody.data.credentialLifecycle).toBe('suspended');
    expect(suspendedBody.data.credential.sealAuthorization.status).toBe('not-authorized');
    expect((await labels(new NextRequest('http://localhost/api/v1/operations/labels', { method: 'POST', headers: headers('session_attestor'), body: JSON.stringify({ assetIds: [assetId], format: 'svg' }) }))).status).toBe(409);

    const reactivated = await lifecycle(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: headers('session_compliance'), body: JSON.stringify({ action: 'reactivate', reason: 'Independent document confirmation completed and recorded.' }) }), { params: Promise.resolve({ caseId }) });
    const reactivatedBody = await reactivated.json();
    expect(reactivatedBody.data.credentialLifecycle).toBe('active');
    expect(reactivatedBody.data.markAuthorization).toBe('pending');
    expect(reactivatedBody.data.credential.sealAuthorization.status).toBe('not-authorized');

    expect((await authorityAction('session_compliance', 'authorize-mark')).status).toBe(200);
    const revoked = await lifecycle(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: headers('session_compliance'), body: JSON.stringify({ action: 'revoke', reason: 'Confirmed material misrepresentation requires permanent revocation.' }) }), { params: Promise.resolve({ caseId }) });
    const revokedBody = await revoked.json();
    expect(revokedBody.data.credentialLifecycle).toBe('revoked');
    expect(revokedBody.data.credential.sealAuthorization.status).toBe('not-authorized');
    const invalidReactivation = await lifecycle(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/lifecycle`, { method: 'POST', headers: headers('session_compliance'), body: JSON.stringify({ action: 'reactivate', reason: 'A revoked credential cannot be restored by operator action.' }) }), { params: Promise.resolve({ caseId }) });
    expect(invalidReactivation.status).toBe(400);
  });

  it('opens a correction, blocks authority, and resolves with a new immutable attestation version', async () => {
    await issueAndAuthorizeMark();
    const requested = await correction(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/corrections`, { method: 'POST', headers: headers('session_reviewer'), body: JSON.stringify({ action: 'request', reason: 'Origin claim and linked evidence require a controlled correction.', fields: ['originClaim', 'evidence'] }) }), { params: Promise.resolve({ caseId }) });
    const requestedBody = await requested.json();
    expect(requested.status).toBe(200);
    expect(requestedBody.data.status).toBe('correction-requested');
    expect(requestedBody.data.credentialLifecycle).toBe('suspended');
    expect(requestedBody.data.credential.sealAuthorization.status).toBe('not-authorized');
    const correctionId = requestedBody.data.corrections.at(-1).id;

    const resolved = await correction(new NextRequest(`http://localhost/api/v1/operations/review/${caseId}/corrections`, { method: 'POST', headers: headers('session_attestor'), body: JSON.stringify({ action: 'resolve', correctionId, resolution: 'Origin evidence corrected and independently re-linked.', claimSummary: 'Corrected origin, identity, treatment, measurement, transfer, and custody claims submitted for re-review.', evidenceSummary: 'Corrected evidence objects preserve prior versions and canonical integrity hashes.', limitations: ['All prior approvals are invalidated by this correction.'] }) }), { params: Promise.resolve({ caseId }) });
    const resolvedBody = await resolved.json();
    expect(resolved.status).toBe(200);
    expect(resolvedBody.data.status).toBe('unassigned');
    expect(resolvedBody.data.approvals).toHaveLength(0);
    expect(resolvedBody.data.credential).toBeUndefined();
    expect(resolvedBody.data.corrections.at(-1).replacementAttestationId).toMatch(/^att_/);
    expect(globalThis.__pvOperationalRepository!.listAttestations(getSession('session_attestor'), 'batch_phx_2026_0720_a').at(-1)?.version).toBe(2);
  });
});
