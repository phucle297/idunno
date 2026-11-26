# Third-Party Asset Sources

## Imported

| Asset | Source (pinned) | License | Files in repo | Notes |
| --- | --- | --- | --- | --- |
| KayKit Character Pack: Adventures 1.0 — Rogue_Hooded (Kay Lousberg) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 @ 672074b73ba276876a19e8816ecdc5241817ab47 | CC0 1.0 (`assets/characters/kaykit_adventurers/LICENSE.txt`, verbatim) | `assets/characters/kaykit_adventurers/` (Rogue_Hooded.glb, rogue_texture.png, LICENSE.txt, SOURCE.md) | T44 critter hoodie base mesh + 41-bone rig; cape/weapons and the 76 upstream clips are not imported. SHA-256 in SOURCE.md. |

Candidate sources verified from their official product pages on 2026-10-05:

| Pack | Official source | Page license | Intake status |
| --- | --- | --- | --- |
| Quaternius Universal Animation Library | https://quaternius.com/packs/universalanimationlibrary.html | CC0 shown on the pack page | Archive and included clips not yet downloaded or verified |
| Kenney City Kit (Suburban) | https://kenney.nl/assets/city-kit-suburban | Creative Commons CC0, confirmed in bundled `License.txt` | Archive inspected in ignored scratch space; 40 GLB files; not imported; SHA-256 `5869c35cf30b1c87bdb2d197b6d325eebadd2ef08ea27f04797e8e08d77a9a39` |
| Kenney Particle Pack | https://kenney.nl/assets/particle-pack | Creative Commons CC0, confirmed in bundled `License.txt` | Archive inspected in ignored scratch space; 80 transparent PNG files; not imported; SHA-256 `b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958` |

The current Quaternius general license page displays a newer Quaternius Asset License. The specific animation pack page still displays CC0; preserve the license bundled with the downloaded archive and record its checksum before importing any files.

`docs/animation-clip-inventory.md` records a 45-clip inspection from a third-party Standard FBX mirror. It is secondary evidence only and is not an imported project asset or a substitute for checking the official archive.
