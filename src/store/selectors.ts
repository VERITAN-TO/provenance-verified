import type { Credential, EvidenceItem, ClaimRecord, SignedEvent, WebhookAttempt } from '@/domain/types';

export function selectClaimScope(credential: Credential) {
  return credential.claims.reduce<Record<string, number>>((acc, claim) => { acc[claim.status] = (acc[claim.status] ?? 0) + 1; return acc; }, {});
}
export function selectSelectedEvidence(evidence: EvidenceItem[], id: string | null) { return evidence.find((item) => item.id === id) ?? null; }
export function selectSelectedClaim(claims: ClaimRecord[], id: string | null) { return claims.find((item) => item.id === id) ?? null; }
export function selectEventTranscript(events: SignedEvent[]) { return events.map((event) => `${event.sequence}. ${event.type} at ${event.at}`).join('\n'); }
export function selectWebhookSummary(attempts: WebhookAttempt[]) { return { delivered: attempts.filter((a) => a.status === 'delivered').length, failed: attempts.filter((a) => a.status === 'failed').length, waiting: attempts.filter((a) => a.status === 'waiting').length }; }
