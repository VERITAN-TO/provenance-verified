'use client';

import { useMemo, useState } from 'react';
import type { LifecycleState, SignedEvent } from '@/domain/types';
import { useProvenanceStore } from '@/store/useProvenanceStore';
import { selectWebhookSummary } from '@/store/selectors';
import { Metric, ProofChapterHeader, StatePill } from './Shared';

type EventFilter = 'all' | 'authority' | 'publication' | 'delivery' | 'lifecycle';
const lifecycleOptions: LifecycleState[] = ['active', 'suspended', 'superseded', 'revoked', 'expired'];

function eventGroup(event: SignedEvent): Exclude<EventFilter, 'all'> {
  if (event.type.includes('webhook')) return 'delivery';
  if (event.type.includes('lifecycle')) return 'lifecycle';
  if (event.type.includes('registry') || event.type.includes('seal') || event.type.includes('credential.issued')) return 'publication';
  return 'authority';
}

export function LifecycleContinuity() {
  const credential = useProvenanceStore((state) => state.credential);
  const events = useProvenanceStore((state) => state.events);
  const webhooks = useProvenanceStore((state) => state.webhooks);
  const retryWebhook = useProvenanceStore((state) => state.retryWebhook);
  const replayWebhook = useProvenanceStore((state) => state.replayWebhook);
  const setLifecycle = useProvenanceStore((state) => state.setLifecycle);
  const [filter, setFilter] = useState<EventFilter>('all');
  const issued = credential.status === 'issued';
  const filteredEvents = useMemo(() => events.filter((event) => filter === 'all' || eventGroup(event) === filter), [events, filter]);
  const webhookSummary = selectWebhookSummary(webhooks);

  return (
    <section className="p3-chapter p3-continuity" aria-labelledby="p3-continuity-title">
      <ProofChapterHeader
        index="05"
        eyebrow="SIGNED CONSEQUENCE + LIFECYCLE"
        title="History remains attributable when current reliance changes."
        description="Issuance, publication, delivery, suspension, supersession, revocation, and expiration remain linked through signed events. A lifecycle transition changes current reliance without deleting prior truth."
        aside={<StatePill tone={credential.lifecycle === 'active' ? 'good' : credential.lifecycle === 'revoked' ? 'danger' : 'warn'}>{credential.lifecycle.toUpperCase()}</StatePill>}
      />

      <div className="p3-continuity-summary">
        <Metric label="Signed events" value={events.length} detail={`Last sequence ${events.at(-1)?.sequence ?? 0}`} />
        <Metric label="Webhook delivery" value={`${webhookSummary.delivered} delivered`} detail={`${webhookSummary.failed} failed · ${webhookSummary.waiting} waiting`} />
        <Metric label="Current lifecycle" value={credential.lifecycle} detail={issued ? 'Credential remains resolvable' : 'No issued credential'} />
        <Metric label="Successor" value={credential.successorId ?? 'None'} detail={credential.lifecycle === 'superseded' ? 'Follow successor record' : 'No successor required'} />
      </div>

      <div className="p3-continuity-grid">
        <div className="p3-event-ledger">
          <div className="p3-panel-head"><span>APPEND-ONLY EVENT LEDGER</span><strong>{filteredEvents.length} EVENTS</strong></div>
          <div className="p3-filter-row" role="group" aria-label="Filter event ledger">
            {(['all', 'authority', 'publication', 'delivery', 'lifecycle'] as const).map((item) => <button key={item} type="button" className={filter === item ? 'active' : ''} onClick={() => setFilter(item)}>{item}</button>)}
          </div>
          <ol className="p3-event-list">
            {filteredEvents.map((event) => (
              <li key={event.id}>
                <div className="p3-event-sequence">{String(event.sequence).padStart(2, '0')}</div>
                <div><strong>{event.type}</strong><span>{event.at}</span><code>{event.eventHash}</code></div>
                <StatePill tone={event.type.includes('failed') ? 'danger' : 'good'}>{eventGroup(event)}</StatePill>
              </li>
            ))}
          </ol>
        </div>

        <aside className="p3-lifecycle-control">
          <div className="p3-panel-head"><span>LIFECYCLE CONTROL</span><strong>TEST MODE</strong></div>
          <p>Lifecycle actions are available only after issuer-authorized credential issuance. Every transition appends a new event and updates public and machine projections together.</p>
          <div className="p3-lifecycle-buttons">
            {lifecycleOptions.map((state) => <button key={state} type="button" disabled={!issued || credential.lifecycle === state} className={credential.lifecycle === state ? 'active' : ''} onClick={() => setLifecycle(state)}>{state}</button>)}
          </div>
          {!issued ? <div className="p3-blocker-list"><strong>CONTROL BLOCKED</strong><span>No credential exists. Eligibility-only cases cannot be suspended, superseded, revoked, or expired.</span></div> : null}
          <div className="p3-chain-proof"><span>Previous event hash</span><code>{events.at(-1)?.previousEventHash ?? 'genesis:test-mode'}</code><span>Current event hash</span><code>{events.at(-1)?.eventHash ?? 'No event'}</code></div>
        </aside>

        <div className="p3-webhook-board">
          <div className="p3-panel-head"><span>DELIVERY ATTEMPTS</span><strong>INSPECTABLE + REPLAYABLE</strong></div>
          {webhooks.length ? webhooks.map((attempt) => (
            <article key={attempt.id}>
              <StatePill tone={attempt.status === 'delivered' ? 'good' : attempt.status === 'failed' ? 'danger' : 'warn'}>{attempt.status}</StatePill>
              <div><strong>{attempt.id}</strong><span>{attempt.endpoint}</span><small>Attempt {attempt.attempt} · {attempt.responseCode ?? 'pending'}</small></div>
              <div className="p3-webhook-actions">
                {attempt.status === 'failed' ? <button type="button" onClick={() => retryWebhook(attempt.id)}>Retry</button> : null}
                <button type="button" onClick={() => replayWebhook(attempt.id)}>Replay</button>
              </div>
            </article>
          )) : <p>No webhook attempts exist because no credential has been issued.</p>}
        </div>
      </div>
    </section>
  );
}
