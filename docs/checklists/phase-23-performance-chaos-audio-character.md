# Phase23 — Performance, chaos, audio and character quality

Status: planned, 2026-10-23. Owner requests planning first, then gradual execution.
No gameplay/asset changes or release are part of this planning checkpoint.
Root `progress.json` owns operational state; DESIGN remains authoritative except
for the owner's explicit removal of Normal. Preserve prior acceptance waiver.

## Evidence and constraints

- Owner reports ~800 MB app RAM, camera hitch after standing idle despite total
  CPU ~20% / system RAM ~40%, and similar memory use on waiting screens. Build,
  resolution, idle duration, memory metric and exact waiting screen unknown.
  These are valid reports, not proof of a leak or of CPU/GPU headroom.
- Owner's supplied Windows About screenshot identifies Ryzen AI 7 H 350,
  Radeon 860M integrated graphics, 32 GB RAM at 5600 MT/s, Windows11 Pro25H2.
  Use as native reference hardware, not an excuse to lower the quality bar.
  Displayed512 MB is not proof of a512 MB total GPU memory ceiling; measure
  shared/dedicated GPU memory and driver/frame timings. Do not store device IDs.
- Owner reports rooftop camping dominates Normal; small movements evade the few
  relevant hazards. This is balance/playtest evidence, not a measured survival rate.
- Owner reports harsh audio and two sounds per press; input/action unspecified.
  Do not assume duplicate signals rather than local/server replay or two distinct cues.
- Owner rejects current character quality. Automated geometry/animation passes
  do not establish aesthetic approval.
- Source: `game/main.gd` retains prepared geometry on lobby return;
  `game/disasters/disaster_director.gd` has Normal/Hard with Hard shortening gaps;
  Main also exposes Hot Potato. `game/gameplay_audio_controller.gd` and toy/bomb
  presentation own separate voices; character is procedural through
  `game/player/toy_character_visual.gd` and the asset generator/manifest.
- Do not increase hazard/mesh/voice load before measuring baseline. Keep authority,
  roof-correct weather, published warnings, escape routes, bounded recovery,
  admission/loading barriers, existing outfits and bomb-private fuse intact.

## M23.1 — Attribute memory and camera hitches, then fix measured costs

- [ ] T23.1a: Baseline fresh Home, Choose Map, network lobby before Start,
  active match, results and returned lobby. Run one/two instances; both maps;
  idle 0/60/300 seconds then identical camera orbit. Include focused, minimized
  and restored controls. Compare cold/warm resources and five match-return cycles.
  Record per-process RSS/private working set where supported, Godot static/object
  memory, node/resource counts, GPU/VRAM if available, main/render/physics timing,
  draws, p50/p95/p99 frame times and max hitch, resolution/V-Sync/frame cap.
  Reference target: stable60FPS at1080p for one foreground client on the owner's
  class of hardware; measure two-client degradation separately. This is a target,
  not an executed result or a guarantee for every driver/power setting.
  Instrument loading/culling/resource work; distinguish one-core stalls, GPU,
  driver/shader work and memory residency rather than guessing from total CPU.
- [ ] T23.1b: Fix highest measured costs in small units. Candidates, not diagnoses:
  suspend unnecessary gameplay/physics/rendering in menu; cap background/menu
  rendering without changing simulation deadlines; deduplicate meshes/materials;
  investigate first-visible shader/resource work. Separate lightweight Home
  preview from retained gameplay world. Decide retained-map versus release on
  explicit Home/room exit from measured RAM/reload cost; preserve cheap same-map
  rematch within a session and never rebuild on map selection.
- [ ] Gate: reproduce each addressed hitch/cost on unchanged baseline and rerun
  identical traces after fix; report absolute MB/ms and tradeoffs. Five-cycle
  memory trend distinguishes bounded cache from retained-resource growth.
  No arbitrary 800 MB failure threshold or native-FPS claim from llvmpipe.
  Run startup/map-loading/lifecycle/weather/rematch and real-client controls.
  Hardware-only unresolved causes stay open, not marked fixed.

## M23.2 — One harder baseline; break rooftop camping

- [ ] Remove Normal as a selectable/default preset and its obsolete branches,
  labels and tests. Do not keep hidden Normal compatibility. Keep Hot Potato
  as an optional rule variant on the same harder survival baseline, not an easy
  alternative; retain its private random fuse and multiplayer-only restriction.
- [ ] First measure existing seed-matched rooftop idle, rooftop tiny-step dodge,
  ground idle and actively rotating route controls on both maps. Record threat
  coverage, forced meaningful relocations, HP/deaths and reachable counters.
- [ ] Design existing-hazard changes around **relocation**, not flat damage or
  more beeps: e.g. warned multi-pulse rooftop footprints that occupy meaningful
  roof sectors temporarily; overhead UFO/bee pressure that can be broken by
  real cover or route changes; alternating ground/roof threats with finite safe
  windows. Exact hazard assignments/values follow coverage measurements.
  No permanent anti-roof punishment: elevation still helps against Flood.
- [ ] Director uses bounded complementary combinations, less dead time and an
  escalating pressure curve. Avoid repeating one easy dodge pattern. Publish
  spatial warnings before locking attacks; verify at least one reachable response
  for each admitted overlap, including collapsed routes and reduced playable area.
  Keep roofs excluding indoor Rain/Snow; do not solve camping with roof penetration.
- [ ] Gate: passive and tiny-step rooftop controls no longer remain effectively
  immune across the agreed seed matrix; active route controls can survive through
  actual traversable counters. Before implementation, set quantitative relocation/
  coverage targets from baseline in decisions. No guarantee of human difficulty
  from bots. Hazard/director/map/collapse tests plus real 2/4/8/20-client replication
  and five rematches; recheck M23.1 frame/physics/wire budgets and inspected warnings.

## M23.3 — Softer, single-event audio feedback

- [ ] Reproduce mouse, keyboard, held input, focus recapture, jump and toy use;
  solo/host/remote client; menu open/close/equip; overlapping warning/music cases.
  Trace event IDs, emitter and voice starts to locate any duplicate action,
  repeated connection, prediction/authority echo or intentional stacked cues.
- [ ] Give each action one owner for confirmation audio; deduplicate by event
  identity when appropriate, not a global delay that swallows legitimate presses.
  Inspect GameplayAudioController, toy/bomb audio and UI/input call sites.
- [ ] Soften sharp transients/high-frequency tone content, smooth envelopes and
  rebalance music/effects/warnings with peak/headroom checks. Preserve warning
  intelligibility, mute/sliders and voice caps; do not merely lower Master volume.
  Asset changes require validating-game-assets and provenance updates.
- [ ] Gate: one intended confirmation per action for local/remote/replayed state,
  distinct repeated presses still audible, no clipping/voice growth under overlap,
  settings survive restart. Render/record real output; compare before/after audio.
  Automated spectrum/peak checks do not establish comfortable human listening.

## M23.4 — Better-looking, coherent character without performance regression

- [ ] Inspect current front/side/back, gameplay-distance silhouettes, all outfits,
  gait/jump/fall/get-up and ragdoll. Establish a visual brief consistent with the
  toy world: coherent rounded proportions, expressive face, shaped hands/shoes,
  material separation and better costume integration rather than extra primitives.
- [ ] Load asset validation; create 2–3 visual directions against actual current
  captures with Painter when this milestone begins. Choose/refine direction before
  rebuilding all costumes; do not treat generated concepts as implemented models.
- [ ] Implement chosen base and adapt existing outfit IDs/equipment, animation
  anchors, held toys/bomb and ragdoll. Cosmetic changes must not alter collision,
  reach, speed or hit rules. Record provenance/licensing; no unapproved dependency.
- [ ] Gate: inspected front/side/back and 720p/1080p Home/collection/gameplay plus
  representative motion/ragdoll, no clipping/floating feet/accessory drift; all
  outfits usable. Measure triangles/materials/draws/memory and 20-player renderer
  cost against M23.1 before setting final asset budget. Better art is not unlimited
  polygon count. Human aesthetic approval remains distinct from technical gates.

## Execution and delivery

Order: M23.1 → M23.2 → M23.3 → M23.4. Finish and validate each coherent unit,
commit/push with Conventional Commits; no speculative all-app refactor.
Keep failed runs and before/after evidence. Full affected regression and matching
package checks follow implementation. This plan does not deploy/release a build;
delivery authorization is separate. Native/user feedback stays in NEED_REAL_CHECK.
