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

## 2026-10-14 — Tests move from deploy to staged commits

Owner explicitly requests removing deployment tests and running them automatically
before commits, selecting affected tests where practical. Use native Git hooks with
Python standard library, not a new Lefthook dependency. The deploy workflow now
exports once and deploys; import/export errors, hashes and backend readiness remain.
Regression/admission, repeated-export and standalone-lifecycle tests are removed.

The hook tests a disposable index snapshot without stashing or altering local edits.
Selection follows resource paths, GDScript global types, Python imports and network
peer drivers; shared changes can select many suites. Unknown/deleted runtime code,
project settings and shell test drivers fall back to full regression. Docs-only
commits skip runtime checks. Static inference cannot guarantee dynamic coverage.
Local hooks are bypassable and need installation per clone; there is no replacement
central CI regression gate, as requested. Orb setup installs the hook automatically
and preserves other existing hook stages. This workflow-only checkpoint uses skip-ci:
no new deployment/release or unmeasured fast-deploy timing is claimed.

Validation:5 contract tests include a real rejected commit with a staged failure and
unstaged passing edit, followed by a successful staged fix. Scratch real-Godot hook
executes only test_shove64; runtime ERROR blocks a commit even with exit0/OK marker.
Installer/setup twice pass (~3.6s/3.5s); YAML parses with tests absent, one export and
SSM retained. Full gameplay suite not rerun for this non-gameplay workflow change.
