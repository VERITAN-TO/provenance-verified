// detector: authorization-guard
export async function GET(request: Request) {
  try { return Response.json(await authorizeWave1Request(request, { action: 'tenant_resource/read' })); }
  catch (error) { return wave1ErrorResponse(error, request); }
}
