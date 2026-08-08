import { denialFromEnvelope, parseAuthorityContext, parseEligibleTenants, safeDenial, type AuthorityContext, type EligibleTenant, type SafeDenial } from './authority-contracts';
export type AuthorityResult = {kind:'allow';context:AuthorityContext}|{kind:'tenant-selection';tenants:EligibleTenant[];correlationId?:string}|{kind:'deny';denial:SafeDenial};
async function request(url:string, init:RequestInit={}, timeoutMs=9000):Promise<{response:Response; body:unknown}> {
  const controller = new AbortController(); const timer = setTimeout(()=>controller.abort(),timeoutMs);
  try { const response=await fetch(url,{...init,cache:'no-store',credentials:'same-origin',signal:controller.signal}); let body:unknown={}; try{body=await response.json();}catch{} return {response,body}; }
  finally { clearTimeout(timer); }
}
export async function resolveAuthoritativeContext(tenantId?:string):Promise<AuthorityResult> {
  try {
    const headers:HeadersInit = tenantId ? {'x-provenance-tenant':tenantId} : {};
    const auth=await request('/api/v1/auth/session',{headers});
    const sessionBody:Record<string,unknown>|null=typeof auth.body==='object'&&auth.body!==null?auth.body as Record<string,unknown>:null;
    const sessionData:Record<string,unknown>|null=sessionBody!==null&&typeof sessionBody.data==='object'&&sessionBody.data!==null?sessionBody.data as Record<string,unknown>:null;
    const authTenants=parseEligibleTenants(sessionData?.memberships??sessionData?.eligibleTenants);
    if (auth.response.status===409 && authTenants.length) return {kind:'tenant-selection',tenants:authTenants,correlationId:typeof sessionBody?.correlation_id==='string'?sessionBody.correlation_id:undefined};
    if (!auth.response.ok) return {kind:'deny',denial:denialFromEnvelope(auth.body,auth.response.status)};
    const authContext=parseAuthorityContext(auth.body); if(!authContext) return {kind:'deny',denial:safeDenial('DENY_MALFORMED_RESPONSE')};
    const ops=await request('/api/v1/operations/session',{headers});
    if(!ops.response.ok) return {kind:'deny',denial:denialFromEnvelope(ops.body,ops.response.status)};
    const opsContext=parseAuthorityContext(ops.body); if(!opsContext) return {kind:'deny',denial:safeDenial('DENY_MALFORMED_RESPONSE')};
    if(authContext.actor.actorId!==opsContext.actor.actorId || authContext.tenant.tenantId!==opsContext.tenant.tenantId || authContext.membership.role!==opsContext.membership.role || authContext.authorization.authorityVersion!==opsContext.authorization.authorityVersion) return {kind:'deny',denial:safeDenial('DENY_AUTHORITY_VERSION_CONFLICT',authContext.correlationId)};
    return {kind:'allow',context:opsContext};
  } catch (error) { return {kind:'deny',denial:safeDenial(error instanceof DOMException && error.name==='AbortError'?'DENY_AUTHORITY_UNAVAILABLE':'DENY_NETWORK_FAILURE')}; }
}
export async function terminateAuthoritySession():Promise<void>{const result=await request('/api/v1/auth/sign-out',{method:'POST',headers:{'content-type':'application/json'},body:'{}'},6000);if(!result.response.ok)throw new Error('SIGN_OUT_SERVER_INVALIDATION_FAILED');}
export function clearNonAuthoritativeClientState():void {if(typeof window==='undefined')return;sessionStorage.clear();localStorage.removeItem('pv-test-session-id');localStorage.removeItem('pv-test-session-selected-at');}
