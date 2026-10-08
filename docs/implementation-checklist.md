# Disaster Party Development Roadmap

This checklist executes `DESIGN.md`; the original brief is archived at `docs/old-docs/PROMPT.md`. `progress.json` is the operational source of truth when this projection and recorded state differ.

## Work hierarchy

```text
Phase — a product outcome
└── Milestone — a reviewable capability with acceptance gates
    └── Task — an optional ordered work unit for a large milestone
```

- A phase may contain one or many milestones.
- A small milestone may have no tasks; do not create bookkeeping-only tasks.
- Finish and validate the current milestone before opening another milestone.
- A phase is complete only when every required milestone gate passes.
- Keep exactly one executable `next_action` in `progress.json`.
- Record durable design/architecture choices in `docs/decisions.md`, not here.
- On phase completion, archive the full file as `docs/old-docs/progress-{phase-slug}.json`, then replace root `progress.json` with a fresh file containing only the next phase.

## Phase 0 — Init Project ✅

Everything implemented and validated before this roadmap reset belongs to Phase 0.

### Milestone 0.1 — Project and playable foundation ✅

- Godot 4.7.2 project and fresh-checkout bootstrap.
- Deterministic generated assets, shared art language, Toy Town map, character, required animation contracts, and synthesized audio.
- Responsive controller, camera, sprint, jump, crouch, grabbing, bounded knockdown/ragdoll, and recovery.

### Milestone 0.2 — Complete multiplayer vertical slice ✅

- Lobby readiness, authoritative match/health/death/winner state, spectating, results, and rematch.
- Meteor, Flood, Tornado, Earthquake, Lightning, Fire, randomized Director, and two-disaster overlap.
- Flood + Lightning and Tornado + Fire behavior-changing interactions.
- Authoritative movement, shared props, ragdoll presentation, disasters, and match state replicated in playable ENet sessions.

### Milestone 0.3 — Validation baseline ✅

- Fifteen headless behavior suites.
- Separate-process authority and playable two-peer checks.
- State-contract 2/4/8/20-client matrix and playable 4/8/20-player matrix.
- Five-rematch cleanup, rendered gameplay gates, native Windows performance, and native WASAPI overlap checks.

Phase 0 is complete for automated, rendered, scale, performance, and target audio-path gates. Its full evidence is archived in `docs/old-docs/progress-phase-0-init-project.json`. A physical multi-PC human LAN feel/loudness playtest remains useful product research, not a missing Phase 0 implementation gate.

## Phase 1 — UI Identity and Feedback ✅

Goal: replace the functional prototype-label UI with a cohesive **Toy Broadcast** presentation—chunky rounded cards, broad readable icons, warm cream/slate surfaces, restrained motion, and strong hazard hierarchy—while preserving world visibility and server authority.

### Milestone 1.1 — Theme, responsive HUD, and component boundary

- [x] Task 1.1.1: Define reusable color, typography, spacing, focus, panel, button, and safe-margin tokens from `DESIGN.md`.
- [x] Task 1.1.2: Extract UI presentation from raw label mutation in `game/main.gd` into semantic HUD components.
- [x] Task 1.1.3: Replace floating labels with a health display, timer card, alive-count pill, and maximum-two active-hazard tray.
- [x] Task 1.1.4: Remove the permanent sandbox title/control legend and show only contextual control prompts.

Acceptance: one shared theme; no permanent debug copy; no clipping at 1280×720 and 1920×1080; readable over representative light and dark scenery; existing gameplay/network state remains authoritative.

Reverified after Task 1.2.1: `tests/test_milestone_1_1.gd` checks theme sharing, authority isolation, layout, contextual actions, and focus; controlled light/dark captures at both resolutions and the 4/8/20-player network matrix passed. Full commands and limitations are recorded in `progress.json`.

### Milestone 1.2 — Warning and personal-danger hierarchy

- [x] Task 1.2.1: Add one reusable major-warning banner with disaster icon, name, countdown, and concise action.
- [x] Task 1.2.2: Add compact active-hazard and combination chips for persistent context; six vector identities and paired interaction chips validated at 720p/1080p without repeating major-warning instructions.
- [x] Task 1.2.3: Unified personal danger prioritizes LEAVE THE WATER during electrical exposure, including combined drowning damage and shallow contact; expiry restores ordinary Flood states. Combined damage/presentation regressions pass.
- [x] Task 1.2.4: Add bounded opacity/countdown feedback, a reduced-motion presenter switch, and quiet final-three-second cues through the existing effect pool without replacing the dedicated warning voice.

Acceptance: hazard identity is never color-only; at most one full warning and one personal-danger banner compete for attention; every incoming disaster shows icon, name, countdown, and action; overlap remains readable.

Milestone 1.2 complete after review remediation: combined electrical damage/personal-instruction coverage and 720p/1080p renders pass; timing, bounded audio, five network rematches, and local 4/8/20-peer regressions remain green. `test_session_lifecycle.gd` also verifies ENet disconnect/failure/retry restores a valid offline peer before authority checks, removing inactive-peer error spam. Settings persistence and physical audio review remain later work.

### Milestone 1.3 — Lobby and spectator presentation

- [x] Task 1.3.1: Reusable player rows with HOST/YOU markers, READY/WAITING badges, long-name ellipsis, four-row fit and scrollable 20-player roster; headless and inspected 720p/1080p checks pass.
- [x] Task 1.3.2: Labeled/validated connection fields, inline joining/retry status, explicit host-start gating, wrapped keyboard/controller focus, dim backdrop and HUD suppression; local input is neutral without pausing authority.
- [x] Task 1.3.3: Brief cause/survival notice collapses to a compact target/survivor card; previous/next buttons, Q/E and controller shoulders cycle living targets; own HP hidden, disconnected targets refresh and results/rematch clear presentation.

Acceptance: a 20-player roster scrolls without overlap; ready/start ownership is unambiguous; keyboard/controller focus order works; lobby and spectator state remain presentation-only.

Milestone 1.3 complete and freshly reverified: headless behavior/regression suites, inspected 720p/1080p lobby/spectator states, real ENet lifecycle, five network rematches and 4/8/20-player spectator/authority matrix pass. Network fixtures must wait for authoritative match rosters, not merely spawned nodes, before measuring movement; abrupt-close lifecycle checks use a test-only timeout inside their recovery deadline. Physical controller/multi-PC and native Windows performance are not established by orb checks.

### Milestone 1.4 — Structured results

- [x] Task 1.4.1: Reusable ranking rows with explicit rank/player/time/disasters/damage/outcome columns, long-text ellipsis/tooltips and scrollable twenty-player results; headless, inspected 720p/1080p and five ENet rematches pass.
- [x] Task 1.4.2: Static winner emphasis, capped 0.405s opacity reveal with immediate reduced-motion cancellation, and optional/shared Most disasters survived award from existing records; inspected 720p/1080p, timing/lifecycle and five ENet rematches pass.
- [x] Task 1.4.3: Host/solo Rematch and Return to Lobby actions, client waiting state, wrapped keyboard/controller focus, cursor recovery and complete results HUD/input suppression. Settings entry is deferred until the real screen exists in Milestone 1.5.

Acceptance: 4- and 20-player results remain legible; all peers show identical authoritative rankings; five network rematches remain green; gameplay HUD is hidden beneath results.

Milestone 1.4 complete: all 24 headless suites pass, 720p/1080p results and action captures were inspected, five real ENet rematches pass, and 4/8/20-player sessions verify exact authoritative rankings/cells, client authority rejection and connected lobby return. Lobby/results snapshots are reliable and sequence-ordered against live packets; final network logs have no errors or oversized-unreliable-packet warnings. Later Milestone 1.6 fixed the reproduced UI/font lifecycle leak; some successful-exit audio diagnostics remain.

### Milestone 1.5 — Pause, settings, accessibility, and UI audio

- [x] Task 1.5.1: Add an online-safe pause overlay that releases local input without pausing server simulation.
- [x] Task 1.5.2: Persist master/effects/warning volume, mouse sensitivity, invert-Y, camera-shake level, fullscreen/windowed mode, and reduced motion.
- [x] Expose local Settings from results for every peer; opening settings does not grant session authority or pause online simulation.
- [x] Task 1.5.3: Reuse generated cues in the four-voice pool for focus, confirm, back, error, ready, countdown, and results reveal.

Acceptance: settings survive restart; warning volume remains independently controllable; reduced motion removes scale/pulse dependence; input focus and cursor capture recover correctly; online pause never stops authority.

Milestone 1.5 complete: dedicated behavior/render checks, a two-process persistence check and actual ENet host/client pause plus five rematches pass. Settings applies eight preferences immediately, draws explicit slider focus, and preserves menu focus when the match ends underneath it. Existing intermittent WAV/playback shutdown diagnostics remain. Per the latest user instruction, 1.5 and 1.6 precede the still-required 1.7; do not close Phase 1 without map safety.

### Milestone 1.6 — UI regression and rendered review

- [x] Audit semantic component-state tests (vitals, visibility, focus, authority and geometry); retain exact hazard/action copy assertions where wording is a required behavior. Add unmounted-scene orphan-count and visible-capture regressions.
- [x] Run all Phase 0 regressions and multiplayer matrices with `GODOT_BIN=$(command -v godot) tests/run_ui_regression.sh` (25 suites, four matrices, separate-process persistence).
- [x] Render and inspect lobby, default HUD, single warning, overlap, drowning, spectating, results, pause, and settings at 1280×720; inspect core states at 1920×1080.
- [x] Re-profile representative overlap and reject UI scene rebuilding; native Windows, AMD Radeon 860M, Compatibility, 1280×720, four demo players, 120 warmup/600 samples, two uncapped p95 1.08 ms runs with stable UI node identities.

Acceptance: all prior functional gates pass; inspected captures meet hierarchy, consistency, accessibility, and no-clipping requirements; representative performance remains within the validated target budget.

Milestone 1.6 complete. Fixed the reproduced orphaned UI children/font-RID leak by allocating children in `_ready`, not unparented member initializers. Visibility assertions caught fallback captures still suppressed by results state; reset the presentation fixture before rendering. Uncapped throughput passes, but default-V-Sync p95 24.09/24.65 ms is a separate frame-pacing limitation, not claimed fixed gameplay. Some Dummy-audio shutdown diagnostics remain. See the advancing skill's recovery guidance; do not suppress font/RID or script errors in the runner.

### Milestone 1.7 — Map boundary and out-of-bounds safety

User-requested addition to Phase 1. Executed after 1.5/1.6 per the superseding user instruction; retain existing milestone IDs rather than renumbering recorded work.

- [x] Establish a continuous, readable toy-town perimeter around the current 64 × 64 m block, with collision on all four sides and corners; do not rely on the existing separated north fences.
- [x] Add a server-authoritative out-of-bounds safeguard for players escaping the perimeter or falling below the map. Eliminate once through existing health/match state with an explicit out-of-bounds cause; release held props and enter the existing spectator/results flow. No competitive respawn or client-authored death.
- [x] Verify walking, sprinting, jumping and disaster impulses at edges/corners, below-map fallback, host/client agreement, solo death, simultaneous eliminations, and rematch reset. Render and inspect the perimeter and death feedback.

Acceptance: ordinary traversal cannot leave the play area; escaped players cannot fall indefinitely; out-of-bounds death is clearly signaled and replicated; existing rankings, spectator behavior and five network rematches remain correct. Do not claim this resolves the reported X-server shutdown without reproducing that failure separately.

Scope: safety and boundary readability only. Enlarging the footprint and adding more map content are planned in Phase 4, not silently included in this fix.

Milestone 1.7 and Phase 1 complete: `MAP_SAFETY_OK checks=96` headless and `checks=99` at both rendered resolutions; all 26 suites, separate-process persistence and four multiplayer matrices pass. Five real network rematches alternate escaped/below-map client deaths, verify identical cause/results and reject client-side elimination. Inspected the four-wall overview, clean corner and actual death feedback, plus representative Phase 1 UI states at both sizes. Native Windows Radeon 860M overlap profiling passes twice at p95 4.09 ms with stable UI nodes. HUD motion tests now explicitly step both sides of tween-duration boundaries rather than relying on wall-clock scheduling. Full evidence is archived in `docs/old-docs/progress-phase-1-ui-identity-and-feedback.json`; `progress.json` contains fresh Phase 2 state. Physical multi-PC/controller/audio playtesting, default-V-Sync frame pacing, and the reported X-server shutdown remain separate limitations, not claimed fixed.

## Phase 2 — Human Playtest and Core Feel (in progress, current)

Goal: deliver Internet-hosted rooms joined by custom room ID, then establish whether the prototype is understandable, responsive and worth rematching with friends. The user's Internet-room request supersedes the earlier mandatory LAN readiness gate and custom-backend deferral. No new gameplay systems or map expansion in this phase; no design for hundreds of thousands or millions of users.

### Milestone 2.1 — Reproducible Windows Playtest Build

- [x] Task 2.1.1: Install/verify matching Godot 4.7.2 export templates, add a Windows x86_64 Compatibility preset and one repeatable export command. Export twice from the same clean revision; compare payload hashes and document any nondeterministic packaging metadata. Keep tools, caches, tests and review artifacts out of the package.
- [x] Task 2.1.2: Identify the build by source revision, engine version and package checksum in the delivered build notes and an accessible in-game/log surface. Launch the exported executable on native Windows without an editor or repository dependency and verify no missing resources. Record OS/GPU, resolution, build identity and logs.

Acceptance: reproducible export evidence, no missing resources/editor dependency and identifiable matching packages. Existing editor-based tests do not satisfy these gates.

Milestone 2.1 complete: official templates verified against release SHA-512; `tools/export_windows.sh` exports isolated committed HEAD. Initial scene-only binary-conversion variability was reproduced and resolved by retaining authored text scenes. Two exports of revision `7eb1f2520795da5eccf826a6be70261816fa4459` match EXE/PCK/build-note hashes exactly. A fresh native Windows directory with only four package files ran 600 iterations at 1280×720 on Intel UHD Graphics 630 / Compatibility / WASAPI, printed correct identity and exited 0 without resource/script errors. Standalone screenshot inspected. Full regression passes 26 suites, persistence and four network matrices; shutdown resource diagnostics remain recorded. Exported session/LAN readiness is not claimed and remains 2.2.

### Milestone 2.2 — Internet Rooms and Playtest Readiness

Depends on 2.1; implement Tasks 2.2.3–2.2.7 in order, validating each before starting the next. Start with one Linux server machine, a small room service and one headless Godot process per room on a bounded UDP port range. Retain Windows clients, solo testing and direct-IP listen hosting for development. Multi-machine placement is a later optimization, not a current gate.

- [x] Task 2.2.1 (historical): Executable direct-IP/LAN guide and evidence boundary delivered. It does not document the future room service.
- Task 2.2.2 (cancelled, not passed): Mandatory physical LAN smoke superseded by Internet readiness below. Existing release and exported-PCK evidence remains in `progress.json`; unfinished settings/audio checks carry forward to 2.2.7.
- [x] Task 2.2.3: Add explicit playerless dedicated-server launch. Remove server peer 1 from playable rosters, alive counts, readiness, results and cameras in this mode; keep all gameplay authority on the server. First admitted player becomes room owner; authorize start/rematch/return-to-lobby requests by actual sender, readiness and match state, not client claims. Transfer ownership deterministically to the longest-connected remaining player on owner disconnect without stopping the match. Test unauthorized/stale requests, no phantom host, disconnect cleanup, and unchanged solo/listen-host behavior before completion.
- [x] Task 2.2.4: Implement a small room service with versioned create/join responses (room ID, public endpoint, compatible build/protocol, short-lived admission token). Define normalized custom IDs, bounded length/allowed characters, atomic duplicate rejection and generated-ID fallback. Room ID is a locator, not a secret; support optional passwords without storing/logging plaintext. The dedicated server validates room-bound, expiring, single-use admission before registering gameplay players; no unrestricted UDP bypass. Use bounded request rates, player/room/process limits and startup deadlines. Launch fixed executable/arguments (never shell-interpolated room input); publish only ready rooms, remove dead rooms, expire empty rooms, and reclaim ports on failure/shutdown. Start with an in-memory registry and local process allocation; restart invalidates rooms/tokens rather than pretending matches survive. Test collisions, concurrent capacity reservations, bad/expired/replayed/wrong-room tokens, version mismatch and crash cleanup.
- [x] Task 2.2.5: Add Windows Create Room / Join Room ID flow with optional password, owner/waiting/readiness presentation and retryable errors for unavailable service, unknown/full room, duplicate ID, bad password, incompatible build and failed server connection. Clients obtain endpoints through HTTPS, then connect via ENet/UDP; do not expose raw-IP entry as the normal Internet flow. Inspect rendered lobby/results/recovery states at 720p/1080p; verify settings/solo and direct-IP development paths still work.
- [x] Task 2.2.6: Provide a local Docker test topology with room service/server and separately addressed clients; run at least two simultaneous rooms to prove isolated rosters, health, hazards, results and rematches. Run 4- and 8-player sessions, five rematches, owner transfer, rejected session-control requests, failed admission, full capacity, service outage, server crash, empty-room expiry, restart and port reclamation. Record room/player counts, CPU/RAM, tick timing and network conditions to set a conservative measured capacity; do not extrapolate to massive concurrency. Preserve existing 20-player regression coverage without treating it as public-service capacity. Containers test networking/lifecycle, not real Internet routing or physical audio.
- [ ] Task 2.2.7: Rebuild/version-identify reproducible Windows clients and headless Linux servers. Prepare operator instructions for TLS, public endpoint/UDP range, modest room limits, logs without credentials, start/stop and failure recovery; obtain specific approval before provisioning/deploying or changing shared firewall/DNS. Verify release clients on separate Windows PCs across different Internet networks create/join by custom ID without player-side port forwarding, see consistent ready/start/movement/props/warnings/death/spectating/results, complete five rematches, transfer owner and retry after server loss. Record server/client builds, hardware, latency/network conditions and logs; check assets, settings restart and physical warning/effect audibility. Update `GUIDE.md` only with executable implemented commands and tested limitations. Leave Internet/human gates blocked when endpoints or people are unavailable.
  - [x] Matching reproducible Windows/Linux bundles, standalone Linux lifecycle and native Windows launch checks.
  - [x] Operator runbook, credential-free logging boundaries and documented failure recovery.
  - [x] Local EC2 Terraform preparation with stage-specific names/state guidance, separate provision/runtime roles, EIP/network rules, Caddy/systemd bootstrap and mocked safety tests. See `infra/ec2/README.md`; no EKS, live apply, DNS change or automatic deployment performed.
  - [x] Main-only existing-EC2 build/deploy workflow: Linux workflow artifact, scoped OIDC/SSM, checksum/revision checks and startup rollback. Actionlint/ShellCheck and isolated mock checks pass; GitHub run37753298487 build/deploy now succeeds after operator IAM/SSM/bootstrap setup. No local AWS inspection. Terraform provisioning is no longer the selected path; Windows distribution is deferred.
  - [x] Public two-source-client Docker transport/gameplay check: after operator fixes SG UDP port0 to29810–29811, real Godot TLS Create/Join/admission, roster/ready/start/movement, Flood/health and later Meteor observations, six natural results/five rematches, owner transfer/new-owner rematch pass on unchanged6fb1e8d EC2 server. No runtime errors; sampled RTT124–137ms. Two subnets share host/upstream NAT, not physically independent networks or Windows release clients.
  - [x] Matching6fb1e8d Windows Internet ZIP delivered locally/Windows Downloads with endpoint launcher and checksums. Repeated exports identical; native release launch/render inspected and launcher endpoint argument verified. Exact-PCK native editor fixtures pass settings/restart/recovery/five rematches; not release Internet or physical audio evidence.
  - [ ] Separate-network Windows release-client acceptance: public server now exists and Docker check passes, but unchanged Windows executable gameplay including props/all hazards/server-loss retry remains unverified. Build Windows from matching deployed revision; old94ad2fd client is incompatible with current server.
  - [ ] Release-executable settings restart and physical warning/effect audibility confirmation. Editor-driven PCK fixtures do not complete this requirement.

Acceptance: all seven new gates in `progress.json` pass with distinct dedicated-server, admission/lifecycle, UI, container, actual Internet release, assets/settings/audio and documentation evidence. LAN smoke is optional legacy-path coverage, not required or retroactively passed. Human baseline still depends on Internet readiness.

Refactor seams: keep room lookup/admission/process allocation out of MatchManager and gameplay simulation; keep client HTTP discovery separate from ENet session establishment. Use a versioned wire contract and explicit room/build/owner identity rather than machine addresses or peer 1 as business identity. A local launcher is the initial implementation, not a generic scheduler framework: later replace allocation with remote workers and registry storage if measured demand warrants it. No Kubernetes, distributed database, message bus, autoscaling, multi-region routing, account system or ranked matchmaking now. Choose the room-service language and deployment tools when implementing 2.2.4, based on installed tooling and maintainability.

Existing evidence: unchanged release EXEs passed localhost ready/start/recovery/rejoin; exact shipped PCK passed editor-driven settings/restart/routing and gameplay/five-rematch fixtures. These do not establish dedicated-server/room-ID readiness. Release templates ignore external `--script`; retain separate evidence layers. Initial Meteor presentation failure followed by passing rerun remains unexplained; investigate recurrence without weakening assertions. Completed phase archives and prior logs remain unchanged.

Task 2.2.3 validated: `--server-port=` starts a playerless development server; first connected player is owner until admission is implemented in 2.2.4. Owner RPCs enforce actual sender, registered membership, session revision and state/readiness. Transfer preserves normal last-survivor rules and refreshes results actions even without a state change. Real ENet three-client control fixture passes 103 checks, five rematches, active/results transfer and late-join rejection; separate-process server/two-client gameplay passes rightward movement, five rematches, matching results and server-loss recovery. Full regression passes 27 suites, persistence restart and five network groups; final targeted/CLI checks also pass. Inspected five owner/guest/transfer states at 720p/1080p on WSL llvmpipe/Dummy audio. Shutdown-only WAV playback resource diagnostics remain; no new Windows package, admission service, Docker or public Internet claim.

Task 2.2.4 validated: Python standard-library loopback backend, normalized/generated IDs, version 1/exact-build lookup, salted passwords and hashed single-use 20-second tickets. Real Godot SceneMultiplayer pre-registration authentication rejects UDP bypass and invalid/expired/replayed/wrong-room tickets; actual rejection recovery/retry and two admitted/ready clients with owner start/ACTIVE admission denial pass. Ten backend tests cover atomic IDs/capacity, private file permissions, startup/port conflicts, crash/empty/heartbeat-loss/shutdown cleanup, registry-loss fail-closed and port reuse. Actual CLI create/SIGTERM/reclaimed UDP port passes. Serial full regression passes 27 suites/five network groups/persistence restart, including five rematches and 20-player source scale. One earlier 20-player client movement assertion failed, then isolated and full reruns passed unchanged; cause unconfirmed and logs preserved. `GUIDE.md` documents local commands and HTTPS/proxy security boundaries; no Windows room-ID UI, Docker or public deployment claim.

### Milestone 2.3 — Human Playtest Baseline

Depends on 2.2 and 2.6; collect baseline evidence before changing core feel.

- [ ] Run an initial 3–4-person session, then a 6–8-person session on separate Windows PCs joining Internet rooms by ID using matching packages. Aim for at least three normal rounds per session; record actual counts and early endings rather than forcing an 8–12-minute outcome. Keep debug/demo launches out of competitive rounds.
- [ ] Before play, record client/server builds and hardware, server region, input devices, resolution/V-Sync, network latency/setup and prior familiarity. Include a brief traversal/prop/camera check through doors, stairs and each elevation route; test controller navigation and physical warning audibility where devices are available.
- [ ] Observe without coaching once the controls are introduced. For each death, record time, authoritative cause, what the player thought happened before explanation, warning noticed and escape attempted. Log camera blockage, client responsiveness, unfair/stuck recovery, spectator downtime, disconnects and frame-pacing complaints with reproduction context.
- [ ] Record voluntary rematch requests separately from facilitator-requested rounds. Timestamp funny/emergent moments and their causal chain. Ask each player what felt unfair, confusing or enjoyable and what they would change first; collect recordings only with consent.

Acceptance: real sessions at both group sizes, per-round observations and player feedback; localhost processes/bots are not substitutes. Lack of people/PCs is an explicit human dependency, not an automated pass.

### Milestone 2.4 — Core-Feel Improvements

Depends on 2.3; create ordered tasks from actual findings, not speculative tuning.

- [ ] Prioritize reproduced issues by severity, recurrence and impact on comprehension/control. Tune movement in `game/player_tuning.gd`, camera in the existing player scene/controller, and pacing in MatchManager/Director/disaster metadata; keep authority, solo exception, recovery protection and physics budgets intact. Do not tune speculatively before observations.
- [ ] Change one coherent issue at a time; record the hypothesis, baseline, values changed and before/after evidence. Re-run affected behavior tests and network checks; inspect renders for appearance changes and native Windows overlap throughput plus default-V-Sync pacing for performance changes.

Acceptance: recurring high-impact issues prioritized with reproduction evidence, addressed with before/after evidence and affected regression checks. Human confirmation belongs to 2.5, not an assumed tuning success.

### Milestone 2.5 — Follow-Up Validation and Phase Review

Depends on 2.4; retest affected scenarios and normal rounds at both group sizes and compare with the baseline.

- [ ] Repeat the affected scenario and normal rounds with humans. Proposed expansion gate: at least 80% of sampled deaths correctly explained without coaching (report numerator/denominator), a majority independently willing to rematch in each follow-up group, and at least two distinct emergent causal patterns recurring across rounds. Record contrary evidence; do not treat small-sample results as statistical proof.

Acceptance: human follow-up and baseline comparison, no unresolved session-blocking/control failures, and the death-clarity/rematch/emergence gate met. Preserve the configurable 8–12-minute target but report actual duration distribution; short rounds may reveal balance problems rather than justify arbitrary timer changes. If gates fail, remain in Phase 2, return observed issues to 2.4 and repeat 2.5. All six milestones must pass before phase closure.

Current constraints: export packaging, standalone launch, historical release localhost ready/start/recovery and editor-driven exported-PCK checks pass. Source dedicated mode/owner controls, local room service/admission, room-ID UI and managed-container validation now pass. Final regression passes 29 suites/five network groups/settings restart; Docker passes 12 backend tests, 107-check ownership and 4/8/20-player coverage. Task 2.2.7 is in progress with matching new release bundles; public Internet and physical listening remain blocked. Do not expose test drivers or unauthenticated development servers publicly. Public server/domain/TLS/UDP exposure requires deployment approval; human Internet sessions, controller feel and physical loudness remain unverified. Historical uncapped Windows throughput passed; default-V-Sync pacing and the reported X-server shutdown remain unresolved observations, not proven causes or fixes.

Task 2.2.6 validated: `bash tests/run_container_network_test.sh` and `python3 tests/run_managed_container_test.py` pass strict internal-bridge checks without published ports. Actual RoomService plus two Godot rooms and separately addressed clients pass four/eight players per room, isolated rosters/83-vs100HP/Flood/Meteor/results, five rematches each, owner transfer/forged-request rejection, admission retry, full capacity, crash, heartbeat outage/resume, live-service restart with unused unexpired old-ticket rejection, empty expiry and port reuse. Proven engine DEL_PEER departure fan-out is prevented by dedicated relay-off; timed-out HTTP reply writes catch only cancellation exceptions. Measured service/two-room budget is 2CPU/1GiB, about 170–185MiB used; 120 warmup/600 samples per room yield physics-work p95 1.25–1.79ms, tick-interval p95 about20.7ms, RTT7–13ms on WSL/internal bridge. Conservative initial local cap: two rooms/four players each, not a production or perfect60Hz promise. Earlier heartbeat, retry-roster and20-player movement failures remain unconfirmed observations with retained logs and extra diagnostics; no assertions relaxed or unrelated gameplay fixes claimed. See GUIDE/progress for evidence and limitations; public Internet readiness remains planned.

Task 2.2.7 local preparation validated: both targets at revision `94ad2fd` match byte-for-byte across repeated exports; PCK audit has88 entries and excludes test drivers/source generators. Standalone Linux package passes actual allocator startup/version rejection/HTTP create/join/crash/recreate/SIGTERM/UDP reclaim without checkout/cache/editor. Official release templates reject `--path`; the allocator now uses project/package cwd, and release stdout flush preserves build/ready logs across termination. Native Windows unchanged release launches/exits cleanly with correct identity and inspected assets; exact-PCK editor fixtures pass settings/restart/recovery/five rematches, not physical listening or release-client admission. Fresh source regression passes29 suites/five network groups. Matching Windows ZIP/Linux TAR and evidence are in `.amp/in/artifacts/release-2-2-7/`. Operator runbook is in GUIDE; public steps remain unexecuted.

Next action: Task 2.2.7 — await main pipeline37770598203 updating the server to4b535af, then use delivered Windows4b535af ZIP by direct EXE launch for separate-network release acceptance (props/all hazards/server-loss retry/settings/listening). Public endpoint is now bundled; default/override UI checks and native exact-PCK fixtures pass. Old6fb1e8d ZIP cannot join the new server. These checks do not close the Windows/human gates; evidence-only updates skip CI. Task2.2.7 and Milestone2.2 remain open; do not start2.6/2.3 yet.

### Milestone 2.6 — Mouse Interaction and Display-Session Reliability

Stable ID added after the original plan; execute after 2.2 and before 2.3.

- [ ] Reproduce the reported inability to rotate the camera or click buttons using `godot --path . -- --host-port=29730` on the user's Linux/X11/llvmpipe environment. Record window focus, mouse capture/visibility, motion/button events, UI event consumption and display-session state. Distinguish game input routing from missing OS events or X-session loss before identifying a cause.
- [ ] Fix the proven input owner only; validate mouse camera rotation during play, clickable lobby/ready/start/results/settings controls, Escape release and click recapture, focus loss/return, rematches and server-loss recovery. Include solo/listen-host and dedicated clients, 720p/1080p, and native Windows regression. Use actual pointer events plus observable camera/control outcomes, not only direct method calls.
- [ ] Investigate the reported `X connection to :0 broken` separately. Record whether the process/display was intentionally stopped and the first failure before the static-string/thread/RID cleanup diagnostics; do not treat shutdown output, V-Sync warnings or unavailable audio devices as the established input-failure cause. Validate normal exit; keep externally unavailable display reproduction explicitly blocked rather than claiming a fix.

Acceptance: reproduced mouse failure with a proven correction and executed pointer/focus/state-transition regression; display-loss sequence classified with evidence or an explicit unresolved blocker. Human baseline depends on this milestone as well as 2.2. No gameplay lighting changes are part of this work.

Preview review follow-up: the user clarifies normal direct host lighting looks normal; only Task 2.2.3 images look excessively bright. Compare the multi-scene capture fixture with a single normal host at matched renderer/camera/settings, including shared-world lights/environments and image encoding/display. Correct and inspect the preview workflow if a difference is reproduced; do not reduce production lighting to compensate for a capture-only issue. Prior captures demonstrate the tested UI layout, not user-approved lighting.

## Planned future phases

These stay concise until they become current.

### Phase 3 — Player-Caused Chaos

- Add one bounded server-authoritative shove with cooldown and recovery protection only if playtests support it.
- Deepen a small set of prop roles and add two or three interruptible social emotes.
- Reject stun-lock, combat dominance, and rigidbody-budget regressions.

### Phase 4 — Disaster Remix and Toy Town Interaction

- Enlarge and enrich the existing Toy Town in response to the user's small/sparse-map feedback: additional usable buildings, props, elevated refuges and connected traversal routes, not just decorative clutter. Select the new footprint during this phase's design; retain readable boundaries and out-of-bounds protection.
- Revalidate disaster coverage, spawn distribution, reachable escape routes, 20-player readability and representative performance for the expanded footprint; larger ground alone is not sufficient.
- Add bounded variants to existing disasters before adding another disaster class.
- Add at most two evidence-driven combinations, prioritizing Tornado + Meteor and Earthquake + Flood.
- Deepen landmark interactions and authored map states without a second map or dynamic destruction system.

### Phase 5 — Session Distribution and Release Readiness

- Harden the Phase 2 Windows package for release/distribution and add robust failure UX; do not defer the playtest export until this phase.
- Resolve the intermittent 20-player movement failure before expanding supported playtest capacity beyond four. Run37770598203: one client observed unchanged local/host positions while the server reported movement=true and clients=false; cause unverified. Retain full4/8/20 fixture/assertions and diagnostics, reproduce under CI load, fix the proven owner and rerun before claiming scale readiness. User temporarily limits playtest to1–4; deploy CI uses PLAYER_COUNTS=4 for playable scale only, not suppressed errors. Other authority/state matrices remain unchanged; deferred scale failures are not passed gates.
- Harden the Internet room service and evaluate Steam lobby/invite integration against its existing discovery/admission boundary; do not defer dedicated rooms until this phase.
- Improve server capacity/placement only from measured demand; adding server machines does not require changing room-ID client UX. No accounts/ranking or mass-scale infrastructure by default.

### Phase 6 — Cosmetic Loot-Box Drops and Customization

- Add earned loot-box drops that unlock new character models/costumes, with a small initial catalog, an opening/reward preview, an owned-cosmetics view and equip flow. Define drop eligibility, odds and duplicate handling when this phase becomes current; paid boxes, currencies and shops are not implied by this request.
- Keep rewards cosmetic-only: unchanged hitboxes, movement, health, abilities and warning visibility. Follow the Design Bible proportions/materials/palette and asset provenance workflow; inspect models/costumes under normal gameplay lighting using faithful previews rather than accepting blown-out captures.
- Persist unlocks and equipped selection; use server-authoritative reward grants with replay/duplicate protection, and replicate only validated equipped cosmetics. Decide durable player identity/storage before claiming ownership survives devices or service restarts; keep reward/ownership logic separate from match simulation for later refactoring without mass-scale infrastructure now.
- Validate drop eligibility and probability boundaries, duplicate/replayed grants, save/restart, unauthorized equips, multiplayer appearance agreement and rematch/disconnect recovery. Inspect reward/equip and representative gameplay states at 720p/1080p and recheck readability/performance. No unlock or persistence gate is passed by planning alone.

## Explicitly deferred

Second map, additional disaster classes, non-cosmetic progression, currencies, shops, non-cosmetic inventories, paid loot boxes, ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production bots, advanced destruction, and a large cosmetic catalog. Earned cosmetic loot-box drops and a minimal owned/equip collection are now planned in Phase 6, not current implementation scope.
