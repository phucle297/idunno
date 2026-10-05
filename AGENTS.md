# Disaster Party Repository Guidance

Before implementation work:

1. Read `PROMPT.md` and `DESIGN.md`. `DESIGN.md` is the local copy of the Disaster Party Design Bible and is authoritative after explicit user instructions.
2. Read `progress.json`; it is the single source of truth for phase state, validation, blockers, and the next action. Update it after every meaningful implementation or validation result.
3. Load `.agents/skills/advancing-disaster-party/SKILL.md` for implementation, planning, or session handoff work.
4. Load `.agents/skills/validating-game-assets/SKILL.md` before downloading, generating, importing, changing, or approving an asset.

Do not rewrite the design plan. Record implementation decisions in `docs/decisions.md` and concise executable work in `docs/implementation-checklist.md`.

Complete and validate the current phase before expanding scope. Never mark imports, animation clips, retargeting, networking, performance, or multiplayer as working without an executed check recorded in `progress.json`.

When the same issue occurs repeatedly, verify and record its cause and proven fix, create or update a focused skill with prevention and recovery steps, and add a concise reminder to the relevant project guidance or checklist. Load the `building-skills` skill before creating or changing any skill.

After completing and validating a feature, milestone, phase, or other coherent work unit, commit its changes and push the current branch to its configured remote before reporting the work complete. Do not include unrelated changes in the commit. Every commit message must follow Conventional Commits (`type(scope): description`), including documentation and workflow-only commits.

Keep generated and third-party asset provenance in `assets/manifest.json`. Do not commit external archives or tools. Prefer deterministic generated assets and the CC0 packs named in the design bible; adapt or replace assets that conflict with its proportions, materials, palette, or gameplay readability.
