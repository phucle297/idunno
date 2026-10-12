# Phase 5 — Validation Follow-up

Owner requests planning and completion of the audit findings. This follow-up supersedes
overbroad completion summaries, not the historical evidence. Phase 6 remains planned.

## 5.5 — Managed scale, fairness and strict gates

- [x] 5.5.1: Execute 20 separately running clients through real HTTP room tickets and
  playerless dedicated ENet. Assert all rosters, server-observed movement and observation
  on every client, full-capacity rejection, five rematches, owner transfer and crash/retry.
  Reuse the managed peer fixture; loopback evidence is not Docker/Internet acceptance.
- [x] 5.5.2: Start Flood before walking each spawn route and assert alive arrival and
  survival at peak on both maps. Exercise actual tornado-radius force at refuges.
- [x] 5.5.2: Execute post-collapse relocation to a surviving refuge during Flood+Earthquake;
  diagnose failed routes before changing gameplay. Keep realistic timings and ordinary input.
- [x] 5.5.2: Make container 4/8/20 failures gating, retaining strict runtime-error scans.

Evidence: `MANAGED_SCALE_OK clients=20` and `CONTAINER_VALIDATION_SLICE_OK`.
Spectator departure regression fails on the old controller and passes on the fix.
Seeded relocation arrives alive before peak on both maps with overlap during movement;
it does not prove survival of standing on a collapsing panel or every random seed.
Serialized two-room 4/8-client container lifecycle/profile validation passed after
the preserved OOM run. Physics-work p95 ≤10.121ms; tick p95 up to21.395ms is not
perfect60Hz or real-GPU/Internet evidence.

## 5.6 — Regression, delivery and truthful records

- [ ] Run full source regression, room-service tests and current release lifecycle.
- [ ] Export matching Windows/Linux packages from a committed revision; verify hashes/PCK.
- [ ] Reconcile README/index/active decisions and acceptance wording. Preserve older build
  confirmation, unresolved failures and every existing archive without rewriting it.
- [ ] Mark real-GPU performance, native Windows interactive capture, physical audio/network
  and human fairness as unverified/nonblocking under the existing waiver, never passed.
- [ ] Commit/push with `[skip ci]`; no deploy, shared restart, infrastructure or Steam publication.

Existing Phase 5 archive remains the historical checkpoint. Final follow-up evidence will
use a new archive directory rather than overwrite it. Current action lives only in root progress.
