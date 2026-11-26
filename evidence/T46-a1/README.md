# T46 A1 — FaceCream uses shaded cream (F1, no F1-tune)

Base: main `a42ff032` (whitelist unchanged since `f395fe84`). Branch `feat/T46-face-cream`.
Strategy: data-only F1 — `generate_assets.gd` FaceCream `mat.Face` → `mat.Cream` (`MAT_Critter_Cream_v002`, emission 0.32, shaded), regenerate `CHR_Base_v001.tscn`. Diff limited to FaceCream `material_override` + ext_resource list (unused Face resource dropped). `MAT_Critter_Face_v002.tres` left on disk, unreferenced.

F1-tune was **not** applied: front-lit plate L = 196.3 (close) / 192.1 (mid) / 234.6 (title), all ≤ 240. Architect's earlier runtime probe of 250 was a different (closer/hotter) sample of the same cream; under the AC gameplay framings the plate does not blow out. Paws on the shared cream material still reach L ≈ 251 (frozen; not retuned).

Renderer: Godot 4.7.2 Compatibility, llvmpipe + xvfb, 1280x720. Scripts: `scripts/capture_t46.gd` (Architect `face_variants.gd` / `home_capture.gd` framings). Plate L = Rec.709 tight mean at the unprojected FaceCream centre. Owner shot refs: `evidence/owner-2026-11-26-1723/`.

## Measured values (after = F1, before = a42ff032)

| View | Before face L | After face L | After hood L | After face/hood | After gradient | eyes / mouth |
|--|--|--|--|--|--|--|
| Title (shot 1) bear/cat/bunny o0-2 c0 | 119.9 (116,121,117) ratio 0.73 | 234.6 (247,235,199) | 168.8 / 168.4 | **1.39** (≥ 1.1) | — | eyes yes; mouth is a visible tiny dot on the stills (auto unproject flagged false at title ortho distance) |
| Gameplay close front-lit (shot 5) | 130.9 | **196.3** all 12 outfits × colours 0-5 | — | **1.39–1.97** (0/72 < 1.1) | 134–144 | 72/72 and 72/72 |
| Gameplay close back-lit (A4 framing) | 130.9 | **132.6** (shaded falloff vs 196) | — | 1.04–1.62 | **139–144** (≥ 15) | 18/18 and 18/18 |
| Gameplay mid front-lit (shot 4 distance) | 130.7 | **192.1** | noisy at this scale | 1.00–1.16 (12/18 < 1.1 — hood sampler picks mixed mid-distance pixels; plate itself is cream, see stills) | 139–153 | eyes 18/18; mouth auto false (too few px) |
| Gameplay mid back-lit | 131.3 | **133.0** | — | 0.79–1.12 | **116** (≥ 15) | eyes 18/18; mouth auto false |

- Face L is identical across player colours 0-5 for every outfit (delta 0.0, gate ±3). `set_player_color` does not paint the plate.
- Cream match (close front-lit, 3 species × 12 outfits × colours 0-5): FaceCream albedo == Mitten albedo (`MAT_Critter_Cream_v002`) 72/72. Lit L: face 196.3, belly 212–238 (dBelly 17–77 by outfit/angle), paw 251.1–251.5 (dPaw ≈ 57; paws still blow out on the shared frozen material). Stills: face reads as the same cream family as belly.
- Concept-sheet face/hood ratios (info only): sheet bear 1.68 / cat 1.58. After close front-lit is in the same "face lighter than hood" direction (1.39–1.97).

## Stills

- `stills/before_*.png` / `stills/after_*.png` — title, mid, close, plus back-lit, bear/cat/bunny (colour 0).
- `montages/*_before_after.png` — side-by-side.
- Raw grids: `before/`, `after/` + `measures_{B,A}.txt`.
- Mid-distance is a front-lit toy_town gameplay framing at ~6.2 m (character in the lower frame like shot 4), not a lava-scene recreation.

## Checks actually run

- Frozen re-hash: `frozen_rehash.txt`. vs a42ff032 only the two whitelist files plus this evidence dir. Frozen list (`toy_character_visual.gd`, `home_screen.gd`, `home_town_stage.gd`, `project.godot`, `MAT_Critter_Cream_v002.tres`, `MAT_Critter_Face_v002.tres`) identical to both a42ff032 and f395fe84.
- Suites (headless, this worktree): `test_critter_asset` CRITTER_ASSET_OK checks=226; `test_character_animation` CHARACTER_ANIMATION_OK checks=292; `test_phase1` PHASE1_TESTS_OK checks=1273. Logs in `suites/`.
- 4P moving bench (6 interleaved pairs, B=a42ff032, llvmpipe): mean avg **-2.36%**, p95 **-5.14%**, prims **+0.000%** → PASS (gate +10/+10/+5). Table: `perf/PERF_SUMMARY.md`. override.cfg ABSENT on every run (`perf/proof_4P_*/`).
- CI on code head ebc5a415: run 45858881005 **success**. CI on 4P-evidence head 61c09bc: run 45861690146 **success**.
- Interior trace (3 interleaved pairs B,A / A,B / B,A, B=a42ff032): overall p95 B1 358.77, A1 368.53, A2 361.98, B2 363.52 (1 retry), B3 356.03, A3 350.19 (1 retry). Mean p95 B 359.44 vs A 360.23 = **+0.22%** → PASS (gate <= +10%). Mean avg B 415.77 vs A 473.81 (+13.96%, informational; A1 avg outlier 723.64). override.cfg ABSENT: `perf/proof_trace_{A,B}{1,2,3}/`. Verified from `perf/trace_*_run*.log`. `heavy.log`/`lock.txt` stamps labeled ICT are actually UTC; ICT = UTC+7 (lock 16:27:34 UTC = 23:27 ICT 26 Nov through 22:58:58 UTC = 05:58 ICT 27 Nov). Table: `perf/PERF_SUMMARY.md`.

## Limits

- llvmpipe proxy (Architect: title face colour on f395fe8 was pixel-identical to the Owner's real-GPU shot 1). Owner eyeball on prod is the final look sign-off (AC5).
- Mid-distance hood-ratio auto-gate is noisy; rely on plate L + stills there.
