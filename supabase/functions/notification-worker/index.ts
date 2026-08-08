import { signedAuthorityFetch } from '../authority-api/aws-sigv4.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const DELIVERY_API_BASE = (Deno.env.get('PV_NOTIFICATION_DELIVERY_API_BASE') ?? '').replace(/\/$/, '');
const WORKER_ID = Deno.env.get('PV_NOTIFICATION_WORKER_ID') ?? `notification-worker-${crypto.randomUUID()}`;

type Notification = {
  id: string; tenant_id: string; event_id: string; channel: 'in-app'|'email'|'sms'|'webhook'; recipient: string;
  template_version: string; consent_reference: string|null; state: string; attempt_count: number;
};

function json(body: unknown, status=200) { return new Response(JSON.stringify(body), { status, headers: { 'content-type':'application/json' } }); }
async function sha256(value: string) { const bytes=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))); return `sha256:${[...bytes].map((b)=>b.toString(16).padStart(2,'0')).join('')}`; }
async function rpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const response=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:SERVICE_ROLE_KEY,authorization:`Bearer ${SERVICE_ROLE_KEY}`,'content-type':'application/json'},body:JSON.stringify(body)});
  if(!response.ok) throw new Error(`RPC_${name}_${response.status}:${await response.text()}`);
  return await response.json() as T;
}

async function complete(item: Notification, outcome: 'delivered'|'retry'|'dead-letter'|'suppressed', requestDigest: string, receipt: Record<string,unknown>|null, errorCode: string|null) {
  return rpc('pv_r3_complete_notification', {
    p_notification_id:item.id,p_worker_id:WORKER_ID,p_request_digest:requestDigest,p_outcome:outcome,
    p_provider_receipt:receipt ?? {},p_error_code:errorCode,
  });
}

async function deliver(item: Notification) {
  const payload={notificationId:item.id,eventId:item.event_id,channel:item.channel,recipient:item.recipient,templateVersion:item.template_version,consentReference:item.consent_reference};
  const requestDigest=await sha256(JSON.stringify(payload));
  if(item.channel==='in-app') return complete(item,'delivered',requestDigest,{receiptId:`inapp-${item.id}-${item.attempt_count}`,decision:'delivered',requestDigest,workerId:WORKER_ID},null);
  if(!item.consent_reference) return complete(item,'suppressed',requestDigest,{receiptId:`suppressed-${item.id}`,decision:'suppressed',reasonCode:'CONSENT_REQUIRED'},'CONSENT_REQUIRED');
  if(!DELIVERY_API_BASE) return complete(item,item.attempt_count>=5?'dead-letter':'retry',requestDigest,null,'NOTIFICATION_PROVIDER_UNAVAILABLE');
  try {
    const response=await signedAuthorityFetch({
      url:`${DELIVERY_API_BASE}/notification/v1/deliver`, body:payload, tenantId:item.tenant_id, subject:item.id,
      operation:'notification.deliver', idempotencyKey:`notification:${item.id}:${item.attempt_count}`, serviceIdentity:'provenance-notification-worker',
    });
    const result=await response.json().catch(()=>({})) as Record<string,unknown>;
    const receipt=result.receipt as Record<string,unknown>|undefined;
    if(!response.ok || !receipt || typeof receipt.signature!=='string' || typeof receipt.receiptId!=='string') {
      return complete(item,item.attempt_count>=5?'dead-letter':'retry',requestDigest,receipt ?? null,`NOTIFICATION_PROVIDER_${response.status}`);
    }
    return complete(item,'delivered',requestDigest,receipt,null);
  } catch(error) {
    return complete(item,item.attempt_count>=5?'dead-letter':'retry',requestDigest,null,error instanceof Error ? error.message : String(error));
  }
}

Deno.serve(async(request)=>{
  if(request.method!=='POST') return json({error:'METHOD_NOT_ALLOWED'},405);
  if(!SUPABASE_URL || !SERVICE_ROLE_KEY) return json({error:'WORKER_CONFIGURATION_INCOMPLETE'},503);
  try {
    const items=await rpc<Notification[]>('pv_r3_claim_notifications',{p_worker_id:WORKER_ID,p_limit:20});
    const results=[]; for(const item of items) results.push(await deliver(item));
    return json({workerId:WORKER_ID,claimed:items.length,results});
  } catch(error) { return json({error:error instanceof Error?error.message:String(error)},503); }
});
