// detector: authorization-guard
export async function POST(request: Request) { const role=request.headers.get('x-role'); if(role==='admin') return Response.json({allowed:true}); }
