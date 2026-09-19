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

The proven PV primary wake route is the **persistent Code session's native notification inbox**, not a repository-local router and not a requirement that the worker expose a separate `subscribe_pr_activity` API call.

Observed runtime pattern:

```text
BOUND PR ACTIVITY
  -> SAME PERSISTENT CODE SESSION RECEIVES NATIVE NOTIFICATION
  -> ReadNotifications
  -> SESSION RECONCILES THE BOUND PR TIMELINE / NEW CTO ORDER / CI OR REVIEW EVENT
  -> COLD-RESOLVE CURRENT PR #17 AUTHORITY + EXACT LANE SHA
  -> EXECUTE CURRENT VALID IN-LANE WORK
  -> POST EXACT EVIDENCE
  -> ReadNotifications / REMAIN ARMED FOR THE NEXT EVENT
```

A notification may be only an echo or signal. The worker must drain it, reconcile the PR timeline, deduplicate already-processed event IDs/SHAs, and act only when a new material event or valid work order exists. The notification itself is transport, never mission authority.

The GitHub Actions router is fallback-only plumbing. Do not make it the primary wake mechanism while the persistent Code-session notification route is functioning. Do not install/register a self-hosted runner, custom webhook bridge, polling daemon, or duplicate control plane merely for continuity.

A lane is wake-proven only when PR activity reaches the same persistent Code session without a manual user message to that session, and that session drains/reconciles the event and continues. Proof does **not** require a separately exposed `subscribe_pr_activity` tool.

On session replacement: bind the successor persistent Code session to the same PR/branch and notification route, cold-resolve live state, prove autonomous notification pickup, continue the existing package, and keep one mutation seat per lane. Never run old and successor mutation sessions concurrently on the same lane.


## Native notification drain protocol

On every autonomous wake or `ReadNotifications` event:

1. Drain the persistent Code session's native notifications.
2. Fetch/reconcile the bound lane PR's current timeline, comments, reviews, checks, and head movement newer than the last processed event.
3. Treat the newest valid CTO work order or material producer/verifier evidence on that bound lane as the actionable payload; an echo-only notification is NO_MATERIAL_ACTION.
4. Cold-resolve current PR #17 authority and exact lane SHA before mutation or acceptance.
5. Deduplicate by comment/review/run ID plus exact head SHA.
6. Execute every currently authorized dependency-ready in-lane action; do not require a manual user prompt merely because the notification omitted the message body.
7. Post exact result/evidence and continue draining/re-arm the same persistent session.
8. Stop only at a reserved-human gate, genuinely ambiguous authority, exhausted package, or sole inaccessible external dependency after all other work is exhausted.
