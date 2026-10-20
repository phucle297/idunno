# Phase19 — Multiplayer frame budget investigation

Status: automated investigation/optimization checkpoint completed; native owner
symptom is NOT confirmed fixed. Source units passed and were pushed, not deployed
or released. Existing hardware/human waiver permits bounded Phase20 continuation;
it does not establish native FPS, thermal headroom or physical focus acceptance.
The original expanded diagnostic matrix is retained below with unexecuted controls
unchecked, not silently converted to passes. Confirmed rendering attribution and
measured fixes satisfy this investigation's explicit-repro/attribution exit;
extended controls remain follow-up rather than a reason to block all new content
on unavailable hardware. Sabotage must pass incremental budgets, not assume room.

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

## Executed diagnostic — 2026-10-19

Runtime/assets unchanged from public741ae34; source checkout e884258 adds planning
only. Godot4.7.2 editor engine, Compatibility, Linux orb, Xeon2.60GHz/4vCPU/7.8GiB,
Mesa22.3.6 llvmpipe LLVM15 software renderer, `LP_NUM_THREADS=2` per graphical client.
Not the exported Windows/PCK build and not the owner's hardware.

Scratch driver extends `tests/managed_container_peer.gd`, uses real RoomService,
dedicated authority and two real ENet clients. One-render network control has an
actual headless second client. All network processes share this orb. Each graphical
client has its own1920×1200 Xvfb display,1280×720 game window, Dummy audio, identical
review camera at(0,5,12) looking at(0,1,0), default Toy Town, dry stationary ACTIVE.
No gameplay/hazard movement profile or same-desktop focus/minimize test is implied.
Director cleanup removes hazards; sampled results require ACTIVE and2 players.
Root3D is disabled during admission only, then restored except the no-3D ablation.
V-Sync disable requested, but driver warns mode changes unsupported; Xvfb provides
no physical vblank. Caps apply to every measured process, including the authority
in the60-cap experiment; this is NOT a production client-only pacing proposal.

Each scenario has3 repeats of2s settling +10s sampling, not120 warmup/600 frames.
Heavy cases yield only7–20 frame intervals per window: tail percentiles are retained
in the [57-row raw sample table](phase-19-render-samples.csv), **not reliable p95/p99
estimates or a60FPS verdict**. Table below is median of each graphical client's
per-window p50, not pooled frame time or FPS. Process time includes renderer waiting;
it is not isolated script CPU time. Static RAM is Godot's allocator, not RSS/VRAM.

| Control / one change only | Median p50, ms | Frame intervals/window | Median draw calls/frame |
| --- | ---: | ---: | ---: |
| Solo, one renderer | 1071.897 | 9 | 8563 |
| Two network players, one renderer | 1093.822 | 8 | 8618 |
| Two network players, two renderers | 1173.726 | 7–8 | 8618–8622 |
| Two renderers, hidden Home/Collection processing+previews disabled | 1187.272 | 7–8 | 8618 |
| Two renderers, root3D disabled (diagnostic only) | 9.588 | 992–1013 | 21 |
| Two renderers, cap60 | 1178.801 | 7–8 | 8618 |
| Two renderers, Sun shadows disabled (diagnostic only) | 474.841 | 19–20 | 3881 |

All21 windows completed: `FRAME_INVESTIGATION_OK scenarios=7 repeats=3 duration=10s
warmup=2s hardware=orb-llvmpipe`; client/server logs contain no SCRIPT ERROR/ERROR.
The successful fixture runs with independent X displays. Earlier runs failed on
test-only1500ms admission timeout, absent dedicated Home in the fixture summary,
then competing X11 pointer grabs on one display; they are not clean passes and
were fixed in the diagnostic fixture only, never by relaxing product policy.

Separate headless inventory: Sandbox contains4709 non-null mesh instances,
4741 surfaces,3,659,980 mesh triangle primitives across all instances before
camera culling,4709 shadow-casting instances,2092 static bodies/2173 colliders.
These are full-scene counts, NOT visible triangles, unique meshes, GPU memory or
active physics work. Paving already uses one ArrayMesh; materials/rounded meshes
are cached. Most other parts remain individual instances; no MultiMesh/LOD policy.

Synthetic unchanged-roster microbench,5×500 calls, no network or deferred layout:
`present_players` median0.032818/0.064338/0.127626/0.641060ms for1/2/4/20 rows.
It proves avoidable per-frame work exists, not that lobby UI causes this2-app issue.
Home preview is hidden and UPDATE_DISABLED throughout ordinary ACTIVE samples.

### Ranked attribution and next experiments

1. **3D rendering dominates this software-render scene.** Shadow ablation removes
   about55% of draw calls; remaining non-shadow rendering is still costly. Trial
   selective shadow casters/distance first, then district-local batching of repeated
   static trim/foliage and distance-aware presentation. Keep rounded silhouettes,
   close detail, real collision, roof shelter and warnings; do not ship all-shadows
   off or delete map content based on this experiment.
2. **Client main-loop cadence collapses when rendering stalls.** Baseline graphical
   clients execute72–80 physics ticks/10s versus599–601 with3D disabled; local
   authority remains599–601 ticks across controls. This can compound input/network
   judder, but does not prove packet loss, authority bugs or the owner's cause.
   Instrument input-to-snapshot/reconciliation and client-only focus/pacing next;
   do not lower server tick/send rates or increase max catch-up steps blindly.
3. **Hidden UI is a secondary CPU candidate, not measured dominant.** Disabling
   hidden previews/process alone does not materially beat baseline. Measure full
   lobby/HUD/catalog call costs; trial change-driven roster/style updates separately
   after rendering. A60FPS cap cannot help a renderer already below1FPS; its power
   benefit on a fast GPU remains unknown, not disproved.

Reproduction recipe: real-client fixture controlled through its existing JSON
commands; start solo or create/join→both Ready→owner Start→authority cleanup;
then send `render_profile` to clients/authority3 times, wait for each result and
capture JSON. Options are cap60, hidden_ui_off, no_3d, shadows_off independently.
Temporary driver/log bundle is retained for review in
`.amp/in/artifacts/phase19-diagnostics/reproduction.tar.gz`; portable numeric
evidence is versioned beside this checklist. No credentials/config tickets bundled.

M19.1 remains open: exported/native builds,600-frame traces, GPU/power/temperature,
same-desktop focus/minimize,1080p/Harbor/hazard/movement cases, remote authority,
network bytes/apply profiling and15-minute trends are not executed by this run.
No native smooth-solo/slow-multiplayer reproduction or final performance fix claimed.

## Reusable tracer follow-up — 2026-10-19

`tools/profile_multiplayer.py` now launches solo or two real direct-IP ENet clients
and playerless dedicated authority, using the same production movement/session RPCs.
This is a local render/simulation control, NOT the earlier HTTP room allocator,
profile persistence, public admission, or separate-network test. No new gameplay
RPCs or exported profiler entry point. The external SceneTree is excluded by the
existing tools export filter; Python orchestrates only local subprocesses/files.

Defaults:120 rendered/process warmup frames,600 chronological intervals,3 repeats,
720p requested window, fixed review camera, dry stationary match. Renderer count0/1/2
selects headless/one/two graphical clients; solo accepts0/1. Headless root actually
reports64×64, recorded per trace: never count it as a720p rendered benchmark.
Controls: Toy Town/Harbor, dimensions, explicit client FPS cap, requested V-Sync mode,
shadows-off/no-3D ablation. Pacing/quality changes never apply to dedicated authority.
Do not interpret no-3D as gameplay quality or proof of GPU throughput.

Outputs: fresh-directory metadata, PCK SHA256/build identity, per-process per-repeat
raw JSON, summaries, logs. Samples retain frame/process/physics time, physics callback
count, draw/primitive counts, nodes/static allocator bytes, state/roster, observed
match/input/ack sequences, RTT and focus. Process timestamps are relative to each
process, NOT synchronized clocks; windows start independently after warmup. Sequence
deltas are observed progress, not RPC counts, packet loss or correction magnitude.
Profiler allocations/polling also cost work. No snapshot-byte/apply-cost, GPU power,
temperature, physical refresh-rate or sustained-throttle measurement is claimed.

Usage (installed pinned editor engine; no remote server touched):

```sh
# Full two-renderer dry trace on a native desktop; vary one setting per fresh run.
python3 tools/profile_multiplayer.py --engine godot --output .scratch/profile-two
# Solo / one-render-two-player controls use the same camera and defaults.
python3 tools/profile_multiplayer.py --engine godot --scenario solo --renderers 1 --output .scratch/profile-solo
python3 tools/profile_multiplayer.py --engine godot --renderers 1 --output .scratch/profile-one
# Exact exported PCK with editor engine, NOT the release binary's performance.
python3 tools/profile_multiplayer.py --engine godot --pack /absolute/release/DisasterParty.pck --output .scratch/profile-pack
```

Orb: add `--xvfb` for independent virtual displays and use the same
`LP_NUM_THREADS=2` policy across matched controls. This does not validate same-desktop
focus/minimize. Short `--warmup 3 --samples 12 --repeats 1` runs validate plumbing
only; use full samples for actual tail statistics. Every stage has a bounded deadline,
errors/stale samples/changed match roster fail, and child processes are cleaned up.

Executed: source and exact741ae34 PCK headless3×600 per process (5400 records per
run); exact-PCK two-graphical no-3D cap60 control3×600, authority cap0; short actual
two-renderer PCK trace; solo Harbor smoke; two durable CLI/summary tests. Full source
headless observed physics59.90–60.15Hz. First no-3D cap test overlapped contract
tests; final serialized rerun with current driver retained5400 records and
physics59.910–60.102Hz, clients cap60/authority cap0. This is cadence/instrumentation
validation, not normal3D render performance. Actual3D trace uses only12 samples/peer and
confirms the driver sees the same severe llvmpipe stalls, not a native FPS verdict.

Editor import also exposed profiling CSV being treated as localization, generating
17 untracked sidecars. `docs/.gdignore` now excludes documentation from Godot's
asset scanner; only generated sidecars were removed, re-import created none.

**Standalone limitation verified, not worked around:** official4.7.2 release
templates reject `--main-pack` and silently ignore external `--script`. The runner
checks capability before peer launch and refuses such binaries instead of timing
normal main as if it were instrumented. Godot's compile guard clears `script` without
`OVERRIDE_PATH_ENABLED` ([upstream code](https://github.com/godotengine/godot/blob/4.7/main/main.cpp#L4322-L4333)).
Editor+exact PCK is supported and labeled explicitly. True release-template profiling
still needs a separately scoped in-build diagnostic entry or external measurement;
do not modify the release PCK/custom-build the engine and call it unchanged evidence.
M19.1 remains open for the unmeasured controls above and hardware acceptance.

### Controlled movement follow-up

`--moving-client` opts client-0 into alternating real left/right input every30
physics ticks; stationary remains the default. No teleport or gameplay RPC is
added. Server traces retain authoritative positions; the runner rejects a moving
run that does not exceed0.5m authoritative displacement. Pending predicted-input
count and ack sequence lag are observations, not milliseconds or packet loss.
Snapshot receipt age and reconciliation correction magnitude are explicitly
unavailable without an actual receive/reconcile hook; do not infer them from
independently sampled client/server clocks.

Executed source headless, client cap60/authority0,120 warmup/600 intervals×3:
`MULTIPLAYER_PROFILE_OK`;5400 records. Authoritative travel11.64–11.90m/window,
max displacement1.00–1.34m, physics59.90–60.12Hz across peers. Four profiler
contract tests pass, including stationary-default and actual authoritative motion.
This verifies the controlled scenario, not rendered movement smoothness or a fix
for the owner's frame drops. Raw outputs: `.scratch/phase19-moving-full`.

### Long-window world-control correction

The first selective-shadow comparison (`.scratch/phase19-shadow-before` and
`-after`) is **rejected as a matched verdict**: later60-frame windows lasted
long enough for automatic terrain collapse. Baseline draws fell8618→7272 as map
geometry disappeared, independently of the intervention. Short instrumentation
passes never justified ignoring this control.

The external driver now extends round duration and resets intact terrain before
sampling; every trace records removed/pending district state and the runner fails
if any warning/removal occurs. Production clocks, collapse and snapshot validation
are unchanged. An attempted invalid fixture stage4/mask0 was caught by client
snapshot-progress assertions and removed after reading the validator. Four
contracts pass again. Movement summaries now use horizontal displacement so
gravity alone cannot falsely prove controlled input. Matched corrected reruns use
the same external driver and engine against the old exact PCK and candidate source.

### Selective small-detail shadow trial — corrected comparison

Same pinned editor engine/llvmpipe/LP_NUM_THREADS=2/720p, two real graphical ENet
clients and local dedicated authority. Baseline is exact public741ae34 PCK;
candidate source differs in runtime only by detail shadow selection. Source and
PCK geometry/collision hashes match on both maps. The external driver's extended
round timer keeps all measured district masks0 and pending=-1; all snapshots still
pass production validation. Normal powerup spawns continue, causing small draw-count
variation; they are not hidden or called identical frozen-effect state.

Each side:12 warmup/60 chronological frames×3,180 intervals per graphical client,
not the default120/600 or a native GPU/hardware acceptance run. Serial runs, same
camera/quality/V-Sync request, client and authority uncapped; independent X displays.

| Metric | Before | Candidate |
| --- | ---: | ---: |
| Per-client median draws/window | 8618–8627 | 5964–5973 |
| Rendered primitives/window median (includes shadow passes) | ~10.15million | ~5.48million |
| Median of six client-window p50s | 1115.356ms | 1052.643ms |
| Median of six client-window p95s | 1221.997ms | 1170.258ms |
| Full-Town shadow casters | 4709 | 2218 |
| Full-Harbor shadow casters | 361 | 206 |

Draw work drops about31% and shadow-inclusive primitives about46%; this is a
repeatable work reduction. Timing improves modestly and overlaps run variation:
do **not** claim a reliable5.6% FPS gain,60FPS, heat reduction or resolved owner bug.
Large buildings, trees, roofs and cover still cast. Only authored detail boxes/
ellipsoids with longest dimension≤1.25m or middle dimension≤0.22m stop casting;
they remain visible, lit, weathered and physically unchanged. No dynamic object,
player, warning, collapse ownership, material or server cadence change.

Full geometry/transform/collision-array hashes match baseline:
- Toy Town4709 meshes/2173 collision shapes:
  `0bbc33e00ac80ac227cb4df6d16d10cbf70e245b9134d8d4aded4176ae3cb044`.
- Harbor361 meshes/142 shapes:
  `af7e23600494b6a3da7c5350fe8802eb35d5dc9ab18a1a5115f226b2f11afca3`.

Street/facade/overview720p plus street/Harbor1080p rendered and inspected; broad
shadows and geometry remain. Sidewalk streaks appear in both baseline/candidate,
not a new policy artifact. Temporary capture map-switch teardown retained2–4
ObjectDB instances/1–2 resources on both builds; no clean-shutdown claim. Strict
profiler logs have no SCRIPT ERROR/ERROR. Map/weather/collapse/network staged
regression is required before this candidate is committed as a runtime fix.
Raw traces/fixtures/logs: `.amp/in/artifacts/phase19-shadow-validation.tar.gz`.

### Shared-helper review and current follow-up

The first candidate above also suppressed crate shadows because moving crates use
the same detail builders. Its statement that dynamic presentation was unchanged
was too broad. The follow-up walks ancestry and retains casting below rigid,
animatable and character bodies and breakable structures. The public map regression
fails on the previous candidate for all three crates on each map, then passes89
checks with the guard. No gameplay physics changes. Both geometry/collision hashes
above still match; current casters are2233 Town and221 Harbor.

Serial guarded rerun: same12/60×3 two-renderer720p software-render conditions,
draws5999–6004 and shadow-inclusive primitives5.5461–5.5463million. Median of six
client-window p50s1000.493ms/p95s1079.257ms. This source also contains the roster
cache below, so this is not an isolated shadow CPU/FPS attribution; draw work is
still about30% below baseline, not a hardware smoothness or temperature verdict.
All five final render views inspected again. Raw traces:
`.scratch/phase19-shadow-guarded-after`.

Roster presentation caches copied visible scalar values, not the mutable input
Dictionary. Name/readiness edits, owner/local identity, owner label, sorted index,
departure and identical-value rejoin invalidate correctly. Existing integration
now passes132 checks. Serial5×500 synchronous-call medians (deferred layout
excluded) for2 rows:0.049962→0.002036ms;20 rows:0.519114→0.015434ms. This is
avoidable UI work, not proof that the roster caused in-match frame drops.

Tracer now accepts2/4/8/20 real clients and up to4 renderers; default remains2.
Four-client real input/authoritative movement and default two-client repeat
contracts pass (4 tests total). It remains an editor-engine diagnostic.

Previous candidate's normal staged gate passed60 suites,7 network matrices,
managed20 clients/five rematches and46 Python tests, then committed/pushed.
Guard/roster follow-up also passed the same broad gate (46 Python tests) and
was committed/pushed as `b021446`; neither unit was deployed or released.

### Network CPU hooks and stable Rain/Snow controls

Private profiler Main subclass calls production methods unchanged and times
snapshot assembly, match/movement apply and whole Main physics callbacks. Raw
per-interval counts/times are summed into summaries; movement receipt age uses
the same process clock. It is not pending reconciliation age/correction distance,
end-to-end latency or packet loss. Variant-encoding the decoded match Dictionary
measures payload representation size, NOT on-wire bandwidth; this extra encoding
is outside the apply timer but remains profiler CPU/frame cost. Older uninstrumented
timing traces are not interchangeable with these new traces.

`--weather dry|rain|snow` defaults dry. The external fixture starts normal
precipitation, holds its lifetime, saturates the starting field and requires
replicated agreement plus unchanged precipitation/district state for every sample.
No production RPC, scheduler, warning or match-duration behavior changes.

Executed4-client moving Rain:120 warmup/600 samples×3,15 traces/9000 records,
headless source, client cap60/authority0; physics59.915–60.147Hz. Per-receipt mean
match apply3.078–3.208ms, movement apply30.76–34.93µs, authority build146–161µs;
mean decoded match representation2040–2140 bytes/receipt. This identifies CPU cost
without pretending a render/thermal verdict. Exact public-PCK/editor-engine
Snowfall90-sample smoke passed. Four contracts cover default dry repeats,
four actual moving Snowfall clients and raw-to-summary counters.

### Eliminate alpha-zero dry weather passes

Confirmed a second rendering hotspot: every world mesh retained its weather
material overlay even when the shader's output alpha was zero. Removing only
fully dry overlays in an independent scratch ablation reduced work and time
beyond these runs' variation. Same source/instrumentation,2 actual renderers,
720p/llvmpipe/LP_NUM_THREADS2, serial12 warmup/60 intervals×3 per configuration:

| Metric | Existing dry overlay | Scratch ablation | State-aware production candidate |
| --- | ---: | ---: | ---: |
| Median draws/window | 5998–6004 | 4089–4104 | 4089–4098 |
| Median six-window p50 | 1024.320ms | 650.993ms | 659.972ms |
| Median six-window p95 | 1104.888ms | 719.916ms | 732.521ms |
| Individual-window p50 range | 1017–1032ms | 630–662ms | 641–667ms |

About32% fewer draws and36% lower median frame interval relative to the already
shadow-optimized dry control, on this software renderer only. No native GPU60FPS,
temperature or owner-bug-resolution claim. All windows retain the intact map.

The candidate weakly tracks registered meshes, switches only at dry/wet boundaries,
keeps overlays through snow/melt/flood/covered residual moisture, enrolls newly
created terrain, clears on rematch and does not retain freed map geometry. Geometry,
colliders, gameplay weather state, shader, particle count and warnings are unchanged.
Existing graphical weather lifecycle test fails3 dry/reset assertions on the prior
source and passes49 checks now; headless weather41 and4 profiler contracts pass.
Town/Harbor geometry/collision hashes remain unchanged.

Actual dry/rain/snow/melt/recovered renders inspected: overlay counts
0/4709/4709/4709/0, versus4709 in every baseline state. The upper1280×470 static
architecture/weather region is pixel-identical before/after in all five states;
full-image differences are confined to the naturally animated avatar. Existing
bright snow and subtle wet sheen are retained, not redesigned by this optimization.
Final captures: `.amp/in/artifacts/phase19-weather-overlay/`. Normal staged gate
passed60 suites/7 matrices/managed20/five rematches and46 Python tests; committed
and pushed [dry-overlay optimization](https://github.com/phucle297/idunno/commit/4b95c1d9843a6bf193a3112e26e7489c542b4e3f).
Source remains unreleased and undeployed. Earlier pending statements are
chronological checkpoints superseded by this delivery, not current gate failures.

Four actual headless clients passed90 consecutive600-frame Rain/moving
windows in one room, client cap60/authority0. Buffers clear between windows, not
the scene/weather. The fixture restores intact terrain/input phase per window;
this is sustained room operation, not an uncontrolled16-minute match.967.495s wall
time,450 traces/270000 intervals, all rosters/ACTIVE/weather intact, clean logs and
normal shutdown. An external scratch sampler collected only UDP/IP lengths
(no payload retained),5s process RSS, and kernel capture-drop counters; exclude
the first60s from trends. Its separate
known-size loopback control passed2 datagrams/216 IPv4 bytes/160 UDP payload bytes,
without counting the outgoing duplicate. Capture reported0 kernel drops and0 IPv4
fragments, not proof of network transport loss/reconciliation correctness.

Interior60..840s aggregate authority→4 clients:148555244 IPv4 bytes/140704968 UDP
payload bytes; reverse14524295/8392855. These include all ENet traffic and are not
per-RPC attribution or Ethernet bandwidth. Client physics59.996–60.155Hz; sampled
authority windows59.903–60.243Hz. Uncapped authority600-frame windows span less wall
time than the capped clients; do not label its CPU trace as continuous16-minute.
RSS first/last-minute medians269.22–269.27→270.25–270.30MiB per client and
247.78→247.78MiB for authority. Full reduction passed: all4 client node counts
remain11646; authority11014. After the first6 windows, client window-start/end
allocator ranges173.16–174.18/175.17–176.20MiB, authority151.96–151.97/154.64–154.65.
This is a bounded profiler-buffer/cache plateau, not a zero-allocation claim.
Local RTT p95=13ms, pending input count≤5; not Internet/loss/reconciliation proof.
Mean Main physics callback330–339µs/client,643µs/authority; full match apply
3251–3288µs/receipt. Instrumentation costs remain included.

Final graphical controls also passed strict logs/intact-world/weather checks:

| Actual2 renderers | Warmup / intervals × repeats | Six-window median p50 / p95 | Draw medians |
| --- | --- | --- | --- |
| Harbor Snow1080p | 120 /600 ×3 | 495.666 /548.217ms | 892–896 |
| Town Rain720p | 12 /60 ×3 | 1040.101 /1114.913ms | 6045.5–6050 |

These are workload controls, not matched quality settings between maps or native
performance passes. Town's60-interval windows are bounded software-render smokes,
not reliable tail-statistic estimates. Full raw traces stay in ignored scratch;
compact [final evidence](final-controls.json) records source identity and results.
All run on this software-render orb; none establish native temperature/60FPS.

### Exit disposition and Phase20 trial ceilings

- M19.1: confirmed orb render bottleneck and ranked attribution; the owner's
  machine-specific thermal/FPS cause remains unclassified. No invented native repro.
- M19.2: isolated tiny-detail shadow and dry-overlay work reduction; roster cache;
  same geometry/collision hashes, inspected renders, old-source regression failures,
  normal staged60 suites/7 matrices/managed20/five rematches/46 Python tests passed.
- M19.3: real2/4-peer weather controls,16-minute4-client room/resource/wire baseline,
  broad rematch regression and the following conservative incremental ceilings.
  Native p95≤16.67ms remains unverified, not passed or erased by phase closure.

First-slice trial:1 held slot/player;≤2 projectiles/player and≤4 globally (NOT12);
≤6 placed/warning effects with rocket warnings reserved before firing; no new
loose rigidbodies; all future dynamic props share the existing32-body ceiling.
No cosmetic physical fragments or new shadow-casting light. Target≤64 additional
draws/client,≤0.5ms incremental mean authority-physics and match-apply CPU,
≤25% additional aggregate IPv4 traffic versus a matched4-peer workload and bounded
resource plateaus after cleanup. These are **acceptance ceilings to test**, not
measured toy capacity or native headroom; later batches cannot raise concurrency
until their own matched controls pass. Reduce effects/concurrency on failure.
Keep ordinary weapon control loss≤1s and shared post-hit/recovery protection≥1.5s;
prefer displacement with no routine stun or direct weapon HP damage in first slice.

Hardware/physical focus/minimize, separate-device/server/network, unchanged release
template profiling, native60FPS/VRAM/temperature and precise loss/reconciliation
acceptance remain open under the existing waiver. Expanded Home/Outfits, mixed
hazard/collapse/ragdoll performance attribution below is unexecuted follow-up,
not evidence of a remaining diagnosed hotspot; functional coverage is in regression.
No server tick/send reduction, forced cap, quality downgrade or map-detail deletion.

## M19.1 — Reproduce and attribute the cost

- [x] Complete bounded orb real-process dry diagnostic and single-change ablations;
  retain failed attempts, raw numbers and explicit hardware/sample limitations above.
- [x] Add reusable source/exact-PCK editor-engine tracer, chronological samples,
  independent client cap/authority cadence and real-client repeated-run contract.
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

- [x] Select interventions from M19.1 measurements, not all candidates at once.
  Measure each independently before combining; retain before/after traces.
- [ ] If pacing is the cause, trial configurable60FPS default and optional lower
  background presentation rate. A simple Engine.max_fps cap can also delay the
  main loop/ENet: measure actual physics cadence, prediction, polling and timeouts.
  Keep server simulation/network service cadence intact; focus return must recover
  camera/input without stuck keys or authority gaps. Dedicated stays unaffected.
- [ ] If rendering dominates, budget shadows/lights, distant animation/cosmetic
  effects and inactive viewports; try resolution/quality controls with honest visual
  tradeoffs. Never hide warning hit footprints, real cover, route geometry or peers.
  Scope candidates to `_add_detail_box`, `_add_round_detail` and repeated trees/trim;
  keep batch ownership within collapse districts after `town_partitions.partition`.
  Exclude breakables, moving mechanisms, props and players from static batching.
  Preserve material/transform/visibility and district removal; mesh caching alone
  does not batch draws. Compare the same camera and inspect close/distant renders.
  Run map-detail collision, town-layout, route-clearance, weather-cover and collapse/
  mechanism regression: shadow/visual optimization must not change physics or roofs.
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
- [x] Run normal staged regression and inspect representative render/quality states
  for visual changes. Record evidence and physical-device limits separately.
- [x] Establish recorded CPU/network/visual baselines and conservative incremental
  trial budgets for Phase20 as qualified above. Native headroom is unknown; no
  budget increases solely because a synthetic headless run passed.

Exit: recorded baseline, verified improvements or explicit blockers, regression
results and budgets. Package/release/deploy requires separate delivery authorization.

No new hardware/infra provisioning, no blanket map-detail removal, no claim that
heat proves a networking bug. Human feedback remains under the existing waiver;
see [NEED_REAL_CHECK](../../../NEED_REAL_CHECK.md).
