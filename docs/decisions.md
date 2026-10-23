# Active decisions

Phase22 is active below. The preceding bomb-only implementation and source
delivery are complete; [Phase21 decisions](old-docs/phase-21-hidden-fuse-bomb/decisions.md)
and [full evidence](old-docs/phase-21-hidden-fuse-bomb/progress.json) are archived.
After separate owner authorization,Phase21 was deployed and published as a
matching prerelease. [Delivery evidence](old-docs/phase-21-hidden-fuse-bomb/delivery-2026-10-22.json)
supersedes the source checkpoint's historical not-deployed status; original
archive payloads are unchanged. No infrastructure/capacity/persistence changes.
Root `progress.json` owns the next action; rejected proposals are not reopened.

## Phase22 — Start-time map loading

Owner corrected the lifecycle: Home and Choose Map must not construct/delete a
gameplay map. Selection is metadata only; Start prepares the selected world.
The independent animated Home diorama remains unchanged. Previously loaded static
geometry may be reused at Start/rematch, but selection must never rebuild it.

The pre-change production request path blocked Town selection for2059–2172ms
in this headless orb, constructing9495 descendants; warm mesh-cache work was
only17ms. Avoid a cache-only workaround. Keep selected identity separate from
loaded anchors, freeze lobby mutations during network loading, and require
current-session acknowledgements before starting match time/disasters. Handle
departure, timeout, stale replies and disconnect without starting a partial room.

After map-loading validation, fan out independent whole-app reviews of UI/session,
network lifecycle and gameplay/performance. Implement only evidence-backed fixes
and useful refactors; no speculative systems or content changes. Commit/push each
validated coherent unit with normal hooks and skip-CI. No new release/deployment
is authorized by the current request; the existing bomb release stays unchanged.

The audits found an admission/Start race, a cancellation status overwritten by
the next UI refresh, and redundant residual texture uploads/geometry snapshot
allocations. Start now waits for pending and authenticating admissions before
freezing the roster; loading rooms stop advertising joinability. Cancellation
copy persists until the next lobby action. Residual textures upload only after
state changes (including gradual melt/dry), while weather cover invalidation
reads a local geometry revision that changes on transforms or visibility,
including client interpolation, not cooldown-only changes. Toy payloads and
gameplay rules are unchanged. Real HTTP/ENet and rendered checks precede the
normal staged regression gate; native performance remains unverified.

Cold managed20 Start exposed a second boundary: moving a synchronous Town build
to Start still stalled ENet. Construction, cleanup, partition clipping, terrain
caching and weather registration now yield ordinary frames with cancellation.
The authority must finish its own world as well as receive every frozen peer's
current ACK before ACTIVE. Session snapshots carry the load generation; stale
lobby snapshots cannot replace a pinned map. Old construction cleans up before
replacement, with no speculative geometry fallback in ACTIVE snapshot handling.

Outer checkpoints alone were insufficient: measured compound construction spans
still reached375–585ms under21 processes. Split base/building/ramp/civic units;
skip disjoint mesh/triangle districts during clipping. Standalone cooperative
preparation fell5408→2087ms before finer slicing. Managed20 then passed cold
Start, authoritative movement at every peer, five rematches, owner transfer and
crash retry with original deadlines. This is loopback evidence, not native FPS.
Hide the partial Sandbox behind the loading page; the final software-rendered
solo capture run completed in9.63s and both loading/started states were inspected.

Repeated cold20 runs still approached the unchanged15s fixture deadline. Frozen
loading now relies on its reliable load/cancel protocol instead of queueing
identical lobby snapshots; completion schedules an immediate match snapshot.
Three runs passed in14.26–14.92s. Fully interior partition triangles now retain
their exact vertices without four unnecessary polygon-clipping passes; measured
cold convergence then fell to11.46s. This improves measured margin, not a claim
that every earlier intermittent transport failure has an established cause.
Keep lightweight timestamp/state diagnostics and the original cold gate.
