// detector: safe-api-error-mapping
export function safe(error: unknown, correlationId: string) {
  const mapped = mapPublicAuthorityError(error, { correlationId, endpoint: '/api/v1/example' });
  recordServerDiagnostic(mapped.diagnostic);
  return Response.json(mapped.public);
}
