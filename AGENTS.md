# Disaster Party Repository Guidance

Before implementation work:

1. Read `PROMPT.md` and `DESIGN.md`. `DESIGN.md` is the local copy of the Disaster Party Design Bible and is authoritative after explicit user instructions.
2. Read `progress.json`; it is the single source of truth for phase state, validation, blockers, and the next action. Update it after every meaningful implementation or validation result.
3. Load `.agents/skills/advancing-disaster-party/SKILL.md` for implementation, planning, or session handoff work.
4. Load `.agents/skills/validating-game-assets/SKILL.md` before downloading, generating, importing, changing, or approving an asset.

Do not rewrite the design plan. Record implementation decisions in `docs/decisions.md` and concise executable work in `docs/implementation-checklist.md`.

Complete and validate the current phase before expanding scope. Never mark imports, animation clips, retargeting, networking, performance, or multiplayer as working without an executed check recorded in `progress.json`.

Keep generated and third-party asset provenance in `assets/manifest.json`. Do not commit external archives or tools. Prefer deterministic generated assets and the CC0 packs named in the design bible; adapt or replace assets that conflict with its proportions, materials, palette, or gameplay readability.
