import { getPublicKnowledge } from '@/authority/publicKnowledge';
export const dynamic='force-dynamic';
export async function GET(){try{return Response.json(await getPublicKnowledge(),{headers:{'cache-control':'public, max-age=300, stale-while-revalidate=60','content-type':'application/ld+json; charset=utf-8'}});}catch(error){return Response.json({error:'knowledge_authority_unavailable',detail:error instanceof Error?error.message:'UNKNOWN'},{status:503});}}
