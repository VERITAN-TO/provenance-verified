import { describe, expect, it } from 'vitest';
import { decryptOfflineBytes, generateOfflineKey, encryptOfflineBytes, sha256Blob } from '@/operations/offline/crypto';

describe('Phase 4 encrypted offline evidence', () => {
  it('creates a stable SHA-256 integrity value for captured bytes', async () => {
    const hash = await sha256Blob(new Blob(['provenance-evidence'], { type: 'image/jpeg' }));
    expect(hash).toMatch(/^sha256:[0-9a-f]{64}$/);
    expect(await sha256Blob(new Blob(['provenance-evidence']))).toBe(hash);
  });

  it('encrypts and decrypts offline bytes with an opaque device-scope key', async () => {
    const key = await generateOfflineKey();
    expect(key.extractable).toBe(false);
    const clear = new TextEncoder().encode('sensitive gemstone evidence').buffer;
    const encrypted = await encryptOfflineBytes(key, clear);
    expect(new Uint8Array(encrypted.ciphertext)).not.toEqual(new Uint8Array(clear));
    const restored = await decryptOfflineBytes(key, encrypted.iv, encrypted.ciphertext);
    expect(new TextDecoder().decode(restored)).toBe('sensitive gemstone evidence');
  });
});
