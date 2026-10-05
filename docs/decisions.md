# Implementation Decisions

## 2026-10-05 — Engine and initial asset pipeline

- **Decision:** Godot 4.7.2 stable, GDScript, Compatibility renderer, with ENet multiplayer APIs and Windows export templates.
- **Reason:** The official portable Linux editor is available for this x86_64 WSL2 environment, Godot supports the target Windows build, and its scene/resource format supports deterministic procedural prototype assets without waiting for Blender.
- **Renderer constraint:** Compatibility is the validated baseline because this WSL display does not expose the Vulkan surface extension required by Forward+. Re-evaluate Forward+ on the Windows target only after an exported build is available; do not claim it tested here.
- **Initial asset path:** Generate the first character proxy, wall, prop, materials, and effect proxy as authored Godot scenes/resources. Add Blender `.blend` and `.glb` outputs later only after Blender is available and the measured import pipeline passes.
- **Authority boundary:** Multiplayer authority is designed alongside the first controller; no networking capability is considered complete until tested with separate local peers.
- **Known limitation:** No engine or Blender was preinstalled. Quaternius animation clips and retargeting remain unverified until the free archive is downloaded and inspected.
