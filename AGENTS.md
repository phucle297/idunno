# Permees Website Guidance

This branch owns the static studio website at permees.com, not the game runtime.
Use React, TypeScript, Vite and Tailwind CSS; production output must be static
files in `dist/` with no backend or server-side dependencies.

- Read `progress.json` and `docs/implementation-checklist.md` before work.
- `DESIGN.md` is background about the game, not a website implementation plan.
- Preserve the honest development status. Do not invent release dates, Steam
  availability, studio achievements, testimonials, team members or social links.
- Keep dependencies minimal, fonts self-hosted and media clearly labelled when
  it is decorative artwork rather than actual gameplay.
- Respect reduced motion, keyboard focus and mobile layouts.
- Use Bun with the committed `bun.lock`: `bun install --frozen-lockfile`.
- Verify with `bun run build` and `bun run test`; inspect rendered desktop and mobile
  screenshots after visual changes. Record actual results in `progress.json`.
- Keep `docs/decisions.md` and the checklist concise and website-specific.
- Commit coherent validated changes using Conventional Commits and push the
  current branch to its remote. Never modify or deploy the game branch.
- Public deployment or domain/account changes require explicit authorization.
