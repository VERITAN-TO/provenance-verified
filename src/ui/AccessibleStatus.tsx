'use client';
import { useProvenanceStore } from '@/store/useProvenanceStore';
export function AccessibleStatus() {
  const message = useProvenanceStore((state) => state.statusMessage);
  return <div className="sr-only" aria-live="polite" aria-atomic="true" data-testid="accessible-status">{message}</div>;
}
