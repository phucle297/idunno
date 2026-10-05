# Implementation Decisions

## 2026-10-05 — Engine and initial asset pipeline

- **Decision:** Godot 4.7.2 stable, GDScript, Compatibility renderer, with ENet multiplayer APIs and Windows export templates.
- **Reason:** The official portable Linux editor is available for this x86_64 WSL2 environment, Godot supports the target Windows build, and its scene/resource format supports deterministic procedural prototype assets without waiting for Blender.
- **Renderer constraint:** Compatibility is the validated baseline because this WSL display does not expose the Vulkan surface extension required by Forward+. Re-evaluate Forward+ on the Windows target only after an exported build is available; do not claim it tested here.
- **Initial asset path:** Generate the first character proxy, wall, prop, materials, and effect proxy as authored Godot scenes/resources. Add Blender `.blend` and `.glb` outputs later only after Blender is available and the measured import pipeline passes.
- **Authority boundary:** Multiplayer authority is designed alongside the first controller; no networking capability is considered complete until tested with separate local peers.
- **Known limitation:** No engine or Blender was preinstalled. Quaternius animation clips and retargeting remain unverified until the free archive is downloaded and inspected.

## 2026-10-05 — Authoritative prop grabbing

- **Decision:** A server-only `GrabManager` owns player registration, one-owner prop claims, spring forces, collision exceptions, and disconnect cleanup. Players supply interaction geometry and request toggles but do not assign prop ownership.
- **Reason:** Shared prop ownership is neither match scoring nor player-local state. Keeping arbitration in one node prevents two players from claiming the same body and gives death, ragdoll, excessive separation, disconnect, and rematch cleanup a common release path.
- **Physics constraint:** Held props receive a clamped spring force and remain world-colliding rigid bodies; they are never teleported to the hold point.

## 2026-10-05 — Meteor Shower authority and impact

- **Decision:** One server-owned `MeteorShower` component controls the complete strike lifecycle: warning target and countdown, one damage batch, bounded player and prop impulses, ragdoll trigger, survival credit, and cleanup.
- **Reason:** Keeping selection and gameplay outcomes in one authoritative component prevents clients from creating damage or force while allowing its telegraph and short impact effect to remain presentation-only children.
- **Physics constraint:** The initial strike uses a 3 m radius, 0.75 m lethal core, distance-scaled near-hit damage, an 8 m/s-equivalent player impulse cap, and an 18 N·s prop impulse cap. It never creates a persistent dynamic meteor body.
