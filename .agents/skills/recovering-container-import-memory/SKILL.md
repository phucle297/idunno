---
name: recovering-container-import-memory
description: Diagnoses Disaster Party managed-container private-import OOM failures and recovers disposable validation processes. Use when eight-player preparation stalls or orb shell commands exit 137 during container tests.
---

# Recovering Container Import Memory

Serialize private editor preparation before admission; run heavy validation jobs one at a time.

## Verified cause and fix

`tests/run_managed_container_test.py` formerly started every client before waiting
for preparation. Two eight-player rooms can run sixteen private Godot editor
imports concurrently, exceeding an 8GiB orb even though settled game processes fit.
The resulting OOM can kill the test coordinator and unrelated shell workloads,
leaving Docker-owned children running. This is an environment startup failure,
not a gameplay assertion pass or evidence that eight-player sessions are broken.

The runner now waits for the service, then each client's `.prepared` file before
starting the next. Admission/state/movement/rematch deadlines remain unchanged.
The serial two-room 4/8 matrix passes isolation, recovery, five rematches and
120-warmup/600-sample physics profiles. Evidence: Phase 5 validation follow-up.

## Prevention and recovery

1. Check `free -m`, Docker availability and already-running validation containers.
   Do not run full regression, exports or other private imports concurrently.
2. Preserve failed logs and identify the exact run prefix (for example
   `disaster-managed-<pid>-8`). Inspect only that run's containers; never prune
   unrelated images, volumes, networks or containers.
3. If the coordinator died, remove only its disposable containers and network.
   If OOM kills shell tools before execution, the owner can stop the disposable
   daemon from Terminal with `sudo systemctl stop amp-svc-audit-docker.service`
   **only when this thread created that service for validation**. Never stop a
   shared runtime or production server as recovery for a local fixture.
4. Confirm memory has recovered; rerun
   `GODOT_BIN=$(command -v godot) python3 tests/run_managed_container_test.py`
   alone. Require both `MANAGED_CONTAINER_OK` markers and strict error scanning.
5. Record actual room/player count, CPU/RAM limit, physics-work p95 and tick-interval
   p95. Physics budget success is not a perfect-60Hz, real-GPU or Internet claim.

Do not extend gameplay deadlines, suppress scale assertions or label an OOM run
passed. Stop a thread-created daemon after validation; keep known shared services intact.
