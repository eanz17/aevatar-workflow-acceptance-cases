# Lark `/init` actor activation recovery regression

Issue #3210 Case 22 can pass the workflow approval/card/continuation contract while still missing a failure in the surrounding role actor. Production logs exposed that gap when `/init` reached checkpoint recovery, awaited durable credential resolution outside the Orleans activation scheduler, and then failed committed-state publication. The user-visible symptom was no reply.

Regression Case `R01` covers both proof layers:

- The deterministic Orleans integration test injects one tool-completion checkpoint append failure, forces durable credential resolution to yield, resumes the same streaming turn, executes the tool once, and commits a successful terminal completion.
- The production probe requires a Ready workload traceable to `f5e51e99f`, one fresh Lark `/init` inbound, exactly one relayed reply, no duplicate reply, and no `Activation access violation` or `CommittedStatePublicationException` in the correlated window.

The local layer passed the full solution build, the targeted integration regression, architecture guards, workflow binding guard, test stability guard, and solution split guards.

The production layer passed on 2026-08-06 at 19:02 UTC. Ready image `4c0596c7` (digest `sha256:7cdca8d5038e2593c5583eba28d77e8bc4398baad4f10e77cd4a814ab04494e6`) is traceable to the required commit. One fresh Lark `/init` inbound produced exactly one relayed authorization-renewal reply, no duplicate reply appeared, and the correlated production log window contained neither `Activation access violation` nor `CommittedStatePublicationException`. No OAuth link was opened and no binding was changed. Public evidence stores no Lark identity, message, actor, OAuth state, or callback value.
