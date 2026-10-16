# Phase12 historical decisions

## Phase12 — Movement drops

Owner continuation2026-10-15 activates the existing Phase12 plan. Phase11's
[decision log](../phase-11-meteor-terrain-collapse/decisions.md) and
[evidence](../phase-11-meteor-terrain-collapse/progress.json) remain archived.
Root [progress.json](../../../progress.json) owns current state.

- Collection is automatic authoritative proximity plus line of sight, with closest
  then peer-ID arbitration. There is no client claim RPC to forge or replay.
- A dedicated round counter covers offline and profile-disabled rooms; the cosmetic
  reward counter only advances for profile-enabled rosters and is not suitable.
- Drops use authored reachable anchors, real floor/clearance queries, reserved-route
  exclusions and current hazard/terrain state. Failed spawn slots are skipped, not
  accumulated into a later burst. Gameplay defaults remain provisional.
- Movement reconciliation rewinds the remaining buff duration with the acknowledged
  position before replay; the slower match snapshot owns HUD/drop presentation only.
  Round-qualified movement rejects packets from another round. Joining/hosting a
  new room resets the ordering scope so an old room's rematches cannot block updates.
- Pickup presentation uses six nonphysical pooled tokens, names plus symbols and
  existing quiet synthesized audio. Optional bob respects reduced motion; warning
  voice always takes priority. Measured204 mesh triangles/token excludes engine text.
- Forced20buffs+6drops remain within the existing snapshot fallback, not a new
  transport budget: Town4324B/Harbor4148B versus empty2100B/1924B. Measured server
  tick p95 is219us/197us on this Linux orb; this is not a GPU/60FPS claim.
- The first cold soak included lazy result-table allocation and transient director
  effects. Warm results once and clean the director each cycle before comparing:
  eight rematches/map then retain zero node/orphan growth. No leak suppression.
- Source delivery uses skip-CI; Phase11 remains the public release. A worker's
  premature fixture-only push triggered workflow38783520114, which was cancelled
  before deployment completed. Preserve history and complete dependencies in the
  normal staged-test gate; do not reclassify that cancelled run as a pass.
