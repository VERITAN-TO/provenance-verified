import { NextRequest } from './next-server';
import { GET as eventsGet } from '@/app/api/v1/events/route';
import { POST as verifyPost } from '@/app/api/v1/verify/route';
import { GET as registryGet } from '@/app/api/v1/registry/[publicId]/route';
import { GET as sessionGet } from '@/app/api/v1/operations/session/route';
import { GET as lotsGet, POST as lotsPost } from '@/app/api/v1/operations/lots/route';
import { GET as batchesGet, POST as batchesPost } from '@/app/api/v1/operations/batches/route';
import { GET as batchGet } from '@/app/api/v1/operations/batches/[batchId]/route';
import { POST as batchAssetsPost } from '@/app/api/v1/operations/batches/[batchId]/assets/route';
import { POST as csvPost } from '@/app/api/v1/operations/batches/[batchId]/csv/route';
import { POST as submitPost } from '@/app/api/v1/operations/batches/[batchId]/submit/route';
import { PATCH as assetPatch } from '@/app/api/v1/operations/assets/[assetId]/route';
import { POST as evidencePost } from '@/app/api/v1/operations/assets/[assetId]/evidence/route';
import { GET as reviewGet } from '@/app/api/v1/operations/review/route';
import { POST as decisionPost } from '@/app/api/v1/operations/review/[caseId]/decision/route';
import { POST as lifecyclePost } from '@/app/api/v1/operations/review/[caseId]/lifecycle/route';
import { GET as correctionsGet, POST as correctionsPost } from '@/app/api/v1/operations/review/[caseId]/corrections/route';
import { GET as searchGet } from '@/app/api/v1/operations/search/route';
import { POST as syncPost } from '@/app/api/v1/operations/sync/route';
import { POST as labelsPost } from '@/app/api/v1/operations/labels/route';
import { GET as auditGet } from '@/app/api/v1/operations/audit/route';
import { POST as replayPost } from '@/app/api/v1/webhooks/replay/route';
import { POST as inquiryPost } from '@/app/api/v1/inquiries/route';

const notFound = () => Response.json({ error: { code: 'standalone_route_not_found', message: 'No canonical standalone route matches this request.' }, meta: { mode: 'test', authoritative: false } }, { status: 404 });

async function dispatch(request: NextRequest): Promise<Response> {
  const { pathname } = request.nextUrl;
  const method = request.method.toUpperCase();
  if (pathname === '/api/v1/verify' && method === 'POST') return verifyPost(request as never);
  if (pathname === '/api/v1/events' && method === 'GET') return eventsGet(request as never);
  if (pathname === '/api/v1/inquiries' && method === 'POST') return inquiryPost(request as never);
  if (pathname === '/api/v1/webhooks/replay' && method === 'POST') return replayPost(request as never);
  let match = pathname.match(/^\/api\/v1\/registry\/([^/]+)$/);
  if (match && method === 'GET') return registryGet(request as never, { params: Promise.resolve({ publicId: decodeURIComponent(match[1]) }) });

  if (pathname === '/api/v1/operations/session' && method === 'GET') return sessionGet(request as never);
  if (pathname === '/api/v1/operations/lots') return method === 'GET' ? lotsGet(request as never) : method === 'POST' ? lotsPost(request as never) : notFound();
  if (pathname === '/api/v1/operations/batches') return method === 'GET' ? batchesGet(request as never) : method === 'POST' ? batchesPost(request as never) : notFound();
  if (pathname === '/api/v1/operations/review' && method === 'GET') return reviewGet(request as never);
  if (pathname === '/api/v1/operations/search' && method === 'GET') return searchGet(request as never);
  if (pathname === '/api/v1/operations/sync' && method === 'POST') return syncPost(request as never);
  if (pathname === '/api/v1/operations/labels' && method === 'POST') return labelsPost(request as never);
  if (pathname === '/api/v1/operations/audit' && method === 'GET') return auditGet(request as never);

  match = pathname.match(/^\/api\/v1\/operations\/batches\/([^/]+)$/);
  if (match) {
    const context = { params: Promise.resolve({ batchId: decodeURIComponent(match[1]) }) };
    if (method === 'GET') return batchGet(request as never, context);
  }
  match = pathname.match(/^\/api\/v1\/operations\/batches\/([^/]+)\/assets$/);
  if (match && method === 'POST') return batchAssetsPost(request as never, { params: Promise.resolve({ batchId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/batches\/([^/]+)\/csv$/);
  if (match && method === 'POST') return csvPost(request as never, { params: Promise.resolve({ batchId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/batches\/([^/]+)\/submit$/);
  if (match && method === 'POST') return submitPost(request as never, { params: Promise.resolve({ batchId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/assets\/([^/]+)$/);
  if (match) {
    const context = { params: Promise.resolve({ assetId: decodeURIComponent(match[1]) }) };
    if (method === 'PATCH') return assetPatch(request as never, context);
  }
  match = pathname.match(/^\/api\/v1\/operations\/assets\/([^/]+)\/evidence$/);
  if (match && method === 'POST') return evidencePost(request as never, { params: Promise.resolve({ assetId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/review\/([^/]+)\/decision$/);
  if (match && method === 'POST') return decisionPost(request as never, { params: Promise.resolve({ caseId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/review\/([^/]+)\/lifecycle$/);
  if (match && method === 'POST') return lifecyclePost(request as never, { params: Promise.resolve({ caseId: decodeURIComponent(match[1]) }) });
  match = pathname.match(/^\/api\/v1\/operations\/review\/([^/]+)\/corrections$/);
  if (match) {
    const context = { params: Promise.resolve({ caseId: decodeURIComponent(match[1]) }) };
    if (method === 'GET') return correctionsGet(request as never, context);
    if (method === 'POST') return correctionsPost(request as never, context);
  }
  return notFound();
}

export function installCanonicalApiBridge() {
  const nativeFetch = window.fetch.bind(window);
  window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const raw = input instanceof Request ? input.url : String(input);
    const origin = window.location.origin && window.location.origin !== 'null' ? window.location.origin : 'https://standalone.provenanceverified.org';
    const url = new URL(raw, origin);
    if (!url.pathname.startsWith('/api/')) return nativeFetch(input, init);
    const base = input instanceof Request ? input : undefined;
    const request = new NextRequest(url, {
      method: init?.method ?? base?.method ?? 'GET',
      headers: init?.headers ?? base?.headers,
      body: init?.body ?? (base && !['GET', 'HEAD'].includes(base.method) ? await base.clone().arrayBuffer() : undefined),
    });
    const response = await dispatch(request);
    return response.clone();
  };
}
