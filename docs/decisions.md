# Disaster Party — Active Decisions

Root [progress](progress.json) owns active state; the [Phase 5 checklist](checklists/phase-5-session-distribution-and-release-readiness.md)
owns the reopened plan. Prior decisions remain in the [Phase 5 archive](old-docs/phase-5-session-distribution-and-release-readiness/decisions.md)
(gate decisions 5.1–5.4), the [Phase 4 archive](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md), the
[Phase 3 archive](old-docs/phase-3-player-caused-chaos/decisions.md) and the [Phase2 suspended snapshot](old-docs/phase-2-human-playtest-and-core-feel/decisions.md).

## Phase 5 reopened (2026-10-12)

Owner "Continue phase 5" reopened the phase after the premature Phase 6 rollover; owner
then delegated the single remaining scope item with "Your call."

- **Supported-playtest capacity target — DECIDED: 20 (design capacity), automation-validated.**
  The 20-player movement blackout is fixed (`throttle_configure(1000,2,1)`) and passes five
  consecutive constrained 20-player runs plus the full 4/8/20 matrix; the supported 1/2/4
  regression and 13 room-service tests also pass. Chose 20 because it is the design-bible
  capacity and is now evidenced, so an intermediate 8 would only defer the same decision.
  The claim is labeled automation-validated: physical LAN/Internet/audio/human acceptance
  stays open in `NEED_REAL_CHECK.md`. Deployment and infrastructure changes remain blocked
  pending separate authorization; Steam SDK/app work needs external credentials.
