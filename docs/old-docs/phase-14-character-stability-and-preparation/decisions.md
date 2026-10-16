# Historical Phase14 decisions

## 2026-10-16 — Phase14 character stability and preparation

- Reuse the existing room lobby, map/preset selectors and acknowledged collection
  equip flow for startup. The default no-argument launch stays in LOBBY with no
  director/timer until Play Solo or a real room Start. Dedicated/CLI networking
  and explicit demo entry points stay separate; `--solo` is an explicit automation
  entry, not a fallback to the rejected auto-start behavior.
- Keep airborne arm poses symmetric and held. A completed takeoff must not restart
  while the player is still rising. Preserve phase-matched walk/run blending.
- Blend face/accessory position, rotation and scale as separate components rather
  than affine Transform3D values. Keep reset tracks for interrupted shove/get-up;
  deleting resets would hide the stop defect but leave interrupted cues deformed.
  Regenerate the packed character deterministically rather than rebuilding its
  library repeatedly from potentially animated node transforms at runtime.
- Do not unlock earned costumes or bypass server inventory. Four starter outfits
  remain equipable offline; earned outfits use existing profile-enabled rooms.
- Phase13's complete historical evidence/checklist/decisions are archived together.
  Later completed regression/shipment supersedes pending snapshots, not native
  hardware/human acceptance. Prior deployment authorization is fulfilled; no new
  deployment/release is inferred for this source change.
