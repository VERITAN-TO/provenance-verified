import type { CertificationDecision, Credential, FixtureRecord, PolicyInput } from '@/domain/types';
import type { EvidenceObject, GemstoneAsset, OperationalDataset, OperationalSession, ReviewCase } from '@/operations/types';
import { getAuthorityRuntimeConfig, type ProvenanceEnvironment } from '@/authority/config';
import type {
  ApiOperation,
  AssetIdentityQuery,
  CollectionState,
  ContinuityState,
  EvidenceValidation,
  LifecycleTransitionCommand,
  McpOperation,
  ProvenanceService,
  ProvenanceServiceMode,
  RegistryLookupResult,
  TierAssessment,
  VerificationResult,
} from './contract';

interface RemoteOptions {
  environment: Exclude<ProvenanceEnvironment, 'sandbox'>;
  authoritative: boolean;
}

export class RemoteProvenanceService implements ProvenanceService {
  readonly mode: ProvenanceServiceMode;
  readonly authoritative: boolean;
  private readonly baseUrl: string;

  constructor(options: RemoteOptions) {
    const config = getAuthorityRuntimeConfig();
    if (!config.authorityApiUrl) throw new Error('PV_AUTHORITY_API_URL_REQUIRED');
    this.mode = options.environment;
    this.authoritative = options.authoritative;
    this.baseUrl = config.authorityApiUrl;
  }

  private async request<T>(path: string, init: RequestInit = {}, requireAuthoritySession = false): Promise<T> {
    let authoritySessionHeaders: Record<string, string> = {};
    if (requireAuthoritySession) {
      const [{ cookies }, { ACCESS_COOKIE, TENANT_COOKIE }] = await Promise.all([
        import('next/headers'),
        import('@/authority/cookies'),
      ]);
      const cookieStore = await cookies();
      const accessToken = cookieStore.get(ACCESS_COOKIE)?.value;
      const tenantId = cookieStore.get(TENANT_COOKIE)?.value;
      if (!accessToken) throw new Error('AUTHORITY_SESSION_REQUIRED');
      if (!tenantId) throw new Error('AUTHORITY_TENANT_REQUIRED');
      authoritySessionHeaders = {
        authorization: `Bearer ${accessToken}`,
        'x-provenance-tenant': tenantId,
      };
    }
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        accept: 'application/json',
        ...(init.body ? { 'content-type': 'application/json' } : {}),
        ...authoritySessionHeaders,
        'x-provenance-environment': this.mode,
        ...init.headers,
      },
      cache: 'no-store',
    });
    const body = await response.json().catch(() => ({})) as Record<string, unknown>;
    if (!response.ok) {
      const error = body.error as { code?: string; message?: string } | undefined;
      throw new Error(`${error?.code ?? `AUTHORITY_HTTP_${response.status}`}:${error?.message ?? 'Authority request failed'}`);
    }
    return body as T;
  }

  async identifyAsset(query: AssetIdentityQuery, session?: OperationalSession): Promise<GemstoneAsset | FixtureRecord | null> {
    const params = new URLSearchParams(Object.entries(query).filter(([, value]) => value !== undefined) as Array<[string, string]>);
    if (session) params.set('tenantId', session.tenantId);
    const body = await this.request<{ data: GemstoneAsset | FixtureRecord | null }>(`/api/v1/authority/assets/identify?${params}`, {}, Boolean(session));
    return body.data;
  }

  async submitEvidence(session: OperationalSession, evidence: EvidenceObject): Promise<EvidenceObject> {
    const body = await this.request<{ data: EvidenceObject }>('/api/v1/authority/evidence', {
      method: 'POST',
      headers: { 'x-provenance-tenant': session.tenantId },
      body: JSON.stringify(evidence),
    }, true);
    return body.data;
  }

  async validateEvidence(evidence: EvidenceObject[]): Promise<EvidenceValidation> {
    const body = await this.request<{ data: EvidenceValidation }>('/api/v1/authority/evidence/validate', { method: 'POST', body: JSON.stringify({ evidence }) }, true);
    return body.data;
  }

  async assessTier(policy: PolicyInput, fixture: FixtureRecord): Promise<TierAssessment> {
    const body = await this.request<{ data: TierAssessment }>('/api/v1/authority/tier/assess', { method: 'POST', body: JSON.stringify({ policy, fixture }) }, true);
    return body.data;
  }

  async issueCredential(session: OperationalSession, reviewCaseId: string): Promise<Credential> {
    const body = await this.request<{ data: Credential }>(`/api/v1/authority/reviews/${encodeURIComponent(reviewCaseId)}/issue`, {
      method: 'POST',
      headers: { 'x-provenance-tenant': session.tenantId },
      body: JSON.stringify({}),
    }, true);
    return body.data;
  }

  async verify(publicId: string): Promise<VerificationResult> {
    try {
      const body = await this.request<Record<string, unknown>>('/api/v1/verify', { method: 'POST', body: JSON.stringify({ publicId }) });
      return { status: 200, body };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'VERIFY_FAILED';
      return { status: message.startsWith('record_not_found') ? 404 : 409, body: { error: { code: message.split(':')[0], message }, meta: { mode: this.mode, authoritative: this.authoritative } } };
    }
  }

  async transitionLifecycle(command: LifecycleTransitionCommand): Promise<ReviewCase> {
    const body = await this.request<{ data: ReviewCase }>(`/api/v1/operations/review/${encodeURIComponent(command.reviewCaseId)}/lifecycle`, {
      method: 'POST',
      headers: { 'x-provenance-tenant': command.session.tenantId },
      body: JSON.stringify({ action: command.action, reason: command.reason, successorId: command.successorId }),
    }, true);
    return body.data;
  }

  async lookupRegistry(publicId: string): Promise<RegistryLookupResult> {
    try {
      const body = await this.request<{ data: Record<string, unknown>; meta?: { canonicalDigest?: string } }>(`/api/v1/registry/${encodeURIComponent(publicId)}`);
      return { record: body.data, canonicalDigest: body.meta?.canonicalDigest };
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      if (message.startsWith('record_not_found')) return { record: null };
      throw error;
    }
  }

  async evaluatePolicy(policy: PolicyInput, fixture: FixtureRecord): Promise<CertificationDecision> {
    return (await this.assessTier(policy, fixture)).decision;
  }

  async continuity(publicId: string): Promise<ContinuityState | null> {
    const body = await this.request<{ data: ContinuityState | null }>(`/api/v1/authority/continuity/${encodeURIComponent(publicId)}`);
    return body.data;
  }

  async collectionState(session: OperationalSession): Promise<CollectionState> {
    const body = await this.request<{ data: CollectionState }>('/api/v1/operations/collection', { headers: { 'x-provenance-tenant': session.tenantId } }, true);
    return body.data;
  }

  async dataset(session: OperationalSession): Promise<OperationalDataset> {
    const body = await this.request<{ data: { dataset: OperationalDataset } }>('/api/v1/operations/session', { headers: { 'x-provenance-tenant': session.tenantId } }, true);
    return body.data.dataset;
  }

  async executeApi(operation: ApiOperation): Promise<Record<string, unknown>> {
    return this.request('/api/v1/authority/execute', { method: 'POST', body: JSON.stringify(operation) }, operation.name === 'operations.collection');
  }

  async invokeMcp(operation: McpOperation): Promise<Record<string, unknown>> {
    return this.request('/api/v1/mcp', { method: 'POST', body: JSON.stringify(operation) }, operation.name === 'provenance_collection_state');
  }
}
