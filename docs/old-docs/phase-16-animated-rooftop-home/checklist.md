# Phase16 — Reference-led Animated Rooftop Home

Completed2026-10-17: all agent-owned gates passed; source pushed, exact-head
deployment and matching prerelease verified. The planning observations below are
historical; final outcomes supersede their pending wording. Human/native/GPU
acceptance remains unverified under the existing waiver. See [full evidence](progress.json).

Owner rejects the static, cream-washed Phase15 background in favor of the already
selected rooftop reference. Keep real Home → Choose Map controls and acknowledged
outfits. This is presentation only, not a new playable map or gameplay collision.

## 16.1 — Live rooftop composition
- [x] Remove the static Home capture, cream wash and separate pedestal.
- [x] Foreground coral rooftop, actual equipped cyan character, teal rails/bench/tree;
      detailed town/roads/sky behind, strong outlined title and amber primary action.
- [x] Deterministic project-authored scene geometry; no concept image as runtime art.

## 16.2 — Motion and verification
- [x] Clouds/traffic move, character alternates idle and occasional wave.
- [x] Reduced motion freezes decoration; off-page/overlay work stops; no gameplay authority.
- [x] Exercise map/back/outfit/settings/multiplayer and inspect720p/1080p plus video.
- [x] Run regression, record real limits, commit and push the coherent correction.

## Owner playtest additions — 2026-10-17

Owner reprioritized landing balance during Home work, then requested the following
image findings be added to planning. Preserve unfinished 16.1/16.2; do not treat
these reports as permission to deploy or as confirmed root causes. Toy Town is the
reported map; exact client revision, seed, platform and network mode are unknown.

### 16.3 — Height-based fall balance (completed technical gates)
- [x] Replace impact-speed damage with actual peak-to-landing descent, measured
      by `PartyPlayer`; retain server-only HP mutation and same-frame batching.
- [x] Initial tuning: ≤3 m safe; quadratic increase to 100 HP at15 m. Reset tracked
      height on spawn/rematch and on each landing; normal jumps remain safe.
- [x] Execute real movement drops, ordinary jump, map safety, player integration
      and collapse/fall-death/reset controls. Measured drops:2.5 m→0HP,
      6 m→6.25HP,10 m→34.03HP,16 m→100HP.
- [x] Review network/reconciliation and repeated-landing behavior before delivery;
      matching public release verified, without human balance acceptance.

### 16.4 — Toy Town environment and hazard readability (completed technical gates)

Order: investigate HP/state consistency first, traversal clearance second, then
hazard visual polish. Module owners below identify code, not delegated agents.

- [x] **PT-01 / P1 — HP0 while apparently still alive.** Volcano screenshot shows
      HUD0, cyan standing character, SURVIVE and1/1 survivors. Hypotheses include
      fractional HP rounding, stale HUD/snapshot or elimination transition; no
      death-state bug established by a still image. Trace exact authoritative HP,
      displayed rounding, alive flag, match state, input eligibility and results
      over consecutive ticks in solo and a real client. Inspect MatchManager,
      HUD, `game/main.gd` and Volcano contact. Gate: positive HP never displays as
      dead; actual zero HP eliminates once, blocks input and reaches the correct
      results/spectator state. Cover first match, rematch and remote snapshot.
- [x] **PT-02 / P2 — Stair/tree intersection and route clearance.** Screenshot
      shows foliage occupying the stair/handrail silhouette. Audit all Toy Town
      stairs/ramps/bridges, not just the pictured tree; identify the exact route
      before moving props. Inspect `_add_tree`, stair generation and world detail
      placement. Move/resize planting outside walking, landing and rail clearance;
      do not simply remove collision from obstructing objects. Gate: real player
      ascent/descent both directions without snagging, visible supported planting,
      no foliage/rail intersections; inspect close gameplay-camera captures and
      rerun map-safety/routes plus damaged-map escape checks.
- [x] **PT-03 / P2 — Volcano looks like stacked orange boxes.** Screenshot shows
      abrupt rectangular terraces and thin bright layered edges. Existing terrain
      already has surface profiles; identify which render/variant produces this
      view before replacing geometry. Inspect `game/disasters/volcano.gd` profile,
      mesh and collision together. Aim for irregular toy-style cooled banks/hot
      fissures, coherent borders and readable escape channels, not realistic noise.
      Gate: same seed before/after captures from ground and above, both variants;
      visual/contact/support agreement, warning-time escape, heat/cooling/Flood
      overlap, client convergence and rematch restoration remain valid.
- [x] **PT-04 / P2 — Rain puddles too uniform/artificial.** Confirmed source:
      `weather_surfaces.gd` draws identical24-segment cyan cylinders at authored
      anchors. Plan deterministic varied outlines, sizes/orientations and restrained
      translucent wet shading. Keep visual bounds consistent with surface sampling
      and Fire cooling; do not randomize appearance independently on each client
      or wet sheltered/unsupported floors. Gate: varied but readable ground-level
      renders, same snapshot reproduces geometry, boundary/cover/height/snow-melt
      and drying/reset tests pass. Distribution changes must preserve safe routes.
- [x] **PT-05 / P2 — Flood circles imply a false danger radius.** Confirmed source:
      `flood.gd::_spawn_surface` places three static cream TorusMesh decorations.
      They are not damage boundaries; Flood contact is water-height-based. Replace
      ordinary fixed rings with subtle moving water cues; preserve distinct
      electrified-Flood feedback, which is a different state. Gate: normal Flood
      has no static target-like circles, electrification remains legible, rise/
      drain/height damage/client snapshots/reset unchanged; inspect both states.

Evidence: owner attachments `9c537cdcc46f22bdaec3e1bfcb26eeb950465bde9129a63032e8005b6d8b36fc`
(stairs), `ab5d19f0bb022c929a922d912e9d793ce3f98125af37c024fcbd23e8dd5335d5`
(Volcano/HUD), `79c6e3fa3c47cfac149add8376ef6c3dcefa04f262b51af39327f887a4d6fa3e`
(Rain), `5629bd2dc0103e7137b19a12ce9624178e498bdd1bd20b742091596b0fe760f4`
(Flood), in this thread. User aesthetic/balance acceptance is unverified; the
existing human-check waiver is unchanged. No DESIGN rewrite or Harbor redesign.

## Final reconciliation and delivery

- HP defect was fractional-value truncation, not a proven failed-elimination bug:
  positive HP now rounds upward; exact-zero server elimination remains unchanged.
- 24 Toy Town routes both directions/two bridges/foliage clearance passed963 checks;
  damaged terrain escape passed18,124 checks. Solid trunks remain solid.
- Volcano shared-rim facets/top collision replace tile plinth walls; perimeter
  height matches all four ramps. Both maps/two variants inspected from ground/above;
  pre-change captures preserve the old box-wall rendering.
- Puddle outline/contact/snapshot use the same deterministic footprint. Ordinary
  Flood rings are gone; electric violet feedback is preserved and inspected.
- Full staged gate:58 Godot suites,6 network matrices, managed20, persistence
  restart and41 Python tests. Fixture exit/admission/rejoin races were corrected,
  not hidden by timeout increases or relaxed gameplay assertions. Failures are
  retained in [progress](progress.json).
- [Source](https://github.com/phucle297/idunno/commit/a2c8ce87800de80784fa87837889005bd92d6288),
  [deployment](https://github.com/phucle297/idunno/actions/runs/39059570910),
  [matching prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-17-a2c8ce8).
  Downloaded public assets match hashes/CI bytes; Windows uses the exact deployed
  PCK. Standalone Linux lifecycle/profile restart and exact-PCK public two-client
  Ready/Start/mutual movement/normal room cleanup passed.
- Physical GPU/60FPS, native Windows/audio, aesthetic/balance feel and separate
  networks remain unverified. No mandatory human checklist is reinstated.
