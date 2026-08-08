import { signedAuthorityFetch } from '../authority-api/aws-sigv4.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const AUTHORITY_API_BASE = (Deno.env.get('PV_AWS_AUTHORITY_API_BASE') ?? '').replace(/\/$/, '');
const WORKER_ID = Deno.env.get('PV_WEBHOOK_WORKER_ID') ?? `webhook-worker-${crypto.randomUUID()}`;
const MAX_RESPONSE_BYTES = 1_048_576;
const TIMEOUT_MS = 10_000;

type QueueItem = {
  id: string; tenant_id: string; endpoint_id: string; event_id: string; delivery_id: string;
  payload: Record<string, unknown>; attempt: number; maximum_attempts: number;
  endpoint_url: string; secret_ciphertext: string;
};

function json(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } }); }

async function rpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST', headers: { apikey: SERVICE_ROLE_KEY, authorization: `Bearer ${SERVICE_ROLE_KEY}`, 'content-type': 'application/json' }, body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`RPC_${name}_${response.status}:${await response.text()}`);
  return await response.json() as T;
}

function privateAddress(address: string) {
  const value = address.toLowerCase();
  if (value === '127.0.0.1' || value === '::1' || value === '0.0.0.0' || value === '169.254.169.254') return true;
  if (/^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(value)) return true;
  return value.startsWith('fc') || value.startsWith('fd') || value.startsWith('fe80:');
}

async function validateTarget(raw: string): Promise<URL> {
  const target = new URL(raw);
  if (target.protocol !== 'https:') throw new Error('WEBHOOK_HTTPS_REQUIRED');
  const port = target.port ? Number(target.port) : 443;
  if (![443,8443].includes(port)) throw new Error('WEBHOOK_PORT_DENIED');
  const host = target.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.internal') || host === 'metadata.google.internal') throw new Error('WEBHOOK_INTERNAL_HOST_DENIED');
  const addresses = /^\d+\.\d+\.\d+\.\d+$/.test(host) ? [host] : [
    ...await Deno.resolveDns(host, 'A').catch(() => []),
    ...await Deno.resolveDns(host, 'AAAA').catch(() => []),
  ];
  if (!addresses.length || addresses.some(privateAddress)) throw new Error('WEBHOOK_PRIVATE_ADDRESS_DENIED');
  return target;
}

async function hmac(secret: string, timestamp: string, body: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${body}`)));
  return `sha256=${[...bytes].map((item) => item.toString(16).padStart(2,'0')).join('')}`;
}

async function openSecret(item: QueueItem): Promise<string> {
  const response = await signedAuthorityFetch({
    url: `${AUTHORITY_API_BASE}/secret-vault/v1/open`,
    body: { tenantId: item.tenant_id, endpointId: item.endpoint_id, ciphertext: item.secret_ciphertext },
    tenantId: item.tenant_id, subject: item.endpoint_id, operation: 'secret.open',
    idempotencyKey: `webhook-secret:${item.delivery_id}:${item.attempt + 1}`,
    serviceIdentity: Deno.env.get('PV_AUTHORITY_SERVICE_IDENTITY') ?? 'provenance-webhook-worker',
  });
  if (!response.ok) throw new Error(`WEBHOOK_SECRET_OPEN_FAILED:${response.status}`);
  const result = await response.json() as Record<string, unknown>;
  const secret = String(result.plaintext ?? '');
  if (secret.length < 32) throw new Error('WEBHOOK_SECRET_UNAVAILABLE');
  return secret;
}

async function boundedBody(response: Response) {
  if (!response.body) return 0;
  const reader = response.body.getReader(); let total = 0;
  while (true) {
    const { done, value } = await reader.read(); if (done) break;
    total += value.byteLength; if (total > MAX_RESPONSE_BYTES) { await reader.cancel(); throw new Error('WEBHOOK_RESPONSE_TOO_LARGE'); }
  }
  return total;
}

async function deliver(item: QueueItem) {
  const body = JSON.stringify(item.payload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  let signature = 'unavailable'; let status: number | null = null; let responseBytes = 0; let error: string | null = null; let success = false;
  try {
    const secret = await openSecret(item); signature = await hmac(secret, timestamp, body);
    let target = await validateTarget(item.endpoint_url);
    for (let redirects = 0; redirects <= 3; redirects += 1) {
      const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
      try {
        const response = await fetch(target, { method: 'POST', redirect: 'manual', signal: controller.signal, headers: {
          'content-type': 'application/json', 'user-agent': 'PROVENANCE-VERIFIED-Webhook/1.0',
          'x-provenance-signature': signature, 'x-provenance-timestamp': timestamp,
          'x-provenance-delivery-id': item.delivery_id, 'x-provenance-event-id': item.event_id,
          'x-provenance-attempt': String(item.attempt + 1),
        }, body });
        status = response.status;
        if ([301,302,303,307,308].includes(response.status)) {
          const location = response.headers.get('location'); if (!location || redirects === 3) throw new Error('WEBHOOK_REDIRECT_DENIED');
          target = await validateTarget(new URL(location, target).toString()); continue;
        }
        responseBytes = await boundedBody(response); success = response.ok;
        if (!response.ok) error = `HTTP_${response.status}`;
        break;
      } finally { clearTimeout(timer); }
    }
  } catch (caught) { error = caught instanceof Error ? caught.message : String(caught); }
  return rpc('pv_r3_complete_webhook_delivery', {
    p_id: item.id, p_worker_id: WORKER_ID, p_success: success, p_http_status: status,
    p_response_bytes: responseBytes, p_error: error, p_signature: signature,
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !AUTHORITY_API_BASE) return json({ error: 'WORKER_CONFIGURATION_INCOMPLETE' }, 503);
  try {
    const claimed = await rpc<QueueItem[]>('pv_r3_claim_webhook_deliveries', { p_worker_id: WORKER_ID, p_limit: 20 });
    const results = [];
    for (const item of claimed) results.push(await deliver(item));
    return json({ workerId: WORKER_ID, claimed: claimed.length, results });
  } catch (error) { return json({ error: error instanceof Error ? error.message : String(error) }, 503); }
});
