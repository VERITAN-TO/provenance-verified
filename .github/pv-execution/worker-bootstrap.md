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



## Single Active Route Mutex

PV preserves both Route 1 and the previously built Route 2 artifacts, but only one execution route may be active at a time.

Current binding:

```text
ACTIVE_ROUTE = ROUTE_1
ROUTE_1 = ACTIVE
ROUTE_2 = DORMANT_RECOVERY_ONLY
OVERLAP_ALLOWED = NO
```

Route 1 is the existing persistent Code-session notification loop:

```text
WAKE / SAME-SESSION CHECK-IN
→ ReadNotifications
→ reconcile bound PR/timeline
→ cold-resolve authority + exact SHA
→ execute
→ post evidence
→ ReadNotifications
→ re-arm same session
```

Route 2 artifacts are preserved for disaster recovery but may not automatically wake, dispatch, or mutate while Route 1 is active. If an old Route-2 explicit PR subscription still exists, disable/unsubscribe it when the current session tooling supports that safely. If it cannot be disabled, its events are transport noise only: deduplicate them and perform NO second execution.

A route switch requires an explicit CTO route-switch order and must stop the old route before the new route receives mutation authority. Never run Route 1 and Route 2 concurrently for the same lane.

One lane = one active persistent mutation/verifier seat = one active execution route.


## Route 1 — Persistent Code Session Notification Loop

This is the primary PV execution route.

It is the proven pre-September-17 continuity pattern observed in the live Lead sessions:

```text
EXISTING PERSISTENT CODE SESSION
        ↓
NATIVE SESSION NOTIFICATION INBOX
        ↓
ReadNotifications
        ↓
BOUND PR / CTO ORDER / CI EVENT DISCOVERED
        ↓
COLD-RESOLVE PR #17 + CURRENT LANE SHA
        ↓
EXECUTE CURRENT AUTHORIZED PACKAGE
        ↓
POST RESULT / CUSTOS EVIDENCE
        ↓
ReadNotifications AGAIN
        ↓
RE-ARM SAME-SESSION SCHEDULED CHECK-IN
        ↓
CONTINUE
```

### Route-1 laws

- The existing persistent Code session is the execution seat.
- The session's native notification inbox is the primary event intake.
- `ReadNotifications` is the normal notification-drain operation.
- GitHub PR activity, CTO comments, CI/check results, and evidence returns may surface through that inbox.
- The session resolves the bound PR timeline and current authority after notification receipt; notification text itself is not authority.
- The same session continues after each result. Do not replace it merely because one package completed.
- The same-session scheduled trigger/check-in is the continuity backstop and may also wake the session to drain notifications.
- A separately exposed `subscribe_pr_activity` primitive is optional implementation detail, not a prerequisite for Route 1 and not the definition of liveness.
- A GitHub Actions router, webhook relay, polling daemon, or duplicate session is not the primary Route-1 mechanism.
- Do not create a replacement lane while the current persistent seat remains usable.
- On usage/session exhaustion, a successor inherits the same lane/PR/branch and must reproduce this same notification-loop behavior before taking mutation authority.

### Route-1 wake handling

On each session wake:

1. Run/read the session notification inbox first.
2. Drain all pending notifications.
3. Identify the newest material event for the bound lane.
4. Fetch/reconcile the bound PR timeline if the notification is only an echo or summary.
5. Cold-resolve PR #17 authority and the exact current lane SHA.
6. Reconcile current work order against live state.
7. Execute all dependency-ready in-lane work.
8. Post exact result/evidence and route verifier evidence to CUSTOS where applicable.
9. Drain notifications again before declaring the turn exhausted.
10. Re-arm the same-session scheduled trigger/check-in.
11. Remain in the same lane and continue on the next wake.

### Route-1 blocker law

A notification echo, CI runner loss, proxy block, dependency-install failure, moved SHA, or stale order is not by itself a reason to abandon the session.

The session must:

```text
READ NOTIFICATIONS
→ RECONCILE LIVE STATE
→ SOLVE / REBIND / ROUTE AROUND
→ CONTINUE OTHER ELIGIBLE WORK
→ POST EVIDENCE
→ RE-ARM SAME SESSION
```

Only a reserved-human gate, genuinely inaccessible external surface after exhaustion, contradictory authority, or exhausted package may terminate active execution.

### Do not substitute the September-17 subscription-first route

The later pattern:

```text
attach successor
→ create/verify explicit PR subscription
→ prove subscription
→ use subscription as liveness definition
```

is not the primary PV Route 1.

It may exist as incidental transport support, but it must not displace the proven persistent-session notification loop or force replacement of a working Route-1 seat.

### Session-end zero-drift handoff

A worker approaching usage exhaustion must post a durable handoff to its existing lane PR with current authority SHA, lane SHA, work order, completed evidence, open defects, CUSTOS state, next executable action, and whether the same-session notification/check-in loop remains armed.

A successor is replacement compute for the same lane, not a new lane or mission.

