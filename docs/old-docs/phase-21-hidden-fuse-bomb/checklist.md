# Phase21 — Hidden-fuse bomb

Owner authorized implementation after narrowing the plan to the bomb only.
All other Phase21 gameplay and UI/UX proposals are removed, not backlogged here.
DESIGN.md remains authoritative except for the explicit hidden-timing rule below.

## Contract

- Optional **Hot Potato** lobby preset for 2–20 players, with Normal disaster
  pacing. Normal/Hard and their existing 16 toys stay unchanged. Solo has no bomb.
- One global toy parcel, separate from personal toy slots. F collects it from
  authored, supported safe ground; a carrier's left click attempts a visible,
  short analytical throw. Personal toy firing resumes when no longer carrying.
- Server samples a private random 5–15 s fuse once when collected. Values are
  initial tuning, not measured balance. Passing, missing or dropping on death
  does not reset/reroll/extend it. Idle uncollected parcels have no running fuse.
- Deadline, duration and RNG seed/state never enter client snapshots/logs. No
  countdown, changing tick rate, age bar, flash acceleration or timing hint.
- **No recipient grace or final transfer cutoff.** Receiving and immediately
  exploding is intentional and accepted. One deterministic server event order
  resolves expiry/transfer; clients cannot backdate intents or choose victims.
- Short throw is swept against real world geometry/players; nearest obstruction
  wins. Miss/block returns possession to the thrower without changing fuse.
  A constant carrier danger ring communicates area, never time remaining.
- Burst is one capped horizontal impulse through existing shove/toy protection
  and credit, no direct HP damage or forced ragdoll. Environmental deaths remain
  possible. Respect cover, vertical separation and immunity; no through-wall force.
- Death/departure drops at validated nearby actual support with the same fuse;
  if no valid support exists, cancel visibly. Never bridge a void, create a new
  escape route or force a replacement after match end. Cancel submerged/unsupported
  ground parcels; suppress new spawns as safe terrain shrinks.
- Clear on lobby/results, mode/map/session change and rematch. Reject stale-round,
  duplicate, malformed, out-of-range, dead/ragdolled and spam intents. No new loose
  rigidbodies. One parcel/flight and one short burst visual; pooled presentation.

## Milestones

### M21.0 — Narrowed contract
- [x] Remove all rejected proposals; record bomb-only scope and owner timing rule.
- [x] Inspect preset, session snapshot, toy input/impulse and map-support contracts.
- [x] Validate tracking and commit/push narrowed plan before implementation.

### M21.1 — Playable authoritative bomb
- [x] Independent bounded bomb controller, private randomized fuse and safe state.
- [x] Lobby preset, Main lifecycle/input/snapshot integration and existing credit.
- [x] Pooled toy-plastic parcel, constant ring, readable carry/pickup/throw cues
  and bounded local pickup/pass/burst audio without timing disclosure.
- [x] Focused public-behavior tests including immediate-receipt explosion, privacy,
  miss/cover, duplicate/old-round requests and departure/reset/support boundaries.

### M21.2 — Integrated validation and delivery
- [x] Real client pickup/throw/receive/burst/state replication and five rematches.
- [x] Both-map, 2/4/8/20-player controls and bounded snapshot/performance evidence.
- [x] Render and inspect ground, held, throw, burst and lobby selection states,
  reduced motion and 720p/1080p where relevant. No timer-visible presentation.
- [x] Run normal staged regression, inspect diff, record evidence; commit/push.

Source delivery: [bomb implementation](https://github.com/phucle297/idunno/commit/cce0b84ec8193d183787a052c408ef3afd59d1e2)
and [solo-selection correction](https://github.com/phucle297/idunno/commit/469ea77d4579af5d1c2076010ab04fe3636dfb37)
are pushed with deployment skipped. Full normal hook passed65 Godot suites,
9 network matrices,20 managed clients,settings restart and46 Python tests.
The correction independently passed its normal56 affected-test gate,including
both-map4/8/20 bomb replication,5 rematches and33 startup assertions. The solo
regression failed without the fix and passed afterward; actual Choose Map render
was inspected. Native hardware/audio/human acceptance is not inferred.

Implementation is authorized; a new public release/deployment is not part of this
request. Preserve the existing public build until separately authorized. Native
Windows/GPU/audio/thermal feel and human fun remain unverified under the existing
waiver; do not add new mandatory human checklists or claim those outcomes passed.
