---
name: recovering-room-retry-fixtures
description: Diagnoses Disaster Party room-UI crash-retry fixture races. Use when Docker tests report Room not found or Retried room must contain both real clients after recreation.
---

# Recovering Room Retry Fixtures

Separate a discovery failure from a roster or ENet failure before changing production code.

1. Inspect `tests/room_ui_peer.gd`, `tests/test_room_service.py` and retained logs. Record each role's discovery status, busy/network state and roster at the failed boundary. Never log passwords or admission tickets.
2. A fixed delay between crash and guest Join does not prove the owner recreated a ready room. Confirm whether the guest received `unknown_room` while the new owner was still starting. Preserve that evidence; do not increase sleeps or relax the two-client assertion.
3. Synchronize the fixture using `--retry-ready-file`: Python observes `ROOM_UI_RETRY_ADMITTED role=owner` before releasing the guest. Each client asserts the two-player roster and sends Ready before teardown; wait for the replicated readiness barrier.
4. Run the actual crash-retry test repeatedly under the failing container resource limits, then `bash tests/run_container_network_test.sh` and `python3 tests/run_managed_container_test.py`. Keep strict runtime-error checks and positive markers.

Readiness synchronization fixes fixture ordering, not a production retry failure. If readiness is confirmed but admission still fails, investigate the actual HTTP/ENet boundary; use `recovering-enet-room-disconnects` for channel-zero departure errors.
