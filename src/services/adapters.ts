import { getAuthorityRuntimeConfig } from '@/authority/config';
import { getOperationalRepository } from '@/operations/runtime';
import { DeterministicProvenanceService } from './deterministic';
import { RemoteProvenanceService } from './remote';

export class SandboxProvenanceAdapter extends DeterministicProvenanceService {
  constructor() { super(getOperationalRepository()); }
}

export class PilotProvenanceAdapter extends RemoteProvenanceService {
  constructor() { super({ environment: 'pilot', authoritative: false }); }
}

export class ProductionProvenanceAdapter extends RemoteProvenanceService {
  constructor() {
    const config = getAuthorityRuntimeConfig();
    if (!config.authoritative) throw new Error('PRODUCTION_ACTIVATION_INCOMPLETE');
    super({ environment: 'production', authoritative: true });
  }
}
