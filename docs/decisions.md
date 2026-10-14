# Disaster Party — Active Decisions

The [integrated-town archive](old-docs/phase-7-integrated-town/decisions.md)
records continuous architecture, canopy, paving, stairs, the expanded terraced map,
rematch recovery and verified source delivery. Full technical evidence is archived
alongside it; concept parity, owner aesthetic approval and native GPU performance
are not claimed. That source-only checkpoint was subsequently released under the
owner's explicit2026-10-14 deploy/release authorization, recorded below.

Root [progress](../progress.json) now owns the
[Phase8 counterplay plan](checklists/phase-8-character-disaster-counterplay.md).
The former safe-zone Phase8 is [Phase11](checklists/phase-11-shrinking-survival-zone.md),
deferred after the new character/UI and disaster phases, not automatically implemented.
The owner's progressive-loading question has a proposed chunk-streaming approach
in the archive, not an implemented feature or an activated phase. The current map
still builds eagerly; same-map rematch reuse is not streaming.

## 2026-10-14 — Model/UI and disaster priority

Owner requests planning for Snow, Rockslide, chasing/stinging Bees, UFO lift/drop,
volcanic changed terrain/hot ground and water/rain/snow cooling; denser meteor,
earthquake escape and more varied/coherent Fire+Flood. The initial useful-crouch/
carry proposal is superseded by the later owner revision below.
Order:8 character/UI and existing counterplay →9 weather/rockslides →10 swarms/UFO/
volcano →11 former8 shrinking zone. Preserve historical numbering/evidence and
released source; this planning request does not authorize another public deploy.

Direct inspection confirms global earthquake pulse damage with no contact/crouch
exemption and no fire extinguishing hook based on water. It does not establish the
cause of the owner's full-round death: quake defaults alone are about35HP/event,
and collapse/fall/overlap/repeated-event traces are required. Fire already has seeded
origin/front randomness; improve variation rather than claiming randomness absent.
Meteor remains3–4 sequential strikes despite approximately3.06× Town area; density
and terrain/player-aware targeting come before higher damage or shorter warnings.

Keep selected Soft Creature B non-human silhouette; refine contacts, pose and matte
coherence, not cosmetic hitboxes. Fire must respect real support height and
wetness; flood extinguishes submerged ground fire, not dry elevated roofs.

Interpret volcanic ground as hot for60s after eruption, dealing contact damage
during that interval; cool faster only where water/rain/snow actually reaches it.
Use authored terrain state swaps and retain safe evacuation routes, not unbounded
runtime terraforming. Numeric meteor/heat/cooling defaults are provisional, requiring
asymmetric boundary/control tests before lock. No new system framework, streaming,
mandatory human checklist or GPU/fun acceptance inferred from planning.

## 2026-10-14 — Simplify actions and avoid compounded late pressure

Owner removes crouch entirely and temporarily removes grabbing/holding. Phase8.2
owns end-to-end removal, including HUD/control help, prediction/authority/snapshots,
carry-only animations and springs; preserve loose hazard bodies and static cover.
No brace replacement, water pail, held shield or pour/refill work in phases8–10.
Future held hammer/wood character-to-character interactions live only in the index
backlog; opening them later needs a scoped effects/fairness/physics/network plan.

Earthquake's escape becomes leaving warned localized fractures/collapse/debris for
reachable stable support, not enduring global HP pulses or pressing another key.
Shake is cosmetic; damage remains actual authoritative hazard exposure. This is a
proposed counterplay contract, not a verified fix for the reported full-round death.

Meteor has more geographically spread strikes on a wide initial map, but replaces
the initial6/9/12 early/middle/late proposal with bounded usable-area budgets.
Counts/concurrency/footprint must reduce or cap as playable area shrinks, never
compound elapsed-time escalation with zone concentration. Phase8 measures full/
half/small-area fixtures; Phase11 integrates actual zone/navigable-area intersection.
Frozen warnings and reachable exits remain mandatory; defer unsafe new waves.

Rapid Shift press/release arm snapping is added to8.1 reproduction and8.2 repair.
Source selects walk/run from speed and starts the changed clip without explicit
blending; restarting gait is a hypothesis until that exact input case is rendered.
Plan interruptible blends and gait continuity without input lag or movement changes;
gate with inspected local/remote interaction clips and different gait phases.

Phase2 checklist moves byte-identically into its existing old-docs group, alongside
unchanged decisions/progress. It is suspended, not complete, removed from the
active/planned roadmap and reopened only on owner request. Historical links inside
the payload describe the old layout; archive/index navigation owns current paths.
This revision is documentation only: public crouch/carry and current hazards remain
unchanged until implementation. No deployment or release is authorized by this plan.

## 2026-10-14 — Integrated Town public delivery

Deploy the existing EC2 workflow and publish matching GitHub pre-release only;
keep room/player limits, infrastructure and profile-store configuration unchanged.
Released source is2619665ce31e02dd7233e9099c0d5a6e8c9a2e2d, not the later delivery
documentation commit. [CI/deployment](https://github.com/phucle297/idunno/actions/runs/38514066230)
passed42 suites, five matrices, managed20, persistence restart,34 room-service tests,
repeated Linux exports and standalone lifecycle.

Two local Windows exports match. CI/local PCKs differ in placement order of
`game/main.gdc` and `scenes/asset_validation.tscn`, not resource content: all95 entries
have identical bytes and valid MD5s. Ship the exact deployed CI PCK in the Windows
ZIP with refreshed manifest, rather than accepting only equivalent packs. Publish
the exact CI Linux archive. Archive/payload hashes and downloaded release bytes,
three uploaded assets and matching tag were verified on the
[pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-2619665).

Final-PCK public smoke passed HTTPS tickets, ENet, roster, Ready/Start, remotely
observed authoritative movement and owner transfer, RTT103ms. Matching unknown-room
404 and previous build409 independently confirm version gating. Two Linux editor
clients on one orb/upstream are not native Windows/separate-network acceptance or
production capacity proof. Packaged profile restart/open replay/equipment passed
locally with synthetic completion; no public profile-store activation is implied.
Logs: `.scratch/release-2619665/{ci,public-smoke,linux-lifecycle,linux-profiles}.log`.
