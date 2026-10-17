# Active phase decisions

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
  [checklist](checklists/phase-16-animated-rooftop-home.md), PT-01–PT-05. Investigate
  HP0/alive-state ambiguity before traversal clearance and hazard visual polish.
  Foliage intersection and rectangular volcanic rendering are observations;
  collision blockage and failed elimination are hypotheses until reproduced.
- Rain currently uses identical cylinder patches; ordinary Flood rings are fixed
  decorative toruses, not damage radii. Visual replacements must stay aligned
  with contact/cover/height rules and preserve electrified-Flood feedback.
- Keep Toy Town scope, prior human-check waiver and Phase15 public delivery.
  No new deployment/release or infrastructure change is implied by this plan.

The completed Home/Choose Map implementation and public-shipment decisions are
archived in [Phase15](old-docs/phase-15-home-and-map-selection/decisions.md).
Root `progress.json` remains the operational source of truth.
