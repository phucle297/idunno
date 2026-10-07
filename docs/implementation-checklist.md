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

## Phase 2 — Human Playtest and Core Feel (planned, current)

Goal: establish whether the validated prototype is understandable, responsive and worth rematching with friends. No new gameplay systems or map expansion in this phase.

### Milestone 2.1 — Reproducible Windows Playtest Build

- [ ] Task 2.1.1: Install/verify matching Godot 4.7.2 export templates, add a Windows x86_64 Compatibility preset and one repeatable export command. Export twice from the same clean revision; compare payload hashes and document any nondeterministic packaging metadata. Keep tools, caches, tests and review artifacts out of the package.
- [ ] Task 2.1.2: Identify the build by source revision, engine version and package checksum in the delivered build notes and an accessible in-game/log surface. Update `GUIDE.md` for executable launches, LAN IP/UDP 29730, firewall, controls, readiness, host authority, rematch and recovery. Correct stale Flood blue-overlay instructions and distinguish same-PC checks from physical LAN evidence.
- [ ] Task 2.1.3: Launch the exported executable on native Windows without an editor or repository dependency; check assets/audio/settings restart. Exercise exported host/client readiness, movement, props, warnings, death/spectating, identical results, five rematches, disconnect and retry. Record OS/GPU, resolution, build identity and logs; confirm one physical LAN host/client session before inviting the group.

Acceptance: reproducible export evidence, no missing resources/editor dependency, identifiable matching packages, executable-based session smoke and usable instructions. Existing editor-based tests do not satisfy these gates.

### Milestone 2.2 — Structured Multi-PC Playtest

- [ ] Run an initial 3–4-person session, then a 6–8-person session on separate Windows PCs using the same package. Aim for at least three normal rounds per session; record actual counts and early endings rather than forcing an 8–12-minute outcome. Keep debug/demo launches out of competitive rounds.
- [ ] Before play, record build, host/client hardware, input devices, resolution/V-Sync, network setup and prior familiarity. Include a brief traversal/prop/camera check through doors, stairs and each elevation route; test controller navigation and physical warning audibility where devices are available.
- [ ] Observe without coaching once the controls are introduced. For each death, record time, authoritative cause, what the player thought happened before explanation, warning noticed and escape attempted. Log camera blockage, client responsiveness, unfair/stuck recovery, spectator downtime, disconnects and frame-pacing complaints with reproduction context.
- [ ] Record voluntary rematch requests separately from facilitator-requested rounds. Timestamp funny/emergent moments and their causal chain. Ask each player what felt unfair, confusing or enjoyable and what they would change first; collect recordings only with consent.

Acceptance: real sessions at both group sizes, per-round observations and player feedback; localhost processes/bots are not substitutes. Lack of people/PCs is an explicit human dependency, not an automated pass.

### Milestone 2.3 — Evidence-Driven Core Feel Tuning

- [ ] Prioritize reproduced issues by severity, recurrence and impact on comprehension/control. Tune movement in `game/player_tuning.gd`, camera in the existing player scene/controller, and pacing in MatchManager/Director/disaster metadata; keep authority, solo exception, recovery protection and physics budgets intact. Do not tune speculatively before observations.
- [ ] Change one coherent issue at a time; record the hypothesis, baseline, values changed and before/after evidence. Re-run affected behavior tests and network checks; inspect renders for appearance changes and native Windows overlap throughput plus default-V-Sync pacing for performance changes.
- [ ] Repeat the affected scenario and normal rounds with humans. Proposed expansion gate: at least 80% of sampled deaths correctly explained without coaching (report numerator/denominator), a majority independently willing to rematch in each follow-up group, and at least two distinct emergent causal patterns recurring across rounds. Record contrary evidence; do not treat small-sample results as statistical proof.

Acceptance: no unresolved session-blocking/control failures, addressed recurring high-impact issues with regression evidence, and the death-clarity/rematch/emergence gate met. Preserve the configurable 8–12-minute target but report actual duration distribution; short rounds may reveal balance problems rather than justify arbitrary timer changes. If gates fail, remain in Phase 2.

Current constraints: export presets and local export templates are absent. Human multi-PC sessions, controller feel and physical loudness are unverified. Historical uncapped Windows throughput passed; default-V-Sync pacing and the reported X-server shutdown remain unresolved observations, not proven causes or fixes.

Next action: implement Task 2.1.1 only; finish Milestone 2.1 before starting the human-session milestone.

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
- Extract the direct-IP session boundary before evaluating Steam lobby/invite integration.
- Validate physical LAN/Internet sessions without building accounts, ranking, or a custom backend.

## Explicitly deferred

Second map, additional disaster classes, progression, currencies, shops, inventories, ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production bots, advanced destruction, and a large cosmetic catalog.
