# issues.md — CEI log and follow-ups

## CEI log

| Signature | Hits | Last seen (ICT, UTC+7) | Status | Notes |
| --- | ---: | --- | --- | --- |
| `test_multiplayer_profile.MultiplayerProfileContract.test_four_real_clients_moving_client_changes_authoritative_position` — `RuntimeError: Controlled input did not move the authoritative client position` (4-client snow, 90 samples, displacement > 0.5 m) | 2 | 2026-11-19 01:46, [44372826235](https://github.com/phucle297/idunno/actions/runs/44372826235) attempt 1 | fixed + unquarantined (T21) | T21: 10/10 under 8-busy-loop load, removed from `tests/FLAKY.md` (blocking again); root cause = fixed-frame server window vs tick-timed strafe phase, see FLAKY.md note. Also failed [44352390724](https://github.com/phucle297/idunno/actions/runs/44352390724) attempt 1 (2026-11-18 23:56). No-code reruns passed: 44352390724 attempt 2 (2026-11-19 02:57), 44372826235 attempt 3 (2026-11-19 03:00). Trees were already green under `pull_request`. Listed in `tests/FLAKY.md`. Improvement due: fold into T21. |
| `test_action_audio` `toy_harbor:bomb_pickup` — one press must give 1..1 action cue(s), got 0 [] (`tests/test_action_audio.gd:191`) | 1 | 2026-11-19 01:48, [44372826235](https://github.com/phucle297/idunno/actions/runs/44372826235) attempt 1 (Godot job) | suite quarantined (T26); assertion unchanged and still runs | toy_town bomb_pickup and toy_harbor bomb_throw were 1; F did pick the bomb up. No-code rerun passed: 44372826235 attempt 3 (2026-11-19 03:02). This signature alone was below the §7 bar; the suite is quarantined after the second fail-then-pass (bomb_throw, below). |
| `test_action_audio` `toy_harbor:bomb_throw` — one press must give 1..1 action cue(s), got 0 [] (`tests/test_action_audio.gd:191`) | 1 | 2026-11-19 02:53, [44384131654](https://github.com/phucle297/idunno/actions/runs/44384131654) attempt 1 (PR #11 T16 @3e6eef87, Godot job) | suite quarantined (T26) | toy_town pickup/throw and toy_harbor bomb_pickup were 1. No-code rerun of failed jobs passed: 44384131654 attempt 2 (2026-11-19 03:21). Second fail-then-pass of `test_action_audio` (first was bomb_pickup). Suite listed in `tests/FLAKY.md`; assertions unchanged. |
| `test_room_service` RealProcesses/Rewards real-Godot tests (`consume_started.wait(8)` "Third real HTTP /consume must reach the held service hook"; no `ROOM_UI_ACTIVE` in 12 s; Godot subprocess `TimeoutExpired` 14/15 s) | 3 | 2026-11-19 22:03, T40 diag repro under 8 CPU burners (`test_profile_bound_admission_and_reservation_cleanup`); prior QA T21 #26 and QA T10 #27 full runs | fixed + unquarantined (T40) | Root cause: harness liveness caps sized near real cold-Godot durations (a peer used up to 10.6 s of 15 s under load) plus host stalls. Caps now 60 s per Godot process, 30 s per condition; assertions and semantic windows unchanged. 10/10 loaded suite runs. |

## Follow-up cards

### F-T26-1 (low) — Make the quarantined 4-client movement test load-independent

- **Goal:** The 4-client snow moving-client check is reliable under CI load so it can leave `tests/FLAKY.md` and block merges again.
- **Owns:** Fold into factory card **T21** (not a separate SWE attempt on T26). Do not change the contract (authoritative displacement > 0.5 m).
- **Done when:** 10 local runs under load pass, then the id is removed from `tests/FLAKY.md`.
- **Status:** done (T21, 2026-11-19): 10/10 local runs under load; id removed from `tests/FLAKY.md`.

### F-T26-2 (low) — Make `test_action_audio` reliable enough to unquarantine

- **Goal:** `toy_harbor` bomb_pickup and bomb_throw each yield exactly one action cue under CI load, so `test_action_audio` can leave `tests/FLAKY.md` and block merges again.
- **Owns:** Follow-up, not T26. Assertions stay 1..1 cues per press.
- **Done when:** 10 local runs under load pass, then the id is removed from `tests/FLAKY.md`.
- **Status:** open.
