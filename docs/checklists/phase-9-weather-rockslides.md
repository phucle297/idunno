# Phase 9 — Weather and Rockslides

Status: planned; after Phase8 counterplay/model/UI gates. Future scope, not started.

## Outcome

Add Snowfall, Rain and Rockslide as readable toy-world disasters with meaningful
escape actions, while providing real wet/cold exposure for fire and later volcanic
cooling. Use existing disaster metadata/director and authoritative snapshots, not
a generic new simulation framework. Numeric durations/rates lock during this phase.

- [ ] 9.1 Weather surfaces: Snowfall gradually builds bounded slippery patches on
  exposed walkable terrain, not invisible global loss of control. Warn accumulation,
  keep steering/braking bounded, indoor shelter and controlled walking safer.
  Rain wets exposed zones and suppresses ground fire; roofed interiors stay dry.
  Snow melts into wetness; Flood washes submerged snow away. No opaque fog/whiteout,
  per-flake collision, temperature-survival meter or slow damage everywhere.
- [ ] 9.2 Rockslide: mark a slope/source and downhill corridor before bounded rocks
  roll through it. Clear lateral exits and sturdy-cover stops on both maps; author
  suitable terrain anchors if none exist, rather than rocks spawning on flat roofs.
  Static cover must intercept actual impacts; no held-crate or crouch dependency.
  Warning geometry/rocks follow real slope collision and authoritative impact damage.
- [ ] 9.3 Integration: fresh distinct icons, Snow/Rain/Rock animations/audio/character
  responses; seeded variants and allowed overlaps (wet ground does not remove rock
  impact). Run solo first-exposure before overlap; pause incompatible selections
  rather than surprising map-wide punishment. Weather state queried by support
  height, cover and water contact, never solely by an active-disaster name.
- [ ] 9.4 Validate dry/wet/roofed/submerged boundaries, traction recovery, actual
  rock avoidance/cover, both maps, same-seed replay, late join/remote state and5 resets.
  Full regression and2/4/8/20-client integration; render at720p/1080p, measure bounded
  particles/physics/memory and export matching local bundles/provenance.

Snapshot convergence checks do not authorize a new midmatch-join feature; preserve
existing admission/lobby restrictions and test fresh presentation state separately.

Exit: players have observable shelter/traction/side-step counters; environmental
exposure is authoritative and reusable for Phase10 cooling. Keep32 loose-body and
two-concurrent-disaster budgets, no GPU/human-fun claims from headless checks.
No public deploy, persistent store activation or release inferred.
