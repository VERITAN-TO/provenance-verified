import { operationalDataset } from '@/operations/fixtures';
import { OperationalRepository } from '@/operations/repository';
import type { OperationalDataset } from '@/operations/types';

declare global { var __pvOperationalRepository: OperationalRepository | undefined; }
const KEY = 'provenance-verified-standalone-r6-dataset';
function load(): OperationalDataset {
  try {
    const stored = globalThis.localStorage?.getItem(KEY);
    return stored ? JSON.parse(stored) as OperationalDataset : structuredClone(operationalDataset);
  } catch { return structuredClone(operationalDataset); }
}
function persist(dataset: OperationalDataset) {
  try { globalThis.localStorage?.setItem(KEY, JSON.stringify(dataset)); } catch { /* private mode */ }
}
export function getOperationalRepository(): OperationalRepository {
  if (!globalThis.__pvOperationalRepository) globalThis.__pvOperationalRepository = new OperationalRepository(load(), persist);
  return globalThis.__pvOperationalRepository;
}
export function resetOperationalRepositoryForTests(): void {
  globalThis.__pvOperationalRepository = new OperationalRepository(structuredClone(operationalDataset), persist);
  try { globalThis.localStorage?.removeItem(KEY); } catch { /* private mode */ }
}
