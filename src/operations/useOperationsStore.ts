"use client";

import { create } from "zustand";
import { stableHash } from "@/domain/hash";
import { can } from "./permissions";
import { createAssetId, isBatchSubmittable, validateBatch } from "./kernel";
import { operationalDataset } from "./fixtures";
import type {
  EvidenceObject,
  GemstoneAsset,
  IntakeBatch,
  OperationalAuditEvent,
  OperationalDataset,
  ReviewCase,
  SyncOperation,
} from "./types";
import { clearOfflineMedia, loadOfflineMedia, saveOfflineMedia, saveOfflineSnapshot } from "./offline/indexedDb";
import { sha256Blob } from "./offline/crypto";
import { authorityFetch, authorizationHeaders } from "./auth";
import { getPublicEnvironment } from "@/authority/public-mode";

interface OperationsState {
  dataset: OperationalDataset;
  sessionId: string;
  selectedBatchId: string;
  selectedAssetId: string | null;
  selectedReviewCaseId: string | null;
  online: boolean;
  syncState: "idle" | "queued" | "syncing" | "synced" | "conflict" | "error";
  statusMessage: string;
  selectSession: (sessionId: string) => void;
  hydrateSession: () => Promise<void>;
  selectBatch: (batchId: string) => void;
  selectAsset: (assetId: string | null) => void;
  createLot: (input: {
    supplierReference: string;
    description: string;
    declaredQuantity: number;
    notes: string;
  }) => Promise<string | null>;
  createBatch: (name: string, reference: string) => string;
  addAsset: (
    input: Pick<
      GemstoneAsset,
      | "serial"
      | "material"
      | "shape"
      | "cut"
      | "colorDescription"
      | "clarityDescription"
      | "treatmentDisclosure"
      | "originClaim"
      | "measurements"
      | "identifyingFeatures"
      | "supplierReference"
      | "laboratoryReportReference"
    >,
  ) => string;
  addBulkAssets: (count: number) => number;
  importCsvFile: (file: File) => Promise<number>;
  updateSelectedAsset: (
    patch: Partial<
      Pick<
        GemstoneAsset,
        | "material"
        | "shape"
        | "cut"
        | "colorDescription"
        | "clarityDescription"
        | "treatmentDisclosure"
        | "originClaim"
        | "measurements"
        | "identifyingFeatures"
        | "supplierReference"
        | "laboratoryReportReference"
      >
    >,
  ) => void;
  addEvidence: (type: EvidenceObject["type"], independent?: boolean) => void;
  addEvidenceFile: (file: File) => Promise<void>;
  validateSelectedBatch: () => void;
  submitSelectedBatch: () => Promise<void>;
  setOnline: (online: boolean) => void;
  flushSyncQueue: () => Promise<void>;
  selectReviewCase: (caseId: string) => void;
  reviewAction: (
    action:
      | "primary-approve"
      | "secondary-approve"
      | "custos-pass"
      | "authorize-signing"
      | "publish-registry"
      | "enable-revocation-control"
      | "authorize-mark"
      | "reject",
  ) => Promise<void>;
  lifecycleAction: (
    action: "suspend" | "reactivate" | "revoke" | "supersede" | "expire",
    reason: string,
    successorId?: string,
  ) => Promise<void>;
  requestCorrection: (reason: string, fields: string[]) => Promise<void>;
  resolveCorrection: (
    correctionId: string,
    resolution: string,
  ) => Promise<void>;
  rejectCorrection: (correctionId: string, resolution: string) => Promise<void>;
}

const publicEnvironment = getPublicEnvironment();
const pendingTenantId = 'authority_pending';
const pendingDataset: OperationalDataset = {
  tenants: [{
    id: pendingTenantId,
    legalName: 'Authenticated organization pending',
    displayName: 'Loading organization authority',
    status: 'active',
    createdAt: new Date(0).toISOString(),
    settings: { defaultCurrency: 'USD', timezone: 'UTC', retentionDays: 0, maxBatchSize: 0 },
  }],
  locations: [],
  sessions: [{
    id: 'authority-session-pending',
    tenantId: pendingTenantId,
    userId: 'authority-user-pending',
    displayName: 'Identity verification pending',
    role: 'auditor',
    locationIds: [],
    deviceId: 'server-authenticated',
    authenticatedAt: new Date(0).toISOString(),
    expiresAt: new Date(0).toISOString(),
    testMode: false,
    environment: publicEnvironment,
    assuranceLevel: 'aal1',
  }],
  lots: [], batches: [], assets: [], evidence: [], attestations: [], reviewCases: [], syncOperations: [], auditEvents: [],
};
const seed = structuredClone(publicEnvironment === 'sandbox' ? operationalDataset : pendingDataset);
const initialSession = seed.sessions[0];
const initialBatch = seed.batches.find((batch) => batch.tenantId === initialSession.tenantId);
const initialAsset = initialBatch ? seed.assets.find((asset) => asset.batchId === initialBatch.id) ?? null : null;

function audit(
  state: OperationsState,
  action: string,
  targetType: string,
  targetId: string,
  resultingState: Record<string, unknown>,
): OperationalAuditEvent {
  const session = state.dataset.sessions.find(
    (item) => item.id === state.sessionId,
  )!;
  return {
    id: `audit_${stableHash(`${action}:${targetId}:${state.dataset.auditEvents.length}`)}`,
    tenantId: session.tenantId,
    actorId: session.userId,
    actorRole: session.role,
    action,
    targetType,
    targetId,
    resultingState,
    requestId: `req_${stableHash(`${session.id}:${action}:${targetId}`)}`,
    at: "2026-07-20T04:30:00Z",
  };
}

function denial(permission: string) {
  return `Action denied. The active role does not hold ${permission}.`;
}
function activeSession(state: OperationsState) {
  return state.dataset.sessions.find((item) => item.id === state.sessionId)!;
}

export const useOperationsStore = create<OperationsState>((set, get) => ({
  dataset: seed,
  sessionId: initialSession.id,
  selectedBatchId: initialBatch?.id ?? "",
  selectedAssetId: initialAsset?.id ?? null,
  selectedReviewCaseId: seed.reviewCases[0]?.id ?? null,
  online: true,
  syncState: "idle",
  statusMessage:
    publicEnvironment === "sandbox"
      ? "Operational workspace loaded. Data is tenant-scoped and Test Mode is explicit."
      : "Waiting for authenticated AAL2 tenant authority. No Test Mode fixtures are loaded.",

  selectSession: (sessionId) =>
    set((state) => {
      const session =
        state.dataset.sessions.find((item) => item.id === sessionId) ??
        state.dataset.sessions[0];
      const batch = state.dataset.batches.find(
        (item) => item.tenantId === session.tenantId,
      );
      const asset = state.dataset.assets.find(
        (item) =>
          item.tenantId === session.tenantId &&
          (!batch || item.batchId === batch.id),
      );
      const review = state.dataset.reviewCases.find(
        (item) => item.tenantId === session.tenantId,
      );
      return {
        sessionId: session.id,
        selectedBatchId: batch?.id ?? "",
        selectedAssetId: asset?.id ?? null,
        selectedReviewCaseId: review?.id ?? null,
        statusMessage: `${session.displayName} active as ${session.role}.`,
      };
    }),

  selectBatch: (selectedBatchId) =>
    set((state) => ({
      selectedBatchId,
      selectedAssetId:
        state.dataset.assets.find((asset) => asset.batchId === selectedBatchId)
          ?.id ?? null,
      statusMessage: `Batch ${selectedBatchId} selected.`,
    })),
  selectAsset: (selectedAssetId) =>
    set({
      selectedAssetId,
      statusMessage: selectedAssetId
        ? `Unit ${selectedAssetId} selected.`
        : "Unit selection cleared.",
    }),

  hydrateSession: async () => {
    const state = get();
    const session = activeSession(state);
    const environment = (process.env.NEXT_PUBLIC_PV_ENVIRONMENT ?? 'sandbox').toLowerCase();
    set({
      syncState: "syncing",
      statusMessage: `Authenticating ${session.displayName} and loading canonical tenant state.`,
    });
    try {
      const response = await authorityFetch("/api/v1/operations/session", {
        headers: authorizationHeaders(session),
      });
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `SESSION_HTTP_${response.status}`,
        );
      const incoming = body.data.dataset as OperationalDataset;
      set((current) => {
        const keepOtherTenant = <T extends { tenantId: string }>(items: T[]) =>
          items.filter((item) => item.tenantId !== session.tenantId);
        const dataset: OperationalDataset = environment === 'sandbox' || environment === 'test'
          ? {
              ...current.dataset,
              tenants: [...current.dataset.tenants.filter((item) => item.id !== session.tenantId), ...incoming.tenants],
              locations: [...keepOtherTenant(current.dataset.locations), ...incoming.locations],
              sessions: current.dataset.sessions,
              lots: [...keepOtherTenant(current.dataset.lots), ...incoming.lots],
              batches: [...keepOtherTenant(current.dataset.batches), ...incoming.batches],
              assets: [...keepOtherTenant(current.dataset.assets), ...incoming.assets],
              evidence: [...keepOtherTenant(current.dataset.evidence), ...incoming.evidence],
              attestations: [...keepOtherTenant(current.dataset.attestations), ...incoming.attestations],
              reviewCases: [...keepOtherTenant(current.dataset.reviewCases), ...incoming.reviewCases],
              syncOperations: [...keepOtherTenant(current.dataset.syncOperations), ...incoming.syncOperations],
              auditEvents: [...keepOtherTenant(current.dataset.auditEvents), ...incoming.auditEvents],
            }
          : incoming;
        const canonicalSession = environment === 'sandbox' || environment === 'test'
          ? session
          : incoming.sessions[0] ?? session;
        const batch = dataset.batches.find(
          (item) => item.tenantId === canonicalSession.tenantId,
        );
        const asset = dataset.assets.find(
          (item) =>
            item.tenantId === canonicalSession.tenantId &&
            (!batch || item.batchId === batch.id),
        );
        const review = dataset.reviewCases.find(
          (item) => item.tenantId === canonicalSession.tenantId,
        );
        return {
          dataset,
          sessionId: canonicalSession.id,
          selectedBatchId: batch?.id ?? "",
          selectedAssetId: asset?.id ?? null,
          selectedReviewCaseId: review?.id ?? null,
          syncState: "synced",
          statusMessage: `${canonicalSession.displayName} authenticated. Canonical tenant state loaded from the ${environment === 'sandbox' || environment === 'test' ? 'durable Test Mode adapter' : `${environment} authority plane`}.`,
        };
      });
    } catch (error) {
      set({
        syncState: "error",
        statusMessage: `Session hydration failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  createLot: async (input) => {
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "inventory.manage")) {
      set({ statusMessage: denial("inventory.manage") });
      return null;
    }
    if (!state.online) {
      set({
        statusMessage:
          "Lot receiving requires a network connection so aggregate inventory is persisted before unit serialization.",
      });
      return null;
    }
    const locationId = session.locationIds[0];
    try {
      const response = await authorityFetch("/api/v1/operations/lots", {
        method: "POST",
        headers: authorizationHeaders(session, "application/json"),
        body: JSON.stringify({ ...input, locationId }),
      });
      const body = await response.json();
      if (!response.ok)
        throw new Error(body.error?.message ?? `LOT_HTTP_${response.status}`);
      set((current) => ({
        dataset: {
          ...current.dataset,
          lots: [
            ...current.dataset.lots.filter((item) => item.id !== body.data.id),
            body.data,
          ],
        },
        statusMessage: `Lot ${body.data.id} received with ${body.data.declaredQuantity.toLocaleString()} aggregate units. No gemstone identities were created.`,
      }));
      return body.data.id as string;
    } catch (error) {
      set({
        statusMessage: `Lot receiving failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
      return null;
    }
  },

  createBatch: (name, reference) => {
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "batch.create")) {
      set({ statusMessage: denial("batch.create") });
      return "";
    }
    const id = `batch_${stableHash(`${session.tenantId}:${reference}`)}`;
    const batch: IntakeBatch = {
      id,
      tenantId: session.tenantId,
      locationId: session.locationIds[0],
      name,
      reference,
      status: "draft",
      assetIds: [],
      lotIds: [],
      validationErrors: [],
      createdAt: "2026-07-20T04:31:00Z",
      updatedAt: "2026-07-20T04:31:00Z",
      createdBy: session.userId,
      version: 1,
    };
    const sync: SyncOperation = {
      id: `sync_batch_${stableHash(id)}`,
      tenantId: session.tenantId,
      deviceId: session.deviceId,
      entityType: "batch",
      entityId: id,
      operation: "create",
      expectedVersion: 0,
      payload: batch as unknown as Record<string, unknown>,
      status: "queued",
      attempts: 0,
      createdAt: batch.createdAt,
    };
    set((current) => ({
      dataset: {
        ...current.dataset,
        batches: [
          ...current.dataset.batches.filter((item) => item.id !== id),
          batch,
        ],
        syncOperations: [
          ...current.dataset.syncOperations.filter(
            (item) => item.id !== sync.id,
          ),
          sync,
        ],
        auditEvents: [
          ...current.dataset.auditEvents,
          audit(current, "batch.created-local", "batch", id, {
            status: "draft",
            sync: "queued",
          }),
        ],
      },
      selectedBatchId: id,
      selectedAssetId: null,
      syncState: "queued",
      statusMessage: `Batch ${reference} saved locally and queued for synchronization.`,
    }));
    return id;
  },

  addAsset: (input) => {
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "asset.create")) {
      set({ statusMessage: denial("asset.create") });
      return "";
    }
    const batch = state.dataset.batches.find(
      (item) =>
        item.id === state.selectedBatchId && item.tenantId === session.tenantId,
    );
    if (!batch) throw new Error("BATCH_NOT_FOUND");
    const serial = input.serial.trim().toUpperCase();
    const id = createAssetId(session.tenantId, serial);
    if (
      state.dataset.assets.some(
        (asset) =>
          asset.tenantId === session.tenantId &&
          asset.serial.toUpperCase() === serial,
      )
    ) {
      set({ statusMessage: `Duplicate unit serial ${serial} is not allowed.` });
      return "";
    }
    const asset: GemstoneAsset = {
      id,
      tenantId: session.tenantId,
      locationId: batch.locationId,
      batchId: batch.id,
      status: "draft",
      ...input,
      serial,
      evidenceIds: [],
      version: 1,
      createdAt: "2026-07-20T04:32:00Z",
      updatedAt: "2026-07-20T04:32:00Z",
      createdBy: session.userId,
    };
    const sync: SyncOperation = {
      id: `sync_${stableHash(id)}`,
      tenantId: session.tenantId,
      deviceId: session.deviceId,
      entityType: "asset",
      entityId: id,
      operation: "create",
      expectedVersion: 0,
      payload: asset as unknown as Record<string, unknown>,
      status: "queued",
      attempts: 0,
      createdAt: asset.createdAt,
    };
    set((current) => ({
      dataset: {
        ...current.dataset,
        assets: [...current.dataset.assets, asset],
        batches: current.dataset.batches.map((item) =>
          item.id === batch.id
            ? {
                ...item,
                assetIds: [...item.assetIds, id],
                updatedAt: asset.updatedAt,
                version: item.version + 1,
              }
            : item,
        ),
        syncOperations: [...current.dataset.syncOperations, sync],
        auditEvents: [
          ...current.dataset.auditEvents,
          audit(current, "asset.created-local", "asset", id, {
            batchId: batch.id,
            serial,
            sync: "queued",
          }),
        ],
      },
      selectedAssetId: id,
      syncState: "queued",
      statusMessage: `Asset ${serial} saved locally and queued for synchronization.`,
    }));
    return id;
  },

  addBulkAssets: (count) => {
    const safeCount = Math.max(1, Math.min(1000, Math.floor(count)));
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "asset.create")) {
      set({ statusMessage: denial("asset.create") });
      return 0;
    }
    const batch = state.dataset.batches.find(
      (item) =>
        item.id === state.selectedBatchId && item.tenantId === session.tenantId,
    );
    if (!batch) return 0;
    const existing = state.dataset.assets.filter(
      (item) => item.batchId === batch.id,
    ).length;
    const created: GemstoneAsset[] = Array.from(
      { length: safeCount },
      (_, index) => {
        const serial = `${batch.reference}-BULK-${String(existing + index + 1).padStart(5, "0")}`;
        return {
          id: createAssetId(session.tenantId, serial),
          tenantId: session.tenantId,
          locationId: batch.locationId,
          batchId: batch.id,
          serial,
          status: "draft",
          material: "Natural gemstone",
          shape: "Unspecified",
          cut: "",
          colorDescription: "",
          clarityDescription: "",
          treatmentDisclosure: "Unknown / not declared",
          originClaim: "Not claimed",
          measurements: {
            weightCarats: null,
            lengthMm: null,
            widthMm: null,
            depthMm: null,
          },
          identifyingFeatures: [],
          supplierReference: "",
          laboratoryReportReference: "",
          evidenceIds: [],
          version: 1,
          createdAt: "2026-07-20T04:33:00Z",
          updatedAt: "2026-07-20T04:33:00Z",
          createdBy: session.userId,
        };
      },
    );
    const operations: SyncOperation[] = created.map((asset) => ({
      id: `sync_${stableHash(asset.id)}`,
      tenantId: session.tenantId,
      deviceId: session.deviceId,
      entityType: "asset",
      entityId: asset.id,
      operation: "create",
      expectedVersion: 0,
      payload: asset as unknown as Record<string, unknown>,
      status: "queued",
      attempts: 0,
      createdAt: asset.createdAt,
    }));
    set((current) => ({
      dataset: {
        ...current.dataset,
        assets: [...current.dataset.assets, ...created],
        batches: current.dataset.batches.map((item) =>
          item.id === batch.id
            ? {
                ...item,
                assetIds: [
                  ...item.assetIds,
                  ...created.map((asset) => asset.id),
                ],
                version: item.version + 1,
              }
            : item,
        ),
        syncOperations: [...current.dataset.syncOperations, ...operations],
        auditEvents: [
          ...current.dataset.auditEvents,
          audit(current, "assets.bulk-created-local", "batch", batch.id, {
            count: created.length,
            sync: "queued",
          }),
        ],
      },
      selectedAssetId: created[0]?.id ?? current.selectedAssetId,
      syncState: "queued",
      statusMessage: `${created.length} individually identified drafts created and queued. No lot quantity was expanded automatically.`,
    }));
    return created.length;
  },

  importCsvFile: async (file) => {
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "asset.create")) {
      set({ statusMessage: denial("asset.create") });
      return 0;
    }
    if (!state.online) {
      set({
        statusMessage:
          "CSV import requires a network connection because accepted rows are persisted by the tenant API.",
      });
      return 0;
    }
    const batch = state.dataset.batches.find(
      (item) =>
        item.id === state.selectedBatchId && item.tenantId === session.tenantId,
    );
    if (!batch) {
      set({ statusMessage: "Select an active batch before importing CSV." });
      return 0;
    }
    set({
      syncState: "syncing",
      statusMessage: `Validating and importing ${file.name}.`,
    });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/batches/${batch.id}/csv`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "text/csv"),
          body: await file.text(),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.rows
            ?.map(
              (item: { row: number; message: string }) =>
                `row ${item.row}: ${item.message}`,
            )
            .join(" | ") ??
            body.error?.message ??
            `CSV_HTTP_${response.status}`,
        );
      const assets = body.data as GemstoneAsset[];
      set((current) => ({
        dataset: {
          ...current.dataset,
          assets: [
            ...current.dataset.assets.filter(
              (item) => !assets.some((asset) => asset.id === item.id),
            ),
            ...assets,
          ],
          batches: current.dataset.batches.map((item) =>
            item.id === batch.id
              ? {
                  ...item,
                  assetIds: [
                    ...new Set([
                      ...item.assetIds,
                      ...assets.map((asset) => asset.id),
                    ]),
                  ],
                  version: item.version + 1,
                }
              : item,
          ),
        },
        syncState: "synced",
        selectedAssetId: assets[0]?.id ?? current.selectedAssetId,
        statusMessage: `${assets.length} explicit gemstone unit records imported and persisted. No lot quantity was expanded.`,
      }));
      return assets.length;
    } catch (error) {
      set({
        syncState: "error",
        statusMessage: `CSV import failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
      return 0;
    }
  },

  updateSelectedAsset: (patch) =>
    set((state) => {
      const session = activeSession(state);
      if (!can(session.role, "asset.edit"))
        return { ...state, statusMessage: denial("asset.edit") };
      const asset = state.dataset.assets.find(
        (item) =>
          item.id === state.selectedAssetId &&
          item.tenantId === session.tenantId,
      );
      if (!asset)
        return { ...state, statusMessage: "No tenant-scoped unit selected." };
      const updated = {
        ...asset,
        ...patch,
        measurements: patch.measurements
          ? { ...asset.measurements, ...patch.measurements }
          : asset.measurements,
        version: asset.version + 1,
        updatedAt: "2026-07-20T04:33:30Z",
      };
      const sync: SyncOperation = {
        id: `sync_update_${stableHash(`${asset.id}:${updated.version}`)}`,
        tenantId: session.tenantId,
        deviceId: session.deviceId,
        entityType: "asset",
        entityId: asset.id,
        operation: "update",
        expectedVersion: asset.version,
        payload: patch as Record<string, unknown>,
        status: "queued",
        attempts: 0,
        createdAt: updated.updatedAt,
      };
      return {
        dataset: {
          ...state.dataset,
          assets: state.dataset.assets.map((item) =>
            item.id === asset.id ? updated : item,
          ),
          syncOperations: [...state.dataset.syncOperations, sync],
          auditEvents: [
            ...state.dataset.auditEvents,
            audit(state, "asset.updated-local", "asset", asset.id, {
              version: updated.version,
              sync: "queued",
            }),
          ],
        },
        syncState: "queued",
        statusMessage: `Unit ${asset.serial} updated locally and queued.`,
      };
    }),

  addEvidence: (type, independent = false) =>
    set((state) => {
      const session = activeSession(state);
      if (!can(session.role, "evidence.manage"))
        return { ...state, statusMessage: denial("evidence.manage") };
      const asset = state.dataset.assets.find(
        (item) =>
          item.id === state.selectedAssetId &&
          item.tenantId === session.tenantId,
      );
      if (!asset)
        return { ...state, statusMessage: "No tenant-scoped unit selected." };
      const id = `ev_${type}_${stableHash(`${asset.id}:${state.dataset.evidence.length}`)}`;
      const evidence: EvidenceObject = {
        id,
        tenantId: session.tenantId,
        assetId: asset.id,
        type,
        label: `${type} evidence for ${asset.serial}`,
        sourceOrganization: independent
          ? "Independent qualified source"
          : state.dataset.tenants.find((item) => item.id === session.tenantId)!
              .displayName,
        sourceType: independent
          ? type === "laboratory"
            ? "laboratory"
            : "registry"
          : "operator",
        acquisitionMethod:
          type === "photo"
            ? "camera"
            : type === "laboratory"
              ? "upload"
              : "manual",
        issueDate: "2026-07-20T04:34:00Z",
        claimIds:
          type === "measurement"
            ? ["claim_identity", "claim_measurements"]
            : type === "laboratory"
              ? ["claim_origin", "claim_treatment"]
              : ["claim_identity"],
        independent,
        qualified: true,
        integrityHash: `sha256:${stableHash(`${asset.id}:${type}:${state.dataset.evidence.length}`)}`,
        storageKey: `tenants/${session.tenantId}/assets/${asset.id}/${id}`,
        visibility: independent ? "public-summary" : "reviewer",
        status: "active",
        createdAt: "2026-07-20T04:34:00Z",
        createdBy: session.userId,
      };
      const sync: SyncOperation = {
        id: `sync_evidence_${stableHash(id)}`,
        tenantId: session.tenantId,
        deviceId: session.deviceId,
        entityType: "evidence",
        entityId: id,
        operation: "create",
        expectedVersion: 0,
        payload: { evidence },
        status: "queued",
        attempts: 0,
        createdAt: evidence.createdAt,
      };
      return {
        dataset: {
          ...state.dataset,
          evidence: [...state.dataset.evidence, evidence],
          assets: state.dataset.assets.map((item) =>
            item.id === asset.id
              ? {
                  ...item,
                  evidenceIds: [...item.evidenceIds, id],
                  version: item.version + 1,
                  updatedAt: evidence.createdAt,
                }
              : item,
          ),
          syncOperations: [...state.dataset.syncOperations, sync],
          auditEvents: [
            ...state.dataset.auditEvents,
            audit(state, "evidence.created-local", "evidence", id, {
              assetId: asset.id,
              type,
              independent,
              sync: "queued",
            }),
          ],
        },
        syncState: "queued",
        statusMessage: `${type} evidence attached locally and queued for synchronization.`,
      };
    }),

  addEvidenceFile: async (file) => {
    const state = get();
    const session = activeSession(state);
    if (!can(session.role, "evidence.manage"))
      return set({ statusMessage: denial("evidence.manage") });
    const asset = state.dataset.assets.find(
      (item) =>
        item.id === state.selectedAssetId && item.tenantId === session.tenantId,
    );
    if (!asset)
      return set({ statusMessage: "No tenant-scoped unit selected." });
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type))
      return set({
        statusMessage: "Capture rejected. Use JPEG, PNG, or WebP evidence.",
      });
    if (file.size > 25 * 1024 * 1024)
      return set({
        statusMessage:
          "Capture rejected. The local evidence limit is 25 MB per image.",
      });
    set({
      syncState: "syncing",
      statusMessage: "Hashing and encrypting captured evidence on this device.",
    });
    try {
      const integrityHash = await sha256Blob(file);
      const id = `ev_photo_${stableHash(`${asset.id}:${integrityHash}`)}`;
      const localMediaKey = `tenant:${session.tenantId}:device:${session.deviceId}:media:${id}`;
      await saveOfflineMedia(localMediaKey, file);
      set((current) => {
        const evidence: EvidenceObject = {
          id,
          tenantId: session.tenantId,
          assetId: asset.id,
          type: "photo",
          label: file.name || `Captured image for ${asset.serial}`,
          sourceOrganization: current.dataset.tenants.find(
            (item) => item.id === session.tenantId,
          )!.displayName,
          sourceType: "operator",
          acquisitionMethod: "camera",
          issueDate: "2026-07-20T06:10:00Z",
          claimIds: ["claim_identity"],
          independent: false,
          qualified: true,
          integrityHash,
          storageKey: `offline://${localMediaKey}`,
          visibility: "reviewer",
          status: "active",
          createdAt: "2026-07-20T06:10:00Z",
          createdBy: session.userId,
        };
        const sync: SyncOperation = {
          id: `sync_media_${stableHash(id)}`,
          tenantId: session.tenantId,
          deviceId: session.deviceId,
          entityType: "evidence",
          entityId: id,
          operation: "create",
          expectedVersion: 0,
          payload: { evidence, localMediaKey },
          status: "queued",
          attempts: 0,
          createdAt: evidence.createdAt,
        };
        return {
          dataset: {
            ...current.dataset,
            evidence: [
              ...current.dataset.evidence.filter((item) => item.id !== id),
              evidence,
            ],
            assets: current.dataset.assets.map((item) =>
              item.id === asset.id
                ? {
                    ...item,
                    evidenceIds: [...new Set([...item.evidenceIds, id])],
                    version: item.version + 1,
                    updatedAt: evidence.createdAt,
                  }
                : item,
            ),
            syncOperations: [
              ...current.dataset.syncOperations.filter(
                (item) => item.id !== sync.id,
              ),
              sync,
            ],
            auditEvents: [
              ...current.dataset.auditEvents,
              audit(current, "evidence.captured-offline", "evidence", id, {
                assetId: asset.id,
                bytes: file.size,
                mime: file.type,
                integrityHash,
              }),
            ],
          },
          syncState: "queued",
          statusMessage: `Captured ${file.name || "image"} is encrypted locally and queued for media upload. It is fingerprint evidence, not laboratory authentication.`,
        };
      });
    } catch (error) {
      set({
        syncState: "error",
        statusMessage: `Capture could not be stored safely: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  validateSelectedBatch: () =>
    set((state) => {
      const session = activeSession(state);
      if (!can(session.role, "batch.edit"))
        return { ...state, statusMessage: denial("batch.edit") };
      const batch = state.dataset.batches.find(
        (item) =>
          item.id === state.selectedBatchId &&
          item.tenantId === session.tenantId,
      );
      if (!batch) return state;
      const issues = validateBatch(
        batch,
        state.dataset.assets,
        state.dataset.evidence,
      );
      const status = isBatchSubmittable(issues) ? "ready" : "blocked";
      const updated = {
        ...batch,
        validationErrors: issues,
        status,
        updatedAt: "2026-07-20T04:34:00Z",
        version: batch.version + 1,
      } as IntakeBatch;
      return {
        dataset: {
          ...state.dataset,
          batches: state.dataset.batches.map((item) =>
            item.id === batch.id ? updated : item,
          ),
          auditEvents: [
            ...state.dataset.auditEvents,
            audit(state, "batch.validated", "batch", batch.id, {
              status,
              issueCount: issues.length,
            }),
          ],
        },
        statusMessage: isBatchSubmittable(issues)
          ? "Batch validation passed."
          : `Batch blocked by ${issues.filter((item) => item.severity === "error").length} errors.`,
      };
    }),

  submitSelectedBatch: async () => {
    const state = get();
    const session = activeSession(state);
    if (
      !can(session.role, "batch.submit") ||
      !can(session.role, "attestation.sign")
    )
      return set({
        statusMessage:
          "Submission denied. Switch to an authorized attestor with batch.submit and attestation.sign.",
      });
    if (!state.online)
      return set({
        statusMessage:
          "Submission blocked while offline. Synchronize the complete batch before signing.",
      });
    const batch = state.dataset.batches.find(
      (item) =>
        item.id === state.selectedBatchId && item.tenantId === session.tenantId,
    );
    if (!batch) return;
    const relatedIds = new Set([
      batch.id,
      ...batch.assetIds,
      ...state.dataset.evidence
        .filter((item) => batch.assetIds.includes(item.assetId))
        .map((item) => item.id),
    ]);
    if (
      state.dataset.syncOperations.some(
        (item) => item.status === "queued" && relatedIds.has(item.entityId),
      )
    )
      return set({
        statusMessage:
          "Submission blocked. Synchronize all batch, unit, and evidence operations first.",
      });
    const issues = validateBatch(
      batch,
      state.dataset.assets,
      state.dataset.evidence,
    );
    if (!isBatchSubmittable(issues))
      return set({
        statusMessage:
          "Submission blocked. Resolve all validation errors first.",
      });
    set({
      syncState: "syncing",
      statusMessage:
        "Signing attestation and submitting the synchronized batch.",
    });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/batches/${batch.id}/submit`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({
            declarationAccepted: true,
            claimSummary:
              "Asset identity, measurements, treatment, and origin claims submitted for review.",
            evidenceSummary:
              "Evidence objects are linked at unit level and retain source, qualification, and integrity status.",
            limitations: [
              "Phone images are supporting fingerprint evidence and are not laboratory authentication.",
            ],
          }),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `SUBMISSION_HTTP_${response.status}`,
        );
      const reviewResponse = await authorityFetch("/api/v1/operations/review", {
        headers: authorizationHeaders(session),
      });
      const reviewBody = reviewResponse.ok
        ? await reviewResponse.json()
        : { data: state.dataset.reviewCases };
      set((current) => ({
        dataset: {
          ...current.dataset,
          attestations: [
            ...current.dataset.attestations.filter(
              (item) => item.id !== body.data.attestation.id,
            ),
            body.data.attestation,
          ],
          batches: current.dataset.batches.map((item) =>
            item.id === batch.id ? body.data.batch : item,
          ),
          assets: current.dataset.assets.map((item) =>
            item.batchId === batch.id
              ? { ...item, status: "submitted" as const }
              : item,
          ),
          reviewCases: reviewBody.data,
        },
        syncState: "synced",
        statusMessage: `Batch ${batch.reference} signed and submitted through the canonical operations API.`,
      }));
    } catch (error) {
      set({
        syncState: "error",
        statusMessage: `Submission failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  setOnline: (online) =>
    set((state) => ({
      online,
      syncState: online
        ? state.dataset.syncOperations.some((item) => item.status === "queued")
          ? "queued"
          : "synced"
        : "queued",
      statusMessage: online
        ? "Network restored. Queued operations can synchronize."
        : "Offline mode active. New work remains local until synchronization.",
    })),

  flushSyncQueue: async () => {
    const state = get();
    const session = activeSession(state);
    const environment = getPublicEnvironment();
    if (!state.online)
      return set({
        syncState: "queued",
        statusMessage: "Synchronization paused because the device is offline.",
      });
    const queued = state.dataset.syncOperations.filter(
      (item) => item.status === "queued",
    );
    const uploadPending = queued.filter(
      (item) =>
        item.entityType === "evidence" &&
        String(item.payload.localMediaKey ?? "").length > 0,
    );
    const uploadPendingIds = new Set(uploadPending.map((item) => item.id));
    const sendable = queued.filter((item) => !uploadPendingIds.has(item.id));
    await saveOfflineSnapshot(
      `tenant:${session.tenantId}:device:${session.deviceId}`,
      state.dataset,
    ).catch(() => undefined);

    const mediaOperations = new Map<string, SyncOperation>();
    const canonicalEvidence = new Map<string, EvidenceObject>();
    let mediaApplied = 0;
    let mediaFailed = 0;

    if (uploadPending.length && environment !== "sandbox") {
      set({
        syncState: "syncing",
        statusMessage: `Uploading ${uploadPending.length} encrypted evidence file${uploadPending.length === 1 ? "" : "s"} into immutable custody.`,
      });
      for (const operation of uploadPending) {
        const localMediaKey = String(operation.payload.localMediaKey ?? "");
        const evidence = operation.payload.evidence as EvidenceObject | undefined;
        try {
          if (!evidence || evidence.id !== operation.entityId)
            throw new Error("INVALID_EVIDENCE_PAYLOAD");
          const file = await loadOfflineMedia(localMediaKey);
          if (!file) throw new Error("OFFLINE_MEDIA_NOT_FOUND");
          const form = new FormData();
          form.set("assetId", evidence.assetId);
          form.set("file", file, file.name);
          const uploadResponse = await authorityFetch("/api/v1/authority/evidence/upload", {
            method: "POST",
            headers: authorizationHeaders(session),
            body: form,
          });
          const uploadBody = await uploadResponse.json();
          if (!uploadResponse.ok || !uploadBody.data?.storageKey)
            throw new Error(
              uploadBody.error?.message ?? `EVIDENCE_UPLOAD_HTTP_${uploadResponse.status}`,
            );
          const canonicalRequest = {
            ...evidence,
            storageKey: uploadBody.data.storageKey,
            integrityHash: uploadBody.data.integrityHash,
            scanReceiptId: uploadBody.data.scanReceiptId,
            scanStatus: uploadBody.data.scanStatus,
            issueDate: new Date().toISOString(),
            location: `device:${session.deviceId}`,
          };
          const evidenceResponse = await authorityFetch(
            `/api/v1/operations/assets/${encodeURIComponent(evidence.assetId)}/evidence`,
            {
              method: "POST",
              headers: authorizationHeaders(session, "application/json"),
              body: JSON.stringify(canonicalRequest),
            },
          );
          const evidenceBody = await evidenceResponse.json();
          if (!evidenceResponse.ok || !evidenceBody.data?.id)
            throw new Error(
              evidenceBody.error?.message ?? `EVIDENCE_CUSTODY_HTTP_${evidenceResponse.status}`,
            );
          const canonical = evidenceBody.data as EvidenceObject;
          canonicalEvidence.set(evidence.id, canonical);
          mediaOperations.set(operation.id, {
            ...operation,
            status: "applied",
            attempts: operation.attempts + 1,
            lastAttemptAt: new Date().toISOString(),
            error: undefined,
            payload: { evidence: canonical },
          });
          await clearOfflineMedia(localMediaKey).catch(() => undefined);
          mediaApplied += 1;
        } catch (error) {
          mediaOperations.set(operation.id, {
            ...operation,
            status: "failed",
            attempts: operation.attempts + 1,
            lastAttemptAt: new Date().toISOString(),
            error: error instanceof Error ? error.message : "MEDIA_UPLOAD_FAILED",
          });
          mediaFailed += 1;
        }
      }
    }

    if (!sendable.length) {
      return set((current) => ({
        dataset: {
          ...current.dataset,
          evidence: current.dataset.evidence.map(
            (item) => canonicalEvidence.get(item.id) ?? item,
          ),
          syncOperations: current.dataset.syncOperations.map(
            (item) => mediaOperations.get(item.id) ?? item,
          ),
        },
        syncState:
          environment === "sandbox" && uploadPending.length
            ? "queued"
            : mediaFailed
              ? "error"
              : "synced",
        statusMessage:
          environment === "sandbox" && uploadPending.length
            ? `${uploadPending.length} encrypted media file${uploadPending.length === 1 ? "" : "s"} remain isolated in deterministic Sandbox storage.`
            : mediaFailed
              ? `${mediaFailed} evidence upload${mediaFailed === 1 ? "" : "s"} failed closed; no custody record was asserted.`
              : mediaApplied
                ? `${mediaApplied} evidence file${mediaApplied === 1 ? "" : "s"} entered immutable custody with scanner and eligibility receipts.`
                : "No queued operations remain.",
      }));
    }

    set({
      syncState: "syncing",
      statusMessage: `Synchronizing ${sendable.length} queued structured operation${sendable.length === 1 ? "" : "s"} in bounded chunks.`,
    });
    try {
      const byId = new Map<string, SyncOperation>(mediaOperations);
      let conflicts = 0;
      let failed = mediaFailed;
      let applied = mediaApplied;
      const chunkSize = 500;
      for (let start = 0; start < sendable.length; start += chunkSize) {
        const operations = sendable.slice(start, start + chunkSize);
        const response = await authorityFetch("/api/v1/operations/sync", {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({ operations }),
        });
        const body = await response.json();
        if (!Array.isArray(body.data))
          throw new Error(
            body.error?.message ?? `SYNC_HTTP_${response.status}`,
          );
        for (const item of body.data as Array<{ operation: SyncOperation }>)
          byId.set(item.operation.id, item.operation);
        conflicts += body.meta?.conflicts ?? 0;
        failed += body.meta?.failed ?? 0;
        applied += body.meta?.applied ?? 0;
      }
      set((current) => ({
        dataset: {
          ...current.dataset,
          evidence: current.dataset.evidence.map(
            (item) => canonicalEvidence.get(item.id) ?? item,
          ),
          syncOperations: current.dataset.syncOperations.map(
            (item) => byId.get(item.id) ?? item,
          ),
        },
        syncState: conflicts ? "conflict" : failed ? "error" : "synced",
        statusMessage: conflicts
          ? `${conflicts} synchronization conflict${conflicts === 1 ? "" : "s"} require resolution.`
          : failed
            ? `${failed} operation${failed === 1 ? "" : "s"} failed closed and remain attributable.`
            : `${applied} operation${applied === 1 ? "" : "s"} synchronized through the ${environment} authority adapter.`,
      }));
    } catch (error) {
      set({
        syncState: "error",
        statusMessage: `Synchronization failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  selectReviewCase: (selectedReviewCaseId) =>
    set({
      selectedReviewCaseId,
      statusMessage: `Review case ${selectedReviewCaseId} selected.`,
    }),

  reviewAction: async (action) => {
    const state = get();
    const session = activeSession(state);
    const review = state.dataset.reviewCases.find(
      (item) =>
        item.id === state.selectedReviewCaseId &&
        item.tenantId === session.tenantId,
    );
    if (!review)
      return set({
        statusMessage: "Review case not found in the active tenant.",
      });
    if (
      (action === "primary-approve" ||
        action === "secondary-approve" ||
        action === "reject") &&
      !can(session.role, "review.decide")
    )
      return set({ statusMessage: denial("review.decide") });
    if (
      action === "secondary-approve" &&
      !can(session.role, "review.approve-tier4")
    )
      return set({ statusMessage: denial("review.approve-tier4") });
    if (action === "custos-pass" && !can(session.role, "custos.decide"))
      return set({ statusMessage: denial("custos.decide") });
    if (
      action === "authorize-signing" &&
      !can(session.role, "credential.issue")
    )
      return set({ statusMessage: denial("credential.issue") });
    if (
      (action === "authorize-signing" ||
        action === "publish-registry" ||
        action === "enable-revocation-control") &&
      !can(session.role, "credential.issue")
    )
      return set({ statusMessage: denial("credential.issue") });
    if (action === "authorize-mark" && !can(session.role, "mark.authorize"))
      return set({ statusMessage: denial("mark.authorize") });
    const role = action === "secondary-approve" ? "secondary" : "primary";
    const otherApproval = review.approvals.find(
      (approval) => approval.role !== role && approval.decision === "approve",
    );
    if (
      (action === "primary-approve" || action === "secondary-approve") &&
      otherApproval?.reviewerId === session.userId
    )
      return set({
        statusMessage:
          "Tier 4 approvals must come from distinct reviewers. Switch to another authorized reviewer.",
      });
    const actionMap = {
      "primary-approve": "review",
      "secondary-approve": "review",
      "custos-pass": "custos-pass",
      "authorize-signing": "authorize-signing",
      "publish-registry": "publish-registry",
      "enable-revocation-control": "enable-revocation-control",
      "authorize-mark": "authorize-mark",
      reject: "review",
    } as const;
    const payload = {
      reviewerId: session.userId,
      role,
      decision:
        action === "reject"
          ? "reject"
          : action === "primary-approve" || action === "secondary-approve"
            ? "approve"
            : "pending",
      independent: true,
      conflictFree: true,
      reasonCodes: [
        action === "reject"
          ? "PV_REVIEW_REJECTED"
          : `PV_${action.toUpperCase().replaceAll("-", "_")}`,
      ],
      action: actionMap[action],
    };
    set({ statusMessage: `Applying ${action} through the authority API.` });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/review/${review.id}/decision`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify(payload),
        },
      );
      const result = await response.json();
      if (!response.ok)
        throw new Error(
          result.error?.message ?? `REVIEW_HTTP_${response.status}`,
        );
      const updated = result.data as ReviewCase;
      set((current) => ({
        dataset: {
          ...current.dataset,
          reviewCases: current.dataset.reviewCases.map((item) =>
            item.id === updated.id ? updated : item,
          ),
          assets: current.dataset.assets.map((item) =>
            item.id === updated.assetId
              ? {
                  ...item,
                  status:
                    updated.credential?.status === "issued"
                      ? "issued"
                      : updated.status === "rejected"
                        ? "blocked"
                        : "in-review",
                }
              : item,
          ),
        },
        statusMessage: `Review action ${action} accepted. Authority status: ${updated.credential?.authorization.status ?? updated.status}.`,
      }));
    } catch (error) {
      set({
        statusMessage: `Review action failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  lifecycleAction: async (action, reason, successorId) => {
    const state = get();
    const session = activeSession(state);
    const review = state.dataset.reviewCases.find(
      (item) =>
        item.id === state.selectedReviewCaseId &&
        item.tenantId === session.tenantId,
    );
    if (!review)
      return set({
        statusMessage: "Select a tenant-scoped review case first.",
      });
    if (!can(session.role, "credential.lifecycle"))
      return set({ statusMessage: denial("credential.lifecycle") });
    set({ statusMessage: `Applying credential lifecycle action: ${action}.` });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/review/${review.id}/lifecycle`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({ action, reason, successorId }),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `LIFECYCLE_HTTP_${response.status}`,
        );
      const updated = body.data as ReviewCase;
      set((current) => ({
        dataset: {
          ...current.dataset,
          reviewCases: current.dataset.reviewCases.map((item) =>
            item.id === updated.id ? updated : item,
          ),
        },
        statusMessage: `Credential lifecycle is now ${updated.credentialLifecycle}. Mark use is ${updated.credential?.sealAuthorization.status ?? "withheld"}.`,
      }));
    } catch (error) {
      set({
        statusMessage: `Lifecycle action failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  requestCorrection: async (reason, fields) => {
    const state = get();
    const session = activeSession(state);
    const review = state.dataset.reviewCases.find(
      (item) =>
        item.id === state.selectedReviewCaseId &&
        item.tenantId === session.tenantId,
    );
    if (!review)
      return set({
        statusMessage: "Select a tenant-scoped review case first.",
      });
    if (!can(session.role, "correction.request"))
      return set({ statusMessage: denial("correction.request") });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/review/${review.id}/corrections`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({ action: "request", reason, fields }),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `CORRECTION_HTTP_${response.status}`,
        );
      const updated = body.data as ReviewCase;
      set((current) => ({
        dataset: {
          ...current.dataset,
          reviewCases: current.dataset.reviewCases.map((item) =>
            item.id === updated.id ? updated : item,
          ),
        },
        statusMessage: `Correction v${updated.corrections.at(-1)?.version} opened. Issuance and mark authority are blocked until resolution and re-review.`,
      }));
    } catch (error) {
      set({
        statusMessage: `Correction request failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  resolveCorrection: async (correctionId, resolution) => {
    const state = get();
    const session = activeSession(state);
    const review = state.dataset.reviewCases.find(
      (item) =>
        item.id === state.selectedReviewCaseId &&
        item.tenantId === session.tenantId,
    );
    if (!review)
      return set({
        statusMessage: "Select a tenant-scoped review case first.",
      });
    if (!can(session.role, "correction.resolve"))
      return set({ statusMessage: denial("correction.resolve") });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/review/${review.id}/corrections`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({
            action: "resolve",
            correctionId,
            resolution,
            claimSummary:
              "Corrected asset identity, measurement, treatment, origin, transfer, and custody claims resubmitted for independent review.",
            evidenceSummary:
              "Corrected evidence set retains immutable prior versions, source identity, claim correspondence, and integrity hashes.",
            limitations: [
              "Correction resolution invalidates prior approvals and requires a complete new authority sequence.",
            ],
          }),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `CORRECTION_HTTP_${response.status}`,
        );
      await get().hydrateSession();
      set({
        statusMessage: `Correction resolved with a new immutable attestation. All prior authority approvals were reset.`,
      });
    } catch (error) {
      set({
        statusMessage: `Correction resolution failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },

  rejectCorrection: async (correctionId, resolution) => {
    const state = get();
    const session = activeSession(state);
    const review = state.dataset.reviewCases.find(
      (item) =>
        item.id === state.selectedReviewCaseId &&
        item.tenantId === session.tenantId,
    );
    if (!review)
      return set({
        statusMessage: "Select a tenant-scoped review case first.",
      });
    if (!can(session.role, "correction.resolve"))
      return set({ statusMessage: denial("correction.resolve") });
    try {
      const response = await authorityFetch(
        `/api/v1/operations/review/${review.id}/corrections`,
        {
          method: "POST",
          headers: authorizationHeaders(session, "application/json"),
          body: JSON.stringify({ action: "reject", correctionId, resolution }),
        },
      );
      const body = await response.json();
      if (!response.ok)
        throw new Error(
          body.error?.message ?? `CORRECTION_HTTP_${response.status}`,
        );
      const updated = body.data as ReviewCase;
      set((current) => ({
        dataset: {
          ...current.dataset,
          reviewCases: current.dataset.reviewCases.map((item) =>
            item.id === updated.id ? updated : item,
          ),
        },
        statusMessage:
          "Correction request rejected with an immutable decision receipt.",
      }));
    } catch (error) {
      set({
        statusMessage: `Correction rejection failed: ${error instanceof Error ? error.message : "UNKNOWN_ERROR"}`,
      });
    }
  },
}));
