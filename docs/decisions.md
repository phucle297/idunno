# Disaster Party — Active Decisions

The [integrated-town archive](old-docs/phase-7-integrated-town/decisions.md)
records continuous architecture, canopy, paving, stairs, the expanded terraced map,
rematch recovery and verified source delivery. Full technical evidence is archived
alongside it; concept parity, owner aesthetic approval and native GPU performance
are not claimed. That source-only checkpoint was subsequently released under the
owner's explicit2026-10-14 deploy/release authorization, recorded below.

Root [progress](../progress.json) awaits the next agreed scope. Phase8 remains
[planned](checklists/phase-8-shrinking-survival-zone.md), not automatically active.
The owner's progressive-loading question has a proposed chunk-streaming approach
in the archive, not an implemented feature or an activated phase. The current map
still builds eagerly; same-map rematch reuse is not streaming.

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
