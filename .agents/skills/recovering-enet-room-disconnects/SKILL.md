---
name: recovering-enet-room-disconnects
description: Diagnoses Disaster Party ENet channel-zero errors during simultaneous room departures and prevents peer-relay regressions. Use for dedicated-room disconnect, crash/retry, or container-network failures.
---

# Recovering ENet Room Disconnects

Keep engine relay errors distinct from gameplay RPC, admission and teardown errors.

## Proven failure and correction

Godot 4.7.2 SceneMultiplayer defaults to server relay. When two clients depart
together, processing one disconnect can send the engine's DEL_PEER notification
to the other, whose native ENet channels have already been destroyed before its
disconnect event is consumed. This emits `Unable to send packet on channel 0,
max channels: 0` even with no gameplay RPCs. Passing assertions do not make that
diagnostic harmless or establish a clean networking gate.

Dedicated Disaster Party clients communicate only with authority. Main sets
`SceneMultiplayer.server_relay = false` before attaching dedicated transport.
Listen-host mode retains relay. Player rosters, ownership and remote entities
are still replicated by authoritative snapshots, not peer discovery.

## Reproduction and recovery

1. Run `godot --headless --path . --script res://tests/test_server_relay.gd -- --relay=true`.
   This intentional negative probe should reproduce the native error without
   Main, gameplay RPCs or scene simulation.
2. Run the same fixture without `--relay=true`. Require `SERVER_RELAY_OK`, two
   departures, one surviving connection and no script/runtime diagnostics.
3. Run `bash tests/run_container_network_test.sh`. Require the strict final
   marker; do not suppress the channel error or weaken fixture assertions.
4. Run `GODOT_BIN=$(command -v godot) tests/run_ui_regression.sh`. Verify gameplay
   snapshots still contain all players although each dedicated client discovers
   only authority at the transport layer. Preserve owner transfer, five rematches,
   crash retry, solo and listen-host coverage.

If an error persists with relay disabled, investigate its actual sender rather
than reusing this diagnosis. An application's broadcast can also include a
native disconnecting peer. `get_peers()` and a server's connected status are not
proof that every target is transport-connected. Do not add per-target wrappers
without a reproduced application-RPC failure that requires them.

## Prevention

- Set relay policy before transport assignment; never accidentally restore relay
  on dedicated reconnect/start paths.
- Keep the no-gameplay reproducer and production-owner contract in regression.
- Stop fixture RPC producers before closing/detaching their transport. Do not
  hide native errors because the test process returned zero.
- Report expected occupied-port negatives and shutdown-only resource diagnostics
  separately from unexpected runtime failures.

## HTTP outage distinction

After a deliberate heartbeat HTTP outage, resuming the listener can process
queued requests whose Godot callers already timed out. Reply writes then raise
BrokenPipeError/ConnectionResetError; this is not the ENet relay failure.
The room-service Handler catches only those two exceptions while flushing
response headers/body. Do not catch generic OSError or roll back room state:
allocation and token expiry remain bounded by the existing lifecycle policy.

Run `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=tests:. python3 -m unittest
test_room_service.Contract.test_response_cancellation_is_not_an_application_failure -v`
to verify both write stages and that unrelated I/O errors still propagate. Run
`python3 tests/run_managed_container_test.py` for actual outage/resume/restart,
unexpired old-ticket rejection and recovery across separately addressed clients.
Keep the managed runner's Python traceback rejection enabled.
