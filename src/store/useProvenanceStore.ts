'use client';

import { create } from 'zustand';
import { STAGES } from '@/domain/constants';
import { fixtures } from '@/domain/fixtures';
import { evaluateCertification } from '@/domain/kernel';
import { buildCredential, buildEvents, buildWebhookAttempts } from '@/domain/projectors';
import type { CertificationDecision, Credential, FixtureRecord, LifecycleState, SignedEvent, VerificationStage, WebhookAttempt } from '@/domain/types';

interface ProvenanceState {
  fixtureKey: string;
  fixture: FixtureRecord;
  decision: CertificationDecision;
  credential: Credential;
  stageIndex: number;
  stage: VerificationStage;
  runState: 'idle' | 'running' | 'complete' | 'error';
  selectedEvidenceId: string | null;
  selectedClaimId: string | null;
  events: SignedEvent[];
  webhooks: WebhookAttempt[];
  apiLog: { id: string; method: string; path: string; status: number; at: string; body: unknown }[];
  statusMessage: string;
  noWebGL: boolean;
  reducedMotion: boolean;
  selectFixture: (key: string) => void;
  setStage: (index: number) => void;
  runVerification: () => Promise<void>;
  replayVerification: () => Promise<void>;
  selectEvidence: (id: string | null) => void;
  selectClaim: (id: string | null) => void;
  retryWebhook: (attemptId: string) => void;
  replayWebhook: (attemptId: string) => void;
  setLifecycle: (state: LifecycleState) => void;
  setNoWebGL: (value: boolean) => void;
  setReducedMotion: (value: boolean) => void;
}

const initialFixture = fixtures.t4;
const initialDecision = evaluateCertification(initialFixture.policy, initialFixture.claims);
const initialCredential = buildCredential(initialFixture);
const initialEvents = buildEvents(initialCredential);

export const useProvenanceStore = create<ProvenanceState>((set, get) => ({
  fixtureKey: initialFixture.key,
  fixture: initialFixture,
  decision: initialDecision,
  credential: initialCredential,
  stageIndex: 0,
  stage: STAGES[0].id,
  runState: 'idle',
  selectedEvidenceId: initialFixture.evidence[0]?.id ?? null,
  selectedClaimId: initialFixture.claims[0]?.id ?? null,
  events: initialEvents,
  webhooks: buildWebhookAttempts(initialEvents),
  apiLog: [],
  statusMessage: 'Deterministic test record loaded. Evidence eligibility and issuance authority are ready for inspection.',
  noWebGL: false,
  reducedMotion: false,
  selectFixture: (key) => {
    const fixture = fixtures[key] ?? fixtures.t4;
    const decision = evaluateCertification(fixture.policy, fixture.claims);
    const credential = buildCredential(fixture);
    const events = buildEvents(credential);
    set({
      fixtureKey: fixture.key,
      fixture,
      decision,
      credential,
      events,
      webhooks: buildWebhookAttempts(events),
      stageIndex: 0,
      stage: STAGES[0].id,
      runState: 'idle',
      selectedEvidenceId: fixture.evidence[0]?.id ?? null,
      selectedClaimId: fixture.claims[0]?.id ?? null,
      statusMessage: `${fixture.name} loaded. Evidence eligibility is Tier ${decision.tier}; issuance state is ${credential.authorization.status}.`
    });
  },
  setStage: (index) => {
    const safe = Math.max(0, Math.min(STAGES.length - 1, index));
    set({ stageIndex: safe, stage: STAGES[safe].id, statusMessage: `Stage ${safe + 1} of 7: ${STAGES[safe].label}. ${STAGES[safe].detail}` });
  },
  runVerification: async () => {
    const { fixture, decision, credential } = get();
    set({ runState: 'running', stageIndex: 0, stage: STAGES[0].id, statusMessage: 'Verification started. Evidence eligibility and authority gates are processing.' });
    const reduced = get().reducedMotion;
    for (let index = 0; index < STAGES.length; index += 1) {
      if (!reduced) await new Promise((resolve) => setTimeout(resolve, 180));
      set({ stageIndex: index, stage: STAGES[index].id, statusMessage: `Stage ${index + 1} of 7: ${STAGES[index].label}. ${STAGES[index].detail}` });
    }
    const status = fixture.lifecycle === 'not-found' ? 404 : credential.status === 'issued' ? 200 : decision.eligible ? 409 : 422;
    const apiEntry = {
      id: `req_${fixture.publicId}_${Date.now()}`,
      method: 'POST',
      path: '/api/v1/verify',
      status,
      at: '2026-07-16T10:07:00Z',
      body: {
        publicId: fixture.publicId,
        eligibleTier: decision.tier,
        issuedTier: credential.tier,
        credentialStatus: credential.status,
        issuanceStatus: credential.authorization.status,
        lifecycle: credential.lifecycle,
        testMode: true
      }
    };
    const statusMessage = status === 200
      ? `Verification completed. Tier ${credential.tier} — ${credential.tierName} is issued and registry-projectable.`
      : status === 409
        ? `Evidence is eligible for Tier ${decision.tier}, but no credential was issued: ${credential.authorization.blockers.join(' ')}`
        : status === 404
          ? 'No deterministic record exists for this public ID.'
          : 'Minimum evidence requirements are incomplete.';
    set((state) => ({
      runState: status >= 400 ? 'error' : 'complete',
      apiLog: [apiEntry, ...state.apiLog].slice(0, 16),
      statusMessage
    }));
  },
  replayVerification: async () => {
    set({ statusMessage: 'Replay requested. Original deterministic inputs and schedule are preserved.' });
    await get().runVerification();
  },
  selectEvidence: (id) => set({ selectedEvidenceId: id, statusMessage: id ? `Evidence ${id} selected. Graph, scene, and semantic detail now reference the same item.` : 'Evidence selection cleared.' }),
  selectClaim: (id) => set({ selectedClaimId: id, statusMessage: id ? `Claim ${id} selected. Evidence correspondence is highlighted.` : 'Claim selection cleared.' }),
  retryWebhook: (attemptId) => set((state) => ({
    webhooks: state.webhooks.map((attempt) => attempt.id === attemptId ? { ...attempt, status: 'delivered', responseCode: 200, completedAt: '2026-07-16T10:10:02Z' } : attempt),
    statusMessage: `Webhook attempt ${attemptId} retried and delivered in deterministic Test Mode.`
  })),
  replayWebhook: (attemptId) => set((state) => {
    const original = state.webhooks.find((attempt) => attempt.id === attemptId);
    if (!original) return { ...state, statusMessage: 'No issued credential webhook exists for this record.' };
    const replay: WebhookAttempt = { ...original, id: `wh_replay_${state.webhooks.length + 1}`, attempt: original.attempt + 1, status: 'delivered', responseCode: 200, scheduledAt: '2026-07-16T10:12:00Z', completedAt: '2026-07-16T10:12:01Z', replayOf: original.id };
    return { webhooks: [...state.webhooks, replay], statusMessage: `Manual replay ${replay.id} linked to original attempt ${original.id}.` };
  }),
  setLifecycle: (lifecycle) => set((state) => {
    if (state.credential.status !== 'issued') {
      return { ...state, statusMessage: 'Lifecycle transitions are prohibited because no credential has been issued.' };
    }
    const credential = { ...state.credential, lifecycle, warnings: lifecycle === 'active' ? state.credential.warnings.filter((warning) => !warning.startsWith('Lifecycle state')) : [...state.credential.warnings.filter((warning) => !warning.startsWith('Lifecycle state')), `Lifecycle state is ${lifecycle}.`] };
    const event: SignedEvent = {
      id: `evt_lifecycle_${state.events.length + 1}`,
      type: 'credential.lifecycle.changed',
      at: '2026-07-16T10:20:00Z',
      recordId: credential.publicId,
      sequence: state.events.length + 1,
      payload: { from: state.credential.lifecycle, to: lifecycle, reason: 'Deterministic operator action in Test Mode.' },
      signature: `ed25519:test:lifecycle_${lifecycle}`,
      previousEventHash: state.events.at(-1)?.eventHash ?? 'genesis:test-mode',
      eventHash: `sha256:lifecycle_${lifecycle}_${credential.publicId}`
    };
    return { credential, events: [...state.events, event], statusMessage: `Lifecycle changed to ${lifecycle}. API, registry, events, and spatial state were updated together.` };
  }),
  setNoWebGL: (noWebGL) => set({ noWebGL, statusMessage: noWebGL ? 'No-WebGL parity enabled. Semantic proof object and all controls remain available.' : 'WebGL spatial proof enabled.' }),
  setReducedMotion: (reducedMotion) => set({ reducedMotion, statusMessage: reducedMotion ? 'Reduced motion enabled. State changes remain immediate and fully described.' : 'Motion preference restored.' })
}));
