import { stableHash } from '@/domain/hash';
import type { CredentialLifecycleAction, CredentialLifecycleEvent, ReviewCase } from './types';
import { createOperationalEventReceipt } from './kernel';

const allowedTransitions: Record<CredentialLifecycleAction, Array<ReviewCase['credentialLifecycle']>> = {
  suspend: ['active'],
  reactivate: ['suspended'],
  revoke: ['active', 'suspended'],
  supersede: ['active', 'suspended'],
  expire: ['active', 'suspended'],
};

const targetState: Record<CredentialLifecycleAction, ReviewCase['credentialLifecycle']> = {
  suspend: 'suspended',
  reactivate: 'active',
  revoke: 'revoked',
  supersede: 'superseded',
  expire: 'expired',
};

const receiptType: Record<CredentialLifecycleAction, Parameters<typeof createOperationalEventReceipt>[1]> = {
  suspend: 'credential.suspended',
  reactivate: 'credential.reactivated',
  revoke: 'credential.revoked',
  supersede: 'credential.superseded',
  expire: 'credential.expired',
};

export interface LifecycleTransitionInput {
  action: CredentialLifecycleAction;
  reason: string;
  actorId: string;
  at: string;
  successorId?: string;
}

export function applyCredentialLifecycleTransition(review: ReviewCase, input: LifecycleTransitionInput): ReviewCase {
  if (review.credential?.status !== 'issued') throw new Error('ISSUED_CREDENTIAL_REQUIRED');
  if (!review.registryPublication || review.registryStatus !== 'ready') throw new Error('REGISTRY_PUBLICATION_REQUIRED');
  if (!review.revocationCapability) throw new Error('REVOCATION_CONTROL_REQUIRED');
  if (!allowedTransitions[input.action].includes(review.credentialLifecycle)) throw new Error(`INVALID_LIFECYCLE_TRANSITION:${review.credentialLifecycle}:${input.action}`);
  if (input.action === 'supersede' && !input.successorId) throw new Error('SUCCESSOR_ID_REQUIRED');

  const updated = structuredClone(review);
  const from = updated.credentialLifecycle;
  const to = targetState[input.action];
  const receipt = createOperationalEventReceipt(updated.eventReceipts, receiptType[input.action], updated.registryId, input.actorId, input.at);
  updated.eventReceipts = [...updated.eventReceipts, receipt];
  updated.credentialLifecycle = to;
  updated.successorId = input.action === 'supersede' ? input.successorId : undefined;

  if (to !== 'active') {
    updated.markAuthorization = 'denied';
  } else {
    // Reactivation restores credential visibility, but never silently restores mark use.
    updated.markAuthorization = 'pending';
  }

  const event: CredentialLifecycleEvent = {
    id: `lifecycle_${stableHash(`${updated.id}:${input.action}:${input.at}:${receipt.id}`)}`,
    action: input.action,
    from,
    to,
    reason: input.reason,
    actorId: input.actorId,
    at: input.at,
    successorId: input.successorId,
    receiptId: receipt.id,
  };
  updated.lifecycleEvents = [...updated.lifecycleEvents, event];
  updated.updatedAt = input.at;
  return updated;
}
