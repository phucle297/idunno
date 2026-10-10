# Disaster Party — Active Decisions

Root [progress](../progress.json) owns active state; the [Phase 4 checklist](checklists/phase-4-disaster-remix-and-toy-town-interaction.md) owns the detailed plan. Prior decisions and evidence remain in the [Phase 3 archive](old-docs/phase-3-player-caused-chaos/decisions.md) and the [Phase2 suspended snapshot](old-docs/phase-2-human-playtest-and-core-feel/decisions.md), not a completed-phase claim for Phase2.

No Phase4 implementation decisions yet; work is paused for the owner's Phase3 self-check (2026-10-10).

## 2026-10-10 — User-requested Phase 3 follow-up

Historical Phase 3 evidence remains unchanged. This follow-up reviews its completed mechanics, not Phase 4 implementation.

- Shove reach now checks the existing 2.2m range in three dimensions before the horizontal facing cone. The original code zeroed vertical offset first and accepted a target 6m above the grounded sender with clear sight. Ground and ramp shoves retain a horizontal-only bounded impulse; no new tuning parameter is needed.
- Accepted shove replication sets the shover's cooldown in the shared effect application path, after sequence validation. Previously only server requests set it, leaving client feedback at READY; rejected/duplicate effects do not renew cooldown. Real ENet coverage now asserts the observer receives it, and the rendered fixture uses the actual replicated cooldown rather than a fixed sample value.
- Emote start/cancellation queries held ownership as well as the medium carry flag. A 4kg held prop has no speed penalty but still occupies the player's hands; acquisition must cancel an emote and holding must reject a new one. Release restores availability. The authoritative GrabManager remains the ownership source of truth.
- New assertions fail before the fixes and pass afterward: `SHOVE_OK checks=70`, `EMOTES_OK checks=55`. Broader follow-up evidence and environment limits are recorded in root `progress.json`; no deployment or publication is authorized.

Follow-up complete: final 38-suite/five-network-group regression, 1/2/4 chaos scenarios, five rematches, requesting-client cooldown under delay/jitter/loss, isolated four-player managed lifecycle and actual Linux release lifecycle pass. Two exports per target are byte-identical with matching client/server PCKs; refreshed local bundles are in `.amp/in/artifacts/phase-3-recheck-packages/`. Inspected 720p/1080p cooldown captures show `SHOVE 2.0s` from the accepted replica, not a synthetic sample.

Keep the limits explicit: the orb's software-rendered throughput still misses 60FPS (frame p95 76.56/147.94ms at 720p/1080p), although overlap physics p95 is 1.05/1.31ms. The first concurrent managed run missed the physics gate; the unchanged isolated four-player rerun passes (10.370/6.129ms), without proving a specific cause for the earlier miss. The eight-player diagnostic fails room creation with HTTP503 and the twenty-player diagnostic retains its snapshot-MTU failure; neither expands support beyond four. Native Windows, hardware-GPU/display pacing, physical audio and Internet/human feel remain unverified. Phase4 stays paused.
