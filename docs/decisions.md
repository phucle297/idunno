# Implementation Decisions

## 2026-10-05 — Engine and initial asset pipeline

- **Decision:** Godot 4.7.2 stable, GDScript, Compatibility renderer, with ENet multiplayer APIs and Windows export templates.
- **Reason:** The official portable Linux editor is available for this x86_64 WSL2 environment, Godot supports the target Windows build, and its scene/resource format supports deterministic procedural prototype assets without waiting for Blender.
- **Renderer constraint:** Compatibility is the validated baseline because this WSL display does not expose the Vulkan surface extension required by Forward+. Re-evaluate Forward+ on the Windows target only after an exported build is available; do not claim it tested here.
- **Initial asset path:** Generate the first character proxy, wall, prop, materials, and effect proxy as authored Godot scenes/resources. Add Blender `.blend` and `.glb` outputs later only after Blender is available and the measured import pipeline passes.
- **Authority boundary:** Multiplayer authority is designed alongside the first controller; no networking capability is considered complete until tested with separate local peers.
- **Known limitation:** No engine or Blender was preinstalled. Quaternius animation clips and retargeting remain unverified until the free archive is downloaded and inspected.

## 2026-10-05 — Authoritative prop grabbing

- **Decision:** A server-only `GrabManager` owns player registration, one-owner prop claims, spring forces, collision exceptions, and disconnect cleanup. Players supply interaction geometry and request toggles but do not assign prop ownership.
- **Reason:** Shared prop ownership is neither match scoring nor player-local state. Keeping arbitration in one node prevents two players from claiming the same body and gives death, ragdoll, excessive separation, disconnect, and rematch cleanup a common release path.
- **Physics constraint:** Held props receive a clamped spring force and remain world-colliding rigid bodies; they are never teleported to the hold point.

## 2026-10-05 — Meteor Shower authority and impact

- **Decision:** One server-owned `MeteorShower` component controls the complete strike lifecycle: warning target and countdown, one damage batch, bounded player and prop impulses, ragdoll trigger, survival credit, and cleanup.
- **Reason:** Keeping selection and gameplay outcomes in one authoritative component prevents clients from creating damage or force while allowing its telegraph and short impact effect to remain presentation-only children.
- **Physics constraint:** The initial strike uses a 3 m radius, 0.75 m lethal core, distance-scaled near-hit damage, an 8 m/s-equivalent player impulse cap, and an 18 N·s prop impulse cap. It never creates a persistent dynamic meteor body.

## 2026-10-05 — Flood and Tornado authority

- **Decision:** Flood and Tornado are independent server-owned lifecycle components registered against authoritative match players, matching Meteor's existing ownership boundary.
- **Flood:** A uniform water level provides a 6 s warning, rises from −0.5 m to 3.5 m over 35 s, measures head submersion with a 2 s breathing grace, applies 12 HP/s afterward, and gives loose props bounded buoyancy, drag, and a 1.5 m/s current target. Water-level crossings account for only the submerged fraction of a simulation step.
- **Tornado:** A visible tornado follows a server-selected linear path at 2 m/s with an 8 m influence radius and 2 m core. Pull, lift, one-shot throw velocity, and prop forces are capped; authored indoor `AABB` cover volumes reduce player pull to 25% and prevent core throws.
- **Cleanup:** Both disasters remove effects and transient exposure state during completion and rematch. Director selection and overlap remain Phase 4 work.

## 2026-10-05 — Deterministic Godot scene serialization

- **Decision:** The asset generator removes Godot's runtime-generated node `unique_id` fields after saving generated `.tscn` files.
- **Reason:** Phase 1 re-audit proved that identical seed runs produced identical geometry but different bytes because `PackedScene` assigned random node IDs. Canonicalizing those editor-only IDs makes generated scene checksums reproducible without changing runtime content.

## 2026-10-06 — Disaster Director selection and overlap

- **Decision:** One server-owned `DisasterDirector` selects registered disasters through their shared metadata/start/active/cleanup contract. It uses a per-match random seed, rejects immediate repeats and incompatible pairs, and caps the slice at two simultaneous disasters.
- **Pacing:** Intensity rises at 2, 5, 8, and 9 minutes. Tornado unlocks after 2 minutes; overlap unlocks at 5 minutes and only after both involved disasters have completed solo. Recovery delays separate completed hazards and overlap replacements.
- **Reason:** A thin director preserves independently validated hazard components while centralizing the server-owned randomness, fairness gates, and overlap budget required by the design bible.

## 2026-10-06 — Phase 5 validation boundary

- **Decision:** Use a dedicated ENet harness with one authoritative server and four separate client processes to validate ready state, active match state, four-player health/alive data, server-applied damage, and simultaneous Flood + Tornado state.
- **Boundary:** This proves the existing authority contracts and snapshot consistency under five separate processes. It does not claim that the playable scene has production lobby, spawning, movement replication, or client-side disaster presentation.
- **Profiling:** Mesa llvmpipe measurements remain descriptive only. Native Windows Godot 4.7.2 running OpenGL Compatibility on Intel UHD Graphics 630 passed two uncapped 600-frame runs at 1280 × 720 with p95 frame times of 11.74 ms and 11.37 ms. The 60 FPS-capped run measured 17.50 ms p95 wall time despite only 5.28 ms p95 process time, so uncapped frame times are the acceptance evidence rather than limiter-induced scheduling jitter.

## 2026-10-06 — Phase 6 multiplayer scale gate

- **Decision:** Parameterize the existing separate-process ENet harness and run the roadmap's 2, 4, 8, and 20-client counts against one authoritative server.
- **Evidence boundary:** Each count validates ready submission, active match state, complete player/health snapshots, server-applied damage, client mutation rejection, and simultaneous Flood + Tornado state. It is a state-contract and connection-scale gate, not proof of playable movement or presentation replication.
- **Next boundary:** Production networking belongs in the playable scene: create/join, authoritative spawning, disconnect cleanup, movement state, and disaster presentation must pass representative sessions before Phase 6 can complete.

## 2026-10-06 — Playable-scene ENet session boundary

- **Decision:** Keep ENet session orchestration in `main.gd`, which already owns playable player registration across match, grabbing, and disaster systems. Preserve the offline path and activate host/join only through explicit methods or command-line arguments.
- **Spawning:** The host owns the canonical peer roster, creates each authoritative player, and reliably sends spawn/remove records to clients. Each client enables only its own player camera. The default limit is 20 total players: one host plus 19 remote clients.
- **Cleanup:** A disconnect removes the player from the scene and from MatchManager, GrabManager, Meteor, Flood, and Tornado registries. Movement, match-state, health, and disaster presentation replication remain separate Phase 6 work.

## 2026-10-06 — Server-authoritative playable movement

- **Decision:** During ENet sessions, clients submit normalized movement controls and camera yaw to the host; only the host advances `CharacterBody3D` movement. Client-owned players no longer simulate their own transforms.
- **Snapshots:** The host sends one unreliable ordered batch containing every player transform and velocity per physics tick. Batching avoids one broadcast per player and keeps snapshot dispatch linear at the 20-player target.
- **Validation boundary:** A two-process playable-scene test drives host and client in opposite directions and verifies that the host simulates both while the client observes both authoritative results. Prediction, interpolation, match/health replication, and disaster presentation remain later Phase 6 slices.

## 2026-10-06 — Playable match-state replication

- **Decision:** `MatchManager` owns serialization and client application of its authoritative state. The host transports a complete snapshot at 10 Hz; clients cannot use this path to mutate the server.
- **Presentation:** Playable HUD and spectating resolve the local ENet peer instead of assuming peer 1. Replicated elimination hides the corresponding avatar on every peer and starts spectating only for the eliminated local player.
- **Channels:** Movement uses unreliable-ordered channel 1 and match state uses channel 2 so frequent movement packets cannot supersede health or elimination snapshots.
- **Validation boundary:** The separate client observed ACTIVE/100 HP, ACTIVE/75 HP with ALIVE 2/2, then RESULTS/0 HP with ALIVE 1/2 and local spectating after server-owned damage. Disaster lifecycle and visual-state replication remain separate Phase 6 work.

## 2026-10-06 — Seven-phase roadmap correction

- **Decision:** Track the original seven phases from `PROMPT.md` separately from completed slice-validation milestones. The next ordered phase is Phase 4 because Earthquake, Lightning, and Fire are absent.
- **Combination boundary:** Simultaneous Flood + Tornado proves scheduling, coexistence, and readability. It is not a Phase 5 cross-disaster interaction; no disaster currently changes another disaster's behavior.
- **Polish boundary:** Baseline HUD and Meteor/Flood/Tornado VFX exist, but Phase 7 remains incomplete without audio, a complete results screen, network rematch, and final feedback tuning.

## 2026-10-06 — Playable disaster presentation replication

- **Decision:** Keep disaster gameplay simulation server-only. Clients apply presentation snapshots containing lifecycle phase and the minimum state required to recreate Meteor, Flood, and Tornado effects; snapshots never invoke damage or force logic on clients.
- **Match start:** In direct-IP sessions, the host explicitly starts a match with Enter after at least two peers connect. This replaces a nonexistent lobby-ready UI without adding a second lobby system.
- **Validation:** A rendered client displayed replicated Flood + Tornado world effects, both named warning lines, HP 100, ALIVE 2/2, timer, and two readable players. Separate-process checks also validated replicated Meteor warning presentation.

## 2026-10-06 — Earthquake and predefined structure state

- **Decision:** Earthquake owns warning and pulse timing, while six map-owned `BreakableStructure` sections own stable piece IDs and intact/damaged/broken presentation. Each active pulse applies one authoritative damage batch plus bounded player and prop disturbance, then advances at most one section.
- **Route budget:** At most two sections may break during one Earthquake. A broken section creates at most one authoritative debris body, preserving the 32-body global budget and preventing every elevation route from disappearing.
- **Replication:** Playable snapshots send the six states as a stable-order `PackedByteArray`; clients recreate structure and hazard presentation only. The compact encoding keeps the complete 10 Hz snapshot below the ENet MTU.
