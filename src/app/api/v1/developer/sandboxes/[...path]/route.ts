import { NextRequest } from 'next/server';
import { createHash, randomUUID } from 'node:crypto';

const sandboxes = new Map<string, Record<string, unknown>>();
function digest(value: unknown) { return `sha256:${createHash('sha256').update(JSON.stringify(value)).digest('hex')}`; }
function result(data: unknown, status=200) { return Response.json({data,meta:{environment:'sandbox',authoritative:false,isolated:true,deterministic:true}},{status}); }

async function handle(request: NextRequest, context: {params: Promise<{path?: string[]}>}) {
  const {path=[]}=await context.params;
  if (request.method==='GET' && !path.length) return result([...sandboxes.values()]);
  const input=request.method==='GET'?{}:await request.json().catch(()=>({})) as Record<string,unknown>;
  if (request.method==='POST' && !path.length) {
    const id=randomUUID(); const seedProfile=String(input.seedProfile ?? 'claim-review-lifecycle-v1');
    const row={id,namespace:`sbx-${id.replaceAll('-','')}`,ownerIdentity:'sandbox-operator',status:'active',seedProfile,seedDigest:digest({profile:seedProfile,version:1}),resetCount:0,createdAt:new Date().toISOString(),authoritative:false};
    sandboxes.set(id,row); return result(row,201);
  }
  const id=path[0]; const current=sandboxes.get(id); if(!current)return Response.json({error:{code:'sandbox_not_found'}},{status:404});
  if(request.method==='POST' && path[1]==='reset'){const next={...current,status:'active',seedDigest:digest({profile:input.seedProfile ?? current.seedProfile,version:Number(input.version ?? 1)}),resetCount:Number(current.resetCount ?? 0)+1,resetAt:new Date().toISOString()};sandboxes.set(id,next);return result(next);}
  if(request.method==='DELETE' && path.length===1){const next={...current,status:'deleted',deletedAt:new Date().toISOString(),deletionReceipt:{receiptId:`sandbox-delete-${randomUUID()}`}};sandboxes.set(id,next);return result(next);}
  return Response.json({error:{code:'method_not_allowed'}},{status:405});
}
export const GET=handle; export const POST=handle; export const DELETE=handle;
