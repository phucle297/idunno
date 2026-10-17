# Phase16 decisions (historical)

Completed2026-10-17. Early pending statements below are planning history;
the final implementation and shipment reconciliation at the end supersedes them.

## Phase16 — reference-led Home and playtest follow-ups

- Preserve the approved Home/Choose Map flow; replace only the static Home
  backdrop with an isolated presentation-only animated rooftop scene. This remains
  unfinished and is not a new playable map.
- 2026-10-17: owner requested lower, height-based fall damage. Local implementation
  measures peak-to-landing descent, not speed; ≤3m safe, quadratic curve to100HP
  at15m. Authority and deferred same-frame damage batching remain unchanged.
  Real drops and jump/collapse/map-safety controls pass; network-specific review
  remains open. This is initial tuning, not human balance acceptance.
- Owner's new screenshots are queued in the existing
  [checklist](checklist.md), PT-01–PT-05. Investigate
  HP0/alive-state ambiguity before traversal clearance and hazard visual polish.
  Foliage intersection and rectangular volcanic rendering are observations;
  collision blockage and failed elimination are hypotheses until reproduced.
- Rain currently uses identical cylinder patches; ordinary Flood rings are fixed
  decorative toruses, not damage radii. Visual replacements must stay aligned
  with contact/cover/height rules and preserve electrified-Flood feedback.
- Keep Toy Town scope, prior human-check waiver and Phase15 public delivery.
  No new deployment/release or infrastructure change is implied by this plan.

The completed Home/Choose Map implementation and public-shipment decisions are
archived in [Phase15](../phase-15-home-and-map-selection/decisions.md).
Root [progress.json](../../../progress.json) remains the operational source of truth.

## Final implementation and shipment reconciliation

- Owner explicitly authorized five-worker fanout, fixes and release/deployment.
  The Home stage is isolated presentation geometry: actual equipped avatar,
  moving clouds/traffic, idle/wave, reduced-motion and hidden-page suspension.
- Fractional HP was truncated for display; ceil positive HP instead of altering
  server elimination or inventing a survival buffer. Actual0HP remains lethal.
- Trees were replanted outside all audited walking/landing/rail corridors without
  making trunks non-solid. Both traversal directions and damaged escapes pass.
- Volcano tiles now share rim vertices and top collision, without repeated plinth
  walls. Full gate exposed a raised outer lip; all perimeter vertices now meet
  four access ramps at0.08m. Decorative skirt indexing was corrected as well.
- Puddle silhouettes/contact share deterministic40-point outlines and feathered
  translucent shorelines. Same-count layout changes invalidate presentation
  geometry; unchanged snapshots do not rebuild it. Normal Flood fixed toruses
  were removed; electric violet cues are retained.
- Keep exact server authority and batched fall damage while tuning height, not
  velocity. Real drops and full network/rematch matrices validate behavior;
  aesthetic and balance approval still belong to the owner.
- Gates caught fixture success-exit, serial-admission-budget, stale-log and
  observer-rejoin races. Fix readiness/branching, not sleeps, raised timeouts,
  suppressed runtime errors or weakened appearance/gameplay assertions.
- [Source](https://github.com/phucle297/idunno/commit/a2c8ce87800de80784fa87837889005bd92d6288)
  passed58 suites/6 matrices/managed20/41 Python, was pushed and deployed by
  [exact-head CI](https://github.com/phucle297/idunno/actions/runs/39059570910).
  [Prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-17-a2c8ce8)
  Windows uses the byte-exact CI server PCK. Public assets/tag were downloaded and
  verified; standalone Linux and public exact-PCK two-client smoke passed.
- No infrastructure/capacity change, public profile-store enablement or new phase.
  Human/native/GPU/audio/separate-network checks remain unverified under the prior
  waiver. Full failed/successful evidence is retained in [progress](progress.json).
