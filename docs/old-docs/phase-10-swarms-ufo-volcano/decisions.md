# Disaster Party — Phase10 Decisions

## 2026-10-15 — Phase10 authorized

The owner requests the next phase through completion. Implement the existing
[Phase10 contract](checklist.md), not the postponed
zone or power-up phases. Phase9 delivery remains historical below. No new public
release/deployment, capacity or storage change is inferred. The existing
[human acceptance waiver](../../../NEED_REAL_CHECK.md) stays in force.

| Mechanic | Authority, counter and bounds | Reset/feedback |
| --- | --- | --- |
| Bees | One server position,12 cosmetic bees,3m/s versus4.5m/s walking;5s initial warning,8HP sting at most once/s within1.4m and unobstructed reach. After6s pursuit or2s blocked steering, rotate sorted surviving peers with3s warning. Actual roof or head immersion breaks pursuit. At most3 swept movement candidates per substep; blocked paths disengage rather than penetrating walls. | Stable peer ID/position snapshot; visible target label, distinct synthesized buzz warning. No per-bee networking/bodies. Clear target/timers on cleanup/disconnect. |
| UFO | Fixed3.5m footprint,5s warning,4s capture; take overhead collision cover or walk out. Preserve horizontal movement; cap upward speed3m/s and height2.5m above the selected support. Roof/ragdoll/exit/elimination interrupts; no recapture in the same event and no added release impulse. | Saucer, violet translucent column, ground footprint and warning text; stable footprint/captured-ID snapshot, bounded20 captures. |
| Volcano | One stable authored district per map:18×18m Town plaza or24×6m Harbor boardwalk.12s evacuation warning;9 predefined shelves form4 raised banks around broad crossing corridors, with4 shallow entrance ramps. Warned occupants are seated on raised support rather than embedded. Existing high-refuge approaches outside the footprint remain intact. | Variant0/1 and per-support heat snapshot reconstruct collision locally. Orange hot, sand warm, slate cooled plus explicit text/seconds. Cooled altered geometry persists until round/map reset; no repeat reheat. |
| Ground heat | Immediate6HP/s on actual contacted support,60 heat-seconds initially. Dry1, exposed Rain3, exposed Snow4, reached Flood10 heat-seconds/s; strongest rate only. Account damage only until local heat reaches0. Heat reserves a director slot until every shelf cools. | HUD context reports local hot contact. Roofs shield precipitation, not immersion; raised dry banks remain hot under partial flooding. Static-map reuse explicitly restores terrain. |

Unsafe force/lethal overlaps are excluded symmetrically by metadata; Bees may
overlap weather/Flood, UFO only precipitation, Volcano precipitation/Flood.
Existing solo-introduction and max2 rules remain. Synthetic transport fixtures
may exceed this cap only to stress snapshot delivery.

### Ordinary falls were missing

Code inspection during UFO verification found no existing fall-damage path.
Both normal and knocked-down movement now report actual pre-collision downward
speed on landing. Authority batches same-frame impacts before winner evaluation:
no damage up to9m/s; quadratic severity to100HP at18m/s. No UFO-specific fake
damage and no new water immunity. The roof-breakage Flood fixture now measures
breathing grace relative to post-landing HP, rather than assuming falls are free.
Landing connections are idempotent when the offline avatar survives room retry.

### Evidence qualifications

Initial solo checks pass Bees77/UFO78/Volcano260. Integration, complete regression,
both-map real-peer matrices, final renders, bounded profiling and matching local
packages are tracked separately in root progress; do not infer their results.
Earlier fixed-FPS scratch runs retained Dummy-audio shutdown refs. Final exact-PCK
Bees77/UFO78/Volcano260 each3 consecutive verbose exits and Integration47 are clean.
49-suite/five-network-group/managed20/settings restart,41 Python tests, both-map
2/4/8/20 peers/five rematches,40 inspected captures and bounded soak pass. Matching
uncommitted local Windows/Linux PCKs and standalone Linux lifecycle pass. Full
[final evidence](progress.json) supersedes chronological pending entries above.
Older regression fixtures retain shutdown-only Dummy-audio resources, recorded
without suppressing runtime errors. No native Windows/GPU/audio/human acceptance,
source commit/push or public Phase10 delivery is claimed. Phase11/12 remain planned.

## 2026-10-14 — Authorized Phase9 shipment verified

Source [c0a7800](https://github.com/phucle297/idunno/commit/c0a780067c10372ca6676725f03916503994aa5e)
passes staged45-suite/five-network-group/managed20/settings-restart and41 Python tests.
[Existing EC2 workflow](https://github.com/phucle297/idunno/actions/runs/38615376266)
deploys that exact revision with backend readiness; no tests run in deployment.
[Public pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-c0a7800)
contains exact CI Linux artifact and Windows with byte-exact deployed PCK/refreshed
hashes. All105 local/CI PCK entry payloads match; only container bytes differ.
Three release assets downloaded and compared, tag verified. Exact final-PCK Weather471/
Rock72 and standalone Linux lifecycle pass. Two public exact-PCK clients pass TLS,
tickets/ENet,Ready/Start/ACTIVE,remote movement and404/409 controls; same orb/upstream,
not native Windows/GPU/audio/separate-network human acceptance. Source/failed logs,
images and packages remain under `.amp/in/artifacts/phase9*`; this is historical
Phase9 authorization, not authorization to deploy Phase10.
This documentation-only checkpoint skips CI to avoid a redundant deployment.
