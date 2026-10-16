# Phase14 — Stable character and pre-match preparation

Scope: repair reported airborne arm flapping and face motion on stopping; launch
into explicit solo/room, map, match-mode and outfit preparation. Preserve existing
network authority, inventory locks, emotes, ragdoll/get-up and demo/server tooling.
No new geometry, gameplay rules or infrastructure. DESIGN remains authoritative.

## 14.1 — Character animation stability

- [x] Reproduce actual AnimationPlayer samples, not only inspect clip definitions.
- [x] Hold symmetric jump/fall poses without replaying completed takeoff.
- [x] Keep face fixed through walk/run-to-idle blending; restore interrupted cues.
- [x] Regenerate serialized clips with deterministic provenance; focused regression.

## 14.2 — Preparation before playing

- [x] Normal startup waits in menu with pointer and blocked movement; no timer/hazard.
- [x] Expose solo/create/join, map, match mode and outfits using existing contracts.
- [x] Equip changes actual avatar after acknowledgement, survives explicit Start.
- [x] Keyboard/controller reaches match mode, menu cannot dismiss into an idle world.
- [x] Exercise startup → equip → map/mode → Play Solo → results → lobby.

## 14.3 — Regression and source delivery

- [ ] Full Godot/Python and real-peer matrices including dedicated startup/rematches.
- [x] Inspect final720p/1080p menu/outfit/map-selected captures and character animation recording.
- [x] Review diff, manifest checksums, JSON, archive preservation and tracking links.
- [ ] Commit/push source with verified staged-tree hook. No new deploy/release assumed.

Linux llvmpipe and automation do not prove Windows/GPU60FPS/audio or human feel.
Existing user waiver is preserved; [NEED_REAL_CHECK](../../NEED_REAL_CHECK.md)
does not add a required acceptance gate.
