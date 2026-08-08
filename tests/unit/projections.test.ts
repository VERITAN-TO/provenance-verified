import { describe, expect, it } from 'vitest';
import { fixtures } from '@/domain/fixtures';
import { buildCredential, buildEvents, buildWebhookAttempts } from '@/domain/projectors';
import { projectionParity, registryProjection } from '@/adapters/projections';

describe('canonical projections', () => {
  it('keeps issued API and registry fields aligned', () => {
    const credential = buildCredential(fixtures.t4);
    expect(Object.values(projectionParity(credential)).every(Boolean)).toBe(true);
    expect(registryProjection(credential).published).toBe(true);
  });

  it('keeps eligibility-only cases unpublished', () => {
    const credential = buildCredential(fixtures.t4MissingSecondApproval);
    const registry = registryProjection(credential);
    expect(registry.published).toBe(false);
    expect(registry.certification).toBeNull();
    expect(credential.tier).toBeNull();
  });

  it('builds a deterministic event hash chain', () => {
    const events = buildEvents(buildCredential(fixtures.t4));
    events.slice(1).forEach((event, index) => expect(event.previousEventHash).toBe(events[index].eventHash));
  });

  it('emits an authorization-blocked event and no webhook for an unissued case', () => {
    const events = buildEvents(buildCredential(fixtures.t4CustosPending));
    expect(events.some((event) => event.type === 'credential.authorization.blocked')).toBe(true);
    expect(events.some((event) => event.type === 'credential.issued')).toBe(false);
    expect(buildWebhookAttempts(events)).toEqual([]);
  });

  it('keeps webhook attempts linked to a displayed issued event', () => {
    const events = buildEvents(buildCredential(fixtures.t4));
    const attempts = buildWebhookAttempts(events);
    expect(attempts.length).toBeGreaterThan(0);
    expect(events.some((event) => event.id === attempts[0].eventId)).toBe(true);
  });
});
