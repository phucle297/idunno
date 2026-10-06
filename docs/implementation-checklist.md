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

## Phase 1 — UI Identity and Feedback

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
- [ ] Task 1.3.3: Add an elimination transition and compact spectator target card with previous/next controls.

Acceptance: a 20-player roster scrolls without overlap; ready/start ownership is unambiguous; keyboard/controller focus order works; lobby and spectator state remain presentation-only.

### Milestone 1.4 — Structured results

- [ ] Task 1.4.1: Replace the space-aligned summary string with reusable ranking rows and explicit columns.
- [ ] Task 1.4.2: Add winner emphasis, restrained row reveal, and one optional award derived from existing result data.
- [ ] Task 1.4.3: Present host Rematch and client waiting states clearly; add Return to Lobby and Settings only where authority allows them.

Acceptance: 4- and 20-player results remain legible; all peers show identical authoritative rankings; five network rematches remain green; gameplay HUD is hidden beneath results.

### Milestone 1.5 — Pause, settings, accessibility, and UI audio

- [ ] Task 1.5.1: Add an online-safe pause overlay that releases local input without pausing server simulation.
- [ ] Task 1.5.2: Persist master/effects/warning volume, mouse sensitivity, invert-Y, camera-shake level, fullscreen/windowed mode, and reduced motion.
- [ ] Task 1.5.3: Add a small pooled UI sound set for focus, confirm, back, error, ready, countdown, and results reveal.

Acceptance: settings survive restart; warning volume remains independently controllable; reduced motion removes scale/pulse dependence; input focus and cursor capture recover correctly; online pause never stops authority.

### Milestone 1.6 — UI regression and rendered review

- [ ] Update exact-string tests toward semantic component state without weakening behavior assertions.
- [ ] Run all Phase 0 regressions and multiplayer matrices.
- [ ] Render and inspect lobby, default HUD, single warning, overlap, drowning, spectating, results, pause, and settings at 1280×720; inspect core states at 1920×1080.
- [ ] Re-profile representative overlap and reject unbounded per-frame UI allocation or scene rebuilding.

Acceptance: all prior functional gates pass; inspected captures meet hierarchy, consistency, accessibility, and no-clipping requirements; representative performance remains within the validated target budget.

## Planned future phases

These stay concise until they become current.

### Phase 2 — Human Playtest and Core Feel

- Package a reproducible Windows build and run structured 3–8-player, multi-PC sessions.
- Tune movement, camera, warnings, pacing, fairness, match length, and cause-of-death clarity from observed evidence.
- Gate expansion on understandable deaths, voluntary rematches, and recurring emergent moments.

### Phase 3 — Player-Caused Chaos

- Add one bounded server-authoritative shove with cooldown and recovery protection only if playtests support it.
- Deepen a small set of prop roles and add two or three interruptible social emotes.
- Reject stun-lock, combat dominance, and rigidbody-budget regressions.

### Phase 4 — Disaster Remix and Toy Town Interaction

- Add bounded variants to existing disasters before adding another disaster class.
- Add at most two evidence-driven combinations, prioritizing Tornado + Meteor and Earthquake + Flood.
- Deepen landmark interactions and authored map states without a second map or dynamic destruction system.

### Phase 5 — Session Distribution and Release Readiness

- Add a reproducible Windows export and robust failure UX.
- Extract the direct-IP session boundary before evaluating Steam lobby/invite integration.
- Validate physical LAN/Internet sessions without building accounts, ranking, or a custom backend.

## Explicitly deferred

Second map, additional disaster classes, progression, currencies, shops, inventories, ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production bots, advanced destruction, and a large cosmetic catalog.
