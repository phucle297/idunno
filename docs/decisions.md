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
