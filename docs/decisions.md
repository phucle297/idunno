# Disaster Party — Active Decisions

Root [progress](../progress.json) owns active state; the [Phase 5 checklist](checklists/phase-5-session-distribution-and-release-readiness.md) owns the detailed plan. Prior decisions and evidence remain in the [Phase 4 archive](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md), the [Phase 3 archive](old-docs/phase-3-player-caused-chaos/decisions.md) and the [Phase2 suspended snapshot](old-docs/phase-2-human-playtest-and-core-feel/decisions.md), not a completed-phase claim for Phase2.

## 2026-10-12 — Bounded joins and checked playtest exports

Owner's “Continue implement” starts Phase 5 milestone 5.1. Reuse the existing room admission deadline in `join_game` for every client connection, including direct-IP and launcher joins. Both transports must appear in the authoritative roster within 10 seconds; a transport handshake alone is not admission. Recovery remains mode-specific (fresh ticket for rooms, address retry for direct IP), clears remote state and restores one offline player. No new timer subsystem or timeout setting is needed.

The exporter now invokes the existing artifact verifier after writing checksums, before its success marker, so missing payload entries, hash mismatches or development-path leaks cannot silently pass an export. Windows native runtime and physical-session acceptance remain separate checks. Keep capacity at four; commits use `[skip ci]` to avoid the main-branch deployment workflow because this request does not authorize deployment.
