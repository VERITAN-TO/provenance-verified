import { createHash, randomUUID } from 'node:crypto';
import { z } from 'zod';
import { getAuthorityRuntimeConfig } from '@/authority/config';

export const dynamic = 'force-dynamic';
const inquirySchema=z.object({mode:z.enum(['contact','access']),name:z.string().min(2).max(120),organization:z.string().min(2).max(160),email:z.string().email().max(240),message:z.string().min(20).max(5000),workflow:z.string().max(160).optional(),website:z.string().max(0).optional(),consent:z.literal(true),consentPolicyVersion:z.literal('privacy-r3.1')});
function sha(value:string){return `sha256:${createHash('sha256').update(value).digest('hex')}`;}
export async function POST(request:Request){
 try{
  const config=getAuthorityRuntimeConfig();
  if(config.environment!=='sandbox') return Response.json({error:{code:'remote_authority_proxy_required',message:'Pilot and Production inquiries must execute through the encrypted authority plane.'}},{status:503});
  const input=inquirySchema.parse(await request.json());
  if(input.website)return Response.json({data:{status:'accepted'},meta:{spamSuppressed:true}},{status:202});
  const recordedAt=new Date().toISOString();const receiptId=`inq_sandbox_${randomUUID()}`;
  return Response.json({data:{receiptId,status:'recorded-sandbox',recordedAt,mode:input.mode,payloadDigest:sha(`${input.mode}:${input.email.toLowerCase()}:${recordedAt}`)},meta:{environment:'sandbox',delivered:false,queued:false,authoritative:false,productionMessageCreated:false}},{status:202});
 }catch(error){if(error instanceof Error&&error.name==='ZodError'&&'issues'in error)return Response.json({error:{code:'invalid_inquiry',issues:error.issues}},{status:422});return Response.json({error:{code:'inquiry_unavailable',message:'The inquiry could not be recorded.'}},{status:500});}
}
