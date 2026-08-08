import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NextRequest } from 'next/server';
import { operationalDataset } from '@/operations/fixtures';
import { OperationalRepository } from '@/operations/repository';
import { useOperationsStore } from '@/operations/useOperationsStore';
import { POST as syncOperations } from '@/app/api/v1/operations/sync/route';
import { POST as submitBatch } from '@/app/api/v1/operations/batches/[batchId]/submit/route';
import { GET as listReviews } from '@/app/api/v1/operations/review/route';
import { POST as reviewDecision } from '@/app/api/v1/operations/review/[caseId]/decision/route';

function installApiTransport() {
  vi.stubGlobal('fetch', vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const rawUrl = typeof input === 'string' || input instanceof URL ? String(input) : input.url;
    const url = new URL(rawUrl, 'http://localhost');
    const nextInit = init ? {
      method: init.method,
      headers: init.headers,
      body: init.body,
      cache: init.cache,
      credentials: init.credentials,
      integrity: init.integrity,
      keepalive: init.keepalive,
      mode: init.mode,
      redirect: init.redirect,
      referrer: init.referrer,
      referrerPolicy: init.referrerPolicy,
      signal: init.signal ?? undefined,
    } : undefined;
    const request = new NextRequest(url, nextInit);
    if (url.pathname === '/api/v1/operations/sync') return syncOperations(request);
    if (url.pathname === '/api/v1/operations/review' && (!init?.method || init.method === 'GET')) return listReviews(request);
    const submit = url.pathname.match(/^\/api\/v1\/operations\/batches\/([^/]+)\/submit$/);
    if (submit) return submitBatch(request, { params: Promise.resolve({ batchId: submit[1] }) });
    const decision = url.pathname.match(/^\/api\/v1\/operations\/review\/([^/]+)\/decision$/);
    if (decision) return reviewDecision(request, { params: Promise.resolve({ caseId: decision[1] }) });
    return Response.json({ error: { message: `UNHANDLED_TEST_ROUTE:${url.pathname}` } }, { status: 500 });
  }));
}

describe('Phase 4 operational store', () => {
  beforeEach(() => {
    const seed = structuredClone(operationalDataset);
    globalThis.__pvOperationalRepository = new OperationalRepository(operationalDataset);
    installApiTransport();
    useOperationsStore.setState({ dataset: seed, sessionId: 'session_intake', selectedBatchId: 'batch_phx_2026_0720_a', selectedAssetId: seed.assets[0].id, selectedReviewCaseId: seed.reviewCases[0].id, online: true, syncState: 'idle', statusMessage: 'reset' });
  });

  it('creates a 1,000-unit explicit batch load without a hard-coded 20-unit limit', () => {
    const before = useOperationsStore.getState().dataset.assets.length;
    const count = useOperationsStore.getState().addBulkAssets(1000);
    const after = useOperationsStore.getState().dataset.assets.length;
    expect(count).toBe(1000);
    expect(after - before).toBe(1000);
    expect(useOperationsStore.getState().dataset.syncOperations.filter((item) => item.status === 'queued').length).toBeGreaterThanOrEqual(1000);
  });

  it('queues new units while offline and marks them synchronized only after server confirmation', async () => {
    useOperationsStore.getState().setOnline(false);
    useOperationsStore.getState().addAsset({ serial: 'OFFLINE-001', material: 'Natural sapphire', shape: 'Oval', cut: 'Faceted', colorDescription: 'Blue', clarityDescription: 'Eye clean', treatmentDisclosure: 'Heat disclosed', originClaim: 'Not claimed', measurements: { weightCarats: 1, lengthMm: 6, widthMm: 4, depthMm: 3 }, identifyingFeatures: ['fingerprint'], supplierReference: '', laboratoryReportReference: '' });
    expect(useOperationsStore.getState().syncState).toBe('queued');
    expect(useOperationsStore.getState().dataset.syncOperations.at(-1)?.status).toBe('queued');
    useOperationsStore.getState().setOnline(true);
    await useOperationsStore.getState().flushSyncQueue();
    expect(useOperationsStore.getState().syncState).toBe('synced');
    expect(useOperationsStore.getState().dataset.syncOperations.at(-1)?.status).toBe('applied');
  });


  it('chunks more than 1,000 queued operations into bounded sync requests', async () => {
    const fetchMock = vi.mocked(fetch);
    useOperationsStore.getState().addBulkAssets(1000);
    await useOperationsStore.getState().flushSyncQueue();
    const syncCalls = fetchMock.mock.calls.filter(([input]) => String(input).includes('/api/v1/operations/sync'));
    expect(syncCalls.length).toBeGreaterThanOrEqual(2);
    for (const [, init] of syncCalls) {
      const body = JSON.parse(String(init?.body));
      expect(body.operations.length).toBeLessThanOrEqual(500);
    }
    expect(useOperationsStore.getState().dataset.syncOperations.filter((item) => item.status === 'queued')).toHaveLength(0);
  });

  it('requires an authorized attestor and synchronized data before submission', async () => {
    const before = useOperationsStore.getState().dataset.attestations.length;
    await useOperationsStore.getState().submitSelectedBatch();
    expect(useOperationsStore.getState().statusMessage).toContain('Submission denied');
    expect(useOperationsStore.getState().dataset.attestations).toHaveLength(before);
    await useOperationsStore.getState().flushSyncQueue();
    useOperationsStore.getState().selectSession('session_attestor');
    await useOperationsStore.getState().submitSelectedBatch();
    expect(useOperationsStore.getState().dataset.attestations.length).toBe(before + 1);
    expect(useOperationsStore.getState().dataset.batches.find((item) => item.id === 'batch_phx_2026_0720_a')?.status).toBe('submitted');
  });

  it('requires distinct authenticated reviewers and compliance authority for Tier 4 issuance', async () => {
    const caseId = useOperationsStore.getState().selectedReviewCaseId!;
    useOperationsStore.getState().selectSession('session_reviewer');
    useOperationsStore.getState().selectReviewCase(caseId);
    await useOperationsStore.getState().reviewAction('secondary-approve');
    expect(useOperationsStore.getState().statusMessage).toContain('distinct reviewers');
    useOperationsStore.getState().selectSession('session_reviewer_secondary');
    useOperationsStore.getState().selectReviewCase(caseId);
    await useOperationsStore.getState().reviewAction('secondary-approve');
    useOperationsStore.getState().selectSession('session_compliance');
    useOperationsStore.getState().selectReviewCase(caseId);
    await useOperationsStore.getState().reviewAction('custos-pass');
    await useOperationsStore.getState().reviewAction('authorize-signing');
    expect(useOperationsStore.getState().dataset.reviewCases.find((item) => item.id === caseId)?.credential?.authorization.status).toBe('registry-required');
    await useOperationsStore.getState().reviewAction('publish-registry');
    expect(useOperationsStore.getState().dataset.reviewCases.find((item) => item.id === caseId)?.credential?.authorization.status).toBe('revocation-control-required');
    await useOperationsStore.getState().reviewAction('enable-revocation-control');
    expect(useOperationsStore.getState().dataset.reviewCases.find((item) => item.id === caseId)?.credential?.status).toBe('issued');
    expect(useOperationsStore.getState().dataset.reviewCases.find((item) => item.id === caseId)?.credential?.sealAuthorization.status).toBe('not-authorized');
    await useOperationsStore.getState().reviewAction('authorize-mark');
    expect(useOperationsStore.getState().dataset.reviewCases.find((item) => item.id === caseId)?.credential?.sealAuthorization.status).toBe('authorized');
  });

  it('allows evidence capture but denies review authority to intake operators', async () => {
    const before = useOperationsStore.getState().dataset.evidence.length;
    useOperationsStore.getState().addEvidence('photo');
    expect(useOperationsStore.getState().dataset.evidence.length).toBe(before + 1);
    expect(useOperationsStore.getState().dataset.syncOperations.at(-1)?.status).toBe('queued');
    await useOperationsStore.getState().reviewAction('primary-approve');
    expect(useOperationsStore.getState().statusMessage).toContain('review.decide');
  });
});
