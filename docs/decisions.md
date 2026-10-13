# Disaster Party — Active Decisions

Phase 6 cosmetics remain planned, not started. Root [progress](../progress.json)
owns the current state; [its checklist](checklists/phase-6-cosmetic-loot-box-drops-and-customization.md)
contains the detailed implementation plan, not evidence of implementation.

The completed [Phase 5 validation follow-up](old-docs/phase-5-validation-followup/decisions.md)
preserves audit reconciliation and delivery decisions. [Its evidence](old-docs/phase-5-validation-followup/progress.json)
qualifies earlier scale, performance, human acceptance and deployment claims.
No Phase 6 feature has been implemented or gameplay-validated yet.

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
