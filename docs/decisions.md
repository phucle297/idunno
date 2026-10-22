# Active decisions

No new phase is active. The bomb-only implementation, validation and source
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
