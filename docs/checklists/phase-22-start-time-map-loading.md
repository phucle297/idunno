# Phase22 — Start-time map loading and app hardening

Owner scope: fix map-selection stalls; after that, fan out whole-app checks and
perform justified refactoring/optimization. DESIGN and existing game rules stay
unchanged. Source delivery is commit/push per coherent validated unit, not deploy.

## M22.1 — Metadata-only selection

- [x] Normal Home startup has no gameplay map geometry.
- [x] Solo/room map selection and replicated lobby selection do not build/delete
      gameplay geometry. Selection does not start time, physics or hazards.
- [x] Start loads the selected map, wires hazards/terrain/weather and seats players.
- [x] Same-map rematches restore mutable state without rebuilding static geometry.
- [x] Existing gameplay fixtures explicitly prepare their world; startup/map tests
      assert the new public lifecycle rather than preserving the previous bug.
- [x] Re-run the production selection measurement and focused controls.

## M22.2 — Multiplayer loading barrier

- [x] Authority requests loading only on accepted Start and freezes lobby changes.
- [x] All registered peers acknowledge the current load before ACTIVE/time/hazards.
- [x] Stale/unregistered replies, late joins, departure, timeout and disconnect
      cannot start a partial/stale session or leave a permanently locked lobby.
- [x] Real ENet map switches and rematches pass on both maps.

## M22.3 — Whole-app audit and integration

- [x] Fan out independent UI/session, authority/network and gameplay/performance
      audits after the loading fix. Review returned evidence before accepting fixes.
- [x] Reproduce concrete findings, fix/refactor narrowly and retain regression tests
      for user-visible contracts. No broad rewrite or unsupported FPS claim.
- [ ] Normal staged regression gate passes; inspect affected rendered UI states.
- [ ] Record findings, unresolved native/hardware checks and actual source delivery.

Native Windows/GPU/thermal and human feel remain unverified, not automated passes.
Existing acceptance waiver is preserved in NEED_REAL_CHECK.md and root progress.
