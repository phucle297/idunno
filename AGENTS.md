# Disaster Party Repository Guidance

Before implementation work:

1. Read `docs/old-docs/PROMPT.md` and `DESIGN.md`. The archived prompt records the original brief; `DESIGN.md` is the local Disaster Party Design Bible and is authoritative after explicit user instructions.
2. Read `progress.json`; it is the single source of truth for the active phase's milestones, tasks, validation, blockers, and next action. Completed-phase evidence lives in `docs/old-docs/{phase-slug}/progress.json`. Update only the active file after every meaningful implementation or validation result.
3. Load `.agents/skills/advancing-disaster-party/SKILL.md` for implementation, planning, or session handoff work.
4. Load `.agents/skills/validating-game-assets/SKILL.md` before downloading, generating, importing, changing, or approving an asset.
5. Load `.agents/skills/organizing-phase-tracking/SKILL.md` when splitting/moving phase documents, reconciling checkboxes, recording user acceptance, or closing a phase. Keep user checks in `NEED_REAL_CHECK.md`, phase checklists separate, and completed-phase documents grouped in `old-docs` as specified below.
6. Load the Amp User Skill `planning-project-phases` when creating/revising planning, phase/milestone/task hierarchy, or consolidating stale documents. Apply this repository's `organizing-phase-tracking` skill for its specific paths and acceptance policy; do not reset progress or rewrite DESIGN during document cleanup.

Do not rewrite the design plan. Record only active-phase implementation decisions in `docs/decisions.md` and executable work in `docs/checklists/{phase-slug}.md`; `docs/implementation-checklist.md` is the navigation index. Record user/device/network acceptance separately in root `NEED_REAL_CHECK.md`, with build and conditions; do not substitute automated evidence for human acceptance. Keep completed tasks of an active phase in its checklist for context. Move completed-phase checklist, decisions and progress together to `docs/old-docs/{phase-slug}/`, preserve evidence, and link archives from the active log. Never overwrite an existing archive.

Work through the hierarchy `phase → milestone → task`. A phase may contain multiple milestones; add tasks only when a milestone is too large for one coherent work unit. Complete and validate the current milestone before starting another, and complete all required milestones before closing a phase. Never mark imports, animation clips, retargeting, networking, performance, or multiplayer as working without an executed check recorded in `progress.json`.

When a phase is complete, archive its full progress before starting the next phase:

1. Confirm every required milestone and gate is complete and the final evidence is recorded.
2. Create `docs/old-docs/{phase-slug}/progress.json`; never overwrite an existing phase archive.
3. Mark the archive as historical (`source_of_truth: false`) and record its phase ID, title, completion status, and archive timestamp.
4. Replace root `progress.json` with a fresh active-phase file containing only the new phase, a link to the previous archive, empty current-phase evidence, and exactly one next action.
5. Validate both JSON files before committing. Do not carry completed-phase validation logs or changed-file diaries into the new active file.
6. Move that phase's decision log and checklist to `docs/old-docs/{phase-slug}/decisions.md` and `checklist.md` before starting the next phase's decisions in `docs/decisions.md`. Update navigation links and reconcile `NEED_REAL_CHECK.md` without dropping unresolved checks.

When the same issue occurs repeatedly, verify and record its cause and proven fix, create or update a focused skill with prevention and recovery steps, and add a concise reminder to the relevant project guidance or checklist. Load the `building-skills` skill before creating or changing any skill.

For repeated ENet channel-zero errors during dedicated-room departures, load `recovering-enet-room-disconnects`; preserve dedicated relay-off policy and strict runtime-error checks.

After completing and validating a feature, milestone, phase, or other coherent work unit, commit its changes and push the current branch to its configured remote before reporting the work complete. Do not include unrelated changes in the commit. Every commit message must follow Conventional Commits (`type(scope): description`), including documentation and workflow-only commits.

Keep generated and third-party asset provenance in `assets/manifest.json`. Do not commit external archives or tools. Prefer deterministic generated assets and the CC0 packs named in the design bible; adapt or replace assets that conflict with its proportions, materials, palette, or gameplay readability.
