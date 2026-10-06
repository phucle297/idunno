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

## 2026-10-06 — Seven-phase roadmap correction (historical Phase 0 workstream)

- **Decision:** Track the original seven phases from `docs/old-docs/PROMPT.md` separately from completed slice-validation milestones. At that time, the next ordered workstream was Phase 4 because Earthquake, Lightning, and Fire were absent. The 2026-10-06 Phase 0 baseline decision below supersedes this numbering for future development.
- **Combination boundary:** Simultaneous Flood + Tornado proves scheduling, coexistence, and readability. It is not a Phase 5 cross-disaster interaction; no disaster currently changes another disaster's behavior.
- **Polish boundary:** Baseline HUD and Meteor/Flood/Tornado VFX exist, but Phase 7 remains incomplete without audio, a complete results screen, network rematch, and final feedback tuning.

## 2026-10-06 — Playable disaster presentation replication

- **Decision:** Keep disaster gameplay simulation server-only. Clients apply presentation snapshots containing lifecycle phase and the minimum state required to recreate Meteor, Flood, and Tornado effects; snapshots never invoke damage or force logic on clients.
- **Match start (superseded by audit remediation):** Direct-IP sessions originally let the host start with Enter after two peers connected. The later audit added the required lobby-ready UI and all-ready gate.
- **Validation:** A rendered client displayed replicated Flood + Tornado world effects, both named warning lines, HP 100, ALIVE 2/2, timer, and two readable players. Separate-process checks also validated replicated Meteor warning presentation.

## 2026-10-06 — Earthquake and predefined structure state

- **Decision:** Earthquake owns warning and pulse timing, while six map-owned `BreakableStructure` sections own stable piece IDs and intact/damaged/broken presentation. Each active pulse applies one authoritative damage batch plus bounded player and prop disturbance, then advances at most one section.
- **Route budget:** At most two sections may break during one Earthquake. A broken section creates at most one authoritative debris body, preserving the 32-body global budget and preventing every elevation route from disappearing.
- **Replication:** Playable snapshots send the six states as a stable-order `PackedByteArray`; clients recreate structure and hazard presentation only. The compact encoding keeps the complete 10 Hz snapshot below the ENet MTU.

## 2026-10-06 — Lightning warning and strike event

- **Decision:** Lightning is a short server-owned lifecycle with a 2 s violet radius ring and targeting column, followed by one distance-scaled damage batch and bounded knockdown. The component emits a named `struck(target)` event after authoritative damage.
- **Combination boundary:** The event exists now so Flood can subscribe without Lightning knowing about Flood. Electrified water remains Phase 5 until Flood implements the behavior-changing interaction.
- **Transport:** Main snapshots now include only active disasters. Missing entries explicitly clean client presentation, keeping packet size below ENet MTU as the disaster roster grows.

## 2026-10-06 — Fire zone graph and wind hook

- **Decision:** Fire owns eight fixed world zones arranged as a 2 × 4 neighbor graph. It begins with a 3.5 s warning, burns for 24 s, applies 12 HP/s inside burning zones, and can ignite only graph-adjacent zones after a separate 1.5 s propagation warning.
- **Combination hook:** `set_wind_active()` halves the propagation interval and emits a named wind-state event. This behavior is independently validated now, but Tornado does not activate it until the Phase 5 interaction is wired.
- **Replication:** Zone states travel as a stable-order `PackedByteArray`; clients rebuild rings and flame presentation without running authoritative damage or propagation.

## 2026-10-06 — Phase 5 interaction ownership

- **Decision:** `main.gd` orchestrates cross-disaster behavior through named signals rather than giving hazards direct references to each other. Lightning's `struck` event asks Flood to electrify connected water; Tornado activation/completion toggles Fire wind state, including the case where Fire begins during an active Tornado.
- **Flood + Lightning:** A strike below the active water surface electrifies the connected flood for three seconds. Players standing in water take a separate authoritative 25 HP/s electric hazard while high ground remains safe. Violet concentric ripples and explicit HUD text replicate to clients; electrification expires and never makes water permanently lethal.
- **Tornado + Fire:** Wind halves Fire's graph-propagation interval and creates at most one tagged, flaming 5 kg debris body. Tornado's existing bounded prop-force path carries it without a special force implementation. Clients receive only its active flag and authoritative position for presentation, and cleanup removes both wind state and debris.

## 2026-10-06 — Phase 6 playable scale transport

- **Decision:** Replicate player movement and match state in packed, stable-order arrays instead of one dictionary per player. Movement includes position, velocity, camera yaw, and visual-facing yaw; match state includes health, alive state, damage, elimination, survival count, and result data.
- **Reason:** The dictionary snapshots exceeded ENet's 1,392-byte MTU with only four match players and twenty movement players. Packed snapshots completed playable 4-, 8-, and 20-player sessions without MTU warnings while preserving authoritative movement, HUD, damage, disaster presentation, and remote facing.
- **Disconnects:** Clients reconcile player nodes from the authoritative match roster. This avoids broadcasting a removal RPC through channels that are closing and keeps all gameplay registries clean after sequential disconnects.

## 2026-10-06 — Phase 7 audio, results, and rematch

- **Audio:** Eight mono 22.05 kHz PCM cues are deterministically synthesized from seed 297. One dedicated warning voice is separate from a four-voice round-robin effect pool, so overlapping impacts cannot take the active warning channel. WSL's dummy audio driver validates import/playback state but not physical speaker output.
- **Results:** The replicated match snapshot already contains winner IDs, names, survival/elimination time, disasters survived, damage, and death cause. Every peer builds the same ranked cream/slate results panel locally from that authoritative data.
- **Rematch:** Enter remains the only required rematch action. Offline play restarts locally; in direct-IP sessions only the host can restart. The host resets lobby/match, players, spectator state, sandbox, hazards, director, results, and audio, while clients restore presentation when the replicated state returns to ACTIVE.

## 2026-10-06 — Audit remediation boundaries

- **Toy Town and character gate:** Keep Phase 1 content deterministic and generated inside Godot. The map now provides open Shop and Town Hall interiors, Parking Garage and Pocket Park landmarks, four tagged elevation routes, shelters, cars, trees, fences, signs, and benches. The generated character has a stable 18-bone contract, all 11 required named clips, six suit colors, and plain/cap/hardhat/backpack variants without introducing an unverifiable third-party dependency.
- **Lobby and disconnects:** The existing `main.gd` session owner also owns a compact direct-IP panel for create/join, player readiness, roster status, and host start. The server starts only when every connected player is ready. Removing a player during ACTIVE immediately re-runs the same winner-resolution rule as damage, so one remaining survivor ends the match.
- **Prop and ragdoll transport:** Keep high-rate player transforms on channel 1 and match state on channel 2. A separate 10 Hz unreliable-ordered channel 3 carries stable prop IDs, transforms, velocities, and grab owners. Player snapshots add only a knockdown bit; clients create the existing 11-body cosmetic ragdoll locally and clear it on authoritative recovery.
- **Windows audio gate:** Validate the actual target backend rather than extrapolating from WSL's dummy driver. Native Windows Godot selected WASAPI and sustained the reserved warning voice together with eight effect plays; physical loudness and taste remain human playtest judgments, not automated correctness claims.

## 2026-10-06 — Flood submersion feedback

- **Authority:** Derive the Flood head sample from the player's current authoritative capsule height. Standing remains sampled at 1.35 m, while crouching lowers the sample with the 0.95 m capsule, so presentation and damage agree.
- **Feedback:** Replicate compact per-player submersion times in the existing Flood snapshot. The local HUD distinguishes water below the head, the two-second breathing grace, and active 12 HP/s drowning with a blue overlay and explicit text; damage remains server-owned.

## 2026-10-06 — Extensible development hierarchy and Phase 0 baseline

- **Decision:** Reclassify the complete validated vertical slice as **Phase 0 — Init Project**. The former seven phases remain historical implementation evidence inside Phase 0 rather than active roadmap units.
- **Hierarchy:** Future work uses `phase → milestone → task`. A phase may contain multiple milestones; tasks are optional and exist only when a milestone needs multiple ordered work units. `progress.json` owns machine-readable state, while `docs/implementation-checklist.md` is its concise human-readable projection.
- **Next product phase:** Phase 1 is **UI Identity and Feedback**. It deepens the existing lobby, HUD, warning, spectator, results, pause, settings, motion, and audio presentation without copying another game's visual identity or adding progression, matchmaking, chat, inventory, or other unrelated systems.
- **Planning basis:** Independent roadmap, UI, and gameplay audits agreed that human playtest evidence and richer feedback have higher near-term value than adding disaster classes, maps, or platform infrastructure.

## 2026-10-06 — One active progress file per phase

- **Decision:** Root `progress.json` contains only the active phase. Once a phase passes all required gates, its complete state and evidence move to `docs/old-docs/progress-{phase-slug}.json`, and a fresh root file starts the next phase.
- **Reason:** Separating immutable completed evidence from current execution state keeps handoffs concise without losing validation history.
- **Safety:** Phase archives are append-only and must never be overwritten. The new active file links to the previous archive and starts with no inherited validation claims or changed-file diary.
