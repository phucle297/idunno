# T44 A4 evidence — face matches sheet.png (AC10), face-only
Godot 4.7.2 Compatibility on llvmpipe (xvfb), under the factory heavy lock. Base fa6b038. Script: `capture_t44_a4_face.gd`.
Framing = sheet.png framing (toy_town, spot (0,0,2), yaw 0, cam spot+(0,1.1,-2.3) look_at spot+(0,0.8,0), fov 65, 1280x720).
- `{bear,cat,bunny}_c{0..5}_front.png`: 3 outfits x 6 player colours (c0 = cyan 31c5df). The face is identical in all 18.
- `{bear,cat,bunny}_c{0,4}_frontlit.png`: front-lit set (visual yaw PI, camera at +Z), colours 0 and 4.
- `sheetcolour_{bear,cat,bunny}.png` + `side_by_side_vs_sheet.png`: rows = sheet.png renders, in-game with the suit tinted to
  the sheet's colours (capture-only material override; not a game change), then face crops sheet / in-game.
- `face_measurements.csv`: per frame patch RGB, plate/eye mask px + bbox, eye centres, eye_h/plate_h, blush node present.
- `suites/`, `frozen_proof.txt`.
## Measured vs sheet (Architect A4 numbers)
| item | sheet | A4 in-game | tolerance |
| plate patch RGB | (130,135,129) | (130,135,129) all 18 + 6 front-lit (identical) | +-20; identical +-3 |
| plate visible px | 6136 | 6493 (+5.8%); front-lit 6640 (+8.2%) | +-10% |
| plate bbox | 108x90 | 110x92 | +-10% |
| eyes px (both) | 1223 | 1326 (+8.4%) | +-10% |
| eyes bbox | 88x31 | 90x32 | +-10% |
| eye centres | (609,307)/(670,307) | (608,308)/(671,308) | +-4 px |
| eye h / plate h | | 0.35 | >= 0.33 |
| blush node | none | none | none |
Deviation notes: the in-game player colours (AC3) still differ from the sheet's muted suits (cyan is vivid); the plate does not change with colour.
The stale MAT_Critter_Blush_v002.tres file is left in place (unreferenced; deleting it is outside the whitelist).
