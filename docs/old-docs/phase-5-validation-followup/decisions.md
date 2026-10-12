# Disaster Party — Phase 5 Validation Follow-up Decisions

Root [progress](../../../progress.json) owns active state; this [checklist](checklist.md) and [evidence](progress.json) are historical. Phase 6 remains planned. Historical [Phase 5](../phase-5-session-distribution-and-release-readiness/decisions.md), [Phase 4](../phase-4-disaster-remix-and-toy-town-interaction/decisions.md), [Phase 3](../phase-3-player-caused-chaos/decisions.md) and [Phase 2](../phase-2-human-playtest-and-core-feel/decisions.md) records are preserved, not rewritten.

## 2026-10-12 — Audit reconciliation and validation follow-up

Owner requests planning and completion of the audit findings. Keep the historical
archives byte-for-byte unchanged; supersede overbroad conclusions here and preserve
the original failed evidence. Phase 6 implementation is outside this follow-up.

- **Scale:** 20-player player-host tests did not prove 20-client managed rooms. Add
  a real HTTP allocator / dedicated ENet scenario, reusing the managed peer driver,
  with authority/all-peer movement, capacity rejection, five rematches, owner transfer
  and crash/retry. One full room is not proof of four simultaneous full rooms or EC2 capacity.
- **Actual defect:** the full-room departure scenario exposes a freed spectator
  target before roster refresh. Validate the dictionary value before typed assignment
  and select a surviving target. Preserve strict runtime-error checks.
- **Fairness:** start Flood before traversal and execute runtime tornado force rather
  than a 15m proximity proxy. For collapse relocation, use reachable safe high ground:
  Town's roof strips remain beside the collapsed 2x2 panel; Harbor cargo lids are below
  peak water, so its actual refuge is the Warehouse access ramp. Require overlap during
  movement and alive arrival before Flood peak, not an artificially prolonged quake
  (default quake 8s, Flood rise 35s). Sprint is ordinary player input. This deterministic
  scenario is not proof for every collapse seed or human reaction time.
- **Performance and acceptance:** Phase 3's software-renderer p95 103/160ms did not
  meet 16.67ms. Measuring it was completed; the hardware target is unverified, not passed.
  Phase 4 human Normal/Hard gates remain waived/nonblocking and unverified. Older native
  Windows/audio/network observations apply only to their recorded builds.
- **Deployment/demand:** older public build `0d10b28` was deployed and user-confirmed.
  The Phase 5 assertion "not publicly deployed, therefore demand zero" is superseded:
  current demand is unmeasured, so no placement/capacity infrastructure change is justified.
  Source, local package and live deployment are separate delivery states.
- **Archive provenance:** Phase 5's archive was edited by the earlier rollover/reopening
  commits; all original 16 validation entries survived. Those revisions remain in Git.
  This follow-up will use a new archive directory, not alter that checkpoint again.

## 2026-10-12 — Follow-up closure

Full regression passed 41 suites/five matrices plus managed20 and settings restart;
13 room-service checks passed. Serialize private container imports before admission:
the recovered two-room 4/8 matrix passed lifecycle/isolation/profile without extending
gameplay deadlines. Physics p95 ≤10.121ms is separate from tick p95 up to21.395ms.
The focused OOM skill preserves failure/recovery evidence and prevents concurrent imports.

Source/package revision is `62b69c84802d5e79502b44d735df02f428a55e06`.
Repeated exports have matching hashes and client/server PCK; standalone Linux release
and delivered archive integrity passed. New archive closes agent-owned gates only;
no native Windows, real-GPU, physical audio/Internet or human-feel pass is inferred.
Skip-CI commits prevent deployment. Phase 6 remains planned; no cosmetics implemented.
