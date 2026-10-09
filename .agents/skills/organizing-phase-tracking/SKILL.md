---
name: organizing-phase-tracking
description: Organizes Disaster Party phase checklists, completed-phase archives and build-specific human acceptance. Use when splitting or moving planning documents, reconciling stale checkboxes, recording user checks or closing a phase.
---

# Organizing Phase Tracking

Keep implementation evidence, human acceptance and historical phase records distinct.

## Sources and layout

- Read root `AGENTS.md`, `DESIGN.md`, `progress.json` and `docs/implementation-checklist.md` before changing tracking.
- Root `progress.json` owns active phase/task/gates and exactly one next action.
- `docs/implementation-checklist.md` is an index, not a combined checklist.
- Active/planned phases each use `docs/checklists/{phase-slug}.md`.
- Root `NEED_REAL_CHECK.md` owns actionable user/device/Internet acceptance instructions, linked to the phase task/gate.
- Completed phases use `docs/old-docs/{phase-slug}/checklist.md`, `decisions.md` and `progress.json`; `docs/old-docs/README.md` indexes them.
- Keep the original brief at `docs/old-docs/PROMPT.md` and active decisions at `docs/decisions.md`.

## Reconcile or reorganize

1. Compare checkboxes with recorded executed evidence. Distinguish implementation, automated validation, package delivery, deployment and human acceptance; completion of one does not imply the others.
2. Put checks requiring real people, physical input/audio/display or separate Internet networks in `NEED_REAL_CHECK.md`. Include matching client/server build, steps, expected outcome, dependencies and a reporting format. Do not require recordings to accept a user's report; record its provenance and known conditions.
3. Preserve earlier user-confirmed Internet/audio results. Do not apply old-build acceptance to later fixes without explicit evidence. Keep unavailable devices and unclassified failures open, not failed or passed by assumption.
4. Split documents without dropping requirements or evidence. Completed tasks of an active phase stay in that checklist for context; archive the whole phase only after all required gates pass. Label chronological pending statements when newer evidence supersedes them.
5. Move existing historical decisions/progress without altering payloads. Document historical path strings in the archive index rather than rewriting old evidence. Never overwrite an existing archive. For new archives, use paths relative to the new depth (`../../../progress.json`).
6. Update active references in README, AGENTS, applicable skills, decisions and root progress. Keep the phase/checklist indexes linked and exactly one operational next action.

## Validation and delivery

- Compare moved historical files byte-for-byte against Git originals; compare split phase sections and ensure every requirement remains represented.
- Check Markdown relative paths/anchors and root progress pointers; run `jq empty` on active/archive JSON and `git diff --check`.
- Record commands/results in active `progress.json`, without inventing new gameplay passes or closing untested human gates.
- Follow `advancing-disaster-party` for phase rollover and repository commit/push policy. Documentation-only delivery uses `[skip ci]` to avoid an unintended shared-server deployment; a tracking change does not authorize deployment or server restart.
