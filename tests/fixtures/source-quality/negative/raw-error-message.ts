// detector: safe-api-error-mapping
export function unsafe(error: Error, correlationId:string){return Response.json({message:error.message,correlationId});}
