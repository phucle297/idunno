# Phase19 — Multiplayer frame budget investigation

Status: planned; owner requested investigation and a plan, not implementation or
redeployment. Performance work precedes the Phase20 sabotage expansion.

## Report and evidence boundary

Owner reports solo is smooth, but two application instances on the same machine
in one multiplayer room cause noticeably more heat and frame drops. Exact build,
OS/GPU, resolution, session length, maps/hazards and FPS are unknown. Latest public
build is741ae34; do not silently assign that revision to the owner's observation.
Heat is reported, not a measured temperature or diagnosed thermal throttle.

Code inspected:
- `tests/profile_overlap.gd`:120 warmup/600 samples, p50/p95 frame/process/physics,
  draw calls, nodes and bodies; synthetic four avatars in one process, NOT two
  independently rendered network clients. V-Sync pacing and uncapped throughput
  are separate. Existing headless20-client pass is not graphical performance proof.
- `project.godot`, `game/ui/pause_settings.gd`: no explicit project FPS cap or
  focus/minimized rendering policy found. Engine/driver defaults remain unknown.
- `game/main.gd`: physics/input reconciliation; full session snapshot assembly;
  prop sorting/broadcast and `_network_prop` group lookup; per-frame HUD/weather.
  These are candidates to measure, not confirmed bottlenecks.
- `game/ui/home_screen.gd` already disables its preview viewport when hidden;
  do not assume hidden Home always renders. Inspect actual active viewports first.

## M19.1 — Reproduce and attribute the cost

- [ ] Extend the existing profiler/real-client driver to produce per-process JSON
  results and timestamped frame traces for actual standalone/PCK clients. Record
  CPU/GPU/driver, OS, release/editor, map/seed, resolution/render scale, monitor Hz,
  V-Sync/FPS policy, focus state and number of processes. Never log credentials.
- [ ] Matched matrix: one solo; one graphical client with headless dedicated server;
  two graphical clients with same server; two clients on separate devices when
  available. Run dedicated on same machine and separately as distinct controls.
  The one-client/two-player control needs an actual second headless network client,
  not a disconnected or fabricated roster.
- [ ] For two apps compare both visible, one unfocused, one minimized, and alt-tab
  focus switching. At1280×720 and1920×1080 test default pacing, explicit60FPS cap,
  and diagnostic uncapped throughput separately; never compare capped FPS alone.
- [ ] Use Toy Town first, Harbor as smaller-map control; Home/Outfits/lobby/dry match,
  moving peers, Rain/Snow, Flood+Tornado, collapse/props and ragdoll bursts. Hold
  map/seed/camera/hazard state constant across before/after. Serialize stress jobs.
- [ ] Collect p50/p95/p99 frame time, >33.3/>50ms hitch counts, process/physics time,
  draw calls/triangles/visible viewports/particles, RAM/VRAM and allocation/node
  trends. OS CPU/GPU utilization, clocks/power/temperature only where available;
  report missing sensors as unknown. Capture RTT/loss/reconcile frequency,
  snapshot bytes/rate/serialization/apply cost to separate network judder from FPS.
- [ ] Repeat3× short runs with120 warmup/600 samples, then15-minute representative
  sessions on hardware when available; compare start vs end for throttling/leaks.
  Guard scenarios against hazards expiring mid-sample; state invalid runs clearly.

Exit: minimal repro or explicit not-reproduced result, measured attribution to
render/CPU/physics/network/thermal/combined contention and a ranked top3 cost table.
Orb llvmpipe evidence cannot close native GPU/temperature acceptance.

## M19.2 — Fix only proven hotspots

- [ ] Select interventions from M19.1 measurements, not all candidates at once.
  Measure each independently before combining; retain before/after traces.
- [ ] If pacing is the cause, trial configurable60FPS default and optional lower
  background presentation rate. A simple Engine.max_fps cap can also delay the
  main loop/ENet: measure actual physics cadence, prediction, polling and timeouts.
  Keep server simulation/network service cadence intact; focus return must recover
  camera/input without stuck keys or authority gaps. Dedicated stays unaffected.
- [ ] If rendering dominates, budget shadows/lights, distant animation/cosmetic
  effects and inactive viewports; try resolution/quality controls with honest visual
  tradeoffs. Never hide warning hit footprints, real cover, route geometry or peers.
- [ ] If CPU/network dominates, instrument then reduce repeated lookup/sort,
  allocations, redundant HUD/layout or unchanged state work. Preserve snapshot
  sequencing, authoritative hit/collision/HP, terrain/mechanism reset and admission.
  Do not reduce tick/send rates or rebuild networking merely to mask a hotspot.

Exit: unchanged-scene comparison on the same hardware/settings; improvement beyond
run variation without authority, visual-readability or input regressions. Reject
changes that only move the cost to the server or lower visible fidelity silently.

## M19.3 — Validate baseline and freeze sabotage budgets

- [ ] Repeat M19.1 matrix on final source, focus/minimize recovery, real2/4 peers,
  existing8/20 headless correctness controls and5 rematches. Monitor15-minute
  node/RAM/VRAM trends after warmup and cleanup rather than allowing monotonic leaks.
- [ ] Target on recorded reference hardware: focused client p95≤16.67ms at agreed
  quality/resolution; quantify p99/hitches and two-visible-client throughput too.
  Two apps on one GPU are a contention stress test, not a universal60FPS promise.
  No chosen reference GPU yet: do not declare that target passed in the orb.
- [ ] Run normal staged regression and inspect representative render/quality states
  for visual changes. Record evidence and physical-device limits separately.
- [ ] Establish measured CPU/network/visual headroom and concurrency budgets for
  Phase20; no budget increases solely because a synthetic headless run passed.

Exit: recorded baseline, verified improvements or explicit blockers, regression
results and budgets. Package/release/deploy requires separate delivery authorization.

No new hardware/infra provisioning, no blanket map-detail removal, no claim that
heat proves a networking bug. Human feedback remains under the existing waiver;
see [NEED_REAL_CHECK](../../NEED_REAL_CHECK.md).
