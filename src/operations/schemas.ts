import { z } from 'zod';

const id = z.string().min(3).max(120);
const iso = z.string().datetime();

export const organizationRoleSchema = z.enum([
  'owner', 'administrator', 'intake-operator', 'evidence-manager', 'inventory-manager', 'authorized-attestor', 'reviewer', 'compliance-officer', 'auditor',
]);

export const operationalSessionSchema = z.object({
  id,
  tenantId: id,
  userId: id,
  displayName: z.string().min(1),
  role: organizationRoleSchema,
  locationIds: z.array(id).min(1),
  deviceId: id,
  authenticatedAt: iso,
  expiresAt: iso,
  testMode: z.literal(true),
});

export const gemstoneAssetInputSchema = z.object({
  serial: z.string().min(3).max(80),
  lotId: id.optional(),
  material: z.string().min(2).max(80),
  shape: z.string().min(2).max(80),
  cut: z.string().max(80).default(''),
  colorDescription: z.string().max(160).default(''),
  clarityDescription: z.string().max(160).default(''),
  treatmentDisclosure: z.string().max(240).default('Unknown / not declared'),
  originClaim: z.string().max(240).default('Not claimed'),
  supplierReference: z.string().max(120).default(''),
  laboratoryReportReference: z.string().max(120).default(''),
  identifyingFeatures: z.array(z.string().max(160)).max(30).default([]),
  measurements: z.object({
    weightCarats: z.number().positive().max(10000).nullable(),
    lengthMm: z.number().positive().max(1000).nullable(),
    widthMm: z.number().positive().max(1000).nullable(),
    depthMm: z.number().positive().max(1000).nullable(),
  }),
});

export const createLotSchema = z.object({
  locationId: id,
  supplierReference: z.string().min(2).max(120),
  description: z.string().min(2).max(240),
  declaredQuantity: z.number().int().positive().max(10000000),
  notes: z.string().max(2000).default(''),
});

export const createBatchSchema = z.object({
  name: z.string().min(3).max(120),
  reference: z.string().min(2).max(80),
  locationId: id,
  lotIds: z.array(id).max(1000).default([]),
});

export const bulkAssetImportSchema = z.object({
  assets: z.array(gemstoneAssetInputSchema).min(1).max(5000),
});

export const evidenceInputSchema = z.object({
  assetId: id,
  type: z.enum(['photo', 'measurement', 'attestation', 'laboratory', 'transfer', 'custody', 'identity', 'video', 'document']),
  label: z.string().min(2).max(160),
  sourceOrganization: z.string().min(2).max(160),
  sourceType: z.enum(['operator', 'supplier', 'laboratory', 'registry', 'custodian']),
  acquisitionMethod: z.enum(['camera', 'upload', 'api', 'scan', 'manual']),
  claimIds: z.array(id).max(100),
  independent: z.boolean(),
  qualified: z.boolean(),
  integrityHash: z.string().min(12),
  storageKey: z.string().min(3),
  visibility: z.enum(['private', 'reviewer', 'public-summary']),
  chainEvent: z.object({
    sequence: z.number().int().positive(),
    actorId: id,
    actorOrganization: z.string().min(2).max(160),
    action: z.string().min(2).max(160),
    occurredAt: iso,
    location: z.string().min(2).max(240),
    previousEventHash: z.string().min(8),
    eventHash: z.string().min(12),
    historyComplete: z.boolean(),
  }).optional(),
});

export const submitBatchSchema = z.object({
  declarationAccepted: z.literal(true),
  claimSummary: z.string().min(10).max(2000),
  evidenceSummary: z.string().min(10).max(2000),
  limitations: z.array(z.string().max(500)).max(50),
});

export const reviewDecisionSchema = z.object({
  reviewerId: id,
  role: z.enum(['primary', 'secondary']),
  decision: z.enum(['approve', 'reject', 'pending']),
  independent: z.boolean(),
  conflictFree: z.boolean(),
  reasonCodes: z.array(z.string()).max(50),
  action: z.enum(['review', 'custos-pass', 'custos-fail', 'authorize-signing', 'publish-registry', 'enable-revocation-control', 'authorize-mark', 'deny-mark']),
});

export const updateAssetSchema = gemstoneAssetInputSchema.partial().extend({
  measurements: gemstoneAssetInputSchema.shape.measurements.partial().optional(),
});
export const syncOperationInputSchema = z.object({
  id,
  tenantId: id,
  deviceId: id,
  entityType: z.enum(['batch', 'asset', 'evidence', 'attestation']),
  entityId: id,
  operation: z.enum(['create', 'update', 'submit']),
  expectedVersion: z.number().int().min(0),
  payload: z.record(z.unknown()),
  status: z.literal('queued'),
  attempts: z.number().int().min(0).default(0),
  createdAt: iso,
});
export const syncRequestSchema = z.object({ operations: z.array(syncOperationInputSchema).min(1).max(1000) });

export const labelRequestSchema = z.object({
  assetIds: z.array(id).min(1).max(500),
  format: z.enum(['svg']).default('svg'),
});

export const lifecycleTransitionSchema = z.object({
  action: z.enum(['suspend', 'reactivate', 'revoke', 'supersede', 'expire']),
  reason: z.string().min(10).max(1000),
  successorId: z.string().min(3).max(120).optional(),
}).superRefine((value, context) => {
  if (value.action === 'supersede' && !value.successorId) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['successorId'], message: 'A successor public ID is required for supersession.' });
  }
});

export const correctionActionSchema = z.discriminatedUnion('action', [
  z.object({
    action: z.literal('request'),
    reason: z.string().min(10).max(2000),
    fields: z.array(z.string().min(1).max(160)).min(1).max(50),
  }),
  z.object({
    action: z.literal('resolve'),
    correctionId: id,
    resolution: z.string().min(10).max(2000),
    claimSummary: z.string().min(10).max(2000),
    evidenceSummary: z.string().min(10).max(2000),
    limitations: z.array(z.string().max(500)).max(50),
  }),
  z.object({
    action: z.literal('reject'),
    correctionId: id,
    resolution: z.string().min(10).max(2000),
  }),
]);
