const SUPABASE_URL = required('SUPABASE_URL').replace(/\/$/, '');
const SERVICE_ROLE_KEY = required('SUPABASE_SERVICE_ROLE_KEY');
const CLOCK_SKEW_SECONDS = Number(Deno.env.get('PV_FRESHNESS_CLOCK_SKEW_SECONDS') ?? '120');

function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`MISSING_SECRET:${name}`);
  return value;
}
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
}

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    if (request.headers.get('authorization') !== `Bearer ${SERVICE_ROLE_KEY}`) return json({ error: 'workload_identity_required' }, 401);
    const timestamp = request.headers.get('x-pv-timestamp');
    const nonce = request.headers.get('x-pv-nonce');
    if (!timestamp || !nonce || !/^[0-9a-f-]{36}$/i.test(nonce)) return json({ error: 'signed_schedule_context_required' }, 401);
    const observedAt = new Date(timestamp);
    if (!Number.isFinite(observedAt.getTime()) || Math.abs(Date.now() - observedAt.getTime()) > CLOCK_SKEW_SECONDS * 1000) return json({ error: 'schedule_timestamp_invalid' }, 401);
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/pv_r3_run_freshness_regression`, {
      method: 'POST',
      headers: { apikey: SERVICE_ROLE_KEY, authorization: `Bearer ${SERVICE_ROLE_KEY}`, 'content-type': 'application/json', 'content-profile': 'provenance_api', 'accept-profile': 'provenance_api' },
      body: JSON.stringify({ p_run_id: nonce, p_actor_identity: 'freshness-worker', p_observed_at: observedAt.toISOString() }),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) return json({ error: 'freshness_regression_failed', detail: body }, 503);
    return json({ data: body, meta: { automatic: true, failClosed: true } });
  } catch (error) {
    return json({ error: 'freshness_worker_failed', detail: error instanceof Error ? error.message : 'UNKNOWN' }, 503);
  }
});
