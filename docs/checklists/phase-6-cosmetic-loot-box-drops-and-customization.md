# Phase 6 — Cosmetic Loot-Box Drops and Customization

Status: **in progress — Milestones 6.1 and 6.2 completed; catalog/assets (6.3) is next**.
Detailed plan recorded 2026-10-13. Planning baseline below is historical to that inspection.
Root [progress](../../progress.json) owns task status and the single next action;
[decisions](../decisions.md) records planning defaults. `DESIGN.md` remains authoritative.
Complete milestones in order; do not begin later feature work before earlier gates pass.

## Current-state baseline

- Phase 5 technical follow-up is archived. GitHub confirms the published
  [playtest pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-12-bd3b606)
  and successful [deployment workflow](https://github.com/phucle297/idunno/actions/runs/38272856925).
  This is recorded delivery evidence, not a new live-server health check.
- `ToyCharacterVisual` has plain/cap/hard-hat/backpack variants; `PartyPlayer.configure_grabbing`
  selects appearance from transient peer IDs. No owned collection or validated equipment exists.
- `MatchManager` erases disconnected players and resets round statistics on rematch.
  Results presentation also runs on clients and can repeat on ownership changes: it must not mint rewards.
- `RoomService` holds rooms, admission tokens and peer reservations in memory. Tickets are
  short-lived join credentials, not durable player identities. `PauseSettings` persists preferences only.
- Existing tests cover match completion, admission replay, results ordering and rematch;
  none prove cosmetic rewards, durable ownership or authenticated equipment.
- Source/local automation supports 20 players; that does not prove production multi-room
  capacity or real-GPU 60 FPS. The manual-acceptance waiver remains in force. Historical
  human/network/audio/hardware uncertainty is not a new prerequisite or a passed gate.

## Product contract — initial implementation defaults

These are reversible planning choices, not implemented behavior or user-tested tuning.

| Topic | Initial contract |
| --- | --- |
| Scope | Free earned boxes, reward reveal, small collection and equip. No money, currencies, shop, trading, stat bonuses, battle pass or Steam account work. |
| Catalog | Eight complete outfit IDs: four existing variants remain free starter items; four new unlockable toy costumes share the base proportions/rig. One whole-outfit slot; no mix-and-match system. Suit color and player labels stay independent for identification. |
| Eligible session | Managed dedicated rooms only; at least two distinct authenticated profiles at authoritative round start. Offline/solo/player-hosted sessions retain starter equip/preview but cannot mint persistent unlocks. |
| Eligible player | Present at round start, connected for at least 60 seconds of ACTIVE play before death/leave, and either connected at finish or authoritatively eliminated before disconnect. Death does not remove eligibility. Leaving alive forfeits the drop; disconnect is not silently treated as death. |
| Eligible round | Normal authoritative completion at elapsed time ≥ 120 seconds. No grants for aborted/crashed rounds, lobby waits, shortened debug rounds or results UI refreshes. Winner, damage and difficulty do not increase odds. |
| Drop chance | Exactly one free box per eligible profile/round (100%), while an unreserved locked outfit remains. At 59.99/119.99 seconds the respective threshold fails; at 60/120 it passes. No hidden daily limit or streak multiplier. |
| Item odds | Uniform among outfits neither owned nor already reserved in unopened boxes: 25% each initially, then 33⅓%, 50%, 100%. Display the next-drop pool/odds in collection and the saved grant-time pool/odds for each sealed box; no rarity tiers or misleading new odds at opening. |
| Duplicates | Never grant duplicates. Reserve the server-selected item when committing the box. Opening atomically unlocks that reservation; retry returns the same receipt. If all items are owned/reserved, show “All rewards earned” rather than grant an empty box. |
| Equip | Starter or owned catalog IDs only. Server acknowledgement precedes display changes; selection applies in lobby/next round, not mid-match. Rematch retains acknowledged equipment. |
| Identity | Anonymous service-issued profile ID and high-entropy bearer credential stored locally in Godot `user://`; server stores its hash. Neither name nor peer ID proves ownership. No automatic cross-device/cloud recovery; losing the credential loses access. |
| Persistence | Service-owned SQLite file outside temporary rooms and release directories. Server ledger is authoritative; local cache cannot add ownership. Same credential + same durable service store restores owned/pending/equipped state after restart. |

Anonymous profiles are a prototype tradeoff: a player can create multiple profiles or idle
to farm; these thresholds prevent instant rematch grants, not cheating/Sybil behavior.
Credentials must never appear in roster snapshots, URLs, exports or logs. Copying a
credential transfers access; no recovery UI or secure cross-device account claim in this phase.

## Milestone 6.1 — Identity, persistence and admission foundation

Status: **completed — all three tasks and both required gates passed** (2026-10-13).

Stable ID: `milestone_6_1_cosmetic_loot_drops_and_customization` (retained from the old umbrella).
Owner: `tools/room_service.py`, `game/session/room_client.gd`,
`game/session/room_admission.gd`; a small service-owned cosmetic store module only if
needed to keep durable ownership separate from room/process allocation.

- [x] **6.1.1 Durable profile/store contract.** Implement profile creation/authentication,
  schema versioning and transactional starter/owned/pending/equipped state. Fail visibly
  on an unwritable/corrupt/unsupported store; never replace it with an empty inventory.
  Credentials are hashed server-side, sent over HTTPS (loopback test exception), and
  loaded from restricted local storage where supported. Bound/rate-limit public requests.
  Evidence: five profile tests against real Python/Godot processes pass; service/client
  restart, cross-profile isolation, forged local/server state, corrupt file/store and
  rate-limit checks included. Opt-in schema-1 backend and service-scoped client owner
  exist; room UI/admission was deferred to 6.1.2 below. Starter ownership/equipped state is
  persisted; `pending=[]` is initial state only, with receipt mutations deferred to 6.2.
  See [profile operation contract](../../GUIDE.md#phase-6-profile-foundation-task-611).
- [x] **6.1.2 Bind admission to identity.** Authenticate room create/join, bind single-use
  tickets to profile and room instance, and return the validated profile to Godot during
  consume. Keep it server-side. Reject a second active connection for the same profile;
  clean reservations on failed admission/disconnect without allowing stale peers to erase
  a new binding. Retain ticket expiry, build match and dedicated relay-off policies.
  Evidence: 20 room-service tests pass, including real profile-enabled HTTP/ENet admission,
  concurrent/active duplicates, bounded failed-admission cleanup, expiry/replay/wrong-room,
  credential-free client snapshots and two real lobby clients Ready/Start/crash/retry.
  One pending ticket or peer per profile is permitted across all rooms. Profile-disabled
  development services remain compatible. See [admission contract](../../GUIDE.md#identity-bound-room-admission-task-612).
- [x] **6.1.3 Prove restart/isolation.** Restart the service and client against an isolated
  on-disk store; confirm the same identity/state returns while old rooms/tickets still die.
  Confirm a second credential cannot read/mutate the first profile. Document data path,
  local reset semantics and limitations; do not touch shared storage or deploy.
  Evidence: full service suite passes 21 tests. Actual lobby Create, service shutdown/solo
  recovery, fresh service/client processes with identical credentials, non-default saved
  starter equip and independent second profile all pass. An unused old ticket fails against
  the recreated same-ID/same-port room before TTL expiry; fresh Join succeeds. Wrong-profile
  and corrupt saved credentials fail without reset or extra profiles; no secret in logs.
  The cap fixture is a stopped disposable-store update, not an equip API. `pending=[]`
  remains initial state only. See [restart/identity operations](../../GUIDE.md#profile-restart-and-isolation-task-613).

**Gate (passed):** authenticated identity survives process restart; malformed/expired/replayed/wrong-profile
admission fails; credential leakage checks pass. Extend `tests/test_room_service.py`
and real HTTP/ENet fixtures. No reward or cosmetic gate is implied by this foundation.

## Milestone 6.2 — Authoritative earned boxes and exactly-once ledger

ID: `milestone_6_2_authoritative_cosmetic_rewards`; depends on 6.1.
Owner: server completion boundary in `game/main.gd`, `MatchManager` signals,
and the service-owned cosmetic store. Keep reward policy outside disaster/health simulation.

- [x] **6.2.1 Capture immutable round participation.** Allocate a service-issued unique round
  ID bound to the managed room instance and start roster; record authoritative connection
  duration, elimination and live departure separately from mutable `MatchManager.players`.
  A rematch receives a new ID. Client-supplied names, winner lists or clocks are never evidence.
  Evidence (2026-10-13): 69 match checks and 22 service tests pass; real profile-enabled
  two-client Start issues a bound roster/ID. Death/leave and 59.99/60, 119.99/120 timing,
  immutable copies, replay/stale ID, replacement keys and five rematches are covered.
  Full regression: 41 suites, five matrices, persistence restart and profile-disabled
  managed20 loopback pass. At that delivery, no durable completion/grants existed;
  missing IDs failed closed. Logs: `.scratch/phase6-participation/`. 6.2.2 adds persistence below.
- [x] **6.2.2 Commit grants transactionally.** Only the authenticated managed process can
  submit its finalized round. Validate roster, eligibility and catalog; commit immutable
  completion plus unique `(round_id, profile_id)` receipts/reservations in one transaction.
  Replayed identical completion returns existing receipts; conflicting payload is rejected.
  Serialize concurrent rounds for one profile so they cannot reserve the same item.
  Establish the eight stable catalog IDs/pool metadata here; their visual assets follow in
  6.3. Persist each box's grant-time pool/odds, and keep its reserved item private until open.
  Evidence (2026-10-13): all 29 service tests and full 41-suite/five-matrix regression
  pass. Schema 1 → 2 preserves identity/non-default equip; migration failure rolls back.
  Tests cover boundary/tie/death/leave, invalid/spoofed/conflicting completion, replay,
  rollback before commit, post-commit acknowledgement failure in real Godot→HTTP→SQLite,
  four concurrent no-duplicate grants, every initial selection index, exhausted pools
  and real service restart with sealed receipts. Busy-store heartbeat stays responsive.
  Authenticated fetch exposes saved box/pool/version/1/N odds, not the reserved item.
  No opening/equip/UI/assets or shared migration/deployment. See [operations](../../GUIDE.md#transactional-reward-grants-task-622)
  and `.scratch/phase6-grants/{final-service,ui-regression}.log`.
- [x] **6.2.3 Open/recover.** Authenticated open atomically changes sealed → opened/owned
  and returns the persisted item. Concurrent opens, response loss and restart cannot
  reroll or grant twice. Fetch pending receipts after reconnect; skipped reveal is not lost loot.
  Catalog IDs reserved in receipts remain resolvable across upgrades.
  Evidence: 30 service tests pass in 87.851s, including four concurrent identical opens,
  ownership rollback on failed transition, cross-profile rejection and real Godot open/
  fetch/service-client restart. Saved credentials and receipt stay identical, owned5 and
  pending0 restore. Log: `.scratch/phase6-opening/full-service.log`.

**Gate:** exercise exact eligibility/odds boundaries, ties, death/disconnect, all-owned,
all-reserved, forged completion, same-room/new-round and same-round/replay. Force failure
before commit and response loss after commit, then restart and check the durable ledger.
Use integer selection boundaries with controlled RNG in tests, not flaky frequency assertions.
Grant eligibility/odds/authority and combined grants/open/restart gates passed.
Grant post-commit acknowledgement loss is injected; opening itself is covered by
concurrent/durable HTTP replay rather than an injected socket-write loss.

**Failure contract:** committed receipts survive client/service restarts. A completed payload
not yet committed cannot be recovered after its room process dies; do not claim crash-proof
unreported matches. Retry the frozen payload while the room lives; rematch must neither
overwrite it nor reclassify it. Show pending/unavailable honestly, never optimistic unlocks.
Current heartbeat fail-closed behavior remains intact.

## Milestone 6.3 — Small cosmetic catalog and faithful assets

ID: `milestone_6_3_cosmetic_catalog_and_assets`; depends on 6.2.
Owner: `game/player/toy_character_visual.gd`, character scenes,
`tools/asset_generation/generate_assets.gd`, `assets/manifest.json` and ragdoll presentation.
Load `validating-game-assets` before any asset work.

- [ ] **6.3.1 Stable outfit catalog.** Map starter IDs to existing variants, preserve their
  availability, bind the four earned IDs from 6.2 to names and outfit descriptions. Proposed themes:
  raincoat, mechanic, park ranger and meteor-observer toy suits. Each needs recognizable
  costume/accessory geometry, not just a new tint. Final shapes follow the bible; no new rigs.
  Keep one versioned catalog source consumable by service and game; verify export includes it.
- [ ] **6.3.2 Generate and validate.** Reuse the deterministic source pipeline, shared
  materials and canonical body; record source/seed/license/dimensions/triangles in manifest.
  Prove required animation clips, attachment behavior through ragdoll/recovery, collider
  equivalence and unaffected controller/shove/grab/health values for all eight outfits.
  Audit existing accessory attachment too; do not assume recovery tests prove ragdoll appearance.
- [ ] **6.3.3 Readability inspection.** Render daylight previews and gameplay cameras for
  locomotion, crouch, carrying, ragdoll, flood and meteor/tornado overlap at 720p/1080p.
  Inspect captures with normal exposure; no blown-out preview, concealed warning footprint,
  oversized accessory or player-ID color replacement accepted.

**Gate:** reproducible generation/import, manifest checks, animation/physics equivalence
and inspected representative renders pass. No added collision bodies or raised budgets.

## Milestone 6.4 — Collection, reveal, equip and multiplayer appearance

ID: `milestone_6_4_collection_reveal_and_equipment`; depends on 6.3.
Owner: lobby/results UI in `game/main.gd` and `scenes/main.tscn`, `game/ui/`,
player spawn/configuration and reliable session snapshots (not per-frame movement packets).

- [ ] **6.4.1 Validated equipment replication.** Replace peer-ID outfit selection with
  acknowledged catalog ID from bound profile. Validate actual sender, ownership, lobby
  state and request ordering; reject unknown/locked/spoofed/stale equips. Apply reliable
  appearance revision to existing/new avatars, owner transfer, lobby return and five rematches.
  Offline/player-hosted modes expose starters only; no local cache promotion to managed ownership.
- [ ] **6.4.2 Owned collection and preview.** Lobby collection shows owned/locked,
  equipped, pending and complete states, full outfit/name, faithful rotatable preview and
  clear Equip action. Unacknowledged selection remains pending; failure retains old equip.
  Manage focus/pointer capture alongside existing Ready/Start/Settings; no match-time obstruction.
- [ ] **6.4.3 Results reveal.** Show earned/no-drop reason/pending/unavailable and free
  Open action. Reveal displays actual server receipt, item name and ownership; can skip
  animation, honors reduced motion, and never blocks rematch. Equip routes to lobby.
  Opening/closing UI does not mint or reroll; reopened collection recovers pending receipts.

**Gate:** real client/server agreement on appearance and inventory; unauthorized equip
rejection; deterministic save/restart and stale response handling. Render default, locked,
empty-pending, sealed/opened, complete and unavailable states at 720p/1080p; inspect them.
Exercise keyboard navigation and settings/modal interactions, not just screenshots.

## Milestone 6.5 — Regression, packaging and handoff

ID: `milestone_6_5_cosmetic_regression_and_handoff`; depends on 6.4.

- [ ] **6.5.1 Full lifecycle and scale.** Run existing regression plus reward/profile checks;
  actual managed 4/8/20-client appearance agreement, repeated open/equip, disconnect/rejoin,
  owner departure, service restart, and at least five rematches. Run heavy managed/container
  jobs serially. Confirm no loot paths change hazard outcomes or movement budgets.
- [ ] **6.5.2 Performance/visual review.** Measure representative overlap with the new
  outfits and preview UI (720p/1080p, 120 warmup/600 samples). Record renderer/hardware,
  p95 and scene/player conditions, stable UI node identity and no growing preview resources.
  Orb software rendering is not proof of real-GPU 60 FPS; retain that uncertainty explicitly.
- [ ] **6.5.3 Matching local packages and operations notes.** Repeat Linux/Windows exports,
  compare hashes/PCK, run standalone managed lifecycle with persistent store, and verify
  clean-install/profile restart. Update run/build docs, odds/no-duplicate text and failure reasons.
  If the cosmetic store is a new Python module, include it in exporter, archive, hash verifier
  and release lifecycle fixtures: the current export copies only `room_service.py`.
  Document future allowlisted HTTPS profile routes and release-independent data path,
  backup/restore/migration/rollback compatibility; do not apply proxy/data changes remotely.

**Phase exit:** all agent-owned milestone gates passed with commands/evidence in progress;
matching local packages and reviewed UI/gameplay captures available. No paid features,
stat changes, budget increase or hidden cross-device promise. Human/GPU/audio/Internet
checks remain honestly unverified/nonblocking under the existing waiver; do not recreate
a mandatory manual checklist. Commit/push documentation with `[skip ci]`; deployment,
shared store migration, server restart and publishing a new release need separate approval.

## Validation map (planned, not executed)

| Risk | Smallest meaningful check |
| --- | --- |
| Identity impersonation/reset | Real HTTP create/auth, wrong credential, altered local cache, service/client restart against same DB; existing admission attack fixtures. |
| Too-early or duplicate grants | 59.99/60 connection and 119.99/120 round boundaries; eliminated versus live leave; concurrent finish and open, lost reply, restart, exhausted pool. |
| Presentation mints rewards | Reapply results snapshot, transfer owner, reopen UI and rematch; ledger count stays one per eligible round/profile. |
| Outfit mismatch/advantage | Two actual ENet clients use different owned IDs; locked/spoofed equips fail; collider/controller and animation/ragdoll checks across catalog. |
| Regressions/scale | `GODOT_BIN=$(command -v godot) PLAYER_COUNTS='4 8 20' tests/run_ui_regression.sh`; `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_room_service.py -v`; extend managed-scale fixtures for cosmetics. |
| Missing packaged store/catalog | Repeated `tools/export_playtest.sh` exports; `tests/run_release_linux_test.py` against exported package and external persistent data directory. |

Keep tests through observable service/game interfaces; extend existing fixtures before
adding suites. Record every failed/blocked/not-run gate honestly. Planning does not pass tests.
