import { canonicalJson } from '@/domain/hash';
import type { Credential } from '@/domain/types';

export function registryProjection(credential: Credential) {
  return {
    publicId: credential.publicId,
    url: `/registry/${credential.publicId}`,
    issuer: credential.issuer,
    program: credential.program,
    subject: credential.subject,
    published: credential.status === 'issued',
    credentialStatus: credential.status,
    eligibility: { tier: credential.eligibleTier, name: credential.eligibleTierName },
    certification: credential.status === 'issued'
      ? { tier: credential.tier, name: credential.tierName, disclosure: credential.disclosure }
      : null,
    authorization: credential.authorization,
    sealAuthorization: credential.sealAuthorization,
    claimScope: credential.claims.map(({ id, label, value, status, scopeNote }) => ({ id, label, value, status, scopeNote })),
    evidenceSummary: {
      count: credential.evidence.length,
      qualifiedSources: credential.sources.filter((source) => source.qualified).length,
      independentSources: credential.sources.filter((source) => source.independent && source.qualified).length
    },
    lifecycle: credential.lifecycle,
    version: credential.version,
    issuedAt: credential.issuedAt ?? null,
    signature: credential.signature,
    integrityHash: credential.integrityHash,
    successorId: credential.successorId,
    warnings: credential.warnings,
    testMode: credential.testMode
  };
}

export function apiProjection(credential: Credential) {
  return {
    data: credential,
    meta: {
      mode: 'test',
      authoritative: false,
      productionCredential: false,
      canonicalDigest: credential.integrityHash
    }
  };
}

export function projectionParity(credential: Credential) {
  const api = apiProjection(credential);
  const registry = registryProjection(credential);
  return {
    publicId: api.data.publicId === registry.publicId,
    eligibilityTier: api.data.eligibleTier === registry.eligibility.tier,
    credentialStatus: api.data.status === registry.credentialStatus,
    issuedTier: api.data.tier === registry.certification?.tier,
    disclosure: api.data.status === 'not-issued' || api.data.disclosure === registry.certification?.disclosure,
    lifecycle: api.data.lifecycle === registry.lifecycle,
    signature: canonicalJson(api.data.signature) === canonicalJson(registry.signature),
    sealAuthorization: canonicalJson(api.data.sealAuthorization) === canonicalJson(registry.sealAuthorization),
    integrityHash: api.data.integrityHash === registry.integrityHash,
    claimCount: api.data.claims.length === registry.claimScope.length
  };
}
