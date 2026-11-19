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

## T3 — harder disasters, break rooftop camping (2026-11-15)

Recorded by idunno-T3j (docs only) on the T3c-integrated branch `1d70659b`. Coverage and Volcano gameplay changes listed below are specified by the plan and contracts; they are **pending T3z** until independently QA-verified on an integrated branch. This page does not invent gate numbers.

### Owner goal (2026-11-15 15:59 UTC+7)

Quoted from `games/idunno/T3-plan.md:6` (labeled there “verbatim sense”; factory `log.md` has no separate 15:59 Owner line):

> the game gets boring because standing on a rooftop dodges most disasters.

T3 exists so rooftops must not dodge most disasters.

### Owner-accepted defaults (now in force)

Quoted from `games/idunno/T3-plan.md:8–14`, which cites `games/idunno/pm-review.md` §4 (lines 104–107) as the source of the defaults:

> - Delete Normal.
> - Current Hard gap scaling becomes the only survival baseline; Hot Potato stays a rule variant on that baseline.
> - Record a baseline first.
> - Use the provisional T3 numbers in `acceptance-T2-T3.md` §2.3.
> - Keep meteor warning lengths (live **2.5 s**; do not shrink toward the 1.2 s DESIGN floor).

**Normal removed; Hard is the baseline (T3c).** On this branch, `MATCH_PRESETS` is `["hard"]` in the director and `["hard", "hot_potato"]` in `main.gd`; default `match_preset` is `"hard"`; `request_match_preset("normal")` is rejected; leaving Hot Potato in solo falls back to Hard. Hot Potato remains a 2+ lobby variant on that Hard director pacing (`hard_pacing_scale = 0.6`; late Hard gaps stay 1.2 s recovery / 2.4 s overlap). T3c commit `1d70659b` was independently QA-passed (factory log 2026-11-15 19:34 UTC+7). Player-facing GUIDE no longer lists Normal as a selectable preset.

### 19:10 floor ruling — Volcano is ground-only

Owner ruling, 2026-11-15 19:10 UTC+7, quoted from `games/idunno/T3-plan.md:229` and `:350` / `:462` (factory `log.md` 2026-11-15 19:10 summarizes the same call):

> Only floor, but larger. Maybe can the whole map.

Rooftop ash was rejected. T3p turns Volcano into a **ground-only, whole-map spreading lava flow**: a twelve-second warning, then lava spreads from the authored vent across the map floor; roofs and elevated pads stay safe. Player-facing copy says **get to high ground** (a roof, terrace, or dock), not “leave the outlined district.” GUIDE.md was updated against T3p commit `87c7826` (not merged into this T3j base). Volcano gameplay and HUD/context copy (T3p / T3s) remain **pending T3z**.

### Numeric product gates

Quoted from `games/idunno/T3-plan.md:38–49` (Owner-accepted provisional set; measured first on current Normal and Hard by T3b/T3bQ, then after implementation on the Hard-only baseline by T3z):

> | Gate | Number | Notes |
> | --- | --- | --- |
> | Matrix | **10 seeds × 2 maps** (`toy_town`, `toy_harbor`) | Publish the seed list in the harness. INFERRED seeds if unset: `101`–`110`. |
> | Controls | Rooftop idle; rooftop tiny-step; ground idle; active route | Same scripts before/after. |
> | Dead time | Median time with **zero** active disasters during **2:00–8:00** drops **≥ 30%** vs current **Normal** | Hard-only after T3c should already cut gaps (`hard_pacing_scale = 0.6` in `disaster_director.gd`). Still measure. |
> | Rooftop camp | Broken on **≥ 8 / 10** seeds **per map** by **6:00** | “Broken” = forced off the starting roof sector for **≥ 3 s** and/or **≥ 30 HP** lost. Elevation may still help versus **Flood**. |
> | Active route | Survive to **≥ 8:00** (or timeout) in **≥ 6 / 10** seeds **per map** | Beatable floor, not a human-skill claim. |
> | Fairness | Meteor warning stays **2.5 s**; no intensity-scaled damage/forces; max two overlaps; solo-first intro; at least one escape; Rain/Snowfall do not penetrate roofs | Director policy “faster, never meaner.” |

T3b/T3bQ produce the before-numbers only and do not have to meet the harder gates (`T3-plan.md:51`). Official after-numbers and pass/fail are **pending T3z**.

### Per-disaster rooftop pressure (as designed in the plan)

All of the following except T3c and the already-recorded T3bQ Earthquake finding are **pending T3z** (not integrated into this branch; maker-only deliveries must not be treated as shipped):

- **Meteor (T3d, `T3-plan.md:125–127`):** occupy a meaningful roof sector with warned, finite, multi-pulse footprints so a camper cannot tiny-step around one small mark; warning stays 2.5 s; players under a static roof stay sheltered.
- **Lightning (T3e, `T3-plan.md:137–139`):** prefer exposed elevated campers (open sky) with the existing 2.0 s telegraph; do not strike through solid overhead cover.
- **UFO carry (T3o, after T3f targeting; `T3-plan.md:307–308`):** during the active beam, carry an exposed rooftop idle camper sideways off the pad (or they take existing fall damage from that drop). A vertical lift that lands back on the same pad is not pressure. Indoor / under-roof players stay untargetable; walk out or take overhead cover still releases.
- **Bee Swarm (T3g, `T3-plan.md:161–163`):** standing on a roof is not shelter; an exposed roof target can be stung. Players under a real roof or indoor volume stay protected.
- **Tornado carry (T3q, after T3k lane bend; `T3-plan.md:371–373`):** an exposed rooftop idle camper must leave the pad or take attributed fall damage. Knockdown or a landing on the same pad is not pressure.
- **Rockslide lane (T3r, after T3m climb; `T3-plan.md:401–403`):** the warned corridor must actually cross an occupied, exposed real-map roof; cover still blocks; rocks travel only the published lane.
- **Earthquake:** not a designed gap. T3bQ already measured rooftop pressure (`T3-plan.md:77`: “Earthquake is not a gap (47/39 HP and 3/1 kills on roofs)”). No T3 contract changes quake.
- **Flood / Rain / Snowfall excluded by design (fairness, T3h, `T3-plan.md:173–175` and `:225–228`):** the roof is the authored Flood counter; Rain and Snowfall do not penetrate roofs. A 0 HP / 0 relocation roof cell for these is not a T3z fail. Fire stays unmeasured in the baseline (no Fire contract in this plan).

### T3z pressure definition

Quoted from `games/idunno/T3-plan.md:219–229`:

> A rooftop_idle / tiny-step **camp cell** is **pressured** only if, while shadow-alive and before 6:00, the player takes **HP loss > 0** from that disaster (including fall damage **attributed to it**), **or** is **relocated off the pad**: feet leave the starting pad footprint and land on **lower ground**. **Knockdown, stagger, or a lift that lands back on the same pad do not count** (T3k’s 10/10 knockdown with 0/10 off-pad is not pressure; T3f’s vertical UFO lift is not pressure).
>
> The overall camp-broken gate is unchanged: forced off the starting roof sector for **≥ 3 s** and/or **≥ 30 HP** lost, on **≥ 8 / 10** seeds per map by 6:00. That gate is the match outcome; this definition is how each disaster’s §4 cell is scored.
>
> **Excluded by design** (a 0 HP / 0 reloc roof cell is not a fail):
>
> - **Flood** — the roof is the authored counter.
> - **Rain / Snowfall** — no roof penetration.
> - **Volcano roof cells** — Owner 2026-11-15 19:10 UTC+7: “Only floor, but larger. Maybe can the whole map.” Roofs and elevated pads stay safe from Volcano. **Ground-idle / ground-camp** Volcano cells **should** show pressure after T3p (idle ground HP > 0; a ground bot that reaches high ground in time may survive).

T3n attribution rules for official T3z fields are in `T3-plan.md:231–236`.
