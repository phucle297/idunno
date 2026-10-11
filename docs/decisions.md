# Disaster Party — Active Decisions

Root [progress](../progress.json) owns active state; the [Phase 5 checklist](checklists/phase-5-session-distribution-and-release-readiness.md) owns the detailed plan. Prior decisions and evidence remain in the [Phase 4 archive](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md), the [Phase 3 archive](old-docs/phase-3-player-caused-chaos/decisions.md) and the [Phase2 suspended snapshot](old-docs/phase-2-human-playtest-and-core-feel/decisions.md), not a completed-phase claim for Phase2.

## 2026-10-11 — 5.1a Windows package integrity

- Owner's “Continue work phase 5” lifts the implementation hold, not deployment,
  publication or capacity limits. Keep 1–4 supported players and prior evidence
  gaps/human waiver intact.
- Reuse the isolated committed-HEAD exporter and existing standard-library PCK
  auditor. Make the audit mandatory and require exact platform manifests.
- Ship a plain Windows CMD launcher plus built-in PowerShell integrity check,
  not an installer/account system or new runtime dependency. Include the
  same-revision guide. Verify all six manifest-listed files before starting,
  check directory writability, retain log location and actionable repair text.
  Checksums detect damage/mixed builds, not authenticity; unsigned ZIPs need a
  trusted source. Direct EXE launches deliberately bypass this launcher check.
- Local tests export a disposable scratch-repository snapshot because the
  application checkout remains uncommitted. These artifacts prove packaging,
  not readiness to join an older deployed server (exact revision is required).
  Application changes are neither committed nor pushed; pushing current `main`
  would trigger EC2 deployment, which this continuation does not authorize.
- Next task tests existing room-ID failure/recovery against the exported PCK;
  keep editor-driver automation separate from untouched release-runtime and
  physically separate Internet/audio acceptance.

## 2026-10-11 — 5.1b Exported room failure/recovery

- Reuse the room-UI contract fixture and native package runner. Match ticket
  fixtures to the payload's actual revision; require the intended error text
  and exercise compatible tickets through `RoomClient`, not by bypassing it.
  An exported negative control with the old hardcoded development identity now
  fails seven assertions, rather than silently testing only build rejection.
- Check a fresh lookup and ticket after server loss, including a second failed
  admission returning to exactly one offline player. Preserve the existing
  settings/recovery/five-rematch package gates. No production gameplay changes.
- Separately execute unchanged release EXE requests against synthetic Windows
  loopback HTTP/UDP endpoints. Inspect default, unknown-room, mismatch, invalid
  ticket, timeout and edited-ID retry screens. These establish local release
  failure presentation/request handling, not Internet play or successful native
  re-admission. Dummy audio does not establish physical audibility.
- Temporary native UI automation must target its own cached HWND and capture
  that window only; global input/ambient desktop captures are not reliable
  evidence on a shared desktop. Retain credential-free final logs and inspected
  images; discard failed/ambient captures and temporary fixtures.
- Final distribution still requires an application-repository commit and a
  matching client/server export. Do not mislabel scratch snapshots as shipped
  revisions or push `main` into its automatic EC2 deployment.

## 2026-10-11 — 5.1c Committed-revision local bundles

- Owner's continuation answers the explicit request to commit on a non-deploying
  branch. Use `phase-5-package-hardening`; leave `main` and the public server
  unchanged. No deployment, publication or increase beyond four players.
- Export both targets from the same clean application-repository commit, then
  ZIP only the manifest-listed files and `SHA256SUMS.txt`. Extract each ZIP into
  a fresh folder, audit again, and run release/PCK checks against that extraction.
- Commit subsequent validation evidence separately without changing runtime
  source. Record the exact exported revision rather than pretending the bundle
  includes later tracking-only commits. Keep bundles local and hashes reviewable.
