# Disaster Party — Active Decisions

The [rounded-world rebuild archive](old-docs/phase-7-rounded-world-rebuild/decisions.md)
records the owner's rejection of boxy7R visuals, curved render geometry, exact
reference image and executed evidence. Source was pushed; user aesthetic approval,
exact concept parity and native GPU performance are not claimed. Layout, scene
density and lighting remain simpler than the concept.

Phase8 remains [planned](checklists/phase-8-shrinking-survival-zone.md), not started.
No automatic phase activation, deployment or release follows this source delivery.
Root [progress](../progress.json) owns the next action; the existing manual-check
waiver remains unchanged.

## 2026-10-14 — Integrated town correction

Owner rejects7S continuity, paving, canopy, map density/size/elevation and stairs.
Preserve prior evidence, not its aesthetic conclusion. Replace presentation pieces
with continuous envelopes/curved canopy and readable treads. Expand Town to112m,
retain Harbor64m. Add populated terrain districts rather than nonplayable skyline.
Per-map bounds and hazard surface placement must follow the real new collision.
No safe-zone, deployment/release or new human-check prerequisite in this scope.

### Rematch recovery and measured limits

Expanded static geometry exposed a reproducible managed20 rematch stall: the
authority entered ACTIVE but clients disconnected during full world rebuild.
Measured reset645ms under that workload,114ms alone; fixture ENet minimum500ms.
Reset same-map mutable state in place (breakable sections, debris, crate spawn
transform/velocity/physics), keep static town nodes, rebuild on map identity changes.
The unchanged managed20 runner then passed five rematches, owner transfer and
crash retry; standalone reset1ms. Keep timeout/capacity unchanged. Prevention in
`recovering-town-rematch-stalls`; final combined regression remains the delivery gate.

Measured2962 visible town mesh instances /2320942 triangles, including repeated
detail. No native GPU budget claim. Actual-framebuffer review confirms continuous
shell/canopy and terraced populated streets, not organic terrain or exact concept
parity. Shadow flecks at the Shop base persist; lowering normal bias introduced
surface acne, so tuning experiments were discarded rather than masking the issue.

### Owner follow-up — progressive loading proposal, not implemented

Current source still constructs the whole map initially. Same-map rematch reuse
is not streaming. Recommend24m chunks,3×3 detailed residency around the camera,
5×5 prefetch and distant coarse shells; keep large buildings/stairs whole and
preload destination before spectating/teleport. Server collision and hazards must
remain authoritative across the full map. Client visuals can stream independently;
simply hiding nodes saves neither construction time nor resource memory.
Chunk resources/data separation from the current main.gd procedural assembly and
measured boundary/load/memory tests need their own agreed work scope. No streaming
implementation, new active phase or automatic Phase8 activation is inferred.
