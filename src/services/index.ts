import { getAuthorityRuntimeConfig } from '@/authority/config';
import type { ProvenanceService } from './contract';
import { PilotProvenanceAdapter, ProductionProvenanceAdapter, SandboxProvenanceAdapter } from './adapters';

export function getProvenanceService(): ProvenanceService {
  const config = getAuthorityRuntimeConfig();
  if (config.environment === 'sandbox') return new SandboxProvenanceAdapter();
  if (config.environment === 'pilot') return new PilotProvenanceAdapter();
  return new ProductionProvenanceAdapter();
}

export { SandboxProvenanceAdapter, PilotProvenanceAdapter, ProductionProvenanceAdapter } from './adapters';
export type { ProvenanceService } from './contract';
