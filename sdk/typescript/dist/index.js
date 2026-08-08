export class ProvenanceError extends Error {
    code;
    status;
    receiptId;
    constructor(code, status, message = code, receiptId) {
        super(message);
        this.code = code;
        this.status = status;
        this.receiptId = receiptId;
    }
}
export class ProvenanceClient {
    options;
    requestFn;
    constructor(options) {
        this.options = options;
        this.requestFn = options.fetch ?? globalThis.fetch;
    }
    async request(path, init = {}) { const response = await this.requestFn(`${this.options.baseUrl.replace(/\/$/, '')}${path}`, { ...init, headers: { authorization: `Bearer ${this.options.token}`, 'x-provenance-tenant': this.options.tenantId, 'content-type': 'application/json', 'x-request-id': crypto.randomUUID(), ...(init.headers ?? {}) } }); const body = await response.json().catch(() => ({})); if (!response.ok || body.data === undefined)
        throw new ProvenanceError(body.error?.code ?? 'request_failed', response.status, body.error?.message, body.error?.receiptId); return body.data; }
    verify(publicId) { return this.request('/api/v1/verify', { method: 'POST', body: JSON.stringify({ publicId }) }); }
    registry(publicId) { return this.request(`/api/v1/registry/${encodeURIComponent(publicId)}`); }
    registryHistory(publicId) { return this.request(`/api/v1/registry/${encodeURIComponent(publicId)}/history`); }
    authorityControlCenter() { return this.request('/api/v1/authority/control-center'); }
    operationalControls() { return this.request('/api/v1/authority/operational-controls'); }
    recordRuntimeClaim(payload, idempotencyKey = crypto.randomUUID()) { return this.request('/api/v1/authority/operational-controls/runtime-claims', { method: 'POST', headers: { 'idempotency-key': idempotencyKey }, body: JSON.stringify(payload) }); }
    issue(reviewCaseId, idempotencyKey = crypto.randomUUID()) { return this.request(`/api/v1/authority/reviews/${encodeURIComponent(reviewCaseId)}/issue`, { method: 'POST', headers: { 'idempotency-key': idempotencyKey }, body: '{}' }); }
    lifecycle(reviewCaseId, command, idempotencyKey = crypto.randomUUID()) { return this.request(`/api/v1/operations/review/${encodeURIComponent(reviewCaseId)}/lifecycle`, { method: 'POST', headers: { 'idempotency-key': idempotencyKey }, body: JSON.stringify(command) }); }
    mcp(name, args = {}) { return this.request('/api/v1/mcp', { method: 'POST', body: JSON.stringify({ name, arguments: args }) }); }
}
