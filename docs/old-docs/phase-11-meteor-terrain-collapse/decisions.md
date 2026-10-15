# Disaster Party — Active Decisions

## Phase11 scope replacement — 2026-10-15

The owner rejects the uncommitted shrinking-circle and gradual HP-loss implementation. It is cancelled, not completed. The prior Phase11 checklist, decisions and root progress are preserved byte-for-byte in [phase-11-superseded-zone](../phase-11-superseded-zone/); its passing evidence applies only to the superseded code and satisfies no new gate.

Phase11 remains stable number 11 with ID `phase_11_meteor_terrain_collapse`, active at11.1. Phase12 is still planned, not activated. The new outcome is a heavy warned meteor causing permanent-for-the-round district disappearance and instantaneous, authoritative void-fall death. It has no circle APIs/tests, gradual or AOE HP pressure, or compatibility fallback. Ordinary MeteorShower retains its explosive contract.

## Terrain-collapse defaults

Use a 3×3 district map. Town cuts use x±30 and z[-37,20]; Harbor x±12 and z[-10,14]; outer bounds are x±56/z±56 and x±32/z±32. All nine districts have equal initial selection eligibility, including centers and the Harbor warehouse. No named refuge is permanently protected, including during Flood. Seed bounded removals whose remaining sectors stay connected; connectivity starts from any surviving sector, not the center. Ground and overlapping foundations are physically partitioned, then their geometry and collision disappear until rematch; reset restores them without rebuilding the world. An alive root below y=-0.8 receives one authoritative lethal damage batch. Roofs and walls do not shelter a removed district.

## Structure-aware district cuts — 2026-10-15

The first x±28/z±34 cuts ran through the northern residence roofs and stair/ramp/gangway seams, so removals deleted footholds outside the warned rectangle. The seam regression (probe x±27.5,z-45 before/after removal) reproduced the roof case. Town x±30/z[-37,20] resolves these seams. Harbor originally used z[-16,14] while the warehouse/center were immune; removing that immunity requires moving the north seam to-10 so the whole warehouse and roof ramp fit inside the northern warning. The gangways fit entirely inside the removable center; dock ramps stay in single corner districts. All18 single-region holes pass, and all278 accepted masks check surviving AND removed high-route support.

Schedule warnings at normalized120/270/390/510 seconds of600. The 30-second warning scales in fixtures. Clock jumps must still produce a warning before removal, postponing the collapse if necessary. Warning rectangles plus a separate HUD row remain readable indoors; spectators see timing only. Pending/removed ground is excluded from new hazard targeting, and remaining high-ground routes are protected.

## Delivery and historical context

Phase10 delivery, the user-acceptance waiver, and historical delivery metadata remain recorded in root `progress.json`. The latest owner instruction explicitly authorizes fixing all findings then commit/push/release. Pushing existing main triggers the existing exact-head server build/deploy workflow; no capacity/configuration/store change is authorized. Native/human acceptance remains unverified.

## Post-Flood crate settle measurement — 2026-10-15

`test_prop_role_feasibility` asserted a drained crate origin below y0.35, which is only true for an upright 0.6m cube. A sideways/tilted settled crate rests on an edge and legitimately raises its authored bottom origin to about0.44m while its collider bottom stays on the ground. The check now measures the real collider bottom against the ray-found support, plus bounded speed and passenger walk-off, instead of assuming an upright orientation.
## Collapse-hole presentation is pure absence — 2026-10-15

Owner feedback: the slate pit walls and dark depth plane read as fake. Removed
districts now render nothing at all — geometry and collision disappear and the
existing sky background color shows through the hole ("biến mất luôn", blue
background continues below). The `CollapsedDistrict` void boxes are deleted
rather than kept as a fallback; warning telegraph visuals are unchanged.

Endless-fall guard (the Phase1 endless-falling crash class): alive players die
in one authoritative batch below y=-0.8 as before; networked props that fall
past `MAP_KILL_Y` are parked below every support ray (frozen, hidden). The ordered
prop snapshot stream is the sole source of client parking/unparking state; the
redundant reliable despawn RPC was removed after Oracle identified a stale-event
rematch race. Rematch resets their spawn transform. Ordinary breakable rubble
does not have a timer (the earlier claim was wrong); its owner now frees it below
y=-8. Burning/hazard debris retains its existing bounded lifecycle.

## Oracle review fixes and equality — 2026-10-15

All three findings are addressed: structure-state updates combine a terrain-removal
flag with damage state, preventing restored invisible support; breakables are no
longer restored by deferred terrain shape writes that can override rematch reset;
ordinary rubble gets owner-managed kill-depth cleanup. Earthquake pulses exclude
pending/removed structure targets on every pulse. Regression checks cover each
failing sequence, including a ray hitting the restored cargo lid top rather than
the platform below. An expanded all-mask test also found same-frame reset/removal
ordering could re-enable static colliders; removal now always queues last. Three
old escape waypoints crossed walls/rails once those colliders were correctly
restored; routes now use the garden west exit and the actual dock gangways.

Follow-up Oracle review found an additional client-only rematch issue: an empty
earthquake snapshot means idle with every structure intact, but clients previously
only cleared the quake effects and retained broken structures. Empty snapshots now
reset damaged sections; explicit idle snapshots still preserve their encoded damage.
The real-peer fixture first breaks a roof panel, then removes center/north terrain,
and verifies intact visual/collision state and a ray hitting the restored panel after
each rematch. Harbor two-player reproduction failed before this fix and passed after
it (`/tmp/collapse-reset-before.log`, `/tmp/collapse-reset-after.log`).

Final focused Oracle review traced both LOBBY-first and ACTIVE-first snapshot paths:
earthquake damage reset preserves terrain removal, and terrain reset then clears that
separate flag; monotonic snapshot sequencing rejects stale prior-round state. No
remaining persistent reset defect was found. Two physics frames before restoration
rays allow an intervening completed physics step, keeping exact collider assertions.
The earlier intermittent Harbor20 predicate was not recovered; do not claim its cause
was proved. Separate Harbor20 and the final eight-case matrix pass. Final staged-tree
regression, matching119-entry packages, exact-head EC2 deployment, no-cache deployed-PCK
core4142, standalone Linux lifecycle and public two-client smoke pass. The matching
prerelease and downloaded assets/tag were verified. Native/human gates remain unverified.
