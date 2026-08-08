import { getAuthorityRuntimeConfig } from '@/authority/config';

const sandboxKnowledge = [
  { canonicalKey: 'platform.identity', locale: 'en', region: 'global', sourceIds: ['R8.1-reference','R3-mandate'], ownerIdentity: 'PROVENANCE VERIFIED™', reviewAt: '2026-10-01T00:00:00.000Z', expiresAt: '2027-01-01T00:00:00.000Z', state: 'published', body: { name: 'PROVENANCE VERIFIED™', description: 'Evidence infrastructure for claim-scoped credentials, lifecycle events, and public registry projections.', authoritative: false, environment: 'sandbox' } },
  { canonicalKey: 'platform.modes', locale: 'en', region: 'global', sourceIds: ['R3-mandate'], ownerIdentity: 'PROVENANCE VERIFIED™', reviewAt: '2026-10-01T00:00:00.000Z', expiresAt: '2027-01-01T00:00:00.000Z', state: 'published', body: { sandbox: 'deterministic and non-authoritative', pilot: 'real infrastructure with production issuance and marks disabled', production: 'requires signed activation and all fifteen gates' } },
  { canonicalKey: 'credential.lifecycle', locale: 'en', region: 'global', sourceIds: ['lifecycle-policy-r3'], ownerIdentity: 'Trust Authority', reviewAt: '2026-10-01T00:00:00.000Z', expiresAt: '2027-01-01T00:00:00.000Z', state: 'published', body: { states: ['ACTIVE','SUSPENDED','REVOKED','SUPERSEDED','EXPIRED','QUARANTINED'], historicalRecordsRemainResolvable: true } },
];

export async function getPublicKnowledge(locale='en',region='global') {
  const config=getAuthorityRuntimeConfig();
  if(config.environment==='sandbox') return {data:sandboxKnowledge.filter(item=>item.locale===locale&&(item.region===region||item.region==='global')),meta:{environment:'sandbox',authoritative:false,freshnessBound:true,generatedAt:new Date().toISOString()}};
  if(!config.authorityApiUrl) throw new Error('KNOWLEDGE_AUTHORITY_UNAVAILABLE');
  const url=new URL(`${config.authorityApiUrl}/api/v1/knowledge`);url.searchParams.set('locale',locale);url.searchParams.set('region',region);
  const response=await fetch(url,{cache:'no-store'});if(!response.ok)throw new Error(`KNOWLEDGE_AUTHORITY_UNAVAILABLE:${response.status}`);
  return response.json();
}
