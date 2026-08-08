import fs from 'node:fs';
import path from 'node:path';
import { operationalDataset } from './fixtures';
import { OperationalRepository } from './repository';
import type { OperationalDataset } from './types';

declare global {
  var __pvOperationalRepository: OperationalRepository | undefined;
}

function persistencePath(): string {
  return process.env.PV_OPERATION_DATA_FILE
    ?? path.join(process.cwd(), '.data', 'provenance-operations-test-mode.json');
}

function loadDataset(filePath: string): OperationalDataset {
  if (process.env.NODE_ENV === 'test' || process.env.PV_OPERATION_PERSISTENCE === 'memory') {
    return operationalDataset;
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8')) as OperationalDataset;
  } catch {
    return operationalDataset;
  }
}

function atomicPersist(filePath: string, dataset: OperationalDataset): void {
  if (process.env.NODE_ENV === 'test' || process.env.PV_OPERATION_PERSISTENCE === 'memory') return;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const temporary = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(dataset, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(temporary, filePath);
}

export function getOperationalRepository(): OperationalRepository {
  if (!globalThis.__pvOperationalRepository) {
    const filePath = persistencePath();
    globalThis.__pvOperationalRepository = new OperationalRepository(
      loadDataset(filePath),
      (dataset) => atomicPersist(filePath, dataset),
    );
  }
  return globalThis.__pvOperationalRepository;
}

export function resetOperationalRepositoryForTests(): void {
  globalThis.__pvOperationalRepository = undefined;
}
