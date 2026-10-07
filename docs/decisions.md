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

## 2026-10-06 — Phase 1 UI token ownership

- **Decision:** `game/ui/ui_tokens.gd` is the single code-owned source for Toy Broadcast colors, typography, spacing, safe margins, radii, focus width, and shared Godot control styles. `main.gd` applies one generated `Theme` resource to the current top-level interface controls until later tasks extract dedicated HUD scenes.
- **Reason:** The existing UI mixed engine-default controls, scene-local panel styling, and per-label overrides. Central tokens create a stable visual contract without coupling presentation to authoritative match state or prematurely restructuring every screen.
- **Accessibility:** Keyboard focus uses a three-pixel warning-amber ring, disabled controls retain readable ink text, and neutral lobby status does not use the danger color.

## 2026-10-06 — Semantic gameplay HUD boundary

- **Decision:** The existing `Interface` canvas is a typed `GameplayHud` presenter. `main.gd` supplies semantic values such as health, survivor counts, match status, hazard lines, Flood exposure, and spectator target; only the presenter formats and mutates their controls.
- **Authority:** The HUD remains presentation-only. `MatchManager`, disaster components, and server snapshots continue to own gameplay state, while the presenter has no references back to those systems.
- **Migration:** Preserve existing node names and visual layout until Task 1.1.3 replaces the raw labels with responsive components, keeping established integration and network contracts stable during the refactor.

## 2026-10-06 — Responsive gameplay HUD components

- **Layout:** Anchor the cream health card to the lower-left safe margin, the timer card to top center, and the survivor pill to the upper-right safe margin. Godot canvas-item stretching preserves the 24 px design-space margin at 1280×720 and scales it consistently at 1920×1080.
- **Hazards:** Present at most two ordered active-hazard chips. Each uses a slate surface, warning-amber border, and explicit text so identity never depends on color alone; later warning work owns prioritization beyond this bounded tray.
- **Testing:** Network regressions assert semantic presented values rather than internal label paths. This keeps authoritative health, player counts, and hazard state covered while allowing later component-layout changes.

## 2026-10-06 — Contextual interaction prompts

- **Decision:** Remove the permanent prototype title and keyboard legend. Show one bottom-center `[F]` action only when the local player can grab an unowned prop or release their held prop; ordinary movement controls remain discoverable outside the gameplay HUD.
- **Eligibility:** `GrabManager.get_interaction_candidate()` is the shared read-only source for range, facing, player-state, and ownership eligibility. It reuses the same candidate in authoritative grab requests and reads replicated owner metadata on clients without granting mutation authority.
- **Suppression:** Hide the prompt outside ACTIVE play, while spectating, while the lobby is open, when eliminated, and when no eligible prop exists.

## 2026-10-06 — Major-warning hierarchy

- **Presentation:** One amber banner presents a deterministic vector icon, explicit disaster name, rounded-up countdown, and concise escape action for each of the six existing disasters. No gameplay state or warning timing is changed.
- **Priority:** Promote the warning with the shortest remaining time. Stable disaster order breaks ties; clearing that phase hands off to the next warning. Hide the banner outside ACTIVE play and while the lobby is open.
- **Readability:** Keep the existing maximum-two tray below the banner with compact 40 px chips while a warning is visible. The inspected 720p capture exposed player-head occlusion in the first layout; the revised stack ends above the representative player's silhouette at both supported resolutions. Persistent chip identity and combination presentation remain Task 1.2.2.

## 2026-10-06 — Persistent hazard and interaction chips

- **Identity:** Reuse the six deterministic vector symbols at 24 px with cream ink beside compact hazard names. Warning phases keep identity in the tray, but countdowns and escape instructions appear only in the major banner.
- **Interactions:** Electrified Flood water and active wind-driven Fire replace their constituent chips with one paired-icon chip naming the implemented interaction. Interaction chips precede ordinary hazards so the two-chip cap cannot hide them. Electrified water remains visible after the Lightning flash ends; warned Fire does not claim spreading flames before activation.
- **Boundary:** Continue using the existing read-only hazard-line contract and replicated disaster state. No hazard timing, selection, damage, networking, or gameplay authority changes. No generic overlap is labeled as an implemented combination.

## 2026-10-06 — Unified personal Flood danger

- **Presentation:** One bottom-anchored slate/amber card replaces the floating Flood label, full-screen tint, and flashing health number. Wading, breathing grace, and drowning replace the same status row; a single action row instructs the player to keep or get their head above water. Text communicates urgency without color or animation dependence.
- **Priority:** Local exposure takes instruction priority over the major warning action and grab/release prompt. Incoming hazard identity/countdown and persistent chips remain visible. Safety clears the card and restores the current warning action and interaction prompt; no control or gameplay ability is disabled by the presentation.
- **Authority and lifecycle:** Read existing per-player exposure and damage-rate state without altering the two-second grace boundary or health rules. Suppress local danger outside ACTIVE play, in the lobby, and during spectating. Additional warning motion remains Task 1.2.4.

## 2026-10-06 — Bounded warning motion and countdown feedback

- **Motion:** New warnings fade from 85% to full opacity over 0.16 s; final-three-second countdown decreases receive a 0.12 s color emphasis. Neither scales nor moves controls. Repeated presenter calls do not restart transitions; handoff/hide cancels stale tweens. `GameplayHud.reduced_motion` cancels motion immediately while preserving text and audio; persistence and a settings control remain Milestone 1.5.
- **Audio:** The HUD emits one signal on each new decrease into the final three seconds, never on entrance/handoff, duplicate snapshots, upward corrections, or as a catch-up burst. Reuse the existing synthesized jump cue at -16 dB in the four-voice effect pool; the reserved disaster-warning voice is untouched. Normal effects reset their voice to -7 dB on reuse. No new audio asset or audio system is introduced.
- **Validation:** Headless timing/lifecycle checks and display-backed overlap checks passed with Flood water visible. Local 4/8/20-peer checks and five network rematches passed; dummy-driver playback proves stream routing, not physical audibility or a multi-PC playtest.

## 2026-10-06 — Client disconnect recovery and electrical danger priority

- **Session ownership:** The inactive-ENet error was reproduced with real localhost server shutdown and failed retry. `main.gd` now replaces the closed peer with `OfflineMultiplayerPeer` before authority-dependent cleanup, disconnects client lifecycle signals, clears remote nodes/registries and stale hazard/prop/presentation state, and restores one local player in an accessible lobby. A null peer was insufficient because camera setup still needs a valid offline unique ID. Connection failure follows the same recovery path; connected clients retain non-authoritative gameplay.
- **Local danger:** Electrical contact takes priority over wading, breathing grace, and drowning: show ELECTRIFIED WATER with LEAVE THE WATER and the active damage rate (25 HP/s electricity, 37 HP/s with drowning). Expiry restores ordinary Flood feedback. Sample feet at the same origin used by electrical damage, including shallow contact; no damage or networking rules changed.
- **Regression:** `test_session_lifecycle.gd` exercises actual ENet handshake, server disconnect, unavailable-port failure, successful retry, repeated disconnect, registry restoration, and client/offline authority. Combined Flood damage/presentation checks cover wading, grace, drowning, expiry, and dry ground, resolving the Milestone 1.2 review finding.

## 2026-10-06 — Structured lobby roster

- **Presentation:** Replace the multiline player label with a bounded vertical scroll container. Reuse rows keyed by numeric peer ID, sort deterministically, remove disconnected players immediately, and show explicit READY/WAITING badges beside names. HOST identifies ENet server ID 1; YOU follows the actual local peer ID. Long names use ellipsis rather than expanding the panel.
- **Layout and scope:** Four players fit without scrolling; twenty players remain reachable with a vertical scrollbar. Rows inherit shared Toy Broadcast tokens and theme. The roster only reads supplied match records; ready/start ownership, backdrop, HUD suppression and controller focus remain Task 1.3.2.
- **Evidence:** Dedicated roster geometry/state tests, inspected 720p/1080p renders, lifecycle/theme/HUD regressions and five playable network rematches passed in the Linux orb. This is not native Windows performance or multi-PC playtest evidence.

## 2026-10-06 — Lobby connection and focus states

- **Connection:** Label IP/UDP fields and validate a nonempty join address and integer port 1–65535 before altering the offline match. Lock fields during sessions, keep Joining until the local roster arrives, disable pending Ready, and preserve actionable failure/retry copy. Only a host sees START; its status distinguishes insufficient players, missing readiness and all-ready eligibility. Authority remains in existing ready/start methods.
- **Focus:** Wrap Tab and directional focus through eligible controls only, repair focus when connection/readiness changes, and use explicit controller A/B bindings for confirm/cancel. Focused roster up/down scrolls; right/Tab leaves it. Closing via button/Escape restores cursor capture. No Steam/account/session systems added.
- **Overlay:** Dim the world and hide gameplay HUD while the lobby is open. Block local camera/grab/control input and submit neutral local movement, but continue server physics, hazard simulation, health and match time. Close the overlay on authoritative ACTIVE/RESULTS transitions for both host and clients.

## 2026-10-06 — Elimination and spectator presentation

- **Transition:** Immediately begin the existing living-target camera on authoritative elimination. A bottom-centered cream target card briefly includes the actual cause and floored survival time for 2.5 seconds, then collapses to its compact layout. One bounded 0.16-second opacity entrance respects the shared reduced-motion switch; repeated presentation does not replay the notice.
- **Controls:** Previous/Next buttons, Q/E and controller LB/RB route to the existing local spectator controller. Keep mouse visible for eliminated players, focus eligible controls, disable cycling for fewer than two targets, and hide own health. Reconcile living targets each presentation frame so eliminated/disconnected targets cannot leave stale cards; emit target changes only when selection changes.
- **Lifecycle:** Lobby hides the card and blocks cycling without changing selection; closing restores spectator access. Results hide/clear the notice, while ACTIVE/rematch stops spectating before restoring camera/input. The card reads match records and never mutates health, disasters, ranking or session authority. One/zero-target fallback fixtures are presentation checks; actual one-survivor/no-survivor multiplayer matches correctly show results.

## 2026-10-06 — Structured results columns

- **Presentation:** Replace proportional-font space alignment with one results-table presenter, fixed rank/player/time/disasters/damage columns and a remaining-width outcome column. Headings stay outside the vertical scroll viewport; four rows fit, twenty remain reachable by mouse, keyboard or controller. Long names/causes use ellipsis and full-text tooltips. Rows are reused by peer ID and removed when absent.
- **Ranking:** Read existing authoritative records and winner IDs without mutation. Preserve survivor-first, descending elimination time, descending disasters survived, ascending damage ordering; numeric peer ID resolves exact ties independently of dictionary insertion order. Winner selection, scoring and transport are unchanged.
- **Scope:** Existing winner marker/title and rematch prompt remain. Winner emphasis/reveal/award are Task 1.4.2; authority-aware actions and complete results HUD suppression are Task 1.4.3. Rendered actual results confirmed health/survivor cards still visible, so that gate is explicitly failed rather than claiming milestone completion.

## 2026-10-06 — Winner emphasis and bounded results reveal

- **Emphasis:** Authoritative winner IDs alone select larger coral rank/name text alongside the existing star; shared winners all receive the same static emphasis. Contain long/shared headings with ellipsis and full-text tooltips. No winner-selection or score changes.
- **Motion:** Reuse one parallel opacity tween: each row fades from 85% to 100% over 0.16 seconds, staggered by 0.035 seconds with delay capped after row eight (0.405 seconds total even for twenty players). Identical presentation does not replay or reset scroll; new content cancels old motion before row reuse/removal. Hiding cancels and clears the round cache; the shared reduced-motion switch immediately restores full opacity and prevents new tweens.
- **Award:** Show one optional Most disasters survived line for a positive maximum in existing records, including every tied leader in numeric peer-ID order. Put the count before names so ellipsis cannot hide it; provide full copy as a tooltip. Zero counts and empty results clear the award. No new stat tracking, transport, assets or sounds.

## 2026-10-06 — Map safety milestone and future expansion

- **Priority:** User-reported endless falling exposed an unimplemented design-bible requirement. Add required Milestone 1.7 to active Phase 1, scheduled after current Milestone 1.4 and before settings/review. Existing milestone IDs and completed-phase archives remain unchanged.
- **Safety contract:** Retain the current 64 × 64 m footprint for this fix. Provide a readable continuous colliding perimeter and authoritative out-of-bounds elimination fallback, explicit death cause, held-prop release, spectator/results integration and rematch cleanup. No competitive respawn. Gates remain unrun until implementation and executed checks.
- **Expansion:** Record the user's larger/richer-map request in Phase 4: expand the existing town with usable buildings, props, refuges and routes. Choose dimensions during that phase's design and revalidate hazards, spawns, navigation, multiplayer and performance; do not rewrite the current design bible with an unvalidated size.
- **Crash evidence:** Endless falling is confirmed by missing boundary/fall handling in the implementation. The supplied log separately reports a broken X-server connection; causation between falling and process termination remains unverified.

## 2026-10-06 — Authority-aware results actions and complete HUD suppression

- **Actions:** Host and solo results expose Rematch and Return to Lobby; clients retain rankings and explicit waiting copy without session-changing buttons. Both actions enforce authority and RESULTS state in code. Rankings and buttons form a wrapped Tab/controller left/right focus loop, with controller A confirmation and a visible cursor for surviving winners too. Settings entry waits for the real Milestone 1.5 screen rather than presenting a dead control.
- **Lifecycle:** Return to Lobby cleans hazards/audio/props/spectating, resets player bodies and match records/readiness, and keeps peers connected. Direct rematch reuses that reset, readies all participants and starts immediately; explicit lobby return requires renewed network readiness. Offline lobby gains a solo Start action. Results suppress all gameplay HUD components and local gameplay input; ACTIVE restores them.
- **Replication:** Preserve authoritative names in match snapshots. Empty name entries encode existing default peer names compactly; entirely default rosters omit entries, custom names remain explicit, and malformed name-array lengths are rejected. Lobby/results use reliable delivery, while ACTIVE match snapshots retain their existing unreliable mode. A shared increasing snapshot sequence prevents delayed session/live packets from rolling results or rematches backward; joining resets the client's sequence watermark.
- **Verification:** Results-action and HUD regressions cover missing controls, visibility call order, surviving-winner input/cursor, focus/confirmation, authority rejection, reset/restoration, name preservation and both directions of snapshot reordering. The playable 4/8/20-player fixture compares every ranking cell with the host, independently asserts expected death-time order, checks client rejection and connected lobby return, and rejects oversized unreliable packets. Separate two-peer checks retain five actual rematches. Rendered results use WSL llvmpipe/Dummy audio, not physical controller/audio or native Windows performance evidence.

## 2026-10-06 — Local pause, settings and UI audio

- **Order:** Latest explicit user instruction overrides the earlier sequence: finish/commit 1.5, finish/commit 1.6, then reverify 1.1–1.6. Milestone 1.7 remains required; Phase 1 cannot roll over yet.
- **Local menu:** Escape/controller B opens pause, returns from settings to pause, then resumes. Only local input is blocked; the SceneTree, authority timer, hazards and networking continue in solo and online sessions. Settings is available from results for every peer, without session-changing authority. Match completion/elimination cannot steal focus from the menu.
- **Preferences:** ConfigFile in `user://settings.cfg` stores eight settings with type/range validation, immediate application and visible save failure. Sensitivity/invert-Y affect the real mouse controller; camera-shake level controls bounded cosmetic knockdown feedback. Reduced motion also disables that shake and existing HUD/results tweens. Native display mode and separate Master/Effects/Warnings bus gains apply immediately. `--settings-path=` isolates automated preference fixtures.
- **Audio:** Reuse existing generated cues, with no new assets or dependencies. Focus/confirm/back/error/ready/results use the existing four-voice effects pool; warning countdown uses Warnings routing, restored to Effects on normal reuse. The dedicated disaster-warning voice remains reserved. Dummy playback validates routing, not speaker loudness.
- **Rendering:** Dynamic controls receive the shared theme before insertion; CanvasLayer does not propagate a Control theme. HSlider has no focus StyleBox slot, so draw the shared amber focus ring explicitly. Panels are opaque with explicit percentages/ON–OFF values; pause uses a compact panel, settings a full eight-row panel.

## 2026-10-06 — UI regression and rendered review

- **Lifecycle:** An unmounted main scene exposed orphaned UI children in lobby/results member initializers. Create those children in `_ready` so ownership begins immediately; a before/after orphan-count regression fails the old implementation and now exits without CanvasItem/font-RID diagnostics. Runtime row reuse and ranking behavior are unchanged.
- **Evidence:** The combined runner checks 25 suites plus persistence restart and four network matrices, requiring explicit success markers and rejecting runtime/parser/font errors. Preserve semantic component, authority, focus and geometry assertions; exact warning/action copy remains intentionally tested. Spectator fallback fixtures now reset hidden results state and require actual card visibility before capture.
- **Performance:** Profile the current checkout via checksum-verified native Windows Godot 4.7.2 and WSL UNC path. Explicitly disable V-Sync for throughput; no global gameplay display policy is changed. Ryzen AI 7 H 350 / Radeon 860M at 1280×720 Compatibility, four staged Flood/Tornado demo players, 120 warmup plus 600 samples: two p95 1.08 ms runs with identical UI node identities. Default-V-Sync p95 24.09/24.65 ms is recorded separately as frame pacing, not silently discarded or claimed fixed. The profiler fails nonzero for budget or identity regression.

## 2026-10-07 — Continuous perimeter, authoritative safety and Phase 1 closure

- **Boundary:** Replace the five separated north fences with four cream static walls and slate caps, 0.5 m thick and 3.2 m tall around the unchanged 64 × 64 m block. East/west spans end at north/south inner faces so corners close without coplanar overlap; caps sit above walls rather than sharing visible faces. Existing map-prop tagging and rematch reconstruction apply. Runtime generation/provenance is recorded in the manifest; no external assets or new scene system.
- **Safety:** At each authoritative physics step, collect living players whose feet exceed ±32 m in X/Z or fall below −8 m, then apply one damage batch with current HP and cause `Out of bounds`. Exact thresholds remain inclusive. Batching preserves same-step shared elimination; existing health/death signals release props, hide bodies and drive spectator/results feedback. Clients cannot author this transition, and dead/non-active records are ignored. No respawn or disaster immunity.
- **Validation:** A dedicated suite exercises all four edges/corners with walking, sprinting, jump and bounded knockdown impulse, proves each attempt reaches the collider, tests both sides of safety thresholds, one-shot death, prop release, spectator copy, simultaneous outcomes and rematches. Five live ENet rematches alternate outside-map and below-floor escapes and verify client rejection and replicated results. Fresh full Phase 1 regression, both-resolution visual review and native Windows overlap profiling retain existing limits. The X-server connection failure is not reproduced or claimed resolved.
- **Review corrections:** Map-prop regression caught omitted wall tags. The spring arm overwrote an initial review-camera transform; the corrected fixture uses a separate camera and a HUD-free full-map view. Inspected captures exposed coplanar cap artifacts; caps and side spans now meet without duplicated visible faces. An intermittent rendered HUD countdown-settle assertion relied on wall-clock timer/tween scheduling; tests now pause and explicitly step both sides of the 0.16/0.12-second durations, without changing production motion.
- **Next phase:** Archive complete Phase 1 evidence and initialize only Phase 2 — Human Playtest and Core Feel. Windows packaging and structured multi-PC feedback are next, not additional map expansion or gameplay systems.

## 2026-10-07 — Phase 2 planning and evidence boundary

- **Sequence (refined with user approval):** Use five separately reviewable milestones: reproducible Windows build (2.1), playtest readiness/instructions/exported session validation (2.2), human playtest baseline at 3–4 and 6–8 players (2.3), evidence-driven core-feel improvements (2.4), and human follow-up/phase review (2.5). This splits the original three milestones without adding features or weakening gates. Only planned Phase 2 IDs are reorganized; completed-phase archives remain unchanged. The Phase 5 export item means release hardening, not postponing the first playable package. No Steam service, new disasters, shove or map expansion in Phase 2.
- **Review boundaries:** Build completion does not imply session readiness; tuning completion does not imply human improvement. Each milestone depends on the preceding one, all five must pass before closing the phase, and failed follow-up returns observed issues to 2.4 before repeating 2.5. Create improvement tasks from baseline findings rather than speculative work. Task 2.1.1 remains the next action.
- **Build contract:** Pin matching Godot 4.7.2 templates, compare repeated same-revision export payloads, record packaging-only nondeterminism explicitly, expose revision/engine identity and package checksums, and validate the executable without editor/repository dependencies. Existing native Windows editor profiling and localhost ENet checks cannot pass exported-build or physical LAN gates.
- **Research contract:** Observe normal rounds without ongoing coaching; capture death explanations before revealing the cause, voluntary rematch interest separately from requested test rounds, and recurring emergent causal chains. Record hardware, display/V-Sync, network, input, build and actual round durations. Human/PC availability is a dependency that automation cannot remove.
- **Proposed exit criteria:** At least 80% of sampled deaths correctly explained without coaching, a majority independently willing to rematch in each follow-up group, and at least two distinct emergent patterns recurring across rounds, with no unresolved session-blocking/control failures. Report counts and contradictory evidence; these are practical product gates, not statistical proof or current achievements.
- **Current evidence:** Fresh regression returned `UI_REGRESSION_OK suites=26 matrices=4 persistence_restart=passed`. The persistence save process also reported 48 ObjectDB leaks and four resources in use at shutdown; their cause is not re-established here. Default-V-Sync pacing, physical controller/audio feel, multi-PC behavior and the reported X-server shutdown remain unverified or unresolved, not silently declared fixed.

## 2026-10-07 — Reproducible Windows playtest package

- **Pipeline:** One Bash command exports committed HEAD through `git archive` into a fresh temporary tree; no existing editor cache or untracked source can affect the build. Reject dirty tracked source and existing output directories. Pin official Godot 4.7.2 / x86_64 release templates, verified against the official release SHA-512 list. Keep downloads and exports untracked.
- **Contents and identity:** Keep EXE and PCK separate. Disable executable resource modification and code signing for this unsigned prototype; no installer, distribution service or Steam work. Ship build notes with full revision/engine/renderer and SHA-256 hashes. Inject revision only into the staged project settings and print it on main-scene startup; development checkout logs say `development`, avoiding misleading release identity.
- **Determinism:** Initial repeated exports had identical EXE/scripts/audio but different converted scene bytes. Retaining authored text resources with `editor/export/convert_text_resources_to_binary=false` removes that variability: two fresh exports now match EXE, PCK and build-note hashes exactly. No binary post-processing or ignored payload differences. Runtime loads the same authored geometry/materials and compiled scripts.
- **Validation boundary:** Release executable tested from a fresh native Windows directory containing only the four delivered files, on Intel UHD Graphics 630 at 1280×720 Compatibility/WASAPI. Correct revision, rendered town/avatar/HUD, exit 0 and no missing-resource/script errors. Fresh 26-suite/four-matrix regression passes; shutdown-only resource diagnostics remain. Settings persistence, exported host/client/rematches/recovery and physical LAN checks remain Milestone 2.2.

## 2026-10-07 — Playtest readiness evidence layers

- **Guide:** Use package/checksum identity rather than matching source checkouts. Document executable launches, trusted-private-LAN/firewall setup, host readiness/actions, local settings and current Flood danger feedback. Add a concrete two-PC readiness checklist and log collection; no global firewall/security changes performed.
- **Automated boundary:** The release template ignored an invalid external `--script` probe and launched normal gameplay. Do not add a shipped cheat/test loader merely to enable fixtures. Reuse existing external GDScript fixtures through the matching native Windows editor with `--main-pack` pointing at the exact checksum-verified shipped PCK, never source `--path`. Keep driver/engine/build identity explicit in the new PowerShell runner and report these checks as exported-payload, not release-runtime or physical LAN evidence.
- **Actual release check:** Mouse/keyboard automation on two unchanged release EXEs verified ready roster, host start, active two-player view, host-loss recovery and client rejoin on localhost. Inspected snapshots and logs support those observations; they do not prove five release-runtime rematches or physical listening.
- **Open evidence:** Native payload settings/restart/audio routing/recovery and five-rematch fixture passed. A prior client run failed only Meteor presentation; added diagnostic state without weakening checks and recorded the passing rerun alongside the failure. Its intermittent cause remains unconfirmed. Milestone 2.2 stays blocked until actual release five-rematch/settings/audio confirmation and two-PC LAN evidence are recorded; do not start 2.3 meanwhile.
