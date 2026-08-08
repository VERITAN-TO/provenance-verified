import { describe, expect, it } from 'vitest';
import { verifyRequestSchema, webhookReplaySchema } from '@/domain/schemas';

describe('security contract validation', () => {
  it('rejects malformed public IDs', () => {
    expect(verifyRequestSchema.safeParse({ publicId: '<script>alert(1)</script>' }).success).toBe(false);
  });
  it('requires a reason for manual replay', () => {
    expect(webhookReplaySchema.safeParse({ attemptId: 'wh_01', reason: '' }).success).toBe(false);
  });
});
