# Disaster Party — Active Decisions

The completed [collision follow-up](old-docs/phase-8-collision-followup/checklist.md),
[decisions](old-docs/phase-8-collision-followup/decisions.md) and
[evidence](old-docs/phase-8-collision-followup/progress.json) are archived separately
from Phase8. Source has solid rail/bush/planter/lamp/vent/Harbor detail collision;
stair presentation rails remain decorative after the release corrections below.

[Random movement drops](checklists/phase-12-match-powerup-drops.md) are planned only;
temporary Speed/Jump proposals extend cosmetic-only scope but are not implemented.
Root [progress](../progress.json) awaits next scope; Phase9–12 not activated.
Native Windows/GPU60FPS/audio/human acceptance remains unverified under the waiver.

## 2026-10-14 — Authorized release recovery

Owner requests release/deploy to existing EC2 and GitHub playtest pre-release.
Run38583685846 failed before deployment: the stair handrail blocked the diagonal
plaza-east approach; drowning ended ACTIVE, cascading into other hazard assertions.
Removing that rail passes map-variety424; the remaining stair side colliders also
block the required crate crossing (prop-role fails). Stair presentation rails now
remain decorative over the solid ramp slab; all other selected detail collisions
remain. Final prop-role191 and detail-collision77 pass, Town781/Harbor55 bodies.
Full CI is still required before delivery; historical archive evidence is unchanged.
Infrastructure, capacity and profile-store settings remain unchanged.

Corrected source run38591914415 passed all42 scene suites and the20-player
match matrix, then failed the known rematch reset-observation race. Production
prop snapshots are unreliable and independent of ACTIVE; gravity can settle the
crate before the exact reset pose is delivered. The test now freezes that one
server-side crate only until the client's existing ACTIVE/reset acknowledgement,
then restores physics. Exact position/shape/role assertions and real RPCs stay;
no tolerance or production behavior changed. Two consecutive real two-peer,
five-rematch fixture runs pass.

Final [CI/deployment](https://github.com/phucle297/idunno/actions/runs/38594162570)
on e68a912 passes42 suites, five matrices, managed20, settings restart,34 room-service
tests, repeated Linux exports/lifecycle and EC2 backend verification. Matching
[pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-e68a912)
contains exact CI Linux artifact and Windows with exact CI PCK/refreshed hashes.
Two final-PCK Linux Godot clients pass public TLS/tickets/ENet/Ready/Start/ACTIVE;
unknown-room404 and old-build409 pass. Three downloaded release assets and tag are
verified. No native Windows/GPU/audio/separate-network human acceptance claimed.
Prevention is recorded in advancing-disaster-party's Rematch Prop Reset Observation
section; always include full map-variety and prop-role gates for collision work.
