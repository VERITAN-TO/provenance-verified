import { createHash } from 'node:crypto';

export type OperatingMode = 'sandbox' | 'pilot' | 'production';
export type ActivationRecord = Record<string, unknown>;

function parseOperatingMode(value: string): OperatingMode {
  if (value === 'pilot' || value === 'production') return value;
  return 'sandbox';
}

function verifyActivationRecord(..._args: unknown[]): void {
  throw new Error('PRODUCTION_ACTIVATION_UNSUPPORTED: authority implementation not included in this distribution');
}

export type ProvenanceEnvironment = OperatingMode;

export interface AuthorityRuntimeConfig {
  environment: ProvenanceEnvironment;
  authoritative: boolean;
  authorityApiUrl?: string;
  supabaseUrl?: string;
  supabasePublishableKey?: string;
  requireAal2: boolean;
  productionEnabled: boolean;
  activationRecordId?: string;
  activationRecordSha256?: string;
  activationRecord?: ActivationRecord;
}

function normalizeEnvironment(value: string | undefined): ProvenanceEnvironment {
  const normalized = value?.trim().toLowerCase();
  if (!normalized || normalized === 'test') return 'sandbox';
  return parseOperatingMode(normalized);
}

function mustProvide(value: string | undefined, name: string): string {
  if (!value?.trim()) throw new Error(`PRODUCTION_ACTIVATION_INCOMPLETE:${name}`);
  return value.trim();
}

function decodeBase64(value: string, name: string): string {
  try {
    return Buffer.from(value, 'base64').toString('utf8');
  } catch (error) {
    throw new Error(`PRODUCTION_ACTIVATION_DECODE_FAILED:${name}`, { cause: error });
  }
}

function parseSignedActivationRecord(): { record: ActivationRecord; publicKey: string; recordHash: string } {
  const recordJson = decodeBase64(mustProvide(process.env.PV_PRODUCTION_ACTIVATION_RECORD_JSON_BASE64, 'PV_PRODUCTION_ACTIVATION_RECORD_JSON_BASE64'), 'record');
  const publicKey = decodeBase64(mustProvide(process.env.PV_PRODUCTION_ACTIVATION_PUBLIC_KEY_BASE64, 'PV_PRODUCTION_ACTIVATION_PUBLIC_KEY_BASE64'), 'public-key');
  let record: ActivationRecord;
  try {
    record = JSON.parse(recordJson) as ActivationRecord;
  } catch (error) {
    throw new Error('PRODUCTION_ACTIVATION_JSON_INVALID', { cause: error });
  }
  const recordHash = `sha256:${createHash('sha256').update(recordJson).digest('hex')}`;
  const expectedHash = mustProvide(process.env.PV_PRODUCTION_ACTIVATION_RECORD_SHA256, 'PV_PRODUCTION_ACTIVATION_RECORD_SHA256');
  if (recordHash !== expectedHash) throw new Error('PRODUCTION_ACTIVATION_HASH_MISMATCH');
  verifyActivationRecord(record, {
    releaseCommit: mustProvide(process.env.PV_RELEASE_COMMIT, 'PV_RELEASE_COMMIT'),
    releasePackageHash: mustProvide(process.env.PV_RELEASE_PACKAGE_SHA256, 'PV_RELEASE_PACKAGE_SHA256'),
    infrastructureVersion: mustProvide(process.env.PV_INFRASTRUCTURE_VERSION, 'PV_INFRASTRUCTURE_VERSION'),
    databaseMigrationVersion: mustProvide(process.env.PV_DATABASE_MIGRATION_VERSION, 'PV_DATABASE_MIGRATION_VERSION'),
    signingKeyId: mustProvide(process.env.PV_SIGNING_KEY_ID, 'PV_SIGNING_KEY_ID'),
    signingKeyVersion: Number(mustProvide(process.env.PV_SIGNING_KEY_VERSION, 'PV_SIGNING_KEY_VERSION')),
    custosAuthorityVersion: mustProvide(process.env.PV_CUSTOS_AUTHORITY_VERSION, 'PV_CUSTOS_AUTHORITY_VERSION'),
    registryVersion: mustProvide(process.env.PV_REGISTRY_VERSION, 'PV_REGISTRY_VERSION'),
  }, publicKey);
  return { record, publicKey, recordHash };
}

export function getAuthorityRuntimeConfig(): AuthorityRuntimeConfig {
  const environment = normalizeEnvironment(process.env.PV_ENVIRONMENT ?? process.env.PV_SERVICE_MODE);
  const productionEnabled = process.env.PV_PRODUCTION_AUTHORITY_ENABLED === 'true';
  const config: AuthorityRuntimeConfig = {
    environment,
    authoritative: false,
    authorityApiUrl: process.env.PV_AUTHORITY_API_URL?.replace(/\/$/, ''),
    supabaseUrl: process.env.PV_SUPABASE_URL?.replace(/\/$/, '') ?? process.env.NEXT_PUBLIC_SUPABASE_URL?.replace(/\/$/, ''),
    supabasePublishableKey: process.env.PV_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    requireAal2: process.env.PV_AUTH_REQUIRE_AAL2 === 'true' || environment === 'production',
    productionEnabled,
    activationRecordId: process.env.PV_PRODUCTION_ACTIVATION_RECORD_ID,
    activationRecordSha256: process.env.PV_PRODUCTION_ACTIVATION_RECORD_SHA256,
  };

  if (environment !== 'sandbox') {
    const missing = [
      !config.authorityApiUrl && 'PV_AUTHORITY_API_URL',
      !config.supabaseUrl && 'PV_SUPABASE_URL',
      !config.supabasePublishableKey && 'PV_SUPABASE_PUBLISHABLE_KEY',
    ].filter(Boolean);
    if (missing.length) throw new Error(`AUTHORITY_RUNTIME_INCOMPLETE:${missing.join(',')}`);
  }

  if (environment === 'production') {
    if (!productionEnabled) throw new Error('PRODUCTION_ACTIVATION_INCOMPLETE:PV_PRODUCTION_AUTHORITY_ENABLED');
    config.activationRecordId = mustProvide(config.activationRecordId, 'PV_PRODUCTION_ACTIVATION_RECORD_ID');
    const verified = parseSignedActivationRecord();
    config.activationRecord = verified.record;
    config.activationRecordSha256 = verified.recordHash;
    config.authoritative = true;
  }

  return config;
}

export function publicEnvironment(): ProvenanceEnvironment {
  return normalizeEnvironment(process.env.NEXT_PUBLIC_PV_ENVIRONMENT ?? process.env.PV_ENVIRONMENT ?? process.env.PV_SERVICE_MODE);
}
