# PV Execution Worker Bootstrap

This file defines runtime continuity rules for replacement Code-agent workers. It does not create mission authority, alter the Mission 2 roadmap, or replace CUSTOS.

## Governing authority

- Mission authority remains private PR #17.
- A/B/C/D keep their existing PRs and branches.
- A trigger is only a wake signal. It is never authority.
- Every wake starts by cold-resolving the current PR head and current authority.
- A historical SHA in a prompt is a hint only.

## Worker lifecycle

On every routed event:

1. Resolve the current lane PR, branch, head SHA, latest CTO order, latest lane return, CI/check state, and relevant CUSTOS receipt.
2. Classify the event as NO_MATERIAL_ACTION, IMPLEMENTATION_REQUIRED, TEST_REQUIRED, CI_REPAIR_REQUIRED, CUSTOS_RESPONSE_REQUIRED, CTO_DECISION_REQUIRED, or EXTERNAL_GATE.
3. Preserve current valid evidence. Invalidate only evidence actually made stale by head movement.
4. Continue the existing lane package. Do not create a new PR, branch, roadmap, authority, trust model, or duplicate permanent Lead.
5. Execute reversible/non-production work within the lane's existing authority.
6. Post exact evidence: current SHA, artifact/test/runtime result, limitations, and next executable action.
7. Do not treat ORDERED, ACTIVE, ROUTED, or COMMENTED as execution.

## Producer boundaries

A/B/C may implement and test on their existing lane branches. They must not merge, deploy production, mutate production DB/data/config, use live money, sign/issue, activate registry/marks/Gold Seal, regenerate keys/certs, submit to stores/TestFlight, or spend without reserved authority.

## CUSTOS boundary

D is an independent verifier. D may inspect, test, and post verdict/evidence receipts but must not implement producer code or self-manufacture producer evidence.

## Executor replacement

Old sessions do not regain mutation authority merely because their usage limit resets. The currently configured worker credential is the active executor for the lane until the CTO explicitly changes it.


## Trigger architecture

The primary wake mechanism is the replacement persistent Code-agent session's native subscription to its existing PR. The GitHub Actions router is fallback plumbing only and is not required for normal lane continuity while hosted-runner capacity is unavailable.

Do not install or register a self-hosted GitHub Actions runner merely to preserve agent continuity. A self-hosted runner changes the infrastructure/security boundary and requires a separate explicit infrastructure decision.

A lane is trigger-proven only after a new PR event autonomously wakes the subscribed successor session without a manual message to that session. Attachment alone is not proof.

On session replacement: attach to the same PR/branch, subscribe natively to PR activity, cold-resolve live state, prove one autonomous wake, then continue the existing package. Never run old and successor mutation sessions concurrently on the same lane.
