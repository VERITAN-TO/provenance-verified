import { createHash } from 'node:crypto';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { getAuthorityRuntimeConfig } from '@/authority/config';

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('authority runtime configuration', () => {
  it('defaults to isolated Sandbox mode', () => {
    vi.stubEnv('PV_ENVIRONMENT', 'sandbox');
    const config = getAuthorityRuntimeConfig();
    expect(config.environment).toBe('sandbox');
    expect(config.authoritative).toBe(false);
  });

  it('fails closed when Pilot lacks real authority services', () => {
    vi.stubEnv('PV_ENVIRONMENT', 'pilot');
    expect(() => getAuthorityRuntimeConfig()).toThrow('AUTHORITY_RUNTIME_INCOMPLETE');
  });

  it('fails closed when Production lacks a signed activation record', () => {
    vi.stubEnv('PV_ENVIRONMENT', 'production');
    vi.stubEnv('PV_AUTHORITY_API_URL', 'https://authority.example');
    vi.stubEnv('PV_SUPABASE_URL', 'https://example.supabase.co');
    vi.stubEnv('PV_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_test');
    expect(() => getAuthorityRuntimeConfig()).toThrow('PRODUCTION_ACTIVATION_INCOMPLETE');
  });

  it('production activation requires authority implementation not included in this distribution', () => {
    const fakeRecordJson = JSON.stringify({ environment: 'production' });
    vi.stubEnv('PV_ENVIRONMENT', 'production');
    vi.stubEnv('PV_AUTHORITY_API_URL', 'https://authority.example');
    vi.stubEnv('PV_SUPABASE_URL', 'https://example.supabase.co');
    vi.stubEnv('PV_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_test');
    vi.stubEnv('PV_PRODUCTION_AUTHORITY_ENABLED', 'true');
    vi.stubEnv('PV_PRODUCTION_ACTIVATION_RECORD_ID', 'activation-2026-01');
    vi.stubEnv('PV_PRODUCTION_ACTIVATION_RECORD_JSON_BASE64', Buffer.from(fakeRecordJson).toString('base64'));
    vi.stubEnv('PV_PRODUCTION_ACTIVATION_PUBLIC_KEY_BASE64', Buffer.from('test-key').toString('base64'));
    vi.stubEnv('PV_PRODUCTION_ACTIVATION_RECORD_SHA256', `sha256:${createHash('sha256').update(fakeRecordJson).digest('hex')}`);
    vi.stubEnv('PV_RELEASE_COMMIT', 'a'.repeat(40));
    vi.stubEnv('PV_RELEASE_PACKAGE_SHA256', 'sha256:' + 'b'.repeat(64));
    vi.stubEnv('PV_INFRASTRUCTURE_VERSION', 'v1');
    vi.stubEnv('PV_DATABASE_MIGRATION_VERSION', 'v1');
    vi.stubEnv('PV_SIGNING_KEY_ID', 'key-001');
    vi.stubEnv('PV_SIGNING_KEY_VERSION', '1');
    vi.stubEnv('PV_CUSTOS_AUTHORITY_VERSION', 'v1');
    vi.stubEnv('PV_REGISTRY_VERSION', 'v1');
    expect(() => getAuthorityRuntimeConfig()).toThrow('PRODUCTION_ACTIVATION_UNSUPPORTED');
  });
});
