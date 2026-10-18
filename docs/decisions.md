# Active phase decisions

## 2026-10-18 — Phase17 weather plan, not implementation

Owner accepts previous proposal sections1–5 as the basis for a plan: continuous
Rain/Snow coverage, gradual recovery, different wet/deep-snow/ice movement and
bounded disaster interactions. Add an explicit first milestone for reported
rain/snow or wet floors beneath intact roofs. Existing exposure sampling does not
prove presentation correctness: drops are offset from patch centers, so inspect
actual trajectories and roof boundaries before declaring a root cause.

Use Toy Town as the primary redesign target, preserve shared Harbor behavior.
No random slipping, ordinary-rain HP drain, temperature meter or fluid simulation.
Separate broad wet sheen from electrically connected local puddles. Flood entering
a roofed room is a separate mechanic, not permission for precipitation through roofs.

Previous B/C idea groups are rejected; do not schedule their extra UI/explanation,
pacing/variant/director changes. More creative player-driven interactions will be
proposed in chat, not silently included as approved implementation.

[Checklist](checklists/phase-17-continuous-weather.md) owns requirements;
root `progress.json` owns status and next action. No gameplay edits, new release,
deployment or infrastructure changes under that earlier planning request. Existing
human waiver and unresolved native/GPU/audio/network limits remain unchanged.

## 2026-10-18 — Owner authorizes execution, A/B and release

Latest request supersedes planning-only delivery boundary: add rotating awning and
rotating shortcut bridge, delegate implementation, validate through completion and
release. Use existing deployment infrastructure unchanged for matching server/client
delivery. Other gameplay proposals remain unapproved. Record six milestones and
keep normal routes available when interactable shortcuts move or terrain is lost.

## 2026-10-18 — Continuous geometry, bounded retained contact and real controls

The first delegated grid still produced isolated islands. Replace it, not keep it
as a fallback: exposed world geometry receives a continuous weather overlay, with
actual floor/roof rays for authoritative contact. Local puddles are authored low
spots, not the definition of the rainy region. Their recovery is slower than open
sheen; covered retained moisture dries more slowly and snow melts into wetness.
Flood leaves height-aware residue rather than reviving washed snow when it drains.
Fire melts by a bounded amount and height band, so it cannot thaw an upper floor.

Keep network state compact: one regional weather state,32 local melt overrides,
32 puddles and at most128 retained1m support contacts. Preserve the small awning's
entire swept footprint before rotation; sampling alone must never mutate snapshots.
The render-only1m top-height cache refreshes1024 probes/frame only after geometry
changes. Headless dedicated instances allocate no precipitation meshes/textures.
This is a bounded toy-world effect, not material-accurate hydrology or fluid flow.

The bridge uses one AnimatableBody carriage path, not an additional manual player
delta. Real-capsule testing found the original ramp ended under the landing; meet
its outer lip instead. Use production server proximity/alive/standing/LOS checks.
E activates nearby controls only while alive, preserving spectator E cycling.
Active-round player admission remains intentionally unsupported. Test a late
initial module snapshot over ENet separately from production two-peer carriage and
five acknowledged rematches; do not add a new admission system to satisfy a fixture.

Only the parent ships the integrated gate-passing source. A delegated partial push
triggered workflow39119384412; it was cancelled before deployment. Do not bypass
the normal staged pre-commit gate for the final integration.

The normal full gate found the south bridge landing spans the z32 collapse cut.
Run the existing partition pass after constructing mechanism approaches; do not
weaken single-district ownership or delete geometry outside a warning. Focused
layout6910 and production ENet carriage/reset controls passed after correction.
Move Town's two central puddles to exposed plaza(-4,4)/(4,-4), not beneath the
old bridge. Production Lightning now exercises the authored warning/electric path.
Crank prompts render through their own moving canopy so rotation cannot hide E;
raise/outline state cues without changing physical clearance or interaction range.
