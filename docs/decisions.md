# Website decisions

- 2026-10-07: Repurpose `feat/website` exclusively for Permees' website. Remove
  game runtime, generated gameplay assets, engine setup, room service, game tests
  and game-only development records. Game history remains in Git and on `main`.
  Retain `DESIGN.md` unchanged for game identity and visual context.
- 2026-10-07: The latest user instruction selects React + TypeScript + Vite +
  Tailwind, superseding Next.js. Build static files; no API, SSR, CMS or forms.
- 2026-10-07: Use an editorial chaos-poster direction: ink/plum background,
  warm cream condensed type, orange and lavender, hand-authored abstract hazard
  vectors. No stock photos, fake footage or external image runtime requests.
- 2026-10-07: Keep all supplied copy and development qualifiers. Only actual
  section anchors and support@permees.com are links. Steam, Discord, trailers and
  social links are added only when real destinations/media are supplied.
- 2026-10-07: On feedback, remove the repetitive chaos/interaction/fun ticker and
  studio positioning repeat; replace the secondary chaos headline with
  "Stay sharp. Stay standing." Preserve substantive game copy and the hero slogan.
- 2026-10-07: Add lightweight pointer parallax, hover/focus feedback and native
  artwork effect toggles that can combine Meteor/Flood/Tornado. Explicitly label
  this an artwork study, not gameplay. Animations are finite, no new dependency,
  all controls work with keyboard/touch, and reduced motion disables movement.
