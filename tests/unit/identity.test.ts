import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { corporateAssets, certificationSealAssets } from '@/identity/assets';
import { resolveIdentityState } from '@/identity/state';

describe('R5 identity authority', () => {
  it('keeps the corporate master mark separate from every certification seal', () => {
    const sealPaths = Object.values(certificationSealAssets).flatMap((asset) => [asset.display, asset.compact]);
    expect(sealPaths).not.toContain(corporateAssets.masterMark);
    expect(new Set(sealPaths).size).toBe(8);
  });

  it('ships every controlled R5 asset referenced by the application', () => {
    const assets = [corporateAssets.lockupHorizontal, corporateAssets.masterMark, ...Object.values(certificationSealAssets).flatMap((asset) => [asset.display, asset.compact])];
    assets.forEach((asset) => expect(fs.existsSync(path.join(process.cwd(), 'public', asset))).toBe(true));
  });

  it('maps canonical authority and lifecycle states into the shared spatial runtime', () => {
    expect(resolveIdentityState({ stageIndex: 0, runState: 'idle', lifecycle: 'active', issuanceStatus: 'authorized', blockers: [] })).toBe('observe');
    expect(resolveIdentityState({ stageIndex: 5, runState: 'complete', lifecycle: 'active', issuanceStatus: 'authorized', blockers: [] })).toBe('verify');
    expect(resolveIdentityState({ stageIndex: 5, runState: 'complete', lifecycle: 'active', issuanceStatus: 'second-approval-required', blockers: [] })).toBe('pending');
    expect(resolveIdentityState({ stageIndex: 4, runState: 'complete', lifecycle: 'active', issuanceStatus: 'reviewer-conflict', blockers: ['Reviewer conflict detected.'] })).toBe('exception');
    expect(resolveIdentityState({ stageIndex: 6, runState: 'complete', lifecycle: 'revoked', issuanceStatus: 'authorized', blockers: [] })).toBe('revoked');
    expect(resolveIdentityState({ stageIndex: 2, runState: 'error', lifecycle: 'active', issuanceStatus: 'review-required', blockers: [] })).toBe('failed');
  });
});
