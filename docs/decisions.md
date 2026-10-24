# Active decisions

## Phase23 — planning checkpoint, 2026-10-23

Owner requests all four concerns planned first, then gradual execution.
Use [the Phase23 checklist](checklists/phase-23-performance-chaos-audio-character.md).
Root `progress.json` owns the next action. No implementation in this checkpoint.

- Performance comes first: total CPU/RAM percentages do not diagnose frame-time
  stalls. Owner hardware: Ryzen AI7 H350/Radeon860M/32GB/Windows11; screenshot
  is hardware evidence only, not a performance trace. Keep device identifiers private.
- Remove Normal entirely during M23.2; do not hide it or keep a compatibility
  branch. Hot Potato remains an optional variant on the harder baseline.
  Increase meaningful movement pressure rather than merely damage/counts or
  attacks through roofs. Decide numeric coverage/pacing after controlled baseline.
- Audio duplicate source remains unverified. Trace event ownership before fixing;
  quieter/softer sound must preserve warning clarity and separate rapid actions.
- Character quality requires a coherent new visual direction and inspected
  motion/outfits, not just more geometry. Concept exploration belongs to M23.4,
  before bulk asset work; retain collision and equipment/network contracts.
- Order M23.1 → M23.2 → M23.3 → M23.4; commit/push verified units. No automatic
  release/deploy or public infrastructure change authorized by this planning request.

Phase22 source work is complete and pushed. Its [decisions](old-docs/phase-22-start-time-map-loading/decisions.md),
[checklist](old-docs/phase-22-start-time-map-loading/checklist.md) and
[full evidence](old-docs/phase-22-start-time-map-loading/progress.json) are archived.
Its subsequent authorized [release/deployment](old-docs/phase-22-start-time-map-loading/delivery-2026-10-23.json)
is complete. Preserve the existing human-acceptance waiver and unresolved native,
thermal/FPS and separate-network limits in `NEED_REAL_CHECK.md`.

## M23.1 — first measured fixes, 2026-10-23

- Planning and new feedback/evidence are in English. Earlier historical user
  reports keep their original wording; no historical acceptance was rewritten.
- Fresh graphical Home used about499MiB RSS with1972 nodes and an empty Sandbox.
  Town gameplay reached830MiB RSS; rotating after60 seconds idle reached868MiB.
  These Linux editor/llvmpipe figures are not Windows private working set or a
  demonstrated leak. Initial stationary samples were isolated; later work shared
  the orb, so later timing is not an isolated throughput comparison.
- A same-scene ablation identified rendering of the retained gameplay world
  underneath opaque preparation pages. With identical retained geometry, Choose
  Map draws fell3621→25 and Home4101→504 (12 sampled frames per state,720p).
  Main now disables only its gameplay viewport while Home/Choose Map occlude it,
  preserving the separate animated preview. It restores the caller's prior state
  at Start/room view and scene exit. No FPS cap, authority or collision change.
  This avoids hidden rendering; it deliberately does not free retained-map RAM.
- A real rendered load exposed weather array errors. Cooperative configuration
  created puddle visuals before their electric state existed; subsequent map
  configuration accumulated old visuals. Validate input first, retire old visuals,
  then reset parallel state before the first frame yield. No index clamp or error
  suppression. The final4→2→4 rendered regression fails against original weather
  source and passes against the fix. Invalid configuration remains atomic.
- Five-cycle headless controls on both maps show stable lobby node/object counts:
  Town11474/20529 with RSS270.67→270.80MiB; Harbor2618/5816 with RSS204.71MiB
  unchanged. This rules out growth in that bounded control only, not a native
  graphical cache/driver leak. Rendered Home/Choose Map captures were inspected.
- Failed validation is retained: the first profiler stopped after an untyped
  dynamic call to `_finish([1])`, so its five-cycle section did not run; the hung
  fixture was stopped after its coroutine failed. The corrected typed fixture
  completed11 stages per map headlessly. Initial regression child counts also
  included128 pooled precipitation nodes; corrected assertions preserve the pool
  and check only replacement growth. Original failure logs remain in `.scratch`.
- M23.1 remains open: two real rendered clients,300-second idle, native1080p,
  focus/minimize/restore, GPU/driver/thermal attribution and the original camera
  hitch are not established as fixed. Do not advance difficulty/audio/art yet.
- Delivery blocker: normal74-root commit gate passed dedicated/four-client/bomb
  network matrices, then managed20 failed cold ACTIVE convergence within15s.
  Authority was ready with18 ACKs outstanding; most clients were still building,
  with306–621ms maximum frames. Cause is unresolved, not automatically attributed
  to the patch or orb capacity. No timeout/prewarm/retry/bypass was introduced.
  Commit was rejected; production/tests remain local and uncommitted. Independent
  managed4 control passed cold Start, movement at all peers, five rematches,
  owner transfer and crash retry; it does not substitute for managed20.
  Map-variety493 also passed. Tracking-only checkpoint may be committed separately
  to preserve this failure, without declaring the runtime work delivered.

## M23.1 — controls and geometry budget, 2026-10-24

- The managed20 cold-Start failure did not reproduce in serialized original-HEAD
  and edited controls: both passed cold Start, movement, capacity, five rematches,
  owner transfer and crash retry. Convergence was 9.218s / 9.015s within the same
  15s deadline. The original failure remains unexplained; no loading workaround.
- The next normal gate exposed a separate profiler lifetime race. Its moving
  client released input at the end of its own trace, before the server necessarily
  sampled it. A controlled 2s observer skew reproduced zero server displacement;
  retaining movement until all observers finish produced 0.925m. Stop through the
  private driver after trace collection, not through a longer timeout or weakened
  movement assertion. The four public profiler tests pass after this correction.
- Add opt-in wall-clock idle and camera orbit to that existing profiler, rather
  than treating a slow SceneTree timer as elapsed wall time. Prepare the rendered
  view before idle; record Linux VmRSS, resource/object counts and renderer memory
  counters with platform limitations. This is diagnostic camera motion, not
  native mouse capture, focus, minimize, Windows private memory or GPU acceptance.
- The earlier rendered Town probe completed all 12 stages. Its internal RSS reads
  were invalid zeros, and its nominal 300s stretched to about 20 wall minutes;
  terrain collapse was not disabled. Keep its timing limitations explicit.
  External RSS rose from 797.28 to 812.09MiB then plateaued, including five Home
  returns. Node/object counts stabilized at 11608/25352 after the first cycle.
  This is bounded-cache evidence, not proof that the owner's hitch is fixed.
- Retain two curved segments per rounded-box edge instead of four: 300 rather
  than 972 triangles, with unchanged dimensions, rounding radii, normals formula,
  materials, collision, anchors and scene-node count. In serialized 720p software
  controls (12 samples after four warmup frames, LP_NUM_THREADS=2), Town submitted
  2,775,112 → 1,211,784 primitives at the same 4039 draws; Harbor's actual player
  camera submitted 621,788 → 239,420 at the same 782 draws. Town p50 was
  844.944 → 466.967ms and Harbor 326.356 → 245.163ms. RSS at gameplay sampling was
  759.63 → 702.96MiB and 581.70 → 523.02MiB. Tiny samples and software rendering
  do not establish native throughput or isolate camera-after-idle hitches.
- Home keeps its live diorama: 399,546 → 206,682 primitives at the same 504 draws;
  initial RSS was about 498.18 → 483.97MiB. Existing sphere faceting is unchanged.
  Both-map geometry and Home were rendered and inspected. The initial Town
  diagnostic camera is unsuitable for Harbor (roof occlusion already existed);
  use Harbor's actual player camera. An initial mislabeled active-map row is
  excluded; the corrected return-to-Results-to-lobby fixture checks the real page.
  Existing Harbor cream-ramp seams are not attributed to this optimization.
- Keep the prepared world for cheap same-map rematches: the measured repeated
  cycles plateau rather than grow. Hidden rendering is now avoided, but retained
  map RAM is intentionally not claimed released. Native/driver causes stay open.
  The full normal staged gate and remaining idle matrix are still required before
  moving to M23.2; no Phase23 release or deployment is authorized.
- Final 1080p Home, Choose Map and both-map gameplay captures were inspected.
  The reduced box curves remain acceptable at gameplay distance. Harbor's
  illegible entrance sign, ramp intersections and tile/channel seams also exist
  in the before control; they are not repaired by this performance change.
- The third full staged gate passed 65 Godot suites, persistence and nine network
  matrices, then failed the held-loading snapshot assertion before managed20 or
  Python suites ran. Source inspection found another observer/lifetime race:
  the departing client could finish its faster load and legitimately abort the
  barrier during the server's 100ms observation. A fast-departure control measured
  loading=false, one remaining player and sequence26→27. This is not evidence of
  snapshots sent while loading stayed frozen.
- Synchronize that fixture with a test-only authority release after the unchanged
  snapshot assertion, then wait for the real transport close before fixture exit.
  Keep production source, real cold preparation and deadlines unchanged. The
  corrected real-ENet matrix passes twice. A disposable negative control removing
  only production's not-loading guard still fails the assertion, demonstrating
  the fix does not mask redundant snapshots. Temporary injection/printing removed.
  Prevention is recorded in `recovering-validation-fixture-races`; rerun the
  normal staged gate rather than claiming the previous failed gate passed.
