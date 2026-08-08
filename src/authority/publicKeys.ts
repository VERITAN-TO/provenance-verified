import { getAuthorityRuntimeConfig } from '@/authority/config';

export interface PublicKeySet {
  keys: Array<Record<string, unknown>>;
  meta: { environment: 'sandbox' | 'pilot' | 'production'; authoritative: boolean; historical: boolean; cacheSeconds: number };
}

const SANDBOX_KEY = {
  kty: 'OKP', crv: 'Ed25519', x: 'QwwzandAYQcNcJ98O_P6zSzjAj3d9UPvzKI_Gv3gtiE',
  kid: 'sandbox-verifier:sandbox-ed25519:v1', use: 'sig', alg: 'EdDSA', key_ops: ['verify'],
  service: 'sandbox-verifier', keyId: 'sandbox-ed25519', keyVersion: 1, status: 'active',
  validFrom: '2026-01-01T00:00:00.000Z', validUntil: '2030-01-01T00:00:00.000Z',
  policyVersions: ['sandbox.v1'], authoritative: false,
};

export async function getPublicAuthorityKeys(includeHistorical = false): Promise<PublicKeySet> {
  const config = getAuthorityRuntimeConfig();
  if (config.environment === 'sandbox') {
    return { keys: [SANDBOX_KEY], meta: { environment: 'sandbox', authoritative: false, historical: includeHistorical, cacheSeconds: 300 } };
  }
  if (!config.authorityApiUrl) throw new Error('AUTHORITY_VERIFICATION_KEYS_UNAVAILABLE');
  const url = new URL(`${config.authorityApiUrl}/api/v1/keys`);
  if (includeHistorical) url.searchParams.set('include', 'historical');
  const response = await fetch(url, { cache: 'no-store', headers: { 'x-provenance-environment': config.environment } });
  if (!response.ok) throw new Error(`AUTHORITY_VERIFICATION_KEYS_UNAVAILABLE:${response.status}`);
  const body = await response.json() as PublicKeySet;
  if (!Array.isArray(body.keys) || !body.keys.length) throw new Error('AUTHORITY_VERIFICATION_KEYS_EMPTY');
  return body;
}
