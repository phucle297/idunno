---
name: advancing-disaster-party
description: Advances Disaster Party through validated phases, milestones, and optional tasks while maintaining progress.json. Use for implementation, planning, verification, or multi-session handoff work in this repository.
---

# Advancing Disaster Party

Deliver the smallest coherent improvement in the current milestone without expanding into later milestones or phases.

## Workflow

1. Read `docs/old-docs/PROMPT.md`, `DESIGN.md`, and root `progress.json` in that order. Treat the prompt as archived context, `DESIGN.md` as the active design authority, and root `progress.json` as active-phase state only.
2. Confirm `current.phase`, `current.milestone`, `current.task`, their acceptance gates, blockers, and `next_action` from `progress.json`.
3. Inspect the current code and local tools. On a fresh checkout or missing `.godot` directory, run `godot --headless --editor --path . --quit` before script-mode checks so Godot registers global `class_name` types. Do not substitute `godot --headless --path . --quit`; it can load the main scene before creating the class cache and emit misleading parse failures.
4. Implement only the current task, or the smallest coherent slice when the milestone has no tasks. Keep server authority explicit for movement inputs, health, hazards, important physics outcomes, and match state.
5. Run the narrowest meaningful automated check, then launch or render representative gameplay when visuals or interactions changed.
6. Record commands and honest results in `progress.json`. Mark a check `passed` only after executing it; use `failed`, `blocked`, or `not_run` otherwise.
7. Set exactly one concrete `next_action` for the next session.

## Planning Hierarchy

- A phase is a product outcome and may contain one or more milestones.
- A milestone is a reviewable capability with explicit acceptance gates.
- Add tasks only when a milestone needs multiple ordered work units; small milestones may omit them.
- Complete all required milestone gates before marking a phase complete.
- Keep future phases concise until they become current; detail the current milestone and immediate next task.

## Phase Rollover

After every required milestone and gate passes:

1. Record the final completion evidence in root `progress.json`.
2. Derive a lowercase hyphenated phase slug from the stable phase ID, such as `phase-1-ui-identity-and-feedback`.
3. Create `docs/old-docs/progress-{phase-slug}.json`. Stop if that path already exists; never replace historical phase evidence.
4. Preserve the completed phase's full milestones, tasks, validation log, blockers, and changed files in the archive. Set `source_of_truth` to `false` and add archive metadata with phase ID, title, status, timestamp, and `superseded_by: "../../progress.json"`.
5. Replace root `progress.json` with a fresh file for only the next phase. Include the workflow schema, `previous_phase_archive`, active phase/milestone/task, empty new-phase validation and changed-file state, blockers, and exactly one executable next action.
6. Validate both files with `jq empty` and confirm the archive is complete while root state contains no completed-phase diary.

## Scope Rules

- Treat `DESIGN.md` as the local Disaster Party Design Bible; do not duplicate or rewrite it.
- Prefer gameplay evidence over infrastructure. Avoid systems for post-slice disasters or hypothetical scale.
- Preserve the solo-testing exception: one local player continues until death or timeout.
- Do not claim four-player readiness from single-process or single-player checks.
- Keep tunable movement and physics values centralized.
- Load the `validating-game-assets` skill for all asset work.

## Session Handoff

Before stopping, ensure root `progress.json` names active-phase changed files, validation evidence, unresolved blockers, and the next action. Keep entries concise so the active file remains operational rather than becoming a cross-phase diary.
