# Permees — Independent Game Studio

Static, one-page studio website for **permees.com**, introducing our first game,
**Disaster Party**. React + TypeScript + Vite + Tailwind CSS. No backend, SSR,
runtime API, analytics, external font requests or image services.

## Run and build

Use Node.js 22.12+ (Node 22 LTS recommended).

```sh
npm ci
npm run dev
npm run build
npm run preview
```

`npm run build` type-checks the app and produces deployable static assets in
`dist/`. Preview is for local review, not a production server.

## Deploy

| Setting          | Cloudflare Pages | Vercel          |
| ---------------- | ---------------- | --------------- |
| Framework        | Vite             | Vite            |
| Install command  | `npm ci`         | `npm ci`        |
| Build command    | `npm run build`  | `npm run build` |
| Output directory | `dist`           | `dist`          |
| Node version     | `22`             | `22.x`          |

Select `feat/website` as the deployment branch. Set Node 22 in the project build
settings (Cloudflare also accepts `NODE_VERSION=22`). No environment secrets or
server functions are required. Attach permees.com through the hosting provider
when authorized; canonical, sharing and sitemap URLs already target that domain.
No deployment has been performed by this implementation.

## Content and artwork

- `src/App.tsx`: page copy, section anchors and the featured-game media figure.
  Replace that clearly labelled decorative figure with real screenshots/key art
  or a `<video controls poster="..." preload="none">` when footage is available.
- `src/ChaosArt.tsx`: original lightweight decorative hazard vectors, not gameplay.
- `src/DisasterArtwork.tsx`: independently toggle Meteor, Flood and Tornado to
  combine decorative effects. Native buttons support keyboard and announce
  selection changes; the artwork is explicitly not a gameplay demo.
- `src/styles.css`: palette, typography, responsive layout and reduced motion.
- `index.html`: SEO/Open Graph/Twitter metadata and studio structured data.
- `public/og-image.png`: 1200×630 sharing graphic; `public/favicon.svg`: brand mark.
- Fonts are self-hosted Latin WOFF2 subsets in `public/fonts/`, sourced from
  Fontsource Barlow Condensed 5.3.0 and DM Sans 5.3.0. Their SIL Open Font Licenses
  are included beside the files. Critical fonts are preloaded.
- `public/og-image.svg` is the original sharing-art source. The PNG was rendered
  from it in Chromium with the studio's local fonts at exactly 1200×630.

Only section anchors and the real contact address are linked. Add Steam,
Discord, social links or a trailer only after real URLs/assets are supplied;
never imply that Early Access is already available. `DESIGN.md` is retained as
game background. Game code and its previous tooling remain on the game branch
and in Git history, not in this website build.

## Verify

```sh
npx playwright install --with-deps chromium
npm run build
npm test
```

Browser tests exercise the production static preview, anchor navigation, email,
development status, metadata, keyboard skip link, independently combinable art
effects, pointer response in both directions, dynamic reduced motion and
320–1440px overflow. Screenshot review artifacts are local and excluded from Git.
