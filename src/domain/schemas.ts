import { z } from 'zod';

export const publicIdSchema = z.string().regex(/^PV-[A-Z0-9]{4}-[A-Z0-9]{6}$/);
export const verifyRequestSchema = z.object({ publicId: publicIdSchema, fixtureKey: z.string().optional() });
export const lifecycleSchema = z.enum(['draft', 'active', 'suspended', 'superseded', 'revoked', 'expired', 'not-found']);
export const issuanceStatusSchema = z.enum([
  'not-eligible',
  'review-required',
  'review-rejected',
  'independent-review-required',
  'second-approval-required',
  'reviewer-conflict',
  'conflict-clearance-required',
  'custos-required',
  'signing-key-required',
  'registry-required',
  'revocation-control-required',
  'authorized',
]);
export const reviewerApprovalSchema = z.object({
  id: z.string().min(1),
  reviewerId: z.string().min(1),
  role: z.enum(['primary', 'secondary']),
  independent: z.boolean(),
  conflictFree: z.boolean(),
  decision: z.enum(['approve', 'reject', 'pending']),
  decidedAt: z.string().datetime().optional(),
  reasonCodes: z.array(z.string()),
});
export const authorityInputSchema = z.object({
  reviewerApprovals: z.array(reviewerApprovalSchema),
  conflictClearance: z.enum(['pending', 'clear', 'conflict']),
  custosVerdict: z.object({
    status: z.enum(['pending', 'pass', 'fail']),
    verdictId: z.string().optional(),
    evaluatedAt: z.string().datetime().optional(),
    reasonCodes: z.array(z.string()),
  }),
  signingKeyStatus: z.enum(['pending', 'active', 'unavailable', 'revoked']),
  registryStatus: z.enum(['pending', 'ready', 'unavailable']),
  revocationCapability: z.boolean(),
  markAuthorization: z.enum(['pending', 'authorized', 'denied']),
});
export const webhookReplaySchema = z.object({ attemptId: z.string().min(1), reason: z.string().min(3).max(240) });
