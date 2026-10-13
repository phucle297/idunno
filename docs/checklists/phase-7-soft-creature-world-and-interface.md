# Phase 7 — Soft Creature, Detailed World and Complete Interface

Status: planned; no implementation or visual/runtime gates passed.

## Outcome and execution policy

Deliver the selected B Soft Creature in a consistent, detailed playable town, with
all existing interfaces and both maps sharing one visual language. This is a full
presentation refactor plus explicitly scoped town content, not a menu reskin.
Execute milestones in order in one continuing implementation effort; validate and
commit each coherent milestone before moving on. "One-shot" means an executable
plan without repeated design discovery, not an untested giant patch or guaranteed
one-pass success. Correct failures before advancing; do not ask for routine approvals.

Root [progress](../../progress.json) owns current work and evidence. Existing
[DESIGN](../../DESIGN.md) stays intact; explicit owner selections below supersede
its humanoid silhouette only. Human/device checks remain nonblocking under the
[existing waiver](../../NEED_REAL_CHECK.md). No deployment or publication is included.

## Binding design and technical contract

- Character: one continuous bean-shaped head/body, small cream face inset, two simple
  eyes/mouth, short arms, distinct legs/feet; no skin, human head/neck, fabric anatomy
  or robot joints. All eight outfits use this same base and scale.
- Preserve 1.60m visual standing height, foot-centered origin and 0.28m-radius/1.50m
  standing gameplay capsule. Fit broad visual bulk close to capsule; do not enlarge
  physics, reach, damage samples, movement speeds or ragdoll gameplay authority.
- Main body roughly 1.1m high above 0.5m legs, approximately 0.55m wide; face inset
  roughly 0.28×0.32m. These are construction defaults, checked at real camera scale,
  not generated-image measurements. Rubber feet remain readable but not oversized boots.
- Palette: existing cream/sand/slate/teal/coral/grass; saturated player colors plus
  names/numbers/accessory silhouettes. Matte body and painted building surfaces,
  rubber soles, controlled water highlights. No macro photographic textures, glossy
  advertisement lighting, bloom, depth blur, fake lens effects or decorative slogans.
- Environment: preserve current map IDs, 64×64m bounds, existing routes, elevations,
  stable breakable IDs, prop physics budgets and hazard semantics. Concept images guide
  material/composition, not literal generated architecture or performance guarantees.
- Doors remain open/static: minimum 1.8m wide/2.2m high (existing 2.4m entries retained);
  main exterior routes ≥3m; primary interior through-paths ≥2.4m. No furniture in exits,
  stair landings or ramp seams. Static decoration is not additional networked physics.
- Four ordinary elevation routes and at least two refuge exits per primary refuge.
  Windows explicitly decorative or traversable; no fake visually open collision walls.
- Compatibility renderer/Godot 4.7.2; shared generated geometry/materials, editable
  engine text/SVG icons, deterministic seed/provenance in `assets/manifest.json`.
  No new renderer, external asset pack, shader framework or account/economy changes.

### Reference targets (concepts, not acceptance evidence)

- [Selected B, center panel](https://ampcode.com/user-content/attachments/db8feb8c2121ba905e7a61d66d590c5128f19a85a5e93f6aa7e4395f8e5a2ebf-file.png)
- [Town/material direction](https://ampcode.com/user-content/attachments/9de50857d0a091c9e574dcf7cd77f24374287819c9ce0c94233bb1bde4db0322-file.png)
- [Camera exploration](https://ampcode.com/user-content/attachments/7892525abfae727f9bc2a59df9047bc30e0cc03b678bd88e75a4eafdb299158a-file.png)

## 7.1 — Representative in-engine foundation

Owners: `tools/asset_generation/generate_assets.gd`, `game/player/toy_character_visual.gd`,
`assets/generated`, `assets/materials`, `scenes/player.tscn`, `game/player/player.gd`,
existing town construction in `game/main.gd`.

- [ ] 7.1a Generate one plain Soft Creature with stable face/limb pivots; reuse the
  current procedural pipeline and public visual API. Build one representative shop
  facade, sidewalk/road module and interior corner using reusable material/geometry.
- [ ] 7.1b Render actual camera candidates A/B with current controls, then use high
  three-quarter B as the implementation default if clearance/readability checks pass.
  Start with 9–12m spring arm, about 30–38° downward pitch, 55–65° FOV. These are tunable
  local presentation values, not the image's asserted coordinates. Do not add overhead
  gameplay mode; retain mouse look, camera-relative movement, sensitivity/invert-Y and shake.
- [ ] 7.1c Check collision arm retraction and indoor visibility. Add local-only fading
  of specifically tagged roof/wall visual meshes if retraction alone fails; never fade
  collision or shelter volumes. Restore opacity on exit, camera ownership transfer,
  spectating, map rebuild and rematch. Avoid scanning every mesh every frame.

Gate G7.1: inspect 720p/1080p outside, doorway, room, ramp, rooftop and carrying captures;
record a moving camera/traversal clip. Character fits world scale, ground remains visible,
no clip-through or invisible shelter, camera yaw survives reconciliation. Run existing
player/collider/map-safety checks. Capture identical candidate paths before picking defaults.

## 7.2 — Character animation, ragdoll and eight outfits

Owners: generator, `toy_character_visual.gd`, `cosmetic_ragdoll.gd`, player integration,
`assets/cosmetic_catalog.json`, collection preview and manifest.

- [ ] 7.2a Preserve `ToyCharacterVisual` API, required animation names/durations, scene
  consumers and 18-bone contract where useful. Replace old head/torso geometry at the
  source, not with one-off consumer wrappers. Continuous body must stay continuous
  through idle/run/crouch/carry/shove/emotes, with ≤8% visual-only squash.
- [ ] 7.2b Rebuild cosmetic ragdoll appearance to match B. Current rig's separate cream
  head and primitive human limbs cannot be shipped unchanged. Keep existing 11-body,
  10-joint, 55kg physics contract; attach a coherent deforming visual to the rig rather
  than exposing physics primitives. Use Godot-native skinning if required to maintain
  continuity; no extra simulated bodies/accessory collisions or replicated ragdoll meshes.
- [ ] 7.2c Adapt all catalog IDs: plain, cap, hard_hat, backpack, raincoat, mechanic,
  park_ranger, meteor_observer. Hats sit on bean top; back attachments fit body; outfit
  shells/panels retain color and silhouette without recreating human clothing anatomy.
  Preserve four starters/four earned, saved odds, server ownership and lobby-only equip.

Gate G7.2: inspect front/back plus walk/run/jump/crouch/carry/ragdoll/get-up for each
outfit at both widths; continuous silhouette, face and accessory attachment survive
motion. Run phase1, collider, player integration, carry, emote and collection tests.
Update geometry-specific expectations only when intentional, never erase gameplay checks.
Record deterministic regeneration/hashes, topology/clip inventory and provenance.

## 7.3 — Town construction and usable interiors

Owner: existing `_build_toy_town`, map anchors, building/prop helpers and
`game/breakable_structure.gd`. Reuse geometry construction; extract a map builder only
if the coherent new construction responsibility warrants it, not incidental helpers.

### Explicit content layout

| Building | Placement/structure | Required interior and routes |
| --- | --- | --- |
| Shop | Existing (-16,-13), 12×10m, roof 4.855m | Sales room + rear stock alcove, counter/shelves off through-path, north/south exits, existing roof ramp/panel retained |
| School | Restyle existing Hall at (16,-13), 12×12m, roof 4.855m | Entry/corridor and two compact classroom zones; desks/chairs, board, coat storage; north/south exits and existing Hall ramp/panel IDs retained; visible name SCHOOL |
| House | New center (-26,25), footprint 8×8m, single storey | Living/kitchen area + bedroom nook, front/back exits on north/south faces, window trim, sparse furniture; static roof, no new primary refuge or dynamic destruction |
| Garage | Existing (-15,15), 14×12m deck | Marked bays, beams, perimeter tools/shelving; existing ramp and upper canopy kept clear |
| Pocket Park | Existing platform/routes | Matching benches/trees/rails, preserve normal ramp and optional crate-boost escape aid |

Coordinates use existing x/z map plane. House bounds x[-30,-22], z[21,29] leave the
boundary and garage face separate; validate actual canopy/collision clearance before
construction. Roofs are not universally safe. School is an intentional Hall content
change, not a third large landmark wedged into the central plaza.

- [ ] 7.3a Build shared authored wall/window/trim/awning/furniture/road elements. Broad
  bevels and value hierarchy, consistent curbs/crossings/grates/lamps, restrained density.
  Preserve ≥40% unobstructed ground and existing 18×18m plaza; house must not block
  spawn groups or required routes. Merge repeated decorative geometry where practical.
- [ ] 7.3b Add interiors and actual sight lines. Each primary room has readable purpose,
  grounded furniture, no floor clipping or stairs that stop short of landings. Static
  internal partitions match cover/roof geometry; do not accidentally create a sealed trap.
- [ ] 7.3c Update map anchors/refuge labels and indoor hazard coverage deliberately.
  Keep stable runtime Hall IDs for historical breakables/routes but visible school label.
  Add house cover only where physical roof/walls justify it. Garage's existing `shelter`
  group alone does not grant tornado cover: reconcile explicit cover volumes with geometry.
  Add indoor fire cells/graph links where needed; warn propagation, no global immunity.

Gate G7.3: real controller walks all exits/ramps and interior through-paths, at least four
ordinary elevation routes pass with collision, two exits per primary refuge remain
after allowed breakage. Test actual meteor cover, tornado reduction, flood exposure and
warned fire in representative rooms. Map-safety/variety/identity + breakable-reset tests
pass. Inspect daylight/night hazard captures, rooms and school roof at 720p/1080p.

## 7.4 — Harbor parity and restrained disaster presentation

- [ ] Apply shared construction/material detail to Warehouse interior, docks, crane,
  cargo platforms and existing props without changing map ID, height/refuge contracts,
  gangway breakables or basins. No house/school grafted into harbor.
- [ ] Refine all six disasters: compact matte meteor/short trail, clean blue flood,
  readable tornado footprint/rings, restrained quake dust, local fire and sharp violet
  lightning. No bloom/opaque prolonged particles. Every warning remains icon+name+time;
  ground telegraph radius/timing match authoritative damage, not concept artwork.
- [ ] Preserve event-driven combinations, Normal/Hard damage parity, force bounds,
  no-repeat/solo-before-overlap/max-two rules and audio warning audibility.

Gate G7.4: inspect each hazard and Flood+Lightning/Tornado+Fire/Fire+Earthquake overlaps
in both maps with visible traversal and player silhouettes. Existing disaster/director,
cover/fairness and combinations tests pass; no gameplay tuning hidden in art changes.

## 7.5 — Complete interface, not just menu skins

Owners: `game/ui/ui_tokens.gd`, other `game/ui/*`, `scenes/main.tscn`, `game/main.gd` wiring.

- [ ] 7.5a Shared type/spacing/icons/states: tactile cream/slate/teal/coral, shallow
  depth, no giant packaging borders during play. Use licensed readable sans/engine
  fallback, editable strings and semantic amber/orange/violet. No currency/rarity/shop.
- [ ] 7.5b Entry/local/direct-IP/managed create/join/lobby, map/preset selectors,
  2/4/8/20-player roster and owner departure, loading/field failure/offline/retry states.
- [ ] 7.5c HUD health/alive/timer/shove, up to two hazards/combinations, personal danger,
  death cause and spectator target/cycle; pause/settings including display confirmation.
  Leave room safely; menus never pause authoritative matches.
- [ ] 7.5d Collection all owned/locked/equipped/loading/unavailable states, rotatable
  accurate preview, odds disclosure and sealed/open/reveal/replay/complete pool states;
  results solo/shared/ranked20/earned or no-drop, rematch and return-to-lobby.
  Equip only after acknowledgement; reward opening never blocks rematch.

Gate G7.5: rendered 720p/1080p representative states, long names and 20 rows have no
clipping; keyboard/controller focus, Escape/back/focus return, disabled/pending/retry,
reduced motion remain correct. Record/inspect clips for navigation, preview and reveal.
Extend existing public-behavior UI regressions, not private layout/call-order tests.

## 7.6 — Cross-system gate before zone behavior

- [ ] Run `GODOT_BIN=$(command -v godot) tests/run_ui_regression.sh`; require positive
  markers and strict runtime-error checks. Run relevant profile-enabled 4/8/20-client
  fixtures with rematches, owner departure/crash retry and earned outfits.
- [ ] Compare `tests/profile_overlap.gd -- --cosmetics` with/without `--preview` at 720p
  and `--1080p`, 120 warmup/600 samples, V-Sync disabled; report p95, nodes, draw calls,
  geometry/memory and import costs on matching scenarios. Cap mesh costs at existing
  3k–6k triangles/base and <800/accessory; no new simulated prop bodies. Keep UI and
  preview node counts stable through ten opens/rematches. Serialize heavy jobs.
- [ ] Commit validated source and archive Phase 7 under existing policy before making
  Phase 8 current. No local package claimed until final integrated committed source.

Gate G7.6: regression/multiplayer and visual gates passed, measured performance results
honestly recorded. Software rasterizer failing 60FPS is not a new success claim or
permission to relax correctness; investigate measured regressions. Native GPU/Windows/
audio/Internet acceptance stays explicitly unverified and nonblocking under prior waiver.

## Non-goals and risk responses

No weapons, ranked economy, new account system, extra maps/disasters, dynamic doors,
AI inhabitants or fully simulated furniture. If camera fading, character deformation,
interior routes or materials fail, fix the representative slice first; don't propagate
a broken family. Never replace the liked environment with unrelated generated styles.
Zone behavior belongs to [Phase 8](phase-8-shrinking-survival-zone.md), after art/map parity.
