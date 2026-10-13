# Disaster Party — Active Decisions

Phase 6 is in progress: the Task 6.1.1 durable profile/store foundation is implemented.
Admission binding, rewards, earned assets and cosmetic UI remain unimplemented. Root [progress](../progress.json)
owns the current state; [its checklist](checklists/phase-6-cosmetic-loot-box-drops-and-customization.md)
contains the detailed plan and task-level implementation evidence.

The completed [Phase 5 validation follow-up](old-docs/phase-5-validation-followup/decisions.md)
preserves audit reconciliation and delivery decisions. [Its evidence](old-docs/phase-5-validation-followup/progress.json)
qualifies earlier scale, performance, human acceptance and deployment claims.
Profile foundation checks do not pass reward/equip or new gameplay gates.

## 2026-10-12 — Authorized deployment and GitHub pre-release

Owner explicitly requests deployment/release of completed important work. Dispatch
the existing main-only EC2 workflow for source `bd3b606971ce9cf5470e03c5945d229052eb5ddf`;
retain infrastructure, room count and player-limit configuration. [Deployment](https://github.com/phucle297/idunno/actions/runs/38272856925)
passes source regression, repeated Linux exports, standalone lifecycle and SSM backend
verification. Windows is exported twice from that same revision; its PCK is identical
to the exact CI Linux artifact deployed. Archive/tag/download hashes are verified.

Publish [Phase 5 Hardening Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-12-bd3b606)
as a GitHub pre-release, not Steam or a production-readiness claim. Two exact-PCK
Linux editor-driven clients passed public HTTPS tickets, ENet admission, roster,
Ready/Start, remote-authoritative movement and owner transfer (RTT sample104ms).
Both share one orb/upstream; native Windows, separate-network human sessions,
real-GPU and physical audio remain unverified. Keep earlier evidence unchanged.
Phase 6 remains planned. Delivery metadata in root progress is separate from its
empty implementation validation log. Subsequent tracking commit skips CI to avoid
an extra deployment of documentation-only changes.

## 2026-10-13 — State inspection and Phase 6 planning defaults

Owner requests current-state inspection and detailed Phase 6 planning, not feature
implementation or another deployment. Local/remote `main` matched and the worktree
was clean at inspection. GitHub confirms the recorded Phase 5 workflow completed
successfully and the pre-release has three uploaded assets. No new live-server health,
native Windows, hardware, audio or separate-network claim is made.

Code inspection establishes the missing foundations: visuals derive from transient
peer IDs; room tickets/registry are memory-only; no profile/inventory ledger exists;
disconnect erases match roster entries; results can be presented repeatedly on clients.
Therefore identity/admission and durable transactions precede rewards, asset expansion
and UI. Preserve the stable 6.1 milestone ID, narrow its title to the foundation, and
add ordered milestones 6.2–6.5 rather than renumber historical references.

Use service-issued anonymous credentials and a service-owned SQLite store as the
smallest durable prototype boundary. No Steam/email account system, automatic
cross-device recovery or tamper-proof player-host grants. Managed dedicated rooms
alone mint persistent rewards; other modes retain starter preview/equip. Store data
outside release/temporary room directories and bind room admission to authenticated
profiles. Keep reward bookkeeping out of match/health/disaster logic and presentation.

Initial product defaults: four existing free starter outfits plus four new earned
costumes on the same rig; one outfit slot; one guaranteed free box for an eligible
completed round, equal selection among unowned/unreserved outfits, no duplicates,
and no paid boxes/currency/shop/stat advantage. Require two distinct profiles at
start, 120 seconds of round time and 60 seconds connected ACTIVE participation
before death/leave. Eliminated players can qualify; leaving alive forfeits the drop.
These thresholds are proposals for implementation, not measured retention/fairness
tuning or an anti-farming guarantee. No winner bonus or punishment for losing.

Reserve the item and persist the grant's pool/odds at box creation; opening is a
transactional unlock/reveal of that receipt, not another roll. Exactly-once applies
to committed `(round_id, profile_id)` receipts; a room crash before submission/commit
can still lose an unreported reward. UI must distinguish pending, unavailable and
complete, and rematch must not overwrite frozen completion payloads. Validate equips
against server ownership and apply in lobby/next round with reliable appearance state.

All five milestones remain planned, with required gates `not_run`. Preserve Phase 5
delivery metadata and the manual-acceptance waiver. Do not reopen mandatory human
checklists, alter `DESIGN.md`, migrate shared data or deploy/publish as part of planning.
Documentation commit/push uses `[skip ci]` to avoid the main-branch deployment workflow.

## 2026-10-13 — Task 6.1.1 durable profile/store foundation

Owner asks to continue implementation. Implement the current task only: service-issued
anonymous profile credentials, SQLite schema 1, transactional starter ownership,
authenticated state fetch and a service-scoped Godot credential owner. Keep `ProfileStore`
in the already-packaged `room_service.py` rather than adding an import/export dependency.
The two profile routes are opt-in via an operator-selected `--profile-store`; omitting
it leaves existing admission unchanged. No remote configuration or data mutation.

Requests cannot set identity, ownership or equipment. Create stores a SHA-256 hash
of a 256-bit random bearer credential, returns the secret once, and grants the four
existing starters. Fetch requires the matching ID/Authorization header and returns
no credential/hash. Initial `pending=[]` is intentionally not a reward implementation;
round receipts, item reservations and equipment mutation remain later milestones.
SQLite schema/version/integrity checks reject unsupported/corrupt/incomplete stores
without resetting them. Request connections use `mode=rw` so lost storage cannot
silently create an empty DB. Disk I/O does not hold the room registry lock, preserving
admission/heartbeat responsiveness when the store is busy.

The client owner is not yet integrated into room Create/Join. It scopes its credential
file to exact service URL, refuses remote HTTP and redirects, writes secret bytes only
after Unix mode0600 is applied, and atomically renames the flushed temporary file.
Wrong/corrupt/other-service credentials are preserved rather than replaced automatically;
local cached ownership is never submitted or treated as authority. Signals expose only
profile state. Native Windows user-directory ACLs remain unverified. A lost create reply
can leave an inaccessible starter-only orphan; no cross-device recovery is promised.

Five new public-interface real-process tests cover client/service restart, isolation,
credentials, forged state, concurrent creation/rate limits and store failures. Initial
client fixture inference and noisy JSON error failures were fixed, not suppressed;
the validation history retains them. The existing room/admission regression remains
required. Mark only 6.1.1 and its durable-identity gate complete; 6.1.2 admission binding
and 6.1.3 integrated restart/isolation remain open. No gameplay visual changed.
Commit/push this local feature with `[skip ci]`: pushing is repository policy, not
authorization to run the main-branch deployment, migrate shared storage or release.

## 2026-10-13 — Task 6.1.2 identity-bound room admission

Continue the current milestone, without beginning rewards. An opt-in profile-enabled
service now requires authenticated profiles on Create/Join. The existing room client
first receives an explicit `profile_required` challenge, creates/fetches its scoped
profile, then retries with the ID and Authorization header. Profile-disabled services
keep their existing development contract; credential/store failures never cause an
anonymous fallback or a replacement identity. No new operator/client mode toggle.

Keep reservations in each room's existing token/peer registry rather than introduce
a second global profile map. One profile may reserve one ticket or active peer across
all rooms, checked under the registry lock. Room creation reserves before startup;
failure removes it and success resets the returned ticket's TTL. Profile database
authentication runs outside that lock. Expired tokens and incomplete six-second peer
reservations are reclaimable; admitted departures follow heartbeat cleanup. A stale
heartbeat touches only its authenticated room instance, not another room's binding.

Consume derives the profile solely from the single-use ticket. ENet carries no durable
credential. Godot validates the consume body before completing authentication and
stores identity only server-side, clearing it on disconnect/auth failure. Pending
requests are tracked by request identity so late callbacks cannot bind/erase a reused
peer's newer request. Preserve dedicated relay-off, build validation, lobby-only
admission, bounded requests and service-loss fail-closed behavior.

Twenty service tests pass, including real enabled/disabled room lifecycles, active and
concurrent duplicates, expiry/replay/wrong-room, cleanup, spoofed consume identities,
credential/snapshot isolation and two real UI clients Ready/Start/crash/retry. Record
the initial GDScript Variant inference failure and the passing rerun honestly. Broader
regression evidence belongs in progress. Integrated service/client restart with room
admission remains 6.1.3; no reward/equip/catalog mutations are implemented. The existing
per-address rate backstop includes profiles; no 20-client profile-enabled cold-start
claim. No appearance change, human acceptance, Windows ACL, shared proxy/store change,
deployment or release. Commit/push with `[skip ci]` to avoid unintended deployment.

## 2026-10-13 — Task 6.1.3 restart/isolation; Milestone 6.1 complete

The owner asks to continue. Close the remaining identity-foundation task with executed
integration evidence rather than add production layers. Extend the existing real-service
Python fixture and Godot profile client fixture with a room-lifecycle mode using actual
Create/Join lobby controls. Keep reports/tickets in mode0600 disposable files, never
stdout/arguments or review artifacts. Honor the configured Godot binary in service tests.

The combined check admits the first profile, holds its client during service shutdown,
observes editable solo recovery, and restarts both real processes on the same endpoint
and durable store. It restores identical credential bytes and a non-default cap saved
while the disposable service was stopped. This distinguishes real restoration from a
default-state reset; it is not a new equip endpoint. The second profile remains plain.
An old unused ticket is deliberately tested on the recreated same-ID/same-port room
before its TTL expires; otherwise rejection could merely prove ordinary expiry/replay.
Fresh authenticated Join succeeds. Wrong-profile credentials and corrupt local JSON
fail through the UI without losing saved evidence or creating replacement profiles;
unauthorized fetch/body mutation leaves the victim unchanged. Secret/token log checks pass.

All 21 service tests pass in 78.403s, including the prior real ENet/UI/store-failure
regressions. No production source changed or fix was needed. The previous 41-suite,
five-matrix and profile-disabled managed20 run is historical to 6.1.2, not a new test
run or profile-enabled scale claim. Native Windows/Internet/hardware acceptance stays
unverified; no human prerequisite is reinstated under the waiver. Document durable
paths, exact URL scoping and loss/reset semantics without promising account recovery.

Mark all three 6.1 tasks and both required gates complete; retain them in the active
Phase 6 checklist/progress. Do not archive the phase or begin reward grants. The single
next action is 6.2.1 immutable authoritative round participation. No schema migration,
shared data/restart, deployment, release or cosmetic asset/UI change. Commit/push this
validated test/operations work with `[skip ci]` to avoid unintended deployment.

## 2026-10-13 — Task 6.2.1 authoritative round participation

The owner asks to continue. Capture participation in `MatchManager` at the actual
start, death, departure and completion boundaries, not in results/UI signal listeners:
replicated snapshots also emit those signals, and unregistering the final opponent
can synchronously finish a round. Record departure before erasing the mutable player.

Only profile-enabled managed admission installs the peer/profile binding. Copy that
binding at start; admission cleanup and identical display names cannot change it.
Keep the active record and latest completed record separate from `players`; return
deep copies. Results/lobby resets and a new active rematch do not rewrite completed
facts. `connected_duration` means alive, connected ACTIVE time before death/leave;
spectating does not rescue death at 59.99 seconds. Preserve death time and departure
time independently, including a live-leave flag. Use authoritative elapsed simulation
time (with timeout clamping), never client clocks or winner rankings.

The loopback-only, room-key-authenticated `/internal/round/start` endpoint issues a
random round ID and derives the immutable roster from admission reservations. The
room key binds it to one process instance. Identical current-sequence retries return
the same ID even after peer cleanup; changed rosters or old sequences reject. Newer
sequences may skip a missed HTTP request, so a failure does not disable later rematches.
Godot binds responses by sequence, including a completed round during HTTP flight;
late replies cannot replace a rematch's ID or an already bound ID. Requests failing
validation/transport leave the ID empty and log only a non-secret unavailable marker.
They do not block gameplay or manufacture local IDs. No automatic retry/grant path
is claimed. Client snapshots contain neither these records nor the identity mapping.

This task retains in-memory facts only: latest completed Godot record and current
service round binding, not an unbounded history. Crash/restart remains fail-closed.
Transactional completion, pending delivery/recovery and durable reward receipts are
6.2.2 work; opening is 6.2.3. No catalog/assets, equip/UI, schema migration, shared
proxy/store change, deployment, release or new human-acceptance prerequisite.

Clean Godot import, 69 match checks and all 22 service tests pass, including an actual
two-profile UI/start/crash/retry round issuance. Timing boundaries, identity removal,
five rematches, stale/conflicting IDs, replay, missed sequences and replacement room
keys are exercised. Broader regression passed 41 suites, five matrices, persistence
restart and existing profile-disabled managed20 loopback; this is not profile-enabled
reward scale or hardware/Internet acceptance. Task 6.2.1 is complete, reward gates
remain not_run, and 6.2.2 is next. Commit/push with `[skip ci]` to avoid deployment.

## 2026-10-13 — Task 6.2.2 transactional sealed reward grants

The owner asks to continue. Keep the standalone service as the persistence owner;
do not introduce an export dependency or mix loot policy into hazards/physics.
Schema 2 upgrades valid schema-1 stores atomically, preserving profile credentials,
owned starters and equipment. Persist each start's ID, hashed room instance, sequence,
roster and configured duration so a later rematch cannot erase its authority binding.
Newer starts remain allowed; identical older issued starts recover their durable ID
without changing lobby joinability. No raw room key belongs in the durable ledger.

Completion accepts only bound identities and internally consistent finite timing facts.
Normal 600-second configuration, two distinct start profiles, ≥120 elapsed seconds,
≥60 alive/connected ACTIVE seconds and no live departure determine eligibility.
Death preserves eligibility; names/winners/difficulty cannot improve odds. Solo,
nonstandard/short rounds, short participation, live departure and exhausted inventory
receive saved no-drop reasons, not empty boxes. Aborted/unreported rounds do not grant.

Use one `BEGIN IMMEDIATE` transaction for canonical completion, `(round, profile)`
receipts and item reservations. A repeated identical completion returns its saved
response; a conflicting completion rejects. Serialize pool selection across rooms,
with a unique profile/item constraint as a second invariant. The four starter IDs stay
unchanged; version-1 earned IDs are raincoat, mechanic, park_ranger and meteor_observer.
Select uniformly with `secrets.randbelow` over neither-owned-nor-reserved IDs. Persist
the grant-time pool/version and private item; expose only box metadata and exact 1/N
odds until opening. Profile fetch recovers sealed boxes without unlocking/equipping.

Godot queues copied completion envelopes across rematches, even completion before
the start HTTP reply. Serialize ID issuance, bind by sequence and retry transport/5xx
failures while the room lives. Invalid evidence is terminal/unavailable, not a local
grant. A room crash loses uncommitted payloads; committed receipts survive service
restart, but the old room key cannot submit again to the restarted registry. SQLite
I/O remains outside the registry lock. No UI/open/equip/assets, public proxy/store
migration, deployment/release, capacity change or mandatory human check is authorized.

First full service regression passes all 29 tests, including six reward fixtures,
actual Godot→HTTP→SQLite frozen delivery with forced post-commit acknowledgement
failure and real service restart with nonempty sealed receipts. Controlled selection
indices and four concurrent grants prove pool depletion without flaky frequency tests.
Busy-store heartbeat returns in 0.056ms while reward SQL remains blocked; failed
migration rolls back its partial table and preserves schema-1 identities/equipment.
Final hardening adds replay/lobby isolation and non-default migration/tie checks.
Final service regression passes all 29 tests in 87.288s; broader regression passes
41 suites, five matrices, persistence restart and profile-disabled managed20 loopback.
Permitted shutdown-only resource diagnostics are not hidden script/runtime failures.
Task 6.2.2 and eligibility/odds/authority gate are complete; the combined grants/open/
restart gate waits for 6.2.3. No profile-enabled reward-scale, human/GPU/Internet or
new package/deployment claim. Commit/push with `[skip ci]`; opening/recovery is next.
