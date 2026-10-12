# Disaster Party — Active Decisions

Root [progress](../progress.json) owns active state; the [Phase 5 checklist](checklists/phase-5-session-distribution-and-release-readiness.md) owns the detailed plan. Prior decisions and evidence remain in the [Phase 4 archive](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md), the [Phase 3 archive](old-docs/phase-3-player-caused-chaos/decisions.md) and the [Phase2 suspended snapshot](old-docs/phase-2-human-playtest-and-core-feel/decisions.md), not a completed-phase claim for Phase2.

## 2026-10-12 — Bounded joins and checked playtest exports

Owner's “Continue implement” starts Phase 5 milestone 5.1. Reuse the existing room admission deadline in `join_game` for every client connection, including direct-IP and launcher joins. Both transports must appear in the authoritative roster within 10 seconds; a transport handshake alone is not admission. Recovery remains mode-specific (fresh ticket for rooms, address retry for direct IP), clears remote state and restores one offline player. No new timer subsystem or timeout setting is needed.

The exporter now invokes the existing artifact verifier after writing checksums, before its success marker, so missing payload entries, hash mismatches or development-path leaks cannot silently pass an export. Windows native runtime and physical-session acceptance remain separate checks. Keep capacity at four; commits use `[skip ci]` to avoid the main-branch deployment workflow because this request does not authorize deployment.

## 2026-10-12 — Responsibility-based script folders

Owner explicitly requests the proposed folder-only refactor before continuing Phase 5. Move six player/controller/interaction scripts to `game/player/`, seven director/hazard scripts to `game/disasters/`, and four match/room/spectator scripts to `game/session/`; preserve existing `game/ui/` and root orchestration/standalone scripts. Move all 17 `.gd.uid` files unchanged. Update runtime, scene, test, generator and current asset-provenance references; refresh the character scene's manifest checksum because its script path changed, not its geometry or animation. Historical progress and archived documents retain their original paths as evidence for their original revisions. Do not split `main.gd`, change behavior or reorganize assets/scenes/tests in this work unit.

## 2026-10-12 — Native Windows package failure gate

Extend the existing package runner rather than create another harness: run the exact release EXE headlessly, then settings/recovery/room UI and five-rematch fixtures through the matching native editor with the shipped PCK. No runtime code or payload changes are needed; reuse verified build `e2ede19`. Ticket-validation fixtures must use the payload's build ID except in deliberate mismatch cases, so invalid fields are not masked by an earlier build rejection. Capture both direct-IP and room admission timeout recovery. Label service-response injection, actual local ENet transport, release headless startup and physical-session acceptance separately. Task5.1.2 and milestone5.1 technical gates pass; advance to the known intermittent 20-player movement investigation without increasing supported capacity or claiming human/Internet acceptance.
