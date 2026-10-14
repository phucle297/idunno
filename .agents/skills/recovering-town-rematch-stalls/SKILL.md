---
name: recovering-town-rematch-stalls
description: Diagnoses Disaster Party managed-client disconnects during large-map rematches. Use when managed scale times out awaiting ACTIVE after a rematch or expanded world rebuilding stalls ENet polling.
---

# Recovering Town Rematch Stalls

Keep static town geometry out of the same-map rematch reset path.

1. Distinguish initial Start from rematch at `tests/run_managed_scale_test.py`.
   Capture each peer's state/network/roster before temporary control files disappear;
   never print credentials or admission tickets. An ACTIVE server with missing
   peers and offline clients is not a readiness-snapshot failure.
2. Time `game/main.gd::_reset_sandbox` in the actual failing workload. The fixture
   sets ENet timeout `(1, 500, 1500)` for crash recovery. Do not increase it or add
   retries to hide synchronous rebuilding stalls.
3. Phase7T reproduced this three times: all20 admitted and initial Start passed,
   but full rebuild during rematch took645ms under load and clients disconnected.
   Standalone reset was114ms. Retaining static geometry and resetting mutable
   structures/props reduced standalone reset to1ms and the unchanged managed20
   test passed five rematches, owner transfer and crash retry.
4. Preserve the reset contract: release held props, restore broken structures and
   remove their debris, restore crate spawn transform/zero velocities/dynamic
   physics and synchronize PhysicsServer state. Scope resets to that Sandbox,
   not global groups that may contain another scene. Map identity changes still
   rebuild geometry and anchors; do not reuse the previous map.
5. Run `tests/test_map_safety.gd` for repeated broken-roof/crate restoration,
   `tests/test_map_identity.gd` for map switching, then the unchanged managed20
   runner and `tests/run_ui_regression.sh`. Require positive markers and reject
   runtime errors. Record failure and recovery separately in active progress.
