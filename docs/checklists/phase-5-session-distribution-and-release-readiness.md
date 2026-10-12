### Phase 5 — Session Distribution and Release Readiness

- Harden the Phase 2 Windows package for release/distribution and add robust failure UX; do not defer the playtest export until this phase.

#### Milestone 5.1 — Windows Package Hardening and Failure UX (in progress)

- Task 5.1.1: bound direct-IP and room UDP joins to 10 seconds until authoritative roster admission; restore offline input and editable retry controls, preserve successful sessions, and export a fresh committed Windows bundle with checksum/PCK verification. Regression: UDP sink before/after deadline, repeated retry, admitted-client control, then supported 1/2/4 network matrices. Package gate: exporter must run `tools/verify_exported_artifacts.py` before reporting success.
- Task 5.1.2: validate the fresh Windows package's failure/retry paths and release-executable startup. Keep external editor-driver checks distinct from release-runtime startup and physical two-PC LAN acceptance; do not infer Internet/session feel from loopback tests.

#### Later milestones (planned)

- Resolve the intermittent 20-player movement failure before expanding supported playtest capacity beyond four. Run37770598203: one client observed unchanged local/host positions while the server reported movement=true and clients=false; cause unverified. Retain full4/8/20 fixture/assertions and diagnostics, reproduce under CI load, fix the proven owner and rerun before claiming scale readiness. User temporarily limits playtest to1–4; deploy CI uses PLAYER_COUNTS=4 for playable scale only, not suppressed errors. Other authority/state matrices remain unchanged; deferred scale failures are not passed gates.
- Harden the Internet room service and evaluate Steam lobby/invite integration against its existing discovery/admission boundary; do not defer dedicated rooms until this phase.
- Improve server capacity/placement only from measured demand; adding server machines does not require changing room-ID client UX. No accounts/ranking or mass-scale infrastructure by default.
