# Phase18 — Selectable Outfits and More Costumes

Owner requests fixing unselectable outfit menu and more costumes. Preserve the
current Home, existing earned rewards, player identity colors and physics.

## M18.1 — Pointer-selectable outfit collection

- [ ] Reproduce Home → Outfits selection through real pointer routing.
- [ ] Fix modal input ownership; retain keyboard navigation, equip acknowledgement,
  close/return focus and movement blocking.
- [ ] Regression uses GUI mouse events, not direct selection or emitted signals.

## M18.2 — Four additional starter costumes

- [ ] Add Chef, Firefighter, Sailor and Pilot with distinct toy silhouettes,
  open faces, shared matte palette and unchanged capsule/ragdoll bodies.
- [ ] Append stable catalog IDs, expose starters offline and in managed inventory,
  preserving existing ownership/receipts. Scroll the grid instead of growing offscreen.
- [ ] Validate every costume's geometry/animation/ragdoll and catalog parity;
  inspect rendered collection and front/back silhouettes at 720p/1080p.

## M18.4 — Original menu and gameplay music

Added by owner follow-up; complete before integrated M18.3 delivery.

- [ ] Compose/generate two original playful instrumental loops with deterministic
  source, no external samples/dependencies; record hashes and provenance.
- [ ] Menu/Outfits/Choose Map keep menu theme; ACTIVE uses gameplay theme;
  results return to menu, rematches reuse bounded crossfading voices.
- [ ] Independent persisted Music volume including mute; duck music under warnings
  without stealing Effects/Warnings voices. No headless/dedicated music playback.
- [ ] Execute real imported-loop/crossfade/interruption/reset tests and settings
  restart; inspect music and rendered controls, provide listenable previews.

## M18.3 — Regression and source delivery

- [ ] Verify actual mouse selection/equip/close and selected avatar at match start;
  execute relevant full regression, including equipment networking/persistence.
- [ ] Record provenance, results and limits, then normal-gated commit/push.

No new shop, currency, gameplay bonuses or infrastructure changes. Release and
deployment are separate delivery states, not inferred from source checks.
Human/device acceptance follows [NEED_REAL_CHECK.md](../../NEED_REAL_CHECK.md).
