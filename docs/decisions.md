# Phase21 — Hidden-fuse bomb decisions

The owner removed every other proposed gameplay/UI/UX improvement and authorized
implementing only the [bomb](checklists/phase-21-hidden-fuse-bomb.md).

The fuse is server-private and random, sampled once per collected parcel. No
recipient grace, final transfer embargo or countdown: immediate explosion after
receipt is an accepted random outcome, not a fairness bug. Presentation exposes
the carrier/constant footprint, never fuse age. No direct HP damage; existing
bounded impulse/protection and environmental death attribution remain authoritative.

Use an independent controller and bounded public snapshot rather than embedding
private fuse values in ToySabotage's public lifetime records. Hot Potato is an
optional lobby preset using Normal disaster pacing, not a default-mode change.
F picks up; left click throws only while carrying; personal toy slots are untouched.

The server blocks personal toy pickup/firing while that player carries or has the
single parcel in flight; input routing alone is not authority. This guard does
not change victim eligibility or grant immunity. Entering/leaving Hot Potato
clears Ready flags so guests acknowledge the changed rules before Start.
The fixed public wire is29 bytes (52 added bytes in the full Main dictionary);
private fuse/RNG never share the personal-toy lifetime serializer. All new
presentation geometry is shadow-free and pooled (972 triangles, two audio voices).

Phase20 [history](old-docs/phase-20-toybox-sabotage/progress.json) and deployed build
remain unchanged. This task authorizes source implementation/verification and
per-unit commit/push, not another public release/deployment. Existing native
thermal/FPS uncertainty, waiver and route-unsafe combo deferrals remain intact.
