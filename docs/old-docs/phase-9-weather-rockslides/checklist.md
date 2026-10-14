# Phase 9 — Weather and Rockslides

Status: completed agent-owned source/local-package gates on2026-10-14.
Source remains uncommitted/unpushed by explicit owner direction. No new deploy/release.
Human/native Windows/GPU/audio acceptance is unverified under the existing waiver.

## Outcome

Add Snowfall, Rain and Rockslide as readable toy-world disasters with meaningful
escape actions, while providing real wet/cold exposure for fire and later volcanic
cooling. Use existing disaster metadata/director and authoritative snapshots, not
a generic new simulation framework. Numeric durations/rates lock during this phase.

- [x] 9.1 Weather surfaces: Snowfall gradually builds bounded slippery patches on
  exposed walkable terrain, not invisible global loss of control. Warn accumulation,
  keep steering/braking bounded, indoor shelter and controlled walking safer.
  Rain wets exposed zones and suppresses ground fire; roofed interiors stay dry.
  Snow melts into wetness; Flood washes submerged snow away. No opaque fog/whiteout,
  per-flake collision, temperature-survival meter or slow damage everywhere.
  - [x] 9.1.1 Bounded authored surface-state model with real overhead collision
    query, stacked support/contact/radius boundaries, rain wetting, snow accumulation,
    melt/dry recovery, Flood washout, client-only snapshot application and five resets.
    `test_weather_surfaces.gd`:37 checks. Wired into Main and full snapshots.
  - [x] 9.1.2 Author patches wholly inside terrain/cover boundaries on both maps;
    Rain warning/lifecycle, visible wetness, Fire suppression, snapshots and reset.
  - [x] 9.1.3 Snowfall warning/lifecycle, visible accumulation and bounded traction;
    steering/braking/recovery controls and grounded-only contact.
    Weather integration471 checks, two maps/five resets; actual720p/1080p captures.
    Transport, comprehensive render review and matching bundles completed in9.4.
- [x] 9.2 Rockslide: mark a slope/source and downhill corridor before bounded rocks
  roll through it. Clear lateral exits and sturdy-cover stops on both maps; author
  suitable terrain anchors if none exist, rather than rocks spawning on flat roofs.
  Static cover must intercept actual impacts; no held-crate or crouch dependency.
  Warning geometry/rocks follow real slope collision and authoritative impact damage.
- [x] 9.3 Integration: fresh distinct icons, Snow/Rain/Rock animations/audio/character
  responses; seeded variants and allowed overlaps (wet ground does not remove rock
  impact). Run solo first-exposure before overlap; pause incompatible selections
  rather than surprising map-wide punishment. Weather state queried by support
  height, cover and water contact, never solely by an active-disaster name.
- [x] 9.4 Validate dry/wet/roofed/submerged boundaries, traction recovery, actual
  rock avoidance/cover, both maps, same-seed replay, late join/remote state and5 resets.
  Full regression and2/4/8/20-client integration; render at720p/1080p, measure bounded
  particles/physics/memory and export matching local bundles/provenance.

Snapshot convergence checks do not authorize a new midmatch-join feature; preserve
existing admission/lobby restrictions and test fresh presentation state separately.

Exit: players have observable shelter/traction/side-step counters; environmental
exposure is authoritative and reusable for Phase10 cooling. Keep32 loose-body and
two-concurrent-disaster budgets, no GPU/human-fun claims from headless checks.
No public deploy, persistent store activation or release inferred.

## Final executed evidence

- `WEATHER_SURFACES_OK37`, `WEATHER_INTEGRATION_OK471`, `ROCKSLIDE_OK72`;
  Fire95/Flood59 controls. Real support/shelter/removal, contact/recovery, capsule
  impacts, walking both lateral exits and sturdy cover on both maps.
- `UI_REGRESSION_OK suites=45 matrices=5 managed_clients=20 persistence_restart=passed`.
  Playable Town2/4/8/20 and Harbor2/4/8/20 markers pass, with real remote weather/
  rock presentation, five dry resets and disconnect cleanup. Synthetic presentation
  stress intentionally exceeds director concurrency; solo-first/max2 tested separately.
- 40 final Godot captures at720p/1080p; eight sheets and targeted originals inspected.
  Town warning below HUD, Harbor camera/player inside boundary; blue meltwater is
  distinct from cream snow with no lingering Snowfall chip. Software renderer only.
- Five600-tick cycles/map: nodes6593→6593 Town,1370→1370 Harbor;64 cosmetic flakes,
  peak3 rocks/3 loose props. Subsystem tick p95=311/111µs, not GPU/frame throughput.
- Matching local Windows ZIP/Linux tar.gz exported from one identified uncommitted
  runtime snapshot. Both hash/unpack/PCK-content checks pass;105 entries, identical
  PCK. Standalone Linux allocator lifecycle passes version rejection, create/join,
  crash/retry, SIGTERM, port reclamation and no editor/cache dependency.
- Exact exported-PCK Weather471/Rock72 fixtures pass cleanly. Each source fixture
  also passes three consecutive verbose clean exits. Initial audio shutdown leaks
  and the Flood→Fire fixture failure are preserved in logs, not suppressed.
  Prevention: follow `reviewing-godot-gameplay` focused-audio teardown and independent
  stage dry-recovery guidance; never bypass wetness or weaken diagnostic checks.

Review images: `.amp/in/artifacts/phase9`; packages/provenance:
`.amp/in/artifacts/phase9-packages`; raw success/failure logs:
`.amp/in/artifacts/phase9-evidence`. These paths are orb handoff files, not releases.
Detailed commands, hashes, earlier failures and qualifications are preserved in this
phase's progress archive. Chronological pending statements there are superseded by
the final validation entries; no human result is inferred.
