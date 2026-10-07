# Permees — Independent Game Studio

Static, one-page studio website for **permees.com**, introducing our first game,
**Disaster Party**. React + TypeScript + Vite + Tailwind CSS. No backend, SSR,
runtime API, analytics, external font requests or image services.

## Run and build

Use Bun 1.3.14 and Node.js 22.12+ (Node 22 LTS recommended for Vite tooling).
Dependencies are locked in `bun.lock`; Bun manages installation and scripts.

```sh
bun install --frozen-lockfile
bun run dev
bun run build
bun run preview
```

`bun run build` type-checks the app and produces deployable static assets in
`dist/`. Preview is for local review, not a production server.

## Deploy

GitHub Pages is configured to publish the site at **https://permees.com**.
The workflow in `.github/workflows/deploy-pages.yml` runs on pushes to
`feat/website`, installs Bun 1.3.14 and Node 22 from `.nvmrc`, runs
`bun install --frozen-lockfile && bun run build`, uploads `dist/`, and deploys
through the official Pages actions. No `gh-pages` branch, personal access token,
server functions or repository secrets are needed.

One-time repository/domain setup:

1. In **Settings → Pages → Build and deployment**, select **GitHub Actions**.
2. In **Settings → Pages → Custom domain**, keep/set **permees.com**.
   With Actions publishing, GitHub uses this setting, not the `CNAME` file, to
   configure the domain. `public/CNAME` is still included and Vite copies it to
   `dist/CNAME` on every build to preserve the requested domain in the artifact.
3. Point the apex domain at GitHub Pages with an ALIAS/ANAME to
   `phucle297.github.io`, or the four GitHub Pages A records:
   `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
   Preserve unrelated email/DNS records. Enable **Enforce HTTPS** once the
   certificate is available, and verify domain ownership in GitHub settings.
4. If the `github-pages` environment restricts deployment branches, allow
   `feat/website` in **Settings → Environments → github-pages**.

Vite uses `base: '/'` for the custom root domain, not `/idunno/`. Canonical,
sharing and sitemap URLs already target https://permees.com. This configuration
does not change remote Pages settings or DNS; an actual Actions deployment must
be confirmed in the repository's Actions tab.

The same static `dist/` output remains compatible with Cloudflare Pages or
Vercel using `bun install --frozen-lockfile`, `bun run build`, and Node 22
with Bun 1.3.14 available in the build environment.

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
bunx playwright install --with-deps chromium
bun run build
bun run test
```

Browser tests exercise the production static preview, anchor navigation, email,
development status, metadata, keyboard skip link, independently combinable art
effects, pointer response in both directions, dynamic reduced motion and
320–1440px overflow. Screenshot review artifacts are local and excluded from Git.
