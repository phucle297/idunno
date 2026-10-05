# Disaster Party Design Bible and Asset Generation Contract

Version 1.0 — Proposed production baseline

## 1. Purpose and authority

This document accompanies the original Disaster Party development prompt. It defines a single visual and physical language for characters, environments, props, animation, disasters and generated assets. Use it as the source of truth whenever an implementation or generation choice affects presentation or gameplay readability.

The intended game is a casual third-person multiplayer disaster survival game for Steam and Windows. The vertical slice contains one map, four-player multiplayer, Meteor Shower, Flood and Tornado. Design capacity is 20 players; 100-player support is outside the slice. All measurements and budgets below are initial tuning targets, not claims of proven performance.

Generate the prototype assets as part of development. Do not deliver an empty scene that requires the developer to find models. Prioritize reproducible procedural 3D assets; use image generation for reference sheets or selected 2D assets when available. Images are not substitutes for rigged meshes, colliders or animations.

Order of authority: explicit user instructions, this design bible, the original development prompt, then engine conventions. Record deliberate deviations in a decision log. Never silently introduce a second art style.

## 2. Unified visual direction

**Friendly toy town under ridiculous disasters.** Everything resembles a small physical playset: chunky forms, rounded edges, matte plastic surfaces and exaggerated motion. Disasters feel dramatic while injuries remain comic and non-graphic.

The silhouette must communicate function before surface detail. Use large shapes and broad color areas. Characters, vehicles, buildings and debris share the same bevel treatment and material family. Avoid realistic skin, photographic textures, gritty scratches, dense foliage, pixel art, anime faces, metallic armor, cinematic fog and realistic gore.

Use mostly flat shaded low-poly meshes. Smooth normals are acceptable on rounded heads and curved props; do not alternate between highly faceted and photorealistic assets. Bevel physical edges approximately 2–5% of local object thickness, with a practical cap of 0.08 m on architecture. Structural gameplay surfaces remain flat despite decorative bevels.

Lighting uses a warm daylight key and cool ambient fill. Keep shadows soft and interiors readable. Do not rely on heavy outlines or post-processing to make an object recognizable. Disaster effects may change lighting briefly, but must not hide jumps, players or telegraphs.

## 3. Palette and material system

| Role             | Color   | Use                                           |
| ---------------- | ------- | --------------------------------------------- |
| Warm cream       | #F4E6C8 | Walls and neutral surfaces                    |
| Sand             | #D9B77E | Walkways and wood-like toy pieces             |
| Slate            | #49566A | Roads, structural frames and neutral contrast |
| Muted teal       | #73B7AD | Secondary buildings and environmental accents |
| Muted coral      | #D98D7D | Secondary buildings and roofs                 |
| Grass            | #86A968 | Ground and simplified foliage                 |
| Water            | #42B8E8 | Flood surface and splash                      |
| Warning amber    | #FFBF3F | Warnings and incoming hazard boundaries       |
| Danger orange    | #F06438 | Active fire and impacts                       |
| Lightning violet | #B892FF | Electrical hazards                            |
| UI ink           | #202A38 | Text and dark UI backgrounds                  |

Character colors are saturated cyan, orange, purple, lime, pink and blue. Names, numbers and accessories supplement color; color alone must never identify a player or hazard. For 20 players, combine six color families with numbered badges and at least four clear accessory silhouettes rather than inventing 20 barely distinguishable hues.

Maintain one shared material library: plastic matte, rubber, wood-painted plastic, translucent water and emissive hazard. Opaque objects use metalness 0 and roughness around 0.65–0.9 where the renderer exposes these parameters. Water is the exception. Do not give every prop a unique shader or texture.

Initially use vertex colors and shared materials. Add texture atlases only when needed for faces, signs or decals. Keep text on signs generated as vector or engine text so it stays editable. Do not generate fake unreadable signage into textures.

## 4. Character design

### Body and silhouette

One base humanoid body and one skeleton serve all players. Characters are rounded toy people wearing a one-piece utility suit, mitten hands and chunky rubber shoes. Their facial design uses two dark oval eyes and a small mouth. No fingers, hair strands or detailed facial anatomy are needed.

| Property                  | Baseline                                    |
| ------------------------- | ------------------------------------------- |
| Standing height           | 1.60 m                                      |
| Head height               | 0.43 m                                      |
| Head width                | 0.48 m                                      |
| Torso width               | 0.43 m                                      |
| Shoulder width            | 0.56 m                                      |
| Shoe length               | 0.24 m                                      |
| Standing movement capsule | Radius 0.28 m, total height 1.50 m          |
| Crouched capsule          | Radius 0.28 m, total height 0.95 m          |
| Visual mesh target        | 3,000–6,000 triangles excluding accessories |
| Accessory target          | Under 800 triangles each                    |

Head size and limb thickness must stay consistent across variations. Cosmetics do not change movement hitboxes or gameplay reach. Put the mesh origin at the center between the feet on the ground plane. Define the canonical Blender source convention as meters, Z up and character forward −Y; explicitly convert to the selected engine during export.

First variations: plain suit, cap, hard hat and small backpack. Accessories remain attached during normal movement and ragdoll; they do not become networked debris. Limit each character to one prominent head accessory and one small back accessory. All variations use the same hand and foot proportions.

### Rig and animation

Use a compact humanoid skeleton with root, pelvis, spine, chest, neck, head, upper/lower arms, hands, upper/lower legs and feet. Use stable bone names and identical bind poses for all characters. Generate walk and run cycles procedurally if no animation tool exists; never leave a frozen T-pose in the playable build.

Required clips: idle, walk, run, jump takeoff, falling, landing, crouch idle, crouch walk, holding idle, holding walk and getting up. Target durations: idle 2 s, walk 0.8 s, run 0.55 s, takeoff 0.15 s, landing 0.20 s and get-up 0.8–1.2 s. Locomotion is driven by movement state with visual foot timing; avoid root motion in the slice.

Animation exaggeration comes from torso lean and arm swing. Landings squash the visual body by at most 8% for less than 0.15 s; never scale the collider. Faces may switch between neutral, panic and dazed through a tiny atlas or material parameters.

Ragdoll uses 8–12 simple bodies and limited joints. Disable self-collision between adjacent bodies. Use a common physical scale and mass distribution across all cosmetics. Remote ragdolls may use cosmetic simulation, but server gameplay position and damage remain authoritative.

## 5. Camera and presentation

Use a third-person follow camera, initially 5.5 m behind and 2.6 m above the character, 65° vertical field of view. Expose sensitivity, invert-Y and camera shake strength. Test camera occlusion with every doorway and stairway.

Camera collision pulls the camera forward using a sphere cast. Roofs or wall segments may fade locally when they obscure the controlled character; this presentation change never alters collision or shelter rules. Keep the player's body visible whenever practical.

Camera shake communicates impact rather than sustained loss of control. Limit strong shake to short impulses. Earthquake uses restrained visual motion with a user setting to disable shake. Low-health presentation must not add opaque red overlays that hide telegraphs.

## 6. First map design

### Toy Town Square

A 64 × 64 m playable block with a central plaza, three distinct landmarks, a road loop and usable rooftops. Ground level is 0 m; intermediate platforms are 2.0–2.5 m; roofs are approximately 4.5 m and 6 m. A flat visual skyline and toy backdrop establish boundaries without suggesting a large explorable city.

| Area           | Footprint | Purpose                                           |
| -------------- | --------- | ------------------------------------------------- |
| Central plaza  | 18 × 18 m | Clear meeting area and meteor visibility          |
| Corner shop    | 12 × 10 m | Roof access, indoor shelter and fire risk         |
| Parking garage | 14 × 12 m | Wide ramp, elevated route and vulnerable sections |
| Community hall | 12 × 12 m | Covered shelter, two exits and low elevation      |
| Road loop      | 5 m wide  | Fast travel, exposed to flood and meteors         |
| Pocket park    | 12 × 10 m | Props, alternate routes and tornado exposure      |

Use four routes from low ground to elevated positions. Every primary refuge has at least two entrances or escapes. Main paths are at least 3 m wide; doorways at least 1.8 m wide and 2.2 m tall. Stairs use a hidden ramp collider. Avoid compulsory single-file jumps for 20 players.

Each rooftop has a staircase or ramp and an alternate traversal route. Optional jumps may save time; basic survival should not depend on advanced parkour. Roof gaps on normal routes are 1.5–2.5 m with landing pads at least 2 × 2 m. Mark traversal ledges with consistent cream or teal trim rather than unique material rules per building.

Keep at least 40% of the map unobstructed to provide hazard visibility. Indoor spaces contain simple furniture and no clutter that catches the movement capsule. Windows may be decorative or traversable; distinguish the two through size and framing.

### Shelter and destruction

Flood threatens low ground, meteors threaten exposed areas and tornado threatens open paths. Indoor shelter reduces tornado force when the server detects a valid cover volume. Cover does not create universal immunity. Meteors can break tagged roof panels after visible damage; some roof sections remain structural to preserve traversability.

Build six predefined breakable sections: two roof panels, two short bridges and two sign or awning assemblies. Each has intact, damaged and broken states. Never destroy all routes to elevation at once. Structure state is replicated; decorative fragments are mostly client effects.

Destroying a section produces at most four short-lived cosmetic fragments and at most one gameplay debris body. Restore every section during rematch. Do not permanently flood or burn the map between matches.

## 7. Modular environment kit

Build on a 1 m placement grid, with 0.25 m substeps for props. Architecture uses wall modules 2 m wide and 2.5 m high, floor modules 2 × 2 m and roof modules 2 × 2 m. Use compatible doorway and window modules. Store snap anchors explicitly.

Required kit: wall, window wall, doorway wall, floor, flat roof, pitched roof facade, stair visual with ramp collider, railing, fence, awning, pillar and breakable panel. Build all three landmarks from this kit using different palette assignments and silhouettes.

Prop set: bench, bin, crate, barrel, traffic cone, sign, toy car, park tree and lamp. Trees use a chunky trunk with two or three foliage masses. Cars are static shelter props in the slice, not driveable vehicles.

Architectural targets: 100–800 triangles per module. Small props: 100–600. Landmark assemblies: approximately 10,000–20,000 excluding reused instances. Use simple box, capsule or convex colliders. Reserve triangle collision for static surfaces only where primitive approximation fails.

## 8. Movement and physical behavior

All values are starting points for playtesting. Keep them in a central configuration rather than scattering constants through controllers and hazards.

| Parameter              | Initial value                      |
| ---------------------- | ---------------------------------- |
| Walk speed             | 4.5 m/s                            |
| Sprint speed           | 6.5 m/s                            |
| Crouch speed           | 2.5 m/s                            |
| Ground acceleration    | 25 m/s²                            |
| Air acceleration       | 8 m/s²                             |
| Gravity                | 20 m/s² downward                   |
| Jump height            | 1.35 m                             |
| Initial jump velocity  | About 7.35 m/s                     |
| Coyote time            | 0.12 s                             |
| Jump input buffer      | 0.12 s                             |
| Step height            | 0.30 m                             |
| Max walkable slope     | 45°                                |
| Physics reference rate | 60 Hz, subject to engine profiling |

Use a responsive capsule controller for normal movement; transition to ragdoll for strong impacts. Do not require a fully simulated upright rigidbody to walk. The estimated level-ground jump range is about 4.8 m at sprint speed before tuning; normal map gaps remain substantially shorter.

Player interaction uses a soft shove or separation impulse, not unlimited rigidbody stacking. Prevent persistent overlap and rapid force escalation in crowds. Introduce optional shove only after basic network movement is reliable. A player cannot repeatedly stun-lock another player: grant a short recovery protection window after standing up.

### Object classes

| Class       | Mass range | Behavior                                                 |
| ----------- | ---------- | -------------------------------------------------------- |
| Lightweight | 2–8 kg     | Cones, empty bins, small signs; grabbable                |
| Medium      | 10–25 kg   | Crates and barrels; grabbable with slower movement       |
| Heavy       | 40–100 kg  | Benches and debris; movable by hazards, not carried      |
| Anchored    | Static     | Buildings, trees and parked cars unless tagged breakable |

Character physical reference mass is 55 kg. Keep surface friction around 0.6 and restitution around 0.05–0.15 initially. Avoid bouncy pinball reactions unless explicitly part of an event. Clamp extreme linear and angular velocities on loose bodies.

Grab range is 1.5 m. One player owns an object at a time, with server arbitration. Hold with a bounded spring or constrained target, not teleporting transforms through walls. Release on death, ragdoll, excessive separation or owner disconnect. Ignore collision between a held object and its holder where necessary; continue collision with the world and other players.

### Damage and recovery

Start at 100 HP. No ordinary walking-contact damage. Collision damage requires a significant relative impact and has a per-source cooldown. Fall damage starts above an impact speed around 9 m/s and increases to lethal near 18 m/s, with a tuned curve. Base damage on server impact measurements, not camera animation.

Ragdoll lasts at least 0.6 s. Recover after speed is low and a valid surface is available, normally within 1.5–2.5 s. Search for a nearby non-overlapping capsule position before standing. Use a bounded timeout recovery only when it will not rescue a player from an active lethal hazard. Out-of-bounds death is clearly signaled.

## 9. Disaster visual and physical specification

### Meteor Shower

Use chunky dark rocks with a hot orange core and a short stylized trail. Ground telegraphs show an amber outlined circle plus a countdown sweep. Initial impact radius is 3 m; early warnings last 2.5 s, later warnings no shorter than 1.2 s. Cover rules must match visible roof geometry.

At impact, server applies damage and a bounded radial impulse once. The visual explosion has a brief bright center, dust ring and a few fragments. Do not spawn a persistent dynamic meteor body for every strike. Pool the visual rocks and effects. Direct hits can be lethal; near misses push and ragdoll.

### Flood

A clean blue surface rises uniformly with large readable ripples. Start with a warning of 6 s, rise toward 3.5 m over approximately 35 s, hold briefly, then drain during recovery. The 6 m roof remains above initial flood, but other hazards make it unsafe.

Determine submersion from server water level and body sample points, not visual particle overlap. Give approximately 2 s of breathing grace before applying 12 HP/s while the head is submerged. Objects use simple buoyancy samples and bounded drag. Limit current speed to around 1.5 m/s initially. Water does not need fluid simulation.

### Tornado

Use a translucent cone made of a few rotating rings, chunky dust and orbiting visual debris. Provide a visible projected danger footprint. Initial influence radius is 8 m, strong core radius 2 m and travel speed about 2 m/s. Cap pull and launch forces; do not create numerical singularities at the center.

Tornado follows server-selected paths and cannot instantly teleport onto a player. Indoor cover volumes reduce pull. Close proximity lifts a player and eventually throws them; players retain some air control after release. Tornado particles are cosmetic and never collide.

### Expansion disasters

Earthquake uses crack decals, local dust and tagged breakable structures. Fire uses chunky orange flames on a fixed zone graph with readable propagation warnings. Lightning uses a thin violet targeting column, a ground ring and a sharp flash. These share the same effect density and warning conventions as the slice.

Flood plus Lightning electrifies connected water zones temporarily after a strike, with violet ripples and an audible cue; it does not silently make all water permanently lethal. Tornado carries tagged burning debris only when Fire exists. Meteor debris can be selected for tornado interaction within the dynamic-body budget. Cross-disaster behavior is implemented through named events and shared hazard queries.

## 10. Fairness and match rules

Keep the original 8–12 minute goal as a configurable target. Early hazards are slower and avoid concentrated lethal patterns. Overlap begins only after players have seen the involved disasters separately. Reserve at least one navigable escape route when selecting breakage and hazard targets.

In multiplayer, end when one survivor remains; if all die in the same authoritative simulation step, declare a shared last-survivor result using elimination time rather than arbitrary player ID. In solo testing, do not instantly end because one player exists: continue until death or timeout. At timeout, rank remaining players by survival, then disasters survived, then least damage taken; allow a shared win if still tied.

Dead players can immediately spectate survivors and cycle targets. Results show cause of death and survival duration. The initial slice does not require a progression system.

## 11. UI and audio language

Use rounded panels, a single readable sans-serif font and a small icon set drawn in the same broad shapes as the world. Display HP, alive count, timer and active hazards. Warnings include icon, disaster name and seconds remaining. Never identify a hazard solely through a color.

Show danger footprints even when effects overlap. Prioritize ground telegraphs and player silhouettes over decorative particles. Keep opaque dust short-lived. UI assets should be generated as SVG where practical, then imported or rasterized at the appropriate resolution.

Create simple synthesized placeholder sounds for warnings, impacts, jump, death and victory if no audio generation tool exists. Flood uses a low pulsing siren; meteor a rising whistle; tornado a broad wind sound. Cap concurrent effect voices and preserve warning audibility. Record provenance for generated audio just as for meshes and textures.

## 12. Asset generation workflow

### Reproducible 3D production

Use Blender Python or an equivalent scriptable modeling workflow to create meshes, bevels, vertex colors, UVs where needed, rigs, simple animation clips and collider proxies. Use primitives as building blocks, but combine them into deliberate authored silhouettes. Placeholders still need correct proportions and usable collision.

Every generation script accepts a seed and parameters, writes to a stable output directory and can regenerate assets without manual editing. Check generated source files and exported game-ready files into the project. A pretty screenshot without usable asset files does not satisfy delivery.

Deliver source .blend files when Blender is available, plus .glb or the selected engine's supported format. Verify meter scale, bone orientation, clip import and material assignment in the engine. The importer may require separate files for animations; test the actual chosen pipeline rather than assuming export compatibility.

Generate the base character, one wall module, one prop and one disaster effect first. Place them together in an asset validation scene. Once proportions, materials and imports pass, generate variants from the same scripts. Do not independently prompt dozens of assets before locking the reference set.

### AI reference generation

If image generation is available, generate a master reference sheet with character front/side/back views, a town kit overview, palette and disaster effect studies. Maintain the same approved reference image for later generations. A turnaround is a visual guide; do not assume its anatomy or measurements are geometrically exact.

Only request 3D generation from a tool that actually outputs downloadable meshes. Such meshes still require cleanup, rig verification, collider creation and style review. If the tool is unavailable, proceed with procedural modeling and clearly record that fallback. Never invent tool access, generate fake paths or label an image as a game-ready model.

### Shared generation prompt

Use this block as the fixed prefix, then append the asset-specific requirements:

> Disaster Party unified art direction. Friendly miniature toy town, chunky rounded low-poly forms, matte painted plastic, broad clean color areas, oversized simple shapes, warm daylight with cool ambient fill. All assets belong to the same physical playset. Use the supplied approved reference and exact palette. Clear functional silhouette at third-person gameplay distance. No photographic textures, realistic anatomy, gritty wear, detailed fingers, dense surface noise, gore or inconsistent rendering style. Preserve specified proportions and scale. Asset: [name]. Function: [gameplay role]. Dimensions: [meters]. Palette slots: [roles]. Output view or asset format: [requirement].

Character reference suffix: front, side and back orthographic views, identical body proportions, 1.60 m figure, 0.43 m head height, mitten hands, utility suit, chunky shoes, neutral pose, plain background, no perspective distortion or decorative text.

Environment reference suffix: modular 2 m wall bays, broad accessible entrances, toy architecture, flat usable roofs, clear stairs, restrained facade detail, same edge treatment as the character. Show functional geometry rather than a cinematic city illustration.

Prop suffix: one centered object, dimensions explicitly named, simple gripping region, no tiny loose attachments, toy-plastic material family, clean silhouette. For 2D cutouts, request transparent background explicitly. For mesh generation, require closed geometry where appropriate, manageable topology and a documented origin.

## 13. Manifest and directory contract

Keep assets under assets/source, assets/generated, assets/materials, assets/animations and assets/references. Put generation code under tools/asset_generation. Use names such as CHR_Base_v001, ENV_WallDoor_2m_v001, PROP_Crate_Small_v001 and VFX_MeteorImpact_v001.

Each manifest record includes: asset ID, category, source path, export path, generator script, seed, generator version, intended dimensions, triangle count, material IDs, pivot, collider type, skeleton version, animation list, gameplay tags, provenance and validation status. Record the actual tool or script and any licensing conditions; do not invent legal clearance.

Generated collision meshes use a distinct naming prefix such as COL_. Breakable structures contain stable piece IDs and snap anchors. Gameplay tags include Shelter, Flammable, Buoyant, Grabbable and Breakable only where behavior is implemented.

## 14. Performance and networking budgets

Initial budgets: at most 32 active authoritative loose rigidbodies across the map, 12 of them grabbable, and two overlapping disasters in the slice. Cosmetic fragments are pooled, non-authoritative and expire after approximately 3 s. Raise budgets only after profiling.

Server decides hazard selection, health, elimination, object ownership, structure state and winner. Clients render particles, lights, camera shake and cosmetic debris. Replicate meaningful state changes rather than every particle or bone. Do not claim that passing a four-player test proves 20-player readiness.

Run local multi-client checks and profile a representative full-disaster scene. State hardware, resolution, build type and player count in performance notes. Target 60 FPS; frame rate is an acceptance target to measure, not a promise based on triangle counts.

## 15. Validation gates

Asset gate: correct dimensions within 5%, approved silhouette, shared materials, valid origin, importable export, no missing dependencies, functional collider and manifest entry. Character gate additionally checks bone compatibility, animation playback and ragdoll recovery in all four cosmetic variants.

Map gate: four routes to elevation, two exits per main refuge, camera works indoors, no hidden collider traps, no spawn inside geometry, hazards visibly match gameplay volumes, and every breakable section resets. Conduct a flood escape test from every spawn group.

Physics gate: no explosive joint instability, grabbed objects release correctly, ragdolls cannot remain stuck indefinitely, movement stays controllable and impact damage cannot fire every simulation frame. Test two players contending for the same object and owner disconnect.

Match gate: four clients join, survive randomized overlapping disasters, die, spectate, obtain consistent results and rematch without restarting. Run at least five rematches to expose persistent debris, materials, callbacks or hazard state. Record unverified checks honestly.

Visual gate: inspect the asset validation scene and the complete map from the gameplay camera, including daylight, flood, meteor impact and tornado overlap. Player silhouettes and ground warnings remain recognizable. Include comparison screenshots in the developer handoff.

## 16. Addendum for the one-shot coding prompt

Paste the following into the original Disaster Party prompt and attach this entire document:

> Generate the usable prototype assets yourself as part of the implementation. Treat Disaster_Party_Design_Bible.md as the authoritative specification for character proportions, map dimensions, palette, materials, animation, physics behavior and generated asset validation.
>
> First inspect the environment and choose one available engine and export pipeline suitable for a Windows multiplayer prototype. Document the choice; do not assume any image or 3D generation service is installed. Implement networking alongside the first controller and sandbox, rather than postponing authority decisions until the end.
>
> Build a reproducible asset generation pipeline using Blender Python or an equivalent available tool. Generate one rigged toy character with four cosmetic variants, a modular town kit, nine prop types, shared materials, required animation clips and Meteor, Flood and Tornado visual assets. Include source scripts, deterministic seeds, exported assets and an asset manifest. If external generation is available, use it for references or source assets and validate the outputs before import. Otherwise continue with procedural assets. Do not block the playable slice on external art tools.
>
> Validate a base character, wall, prop and effect together before producing the full set. Assemble Toy Town Square from the approved modules. Implement simplified colliders separately from visible meshes, bounded physics forces, server-authoritative health and hazards, cosmetic client effects and complete rematch cleanup. Follow the single-player testing exception and simultaneous-elimination rules in the design bible.
>
> Deliver a playable four-player vertical slice, an asset validation scene, all generated asset sources, engine import configuration, an exact run/build guide and a validation report distinguishing tested behavior from remaining work. Add additional disasters only after Meteor, Flood, Tornado and their overlap pass the slice checks. Report missing tools or failed build steps clearly. Do not present concept images, untested networking or unfinished scenes as completed gameplay.

## 17. Development sequence

1. Inspect tools, establish engine conventions and import one generated asset.
2. Lock the shared palette, base character and modular kit in the validation scene.
3. Implement networked movement and basic map traversal with generated animation.
4. Add health, ragdoll, grabbing, match state, spectating and rematch cleanup.
5. Implement Meteor, Flood and Tornado with readable telegraphs and bounded physics.
6. Add director randomness and two-disaster overlap; profile the resulting scene.
7. Inspect art consistency, tune movement and warnings, then run the multiplayer validation gates.

The design is successful when assets feel like parts of one toy world, hazards remain readable, and friends create funny survival moments through movement and interaction. Tune the proposed values through playtesting while preserving the visual language and reproducible generation pipeline.
