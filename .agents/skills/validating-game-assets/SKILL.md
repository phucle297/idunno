---
name: validating-game-assets
description: Sources, generates, imports, and validates Disaster Party assets with deterministic provenance and design-bible checks. Use for any character, environment, prop, animation, material, VFX, audio, or third-party asset work.
---

# Validating Game Assets

Treat every asset as untrusted until its source, license, contents, scale, appearance, and engine import are checked.

## Intake Workflow

1. Read the applicable dimensions, palette, materials, naming, and validation gate in `DESIGN.md`.
2. Prefer Quaternius Universal Animation Library Standard and Kenney City Kit Suburban / Particle Pack when their actual contents fit.
3. Download archives to an ignored scratch/tool directory first. Do not commit archives.
4. Record the official source URL, archive filename, retrieval date, license shown at retrieval, and checksum.
5. List archive contents before copying selected files. For animation libraries, derive the clip inventory from the downloaded files; never infer clips from marketing copy.
6. Import one representative asset and test it in the engine before batch intake. Verify scale, orientation, materials, dependencies, and animation playback where applicable.
7. Generate or adapt assets that do not match the bible. Keep generation deterministic with a stable seed and source script.
8. Add or update `assets/manifest.json` with measured results and an honest validation status.

## Required Visual Checks

- Compare character height, head and torso proportions, silhouette, material response, and palette against `DESIGN.md`.
- Inspect assets at the gameplay camera distance in the asset validation scene.
- Keep collider geometry separate and simple.
- Reject inconsistent realistic textures, gritty wear, tiny noisy details, or unreadable hazard effects.

## License Discipline

Do not call an asset CC0 unless the specific official download page or included license says so. Preserve included license files with selected third-party assets and do not imply that project-generated assets came from an external pack.
