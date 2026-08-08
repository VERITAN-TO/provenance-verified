import { beforeEach, describe, expect, it } from 'vitest';
import { useProvenanceStore } from '@/store/useProvenanceStore';

describe('canonical interactive authority state', () => {
  beforeEach(() => {
    useProvenanceStore.getState().selectFixture('t4');
    useProvenanceStore.getState().setReducedMotion(true);
  });

  it('propagates a blocked Gold case through UI state without credential, registry publication, or webhooks', async () => {
    const store = useProvenanceStore.getState();
    store.selectFixture('t4MissingSecondApproval');
    await useProvenanceStore.getState().runVerification();
    const state = useProvenanceStore.getState();
    expect(state.decision.tier).toBe(4);
    expect(state.credential.status).toBe('not-issued');
    expect(state.credential.authorization.status).toBe('second-approval-required');
    expect(state.webhooks).toEqual([]);
    expect(state.runState).toBe('error');
    expect(state.apiLog[0].status).toBe(409);
  });

  it('prevents lifecycle transitions before credential issuance', () => {
    useProvenanceStore.getState().selectFixture('t4CustosPending');
    const before = useProvenanceStore.getState();
    expect(before.credential.lifecycle).toBe('draft');
    before.setLifecycle('suspended');
    const after = useProvenanceStore.getState();
    expect(after.credential.lifecycle).toBe('draft');
    expect(after.statusMessage).toContain('prohibited');
  });

  it('allows an issued credential while withholding the certification mark', () => {
    useProvenanceStore.getState().selectFixture('t4MarkPending');
    const state = useProvenanceStore.getState();
    expect(state.credential.status).toBe('issued');
    expect(state.credential.tier).toBe(4);
    expect(state.credential.sealAuthorization.status).toBe('not-authorized');
    expect(state.webhooks.length).toBeGreaterThan(0);
  });

  it('updates lifecycle and appends a signed lifecycle event only for an issued credential', () => {
    const before = useProvenanceStore.getState();
    const eventCount = before.events.length;
    before.setLifecycle('suspended');
    const after = useProvenanceStore.getState();
    expect(after.credential.lifecycle).toBe('suspended');
    expect(after.events).toHaveLength(eventCount + 1);
    expect(after.events.at(-1)?.type).toBe('credential.lifecycle.changed');
  });

  it('keeps a denied mark separate from credential issuance', () => {
    useProvenanceStore.getState().selectFixture('t4MarkDenied');
    const state = useProvenanceStore.getState();
    expect(state.credential.status).toBe('issued');
    expect(state.credential.sealAuthorization.reasonCodes).toContain('PV_MARK_DENIED');
  });
});
