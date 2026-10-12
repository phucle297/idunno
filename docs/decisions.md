# Disaster Party — Active Decisions

Phase 6 cosmetics remain planned, not started. Root [progress](../progress.json)
owns the current state; [its checklist](checklists/phase-6-cosmetic-loot-box-drops-and-customization.md)
is the future scope, not evidence of implementation.

The completed [Phase 5 validation follow-up](old-docs/phase-5-validation-followup/decisions.md)
preserves audit reconciliation and delivery decisions. [Its evidence](old-docs/phase-5-validation-followup/progress.json)
qualifies earlier scale, performance, human acceptance and deployment claims.
No new-phase implementation decisions or validation results exist yet.

## 2026-10-12 — Authorized deployment and GitHub pre-release

Owner explicitly requests deployment/release of completed important work. Dispatch
the existing main-only EC2 workflow for source `bd3b606971ce9cf5470e03c5945d229052eb5ddf`;
retain infrastructure, room count and player-limit configuration. [Deployment](https://github.com/phucle297/idunno/actions/runs/38272856925)
passes source regression, repeated Linux exports, standalone lifecycle and SSM backend
verification. Windows is exported twice from that same revision; its PCK is identical
to the exact CI Linux artifact deployed. Archive/tag/download hashes are verified.

Publish [Phase 5 Hardening Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-12-bd3b606)
as a GitHub pre-release, not Steam or a production-readiness claim. Two exact-PCK
Linux editor-driven clients passed public HTTPS tickets, ENet admission, roster,
Ready/Start, remote-authoritative movement and owner transfer (RTT sample104ms).
Both share one orb/upstream; native Windows, separate-network human sessions,
real-GPU and physical audio remain unverified. Keep earlier evidence unchanged.
Phase 6 remains planned. Delivery metadata in root progress is separate from its
empty implementation validation log. Subsequent tracking commit skips CI to avoid
an extra deployment of documentation-only changes.
