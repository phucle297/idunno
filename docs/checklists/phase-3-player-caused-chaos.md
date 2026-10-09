# Phase 3 — Player-Caused Chaos

**Stable phase ID:** `phase_3_player_caused_chaos` · **Status:** in progress;3.1 complete,3.2.1 next · **Plan checked:** 2026-10-09.

## Outcome and boundaries

Give supported **1–4 players** a few readable ways to affect survival and create comic situations: safe carrying, one useful environmental prop role, an optional bounded shove, and two interruptible social emotes. Improve the existing capsule, grab manager and prop replication rather than introducing combat, inventory or a second physics system.

Authority and proportions remain governed by [DESIGN](../../DESIGN.md). The [phase index](../implementation-checklist.md) owns navigation; [root progress](../../progress.json) owns the active phase and exactly one operational next action. User-authorized activation preserves Phase2 in a [deferred, not completed snapshot](../old-docs/phase-2-human-playtest-and-core-feel/progress.json); no unfinished gate is reset or passed.

- Required: safe grabbing/carrying, one demonstrated survival-useful prop, minimal interaction feedback, two emotes, network/lifecycle/performance regression and reproducible matching packages.
- Conditional: shove ships only after the bounded experiment below passes. Explicitly declining it completes the decision, not a nonexistent gameplay test.
- Deferred: a third emote and second prop role until the first set passes and evidence supports another. No player grabbing, weapons, throwing attack, damage from ordinary contact, inventory, crafting, new disaster classes, map replacement, broad Settings redesign or capacity increase.
- Budgets: at most **32 active authoritative loose bodies**, including relevant disaster debris, and **12 grabbable props**. Cosmetic ragdolls/fragments are measured separately, not counted as authoritative bodies or exempted from performance review. Keep at most two active disasters.
- No required manual acceptance checklist: the 2026-10-09 user waiver applies. Human input/audio/Internet feel stays explicitly unverified unless reported; user feedback may refine or reject an experiment without becoming a prerequisite for continuation. [Bug reporting](../../NEED_REAL_CHECK.md) remains the policy.

## Checked implementation baseline

These are source observations at planning time, before3.1 implementation, not current feature passes. Earlier Phase2 executed evidence remains in its frozen snapshot; subsequent Phase3 results live in root progress and the milestone notes below.

| Area | Existing owner and behavior | Gap this phase must address |
| --- | --- | --- |
| Grab authority | `game/grab_manager.gd`: sender-derived reliable toggle, exclusive owner, nearest forward-cone selection, 1.5m range, capped spring, release on death/knockdown/separation/disconnect | No obstruction query or mass eligibility; direct acquisition does not apply the selection cone. A force cap alone does not prove safe speed/energy under repeated input. |
| Prop network state | `game/main.gd::_broadcast_prop_snapshots/_apply_prop_snapshots`: stable numeric ID, transform, velocities and owner at 0.1s interval; clients freeze bodies and apply snapshots | No interpolation or demonstrated stable moving footing; holder collision exception is applied server-side but not mirrored at the client snapshot owner. Measure actual correction before choosing changes. |
| Player carrying | `game/player.gd`, `game/player_tuning.gd`: existing grab input, hold origin/target and normal locomotion/prediction | No carry speed tradeoff or holding-state animation selection. `holding_idle/holding_walk` clips exist; their current arm swing is not proof of a useful holding pose. |
| Props and water | `game/main.gd::_add_physics_crate`: three generic 12kg, 0.6m crates; `game/flood.gd::_apply_water_effects`: bounded depth lift/current/drag | Floating does not establish upright stability, passenger support or an escape role. Player replay uses the present collision world, not historical prop rollback. |
| Player interaction | `scenes/player.tscn`: layer2 capsules, mask5 world/props, players pass through each other; knockdown lasts1.4s | No shove action or post-recovery protection. Do not silently enable hard capsule collisions or infer pushing from overlap tests. |
| Presentation | `game/toy_character_visual.gd`, generated character/generator, Main context prompt | Connected pivots/shoes are corrected in Phase2; no social-emote state/replication or emote input exists. Death/spectator/recovery must retain visual priority. |
| Coverage | `tests/test_grab_manager.gd`, `test_flood.gd`, `test_player_integration.gd`, `test_network_prediction.gd`, `playable_scene_network_peer.gd`, dedicated/latency runners | Existing ownership tests do not prove standability. Flood's `constant_force` assertion does not measure forces applied via `apply_central_force`; use actual body motion for the new role. |

## Entry and execution order

1. Phase2 roof correction is validated at the existing map owner, not relabeled Phase3 or bundled with Flood pacing. Corrected death/recovery, prediction and current ramps support the1–4 technical entry baseline. Older unverified human gates are not prerequisites under the waiver.
2. User-authorized suspension preserves Phase2's complete evidence and unfinished gates as `deferred_not_completed`, not a completed-phase rollover. Unclassified X-loss/rematch/scale observations and unexecuted release acceptance remain historical limits. No Phase2 gate is passed by activation.
3. Fresh root Phase3 state now links to that frozen snapshot and contains only current-phase milestone/task IDs, evidence and gates. The original Phase2 checklist remains a deferred reference at its existing path.
4. Execute **3.1 → 3.2 → 3.3 → 3.4 decision → 3.5 → 3.6**. A small milestone needs no extra tasks; split only the multi-step carrying, prop experiment and shove work described below. Validate a unit before adding another mechanic.

## Milestone 3.1 — Safe Interaction Contract

**ID:** `milestone_3_1_safe_interaction_contract` · **Required** · **Depends on:** the technical entry baseline.

**Behavior/owners:** Centralize the existing acquisition eligibility at `GrabManager` so prompt, nearest selection and authoritative request agree on living/controllable state, range, forward direction, permitted body/mass and unobstructed reach. Keep release available even if the held body moves out of acquisition range or behind cover. Preserve one player/one body ownership and sender-derived identity; do not create a new generic interaction framework.

- [x] Establish boundary expectations using real wall/doorway/prop geometry; reject grabbing through a wall and allow a reachable prop through an open doorway. Heavy/anchored objects remain uncarryable; use DESIGN's lightweight2–8kg/medium10–25kg classes rather than arbitrary per-prop behavior.
- [x] Align contextual eligibility and acquisition at the existing source of truth. Diagnose repeated-toggle behavior before adding rate limiting; protect authoritative state without rejecting ordinary deliberate release/re-grab.
- [x] Verify collision exceptions end on release and are consistent for a predicted local holder versus an observing client. Reject stale ownership across destruction, reset and disconnect.
- [x] Measure repeated carry/release near a wall, ramp and another player; establish velocity/impulse bounds through actual motion. Add a clamp only at the owner where unsafe behavior is reproduced, with centralized tunables; a single easy spring test is not the safety gate.

**Complete2026-10-09:** shared eligibility, observer collision synchronization and destroyed-prop cleanup implemented. Final grab218 checks include100 immediate toggles and nine240-tick wall/ramp/player scenarios across2/12/25kg: each actually acquires3–4 times, peak6.686m/s/9.841rad/s/0.111m per tick, no floor/wall tunneling or stale ownership/exclusions. Initial speed failures came from the fixture walking off its20m floor; diagnostic owner/position trace and corrected80m floor/original physics prove no grab launch in these cases. Speculative clamp removed; no new rate limiter or production tuning. Real two-process ENet host→client→host transfer uses sender-derived toggle RPC; five rematches free actually held old props and restore unowned replacements. Separate controlled snapshot-ingress probe covers both roster orders and direct90→8→90 ownership changes; not latency/loss evidence. Full34-suite/five-network-group/settings-restart regression passes; known shutdown-only ObjectDB/resources diagnostics retained. Evidence in root progress; no new package/deployment/native-Windows or human-feel pass.

**Acceptance:** Rejected acquisition changes neither owner nor body transform; contention yields exactly one owner; valid input remains responsive; no wall teleport, explosive launch, leftover collision exception or stuck ownership through five rematches.

**Validation:** Extend `tests/test_grab_manager.gd` and the existing real-network peer fixture with range/cone/occlusion boundaries, asymmetric contention and death/knockdown/separation/disconnect release. Test both holders/update orders. Use real physics ticks for motion; retain the relevant existing assertions. No new asset required.

## Milestone 3.2 — Readable Carrying with a Survival Tradeoff

**ID:** `milestone_3_2_readable_carrying` · **Required** · **Depends on:** 3.1.

### Task 3.2.1 — Authoritative carrying movement

**ID:** `task_3_2_1_carry_movement` · **Owners:** `player.gd`, `player_tuning.gd`, GrabManager and Main's existing movement/prop snapshots.

- [ ] Choose a single readable medium-prop slowdown from a measured unladen/carry route comparison; record the value and reason in active decisions. No speed change for every player, acceleration overhaul or hidden hazard immunity.
- [ ] Carry state/eligibility must be server-owned and available at the physics-tick prediction/reconciliation boundary, including replay. Do not trust client-supplied mass, owner or speed. Avoid unconditionally reading a later prop snapshot as historical replay state; inspect whether the existing player snapshot needs a small carry-state field.
- [ ] Release immediately restores normal movement; death, knockdown, disconnect, pause/input blocking and rematch cannot leave a persistent penalty. Keep UI-blocked acquisition distinct from simulation and cleanup, so opening Settings is not an ownership exploit.

**Acceptance/validation:** Compare independently specified normal versus carrying displacement, then release and restore normal speed; test actual ascent on current ramps without compulsory jumping. Extend prediction and delayed network coverage at0/100/200ms, ±30ms jitter and every20th-datagram loss using the existing runner. Measure correction magnitudes as well as first response; do not claim physical smoothness from headless telemetry.

### Task 3.2.2 — Holding pose and minimal feedback

**ID:** `task_3_2_2_carry_presentation` · **Owners:** Player animation selection, `toy_character_visual.gd`, character generator/manifest if a clip changes, Main's existing context prompt.

- [ ] Use/refine existing holding clips before adding a new rig or animation layer; inspect arms, prop and shoulder pivots at gameplay distance. Holding must read while idle/walking without hiding the avatar or ground warnings.
- [ ] Define priority: elimination/spectator and knockdown override holding; airborne/crouch presentation remains coherent; ordinary locomotion resumes after release. Keep camera yaw locally owned.
- [ ] Context feedback names acquisition/release and an actual carry tradeoff, not a new HUD dashboard. Reject an owned/unreachable prop consistently with3.1.

**Acceptance/validation:** Render idle/carry-walk/release, crouch/airborne carry and knockdown recovery at720p/1080p; inspect captures for connected limbs, collider/mesh agreement and unobscured warnings. Load asset-validation skill before changing clips/assets; deterministic provenance/manifest and all four cosmetic variants remain required. Extend existing animation/player tests for externally observable carry-state transitions; no unverified rig/skinning claim.

## Milestone 3.3 — One Useful Survival Prop

**ID:** `milestone_3_3_useful_survival_prop` · **Required** · **Depends on:** 3.2.

**First candidate:** one existing crate as a temporary buoyant foothold/escape aid, not a vehicle, invulnerable raft or weapon. Reuse current ownership, body IDs, Flood and map reset. Keep normal refuge routes usable without the crate; an optional prop may improve a route but must not make early survival depend on ownership contention.

### Task 3.3.1 — Go/no-go physics experiment

**ID:** `task_3_3_1_prop_role_feasibility` · **Owners:** Main crate assembly, Flood, Player and existing prop replication.

- [ ] First measure unheld upright/tilted crate behavior during water rise and current with an actual passenger. Track player/prop position, floor contact, head exposure, health and correction displacement; do not derive expected outcomes from private force fields.
- [ ] Exercise boarding, walking off, another player grabbing/releasing, wall/ramp contact, Tornado/Meteor disturbance and water drainage. Separate a supported standing player from the holder's collision exception; holding one's own foothold cannot levitate/rescue the capsule.
- [ ] Test two clients and synthetic delay/jitter/loss: server-approved footing must not become a client-only elevator or repeated replay launch. Present-world collision replay is a known limit; do not start historical rigidbody rollback merely to save this candidate.
- [ ] Record go/no-go with bounded tunables and contrary cases. If floating support is unstable or requires a new vehicle/rollback system, defer the buoyant role explicitly and evaluate a dry-ground step/escape-aid role using the same crate. A fallback must independently demonstrate a useful route and pass the same lifecycle/network contract; it is not a floating-role pass.

**Acceptance:** Select one role that measurably changes a feasible escape choice versus ignoring the prop, remains optional and fits the physics/network budget. Document deferred candidate reasons; do not ship a role based only on buoyancy visuals.

### Task 3.3.2 — Integrate only the selected role

**ID:** `task_3_3_2_prop_role_integration` · **Owners:** existing prop constructor/Flood as applicable; generator/manifest only if readability requires geometry changes.

- [ ] Place a small bounded set where its selected role has a real use; distinguish function with shared toy silhouette/materials and a short contextual cue, not a new item UI or texture family.
- [ ] Verify wet/dry boundaries, passenger/holder states and actual escape success against the unchanged controller. Flood grace, electricity, damage/death and other hazards still apply normally; no permanent safety or immunity flag.
- [ ] Restore exact spawn/shape/role/owner state on five rematches and clear any added role state on drain/disconnect/death as appropriate. Do not spawn unbounded replacement props.

**Validation:** Extend `test_flood.gd`, grab/player tests and existing real-network fixture with asymmetric passenger/holder cases and both sides of role boundaries. Capture use and failure states. If the selected role changes moving-world collision, rerun the latency/traversal matrix and record correction maxima. Gate on observable route/health/state outcomes, not new helper call order.

## Milestone 3.4 — Optional Fair Shove Decision

**ID:** `milestone_3_4_bounded_shove_decision` · **Decision required; mechanic optional** · **Depends on:** 3.3 and a validated prop baseline.

### Task 3.4.1 — Bounded prototype and fairness decision

**ID:** `task_3_4_1_shove_experiment` · **Owners:** Player/Main server input boundary, centralized tuning, existing knockdown/recovery state.

- [ ] Prototype one explicit short-range forward shove, with server validation of sender, live active-match state, range, direction, line of sight and cooldown. Pick at most one target by a deterministic rule; do not enable hard player collision as a substitute.
- [ ] Start with no HP damage and no routine knockdown. Clamp accepted horizontal impulse and prevent arbitrary client direction/magnitude/target IDs. No homing, sprint stacking, airborne launch or shove through cover.
- [ ] Add a short server-owned protection window against player shoves after recovery/accepted shove so alternating attackers cannot chain-lock a target. Protection must not create immunity to disaster damage or silently disable existing Earthquake/Tornado/Meteor behavior.
- [ ] Test spam, opposing attackers, simultaneous requests, angle/range boundaries, stationary and moving targets, stairs/roof edges, death/spectator and rematch. Check whether victim retains a genuine opportunity to move/escape between accepted effects.
- [ ] Record include/defer decision based on reproducible scenarios and available user feedback: omit if combat dominates route/disaster decisions or fairness needs substantial new systems. No user session/checklist is required to make an honest technical go/no-go decision under the waiver.

### Task 3.4.2 — Integrate only if included

**ID:** `task_3_4_2_shove_integration` · **Conditional** · **Depends on:** passing3.4.1.

- [ ] Add one distinct input, minimal ready/cooldown feedback and readable arm/body cue. Carrying, emote interruption and input blocking have explicit rules; default to no shove while holding a prop, knocked down, dead or in menus.
- [ ] Replicate authoritative accepted effect and protection state where prediction needs it; suppress duplicate application under loss/reordering. Client responsiveness cannot authorize a second impulse or damage.
- [ ] Validate two-client victim/observer agreement under the existing delay/jitter/loss matrix and five rematches. Inspect supported gameplay-distance cues without obscuring warnings.

**Acceptance:** Either the included mechanic passes cooldown, no-damage, bounded-force, anti-chain-lock and authority gates, or it is explicitly deferred with no residual action/RPC/UI/assets. A third-party request cannot move another player without passing server checks. No claim of human fun/fairness without observation.

## Milestone 3.5 — Two Interruptible Social Emotes

**ID:** `milestone_3_5_interruptible_emotes` · **Required** · **Depends on:** 3.2 and the3.4 decision.

**Initial set:** wave and cheer; third emote deferred. Owners: input actions in `project.godot`, Player/character visual and Main's existing player-state presentation. Reuse current skeleton/pivots and deterministic clip generation; no emote wheel, chat, audio pack or cosmetic catalog.

- [ ] Define a small bounded start/cancel state with server-validated emote identity, player state and request rate; clients cannot request arbitrary clip/node paths. Presentation state carries sufficient identity/time for observers without transmitting bones.
- [ ] Movement, jump, crouch, grab and accepted shove cancel immediately; damage/knockdown, death, session loss and rematch override and clear it. Opening UI stops local emote initiation. No rooted animation, movement lock, hitbox change, health effect or buffering an emote for the next round.
- [ ] Camera can still look around; emote playback never changes locally owned aim. A delayed start cannot restart an emote after authoritative cancellation/death or regress current locomotion.
- [ ] Keep existing locomotion/holding/recovery clip contract and four variants; update generated provenance only for assets actually changed. Inspect wave/cheer and interruption mid-pose at720p/1080p.

**Acceptance/validation:** Two clients agree on eligible identity and termination; no stale presentation after death/rematch, spam or reordered movement/state. Extend existing player/animation and real-network tests through public behavior; render living/carrying/knockdown interruption states. Load asset-validation before clip changes. Emotes are cosmetic, not proof of new player physics.

## Milestone 3.6 — Integrated Chaos Regression and Matching Delivery

**ID:** `milestone_3_6_integrated_chaos_validation` · **Required** · **Depends on:** 3.1–3.5 required outcomes and explicit conditional decisions.

- [ ] Run a supported1/2/4-player scenario combining carry/contention, selected prop escape, both emotes, included shove, two overlapping hazards, death/spectating, owner disconnect/transfer and five rematches. Require matching authoritative health/results/ownership/structure states and stable cleanup, not just process survival.
- [ ] Run `GODOT_BIN=$(command -v godot) tests/run_ui_regression.sh` with supported playable scale scoped `PLAYER_COUNTS=4`; retain required network matrices and strict runtime-error checks. Run dedicated, targeted grab/Flood/player/prediction and applicable movement-latency checks. Do not lower assertions to conceal moving-platform regressions.
- [ ] Recheck `tests/run_container_network_test.sh` and serial `tests/run_managed_container_test.py` using their current documented invocation/configuration. Preserve dedicated relay-off policy and load the focused ENet/retry skills if their exact failure recurs. Unchanged20-player failure remains an honest diagnostic beyond supported1–4, not a Phase3 readiness claim.
- [ ] Profile the worst supported4-player prop/hazard scenario at720p/1080p with renderer/GPU/build,120 warmup/600 samples, p95 and authoritative/cosmetic body counts. Target60FPS/16.67ms; use the existing profiler where possible. Native throughput profiles disable V-Sync; report default-V-Sync pacing separately. A failure blocks technical readiness, not justified capacity growth.
- [ ] Inspect final representative native Windows gameplay captures: carry/prop use, emotes, any shove cue, overlapping hazards, eliminated/spectator and rematch. Keep warning/ground/character readability; link only final reviewed images. No clip recording unless timing/motion needs it.
- [ ] Export twice from the same clean committed revision with existing Windows/Linux exporters; compare payload hashes. Run exact-PCK/native checks, actual release executable smoke and standalone Linux lifecycle checks. Distinguish editor-driven PCK fixtures from release input/network/feel evidence.
- [ ] Prepare matching client/server bundles and short control/bug-report notes. Package readiness does not authorize GitHub Release publication, existing-EC2 deployment, infrastructure changes or server restart. Request scoped approval only after local work is ready; use `[skip ci]` pushes until deployment is authorized.

## Phase exit gates

`safe_grab_ownership_and_release` is **passed** for Phase3 after3.1's executed checks. All remaining gates are **not run**. Existing Phase2 passes support the baseline only.

| Gate | Required evidence |
| --- | --- |
| `safe_grab_ownership_and_release` | Obstruction/eligibility/contention boundaries, safe repeated carry/release and client collision consistency, five rematches. |
| `carry_tradeoff_and_prediction_agreement` | Measured unladen/carry/release paths, delay/jitter/loss replay agreement and reviewed holding presentation. |
| `one_useful_prop_role_validated` | Selected role changes a real escape choice without mandatory ownership or immunity; role-specific physics/network checks, budget and reset pass; failed float candidate explicitly deferred if applicable. |
| `shove_include_or_defer_decision` | Documented decision; included shove passes authority/cooldown/no-damage/protection/force gates, or no leftover implementation exists. |
| `two_interruptible_emotes_validated` | Wave/cheer visible, network-consistent and immediately interruptible with no stale replay or next-round state. |
| `supported_multiplayer_lifecycle_and_performance` |1–4 integration, authoritative agreement, five rematches/recovery, strict regression and recorded4-player frame/body budget. |
| `matching_packages_and_reviewable_visuals` | Repeated hashes, exact-bundle/native/standalone checks and inspected final gameplay captures; deployment/publication tracked separately. |

**Closure:** Record results/failed experiments and conditional decisions in active Phase3 progress/decisions, then archive checklist, decisions and full progress together under `docs/old-docs/phase-3-player-caused-chaos/` without overwriting an archive. Do not call deployment, physical feel, audio or separate-network acceptance passed from these automated gates. No extra mandatory manual checklist is introduced.
