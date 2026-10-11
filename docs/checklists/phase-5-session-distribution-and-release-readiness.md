### Phase 5 — Session Distribution and Release Readiness

- Harden the Phase 2 Windows package for release/distribution and add robust failure UX; do not defer the playtest export until this phase.
- Resolve the intermittent 20-player movement failure before expanding supported playtest capacity beyond four. Run37770598203: one client observed unchanged local/host positions while the server reported movement=true and clients=false; cause unverified. Retain full4/8/20 fixture/assertions and diagnostics, reproduce under CI load, fix the proven owner and rerun before claiming scale readiness. User temporarily limits playtest to1–4; deploy CI uses PLAYER_COUNTS=4 for playable scale only, not suppressed errors. Other authority/state matrices remain unchanged; deferred scale failures are not passed gates.
- Harden the Internet room service and evaluate Steam lobby/invite integration against its existing discovery/admission boundary; do not defer dedicated rooms until this phase.
- Improve server capacity/placement only from measured demand; adding server machines does not require changing room-ID client UX. No accounts/ranking or mass-scale infrastructure by default.

## Milestone 5.1 — Windows Package Hardening and Failure UX

Owner authorized continuation on 2026-10-11. Keep supported playtests at 1–4;
do not publish, deploy, change infrastructure or claim physical/Internet acceptance.
Root `progress.json` owns task status, executed evidence and the next action.

### 5.1a — Package integrity and launcher

Implemented and locally verified; final committed-revision local distribution
is recorded in 5.1c. Internet admission remains separately unverified.

- Export the same-revision play guide, `Play.cmd` and `Verify-Package.ps1` with
  the EXE/PCK/build identity/checksum manifest.
- Before launch, reject missing/corrupt files, unexpected/duplicate/unsafe or
  incomplete manifests, and an unwritable log directory. Show re-extraction
  instructions; never disable certificate, firewall or machine security policy.
- Require the existing Python hash/PCK auditor before export success on both
  platforms. Require exact per-platform manifests and no development-path leaks.
- Gates: native PowerShell integrity rejection/restored retry; matching hashes
  across two isolated exports; native standalone release launcher/build identity;
  exported-PCK settings restart, recovery and five rematches; Linux release
  lifecycle regression. All executed locally; evidence in `progress.json`.

### 5.1b — Exported room failure/recovery

Implemented and locally verified on 2026-10-11. Source fixture passes 74 checks;
native rendered exported-PCK fixture passes 148 at 1280×720. The complete native
package runner retains settings restart, session recovery and five rematches.
Standalone release HTTP/UDP-fixture captures additionally verify unknown-room,
build mismatch, invalid-ticket and timeout errors plus an edited-ID lookup retry
without restarting. These are local synthetic endpoints, not Internet admission.

- Adapt `tests/test_room_ui.gd` to actual runtime revision instead of the source
  `development` identity and add it to the native exported-PCK runner.
- Cover room lookup failures, invalid/incompatible tickets, admission timeout,
  disconnect recovery and restored editable fields/fresh-ticket retry.
- Execute against the shipped PCK and separately check representative failure
  UX in the untouched release EXE. Editor-driver results do not certify release
  Internet gameplay, physical audio or human comprehension.

### 5.1c — Distribution bundle

Completed locally on 2026-10-11 from application revision
`f14791ecd5a5d38ef7252193d04648b44d879662`. Matching Windows/Linux ZIPs and
`SHA256SUMS.txt` are in `C:/Users/permees/Downloads/DisasterParty-Phase5-f14791e`;
exact sizes/hashes and evidence paths are recorded in root `progress.json`.
Fresh extracted packages pass audits, native Windows standalone launch and
editor-driver settings/recovery/room-failure/five-rematch checks, plus the Linux
release lifecycle gate. Copied ZIP hashes pass. No push or deployment occurred;
the older deployed server cannot admit these clients unless its revision matches.

- Export matching Windows/Linux bundles from the approved committed revision;
  ZIP only manifest-listed runtime files plus `SHA256SUMS.txt`, not developer logs.
- Audit the extracted bundle and repeat standalone launch; record full identity
  and artifact hashes. Check client/server revision equality before admission.
- Record delivery separately from implementation; no public upload/deployment.

## Milestone 5.2 — Stable Multiplayer Capacity

### 5.2a — Reproduce and isolate (completed investigation)

- Full4/8/20 runs retain all original movement, rematch and MTU assertions.
  Unrestricted CPUs pass movement but fail20 on a1592-byte unreliable live-state
  packet (1392 MTU). Two-CPU affinity reproduces unchanged host positions.
- Temporary receipt counters show affected peers receive no moving-host packets;
  server ENet throttle reaches0. A server-only deceleration0 control keeps throttle32
  and restores movement on all19 clients plus the server. The control still fails
  the strict MTU gate; it is diagnostic evidence, not a congestion-safe fix.
- Remove all temporary runtime counters/throttle changes. Keep fixture-only
  timing, physics-frame and ENet-statistic logs; final four-player two-CPU run
  passes with five rematches. Exact commands/results are in root progress.
- This reproduces a similar local failure and isolates its transport cause;
  it does not establish the exact cause of the historical CI run.

### 5.2b — Congestion-safe replication (pending)

- Resolve unreliable movement starvation without disabling congestion protection
  or weakening movement assertions/time windows. Bound active-state packets.
- Require the unchanged full4/8/20 matrix on two CPUs and unrestricted CPUs,
  including MTU rejection and all19 client markers; retain four-player controls.
- Do not increase supported capacity, publish or deploy from these experiments.
