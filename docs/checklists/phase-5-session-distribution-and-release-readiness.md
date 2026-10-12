# Phase 5 — Session Distribution and Release Readiness (reopened)

Reopened 2026-10-12 by owner "Continue phase 5." The 5.1–5.4 technical gates already
passed on executed evidence; the full checklist and validation log for those gates live
in the [archived checkpoint](../old-docs/phase-5-session-distribution-and-release-readiness/checklist.md)
and its [progress](../old-docs/phase-5-session-distribution-and-release-readiness/progress.json),
preserved as historical evidence (not overwritten). Root `progress.json` is authoritative.

## Completed (evidence archived)

- [x] Milestone 5.1 — Windows Package Hardening and Failure UX
- [x] Milestone 5.2 — Stable Multiplayer Capacity (20-player movement blackout root-caused
  to the ENet throttle baseline and fixed via `throttle_configure(1000, 2, 1)`; five
  constrained 20-player runs + full 4/8/20 matrix pass)
- [x] Milestone 5.3 — Room Service Hardening and Steam Integration Evaluation
- [x] Milestone 5.4 — Measured Capacity and Placement (demand is zero; no change justified)

## Remaining scope — owner decision

- [x] **5.2.4 — Expand supported playtest capacity beyond four → 20 (design capacity).**
  Owner delegated with "Your call"; chose 20 because it is the design-bible capacity and is
  now evidenced by five consecutive constrained 20-player runs plus the full 4/8/20 matrix.
  The claim is automation-validated only; physical LAN/Internet/human acceptance stays open
  in `NEED_REAL_CHECK.md`. Done (2026-10-12):
  1. raise `progress.json` `phase.budgets.supported_players`;
  2. restore the CI scale matrix (`PLAYER_COUNTS`) in `.github/workflows/deploy-existing-ec2.yml`;
  3. align the room-service per-room default in `tools/room_service.py` (`--players`);
  4. update the scope wording in `README.md` / `NEED_REAL_CHECK.md`;
  5. re-run the full 4/8/20 matrix and the supported 1/2/4 regression.

  Do **not** deploy, change EC2/terrain infrastructure, or do Steam SDK/app work without
  separate explicit authorization and external resources.
