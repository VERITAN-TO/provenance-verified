export type Environment = 'sandbox' | 'pilot' | 'production';
export interface ClientOptions {
    baseUrl: string;
    token: string;
    tenantId: string;
    fetch?: typeof globalThis.fetch;
}
export declare class ProvenanceError extends Error {
    code: string;
    status: number;
    receiptId?: string | undefined;
    constructor(code: string, status: number, message?: string, receiptId?: string | undefined);
}
export declare class ProvenanceClient {
    private readonly options;
    private readonly requestFn;
    constructor(options: ClientOptions);
    private request;
    verify(publicId: string): Promise<Record<string, unknown>>;
    registry(publicId: string): Promise<Record<string, unknown>>;
    registryHistory(publicId: string): Promise<Record<string, unknown>>;
    authorityControlCenter(): Promise<Record<string, unknown>>;
    operationalControls(): Promise<Record<string, unknown>>;
    recordRuntimeClaim(payload: Record<string, unknown>, idempotencyKey?: `${string}-${string}-${string}-${string}-${string}`): Promise<Record<string, unknown>>;
    issue(reviewCaseId: string, idempotencyKey?: `${string}-${string}-${string}-${string}-${string}`): Promise<Record<string, unknown>>;
    lifecycle(reviewCaseId: string, command: Record<string, unknown>, idempotencyKey?: `${string}-${string}-${string}-${string}-${string}`): Promise<Record<string, unknown>>;
    mcp(name: string, args?: Record<string, unknown>): Promise<Record<string, unknown>>;
}
