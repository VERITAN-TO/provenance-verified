import type { IdentityStateName } from './contracts';
import type { LifecycleState } from '@/domain/types';

type RunState = 'idle' | 'running' | 'complete' | 'error';
interface IdentityStateInput { stageIndex: number; runState: RunState; lifecycle: LifecycleState; issuanceStatus: string; blockers: string[]; }
const stageStates: IdentityStateName[] = ['observe', 'attest', 'prove', 'policy', 'approve', 'verify', 'secure'];
export function resolveIdentityState(input: IdentityStateInput): IdentityStateName {
  if (input.lifecycle === 'revoked') return 'revoked';
  if (input.runState === 'error') return 'failed';
  if (input.blockers.some((blocker) => /conflict|custos/i.test(blocker))) return 'exception';
  if (input.stageIndex >= 4 && input.issuanceStatus !== 'authorized') return 'pending';
  return stageStates[Math.max(0, Math.min(stageStates.length - 1, input.stageIndex))];
}
