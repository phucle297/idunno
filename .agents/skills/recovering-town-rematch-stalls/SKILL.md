---
name: recovering-town-rematch-stalls
description: Diagnoses Disaster Party managed-client disconnects during cold Start or large-map rematches. Use when managed scale times out awaiting ACTIVE or world construction stalls ENet polling.
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

## Cold Start and Cooperative Construction

- Keep selection metadata-only; never prewarm the managed cold-Start gate or
  lengthen its ENet/HTTP/state deadlines. `(1, 500, 1500)` may time out an
  unacknowledged reliable command at500ms, not only at1500ms.
- A4ms checkpoint is not an interrupt: measure the longest uninterrupted work
  interval and frame gap under the real20-client workload. Phase22 measured
  375–585ms compound Town construction spans despite outer checkpoints. Split
  base pieces, buildings, ramps and civic construction between completed units.
- Yield normal frames, not recursive `MultiplayerAPI.poll()` or peer polling
  inside an RPC. Freeze roster synchronously, construct outside RPC dispatch,
  and require authority-local readiness plus every frozen peer's current ACK.
- Budget partition traversal/triangle clipping, terrain caching, weather mesh
  registration and deletion too. Skip mesh/triangle districts with disjoint
  bounds; Phase22 reduced standalone cooperative preparation5408ms to2087ms.
  After splitting the remaining measured bursts, real managed20 passed cold
  Start, movement at every peer, five rematches, owner transfer and crash retry.
- Pin map/generation/connection while loading; stale lobby snapshots cannot
  change the target. Cancel old work and finish its cleanup before replacement.
  Keep anchors/players unavailable and rigid props frozen until complete.
- Preserve subtree lifetimes during cleanup. Freeing collected descendants
  individually across frame yields caused a native crash on Town/Harbor replacement;
  budget top-level subtree destruction instead, checking validity after yields.
  Re-run `tests/test_disaster_combinations.gd` and real map-loading ENet controls.
- Hide partial Sandbox rendering behind the loading UI. Inspect rendered solo
  loading and gameplay as well as headless networking; software rendering of
  thousands of partial meshes otherwise makes each construction yield costly.
- Lobby-movement fixtures must finish explicit preparation before connecting,
  then acknowledge that both observers recorded their origins before walking.
  Otherwise the host can finish its movement before the client samples it,
  exhausting the readiness deadline. Keep real Start/ACK flow and cold loading
  in separate unprewarmed gates; do not fix observation races with longer sleeps.
- Capture selective peer diagnostics before temporary control files disappear.
  Retain strict script/runtime checks and distinguish shutdown-only warnings.
