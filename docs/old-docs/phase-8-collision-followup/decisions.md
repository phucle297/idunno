# Disaster Party — Collision Follow-Up Historical Decisions

Phase 8 source, render, network and local-package technical gates are complete;
its [decisions](../phase-8-character-disaster-counterplay/decisions.md),
[checklist](../phase-8-character-disaster-counterplay/checklist.md) and
[full evidence](../phase-8-character-disaster-counterplay/progress.json)
are archived together. Root [progress](../../../progress.json) owns current state;
the completed [collision follow-up](checklist.md) is archived here separately.
Phase9 is planned, not started; the completed Phase8 archive remains unchanged.

Source14be2c3 is pushed; matching Windows/Linux review bundles are local only.
Public Integrated Town revision2619665 is unchanged. No new deployment/release,
profile-store activation, capacity change or Steam publication authorized.
Native Windows/GPU60FPS/audio/human difficulty/separate-network acceptance remains
unverified and nonblocking under the existing waiver; see [real-check policy](../../../NEED_REAL_CHECK.md).

## 2026-10-14 — Solid map details

Owner asks for rail/shrub/environment collision. Opt in the substantial blockers
at their existing builders instead of making every visual detail collidable:
paint/paving and thin window/trim/finial overlays are not invisible obstacles.
Rail bars/posts, planter containers/shrub lobes, lamp posts/feet/globes, roof vents
and Harbor bollards/cargo use static layer1 geometry. Boxes match authored sizes;
shrubs bake radii into26-point convex hulls without scaling a physics body or using
triangle collision. No new loose/network props; rematch owns colliders with Sandbox.

First route regression proved the former decorative ParkRail crossed ParkRamp:
ordinary walking stopped atz8.63 and failed Flood escape. Shorten mesh and collider
together to2.2m atx17.9, leaving the full3m ramp plus capsule clearance visible.
The shortened rail is reseated on the platform edge atz10.15: a rail in midair
can block a sweep yet let a walking player fall under it. Add sustained grounded
contact, not just shape casts. Sloped stair rails/balusters also use their actual
rotated box transforms. Do not hide a gap behind unbroken visual geometry.
Final capsule/foliage/stair/contact/five-rematch tests pass82 checks; all route/exit
controls reran on final source (58 checks), safety231 and combinations102 passed.
Actual map-aware2/4 peers/five rematches passed on both maps. One additional scene
fixture failed a transient prop-reset observation; preserved, no tolerance relaxed.
Headless20-avatar stress p95physics7.311ms/process5.481ms, fixed transport/loose-body
caps and stable memory; not GPU60FPS. Three720p/1080p states inspected. No new bundle
or deployment; old Phase8 packages do not include this follow-up.

## 2026-10-14 — Movement pickup planning only

Owner explicitly adds planning for random speed/jump drops, extending the former
cosmetic-only scope. [Phase12](../../checklists/phase-12-match-powerup-drops.md) reserves
an ID without renumbering9–11 or activating implementation. Proposed Speed+20%
for12s / Jump height+20% for10s, one active buff, refresh/replace without stacking.
Jump velocity is derived from height/gravity, not naively boosted20%. Seeded safe
anchor selection, bounded drops, server-only atomic collection, predicted movement,
HUD/countdowns and reset/death/rematch gates are planned. No persistent stats,
profile/economy changes, cosmetic advantage, held-item mechanics or new pickup code.
