# Phase 7T — Integrated terraced town

Owner rejects7S as insufficient: disconnected architecture, bland paving, segmented
shop awning, too few buildings, small/flat map and ramp-like stairs. Exact priority
reference remains `assets/references/phase7/rounded-town-camera-reference.png`.
The latest request overrides DESIGN's original64m town footprint. Phase8 stays paused.

- [x] 7T.1 Continuous cream wall/cornice envelope with real doorway openings; no
  rounded-module seams. Curved teal/cream awning with scalloped valance, coherent
  staggered paving, visible stair treads/risers, landings and rails on walkable ramps.
  Inspect actual Shop/School/House/stair renders, not generated concepts.
- [x] 7T.2 Expand Town to112×112m with residential/commercial buildings, civic
  terrace, side terraces and low park. Elevation must have real collision and routes,
  not backdrop-only hills. Update per-map perimeter/elimination, flood visual extent,
  strike coverage/terrain warning heights, tornado paths, cover and fire layouts.
  Keep Harbor extent64m and existing multiplayer/breakable/prop contracts.
- [ ] 7T.3 Walk new terrain transitions and doorways; test enlarged bounds/map
  switching, hazard surface placement, flood escape and existing multiplayer matrix.
  Render and inspect gameplay-distance and close-up views. Record provenance,
  exact limitations, commit/push `[skip ci]`; no deployment/release implied.

No native-GPU/60FPS or human aesthetic acceptance inferred from tests. Do not close
this phase with only a mesh change while populated terrain/district work is missing.

For managed20 rematch disconnects, load `recovering-town-rematch-stalls`.
Same-map reset must restore broken structures/crates without recreating static
streetscape nodes; map switches still rebuild. Do not relax ENet timeouts.
