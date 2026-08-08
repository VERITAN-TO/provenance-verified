export type Environment='sandbox'|'pilot'|'production';
export interface ClientOptions { baseUrl:string; token:string; tenantId:string; fetch?:typeof globalThis.fetch; }
export class ProvenanceError extends Error { constructor(public code:string,public status:number,message=code,public receiptId?:string){super(message);} }
export class ProvenanceClient {
  private readonly requestFn:typeof globalThis.fetch;
  constructor(private readonly options:ClientOptions){this.requestFn=options.fetch??globalThis.fetch;}
  private async request<T>(path:string,init:RequestInit={}):Promise<T>{const response=await this.requestFn(`${this.options.baseUrl.replace(/\/$/,'')}${path}`,{...init,headers:{authorization:`Bearer ${this.options.token}`,'x-provenance-tenant':this.options.tenantId,'content-type':'application/json','x-request-id':crypto.randomUUID(),...(init.headers??{})}});const body=await response.json().catch(()=>({})) as {data?:T;error?:{code?:string;message?:string;receiptId?:string}};if(!response.ok||body.data===undefined)throw new ProvenanceError(body.error?.code??'request_failed',response.status,body.error?.message,body.error?.receiptId);return body.data;}
  verify(publicId:string){return this.request<Record<string,unknown>>('/api/v1/verify',{method:'POST',body:JSON.stringify({publicId})});}
  registry(publicId:string){return this.request<Record<string,unknown>>(`/api/v1/registry/${encodeURIComponent(publicId)}`);}
  registryHistory(publicId:string){return this.request<Record<string,unknown>>(`/api/v1/registry/${encodeURIComponent(publicId)}/history`);}
  authorityControlCenter(){return this.request<Record<string,unknown>>('/api/v1/authority/control-center');}
  operationalControls(){return this.request<Record<string,unknown>>('/api/v1/authority/operational-controls');}
  recordRuntimeClaim(payload:Record<string,unknown>,idempotencyKey=crypto.randomUUID()){return this.request<Record<string,unknown>>('/api/v1/authority/operational-controls/runtime-claims',{method:'POST',headers:{'idempotency-key':idempotencyKey},body:JSON.stringify(payload)});}
  issue(reviewCaseId:string,idempotencyKey=crypto.randomUUID()){return this.request<Record<string,unknown>>(`/api/v1/authority/reviews/${encodeURIComponent(reviewCaseId)}/issue`,{method:'POST',headers:{'idempotency-key':idempotencyKey},body:'{}'});}
  lifecycle(reviewCaseId:string,command:Record<string,unknown>,idempotencyKey=crypto.randomUUID()){return this.request<Record<string,unknown>>(`/api/v1/operations/review/${encodeURIComponent(reviewCaseId)}/lifecycle`,{method:'POST',headers:{'idempotency-key':idempotencyKey},body:JSON.stringify(command)});}
  mcp(name:string,args:Record<string,unknown>={}){return this.request<Record<string,unknown>>('/api/v1/mcp',{method:'POST',body:JSON.stringify({name,arguments:args})});}
}
