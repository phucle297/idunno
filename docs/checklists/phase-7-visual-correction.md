# Phase 7 — Visual correction

The earlier Phase 7 archive remains historical. Its blanket visual-completion claim is superseded: the audit found no Phase 7 UI-source redesign. Root `progress.json` owns this correction, not the planned survival-zone phase.

## 7R.1 — Character and coherent environment

- [x] Broad single-body B Soft Creature with oval face, rounded limbs/feet and eight adapted outfits.
- [x] Ragdoll copies actual visible meshes without changing gameplay bodies/joints or capsule.
- [x] Town/harbor facade trim, framed windows, awnings, house roof, school clock, paving and street detail share matte palette.
- [x] Execute character regression and unchanged collision/anchor contract: town107, harbor46; route/carry/breakage checks pass.
- [x] Inspect actual character and environment renders. Architectural silhouettes remain simpler than concepts; no exact-match claim.

## 7R.2 — Whole-interface composition and references

- [x] Two-column room lobby and numbered roster, preserving control paths/session behavior.
- [x] Outfit grid with real one-shot mesh thumbnails, larger preview, clear equipped/locked/reveal states.
- [x] Compact timer/vitals, warning chips, spectator presentation; remove stale shove indicator beneath lobby.
- [x] Audio/camera/display sections, consistent actions, alternating result rows and winner highlight.
- [x] Preserve selected images under `assets/references/phase7`, document use/rejection/provenance and exclude them from runtime exports.

## 7R.3 — Combined verification

- [x] `GODOT_BIN=$(command -v godot) bash tests/run_ui_regression.sh`: `UI_REGRESSION_OK suites=42 matrices=5 managed_clients=20 persistence_restart=passed`.
- [x] Render room states, settings, gameplay warnings, results and spectator at720p/1080p; collection at720p. Existing long-name ellipsis/tooltips retained intentionally.
- [x] Real-pointer collection select/rotate/reveal/close recording reviewed; ten opens preserve node count.
- [x] Record limits: software renderer, no native-GPU performance claim, no new human acceptance or public deployment.

## 7R.4 — Delivery

- [ ] Commit and push the authorized current branch, using `[skip ci]` to avoid triggering the existing deployment workflow.
- [ ] Verify remote HEAD and record actual delivery; do not infer a new release or server deployment.

Phase8 remains planned and unimplemented. User acceptance stays nonblocking under the existing waiver; aesthetic feedback is not manufactured from automated checks.
