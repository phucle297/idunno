# Disaster Party — Phase9 Decisions (Historical)

The completed [collision follow-up](../phase-8-collision-followup/checklist.md),
[decisions](../phase-8-collision-followup/decisions.md) and
[evidence](../phase-8-collision-followup/progress.json) are archived separately
from Phase8. Source has solid rail/bush/planter/lamp/vent/Harbor detail collision;
stair presentation rails remain decorative after the release corrections below.

[Random movement drops](../../checklists/phase-12-match-powerup-drops.md) are planned only;
temporary Speed/Jump proposals extend cosmetic-only scope but are not implemented.
Root [progress](../../../progress.json) is idle after Phase9; Phase10–12 remain planned.
Native Windows/GPU60FPS/audio/human acceptance remains unverified under the waiver.

## 2026-10-14 — Final technical closure

All four milestones completed: Weather37/integration471/Rock72, full45-suite/five-
matrix/managed20/settings-restart regression and weather-aware Town/Harbor2/4/8/20
real-peer matrices pass. Five rematches clear weather/rocks/surface state; disconnect
registries are checked. Synthetic presentation stress exceeds max2 deliberately;
director solo-first/max2 and allowed combinations are separately exercised.

Town warning label moved below the HUD; Harbor review camera now sits inside the
perimeter wall. Full cream snow versus Water-blue wetness/melt with no Snowfall chip
is distinct in final720p/1080p renders. Forty originals/eight contact sheets inspected.
Wet roughness0.25 blends to snow0.85. Five600-tick cycles/map retain stable node counts,
64 cosmetic flakes,3 rocks/3 loose props. Headless tick p95=311/111µs is not GPU FPS.

Initial full regression failed because Flood now correctly leaves wet ground and the
fixture tried igniting it immediately. Its independent Fire stage now advances normal
dry recovery; random scheduling pauses during scripted hazard observations. Gameplay
wetness remains intact. New fixture shutdown leaks were pending WAV playback owners;
stop/detach, free Main and post-free audio cleanup resolves them without filtering.
Three consecutive verbose runs per focused fixture and exact final-PCK runs are clean.
Failed/intermediate logs remain in `.amp/in/artifacts/phase9-evidence`; existing
unrelated historical-suite Dummy audio diagnostics remain visible and qualified.

An isolated uncommitted runtime snapshot exports matching Windows/Linux PCKs with
identity `uncommitted-c8727ddf956e9de19f9e7fa27719`, not a Git commit. Both unpack/hash/
PCK checks and standalone Linux version rejection/create/join/crash-retry/SIGTERM/
port reclamation pass. Exact PCK Weather/Rock fixtures pass. Packages/provenance are
under `.amp/in/artifacts/phase9-packages`, images under `.amp/in/artifacts/phase9`.
The committed-HEAD exporter guard is unchanged. Source remains uncommitted/unpushed;
no public deployment/release, native Windows/GPU/human/audio acceptance is inferred.
The earlier chronological pending statements below are superseded by this closure.

## 2026-10-14 — Weather and Rockslide contracts

Rain/Snowfall use the director's existing authority lifecycle:5s warning,24/26/28s
seeded duration. Rain wets exposed authored patches at0.25/s. Snow accumulates at
0.05/s, melts0.025/s into wetness, which dries0.02/s. Rain wins a direct simultaneous
request, but director excludes opposite precipitation. Static overhead collision,
actual support height and Flood contact determine exposure. Perimeter probes reject
seams/partial shelter;19 Town and6 Harbor patches fit. Harbor fuel0 moves to open
ground(-12,0,-8.5), because all old candidates crossed terrain/cover boundaries.
Destroyed supports clear their state. Full surface snapshots persist after weather,
and LOBBY clears synchronously so immediate rematches cannot retain ice/meltwater.
Wetness≥0.2 prevents/extinguishes ground Fire, not unrelated airborne hazards.

Snow modifies grounded acceleration/braking only: fully snowed sprint35%, walking75%
of25m/s²; steering never vanishes and airborne8m/s² remains unchanged. Walking brakes
more safely. Bounded cream/teal disks exactly cover contact radii;64 noncolliding
animated flakes/streaks maximum, no fog. Wet hunch0.06rad and snow shiver0.025rad
are visual-only offsets. Three distinct vector icons and deterministic1s warning
sounds share the reserved warning voice; Rockslide uses ordinary ragdoll recovery.

Rockslide uses a4m-wide,18m-run/4m-rise authored embankment on both maps, outside
existing refuge paths.5s warning and10s active; three1.3m rocks at seeded1.0/1.2/1.4s
spacing. Swept spheres slide on real slope normals, stop at real static cover and
capsules, cap9m/s, and deal25HP once per rock with bounded knockdown. Batch damage
after collision iteration preserves simultaneous outcomes and synchronous cleanup.
No new loose rigidbodies; remote rocks are meshes only. Both lateral walking exits
take at most1.25s in the real-controller test. A sturdy2.2m cover block intercepts
all lanes; no held-item/crouch immunity. Rock only overlaps seen Rain/Snow; other
hazards and opposite weather pause in the director. Wetness never removes impacts.
Solo-first exposure, history and max2 remain the existing director's responsibility.

Validation now includes Weather37/integration471/Rock72, real two-map escape/cover
controls, five resets/replay, distinct audio dispatch and actual720p/1080p renders.
Final network/full-regression/local-package gates remain9.4. Source remains uncommitted
by explicit owner direction; no deploy/release authorization. Runtime generation
and sound provenance are in assets/manifest.json. Original foundation notes below
describe its historical state, not current integration limitations.

## 2026-10-14 — Phase9 surface exposure foundation

Owner continuation resumes the next planned phase, starting with9.1.1 rather than
adding hazards without a contact model. `WeatherSurfaces` stores at most64 authored
patches with explicit support heights, snow/wetness in0–1 and a shared radius.
Overhead static collision determines precipitation exposure each update, so broken
cover stops sheltering. Authored patches must fit wholly within one support/cover
region; the model does not tessellate terrain or infer indoor floors from the highest
roof ray. Map authoring and missing/destroyed-support handling remain9.1.2 work.

Rain wets exposed patches; Snowfall builds snow there. Rain wins a simultaneous
precipitation request. Snow melts into wetness after precipitation ends; drying uses
only the time left after melting so recovery does not depend on tick size. Flood
at the patch support overrides shelter, clears snow and saturates wetness. Queries
outside radius or more than0.3m from support return dry, not global slippery movement.
Rates are centralized starting values, not playtested tuning. No new body or particle.

Only offline/server callers configure or tick. Client snapshots validate bounded
arrays and apply atomically; snapshots include full layout for fresh/reset state.
The37-check suite uses real roof physics, removal, stacked floors, exact boundaries,
tick equivalence, a client MultiplayerAPI and five resets. It does not send RPCs or
prove map authoring, transport, Rain/Fire integration, visible weather or traction.
Those remain9.1.2/9.1.3; no appearance changed so no render claim. Existing hazards,
director and public build are unchanged. Prior idle validation/hook evidence is
preserved in [continuation state](../phase-8-collision-followup/continuation-state.json)
without replacing the completed archive. Earlier delivery notes below are historical.

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
