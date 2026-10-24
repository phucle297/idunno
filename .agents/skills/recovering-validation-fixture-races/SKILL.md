---
name: recovering-validation-fixture-races
description: Diagnoses Disaster Party observer/workload lifetime races. Use when moving-client profiles report no server displacement or held-loading snapshot checks fail after legitimate peer departure.
---

# Recovering Validation Fixture Races

Keep the scenario alive until every observer finishes; prove the race before
changing a test. This is not a blanket explanation for flaky validation.

## Diagnose

1. Read the first failing assertion, its fixture, and the production state owner.
   Preserve the failed log. Do not rerun the entire gate blindly, increase a
   timeout, prewarm a map, retry Start, or weaken a positive movement assertion.
2. Record both halves of compound checks: loading state and snapshot sequence,
   roster and generation, or server position and the moving client's input
   lifetime. Distinguish legitimate lifecycle transitions from forbidden work.
3. Use a bounded controlled skew to reproduce the suspected race, then remove
   temporary hooks. Keep heavy jobs serialized and native timing claims separate.

## Moving Client Finishes Before Its Observer

- Owner: `tools/profile_multiplayer.py` and `profile_multiplayer_peer.gd`.
- The client's trace completing does not mean the server has sampled its motion.
  Keep bounded alternating real input active until all requested traces have been
  read and checked. The driver then sends the private `stop_movement` command.
- Proven control: delaying the server observer by 2s produced zero authoritative
  displacement with early release, versus 0.925m with shared-workload ownership.
  Keep sample counts, server FPS and the displacement assertion unchanged.
- Run `python3 -m unittest discover -s tests -p test_multiplayer_profile.py` with
  the pinned engine in `GODOT_BIN`; it exercises real two/four-client sessions.

## Departure Races the Held-Loading Observation

- Owner: `tests/map_loading_network_peer.gd`. Production correctly resumes lobby
  snapshots after a departure cancels loading. A fixed client-side sleep is not
  synchronization with the server's 100ms snapshot observation.
- Proven fast-departure control: `loading=false`, roster reduced to one, sequence
  26→27. The old compound assertion misreported this as redundant loading work.
- Hold the actual departing peer until the authority finishes its unchanged
  snapshot assertion and sends a test-only reliable release RPC. The client waits
  for its real transport close, not a timer, before its fixture is freed.
  Keep real preparation, ENet, generation checks and existing deadlines intact.
- Run `tests/run_map_loading_network_test.sh` twice. Require held ACK, departure
  abort, timeout, stale ACK, second-map retry and both-client ACTIVE markers.
- In a disposable checkout, remove only production's `not _map_loading` snapshot
  guard and rerun the corrected fixture. It must still fail the snapshot check;
  otherwise the fix may merely have hidden a genuine regression. Never commit
  that negative-control mutation or leave it in the working production source.

Record executed controls in `progress.json`, then run the unchanged normal staged
gate. A managed20 cold-Start timeout without these observations is still
unexplained: use `recovering-town-rematch-stalls` rather than assuming this race.
