# Phase 1 — UI Identity and Feedback: Historical Decisions

Archived on 2026-10-08. This phase is complete; these entries preserve historical decisions. Current decisions live in [the active-phase log](../decisions.md); validation evidence lives in [the Phase 1 progress archive](progress-phase-1-ui-identity-and-feedback.json).

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
