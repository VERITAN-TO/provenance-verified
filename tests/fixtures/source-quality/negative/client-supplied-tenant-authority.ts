// detector: authorization-guard
export async function POST(request: Request) { const body=await request.json(); if(body.tenantId) return Response.json({allow:true}); }
