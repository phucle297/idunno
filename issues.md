# issues.md — CEI log and follow-ups

## CEI log

| Signature | Hits | Last seen (ICT, UTC+7) | Status | Notes |
| --- | ---: | --- | --- | --- |
| `test_multiplayer_profile.MultiplayerProfileContract.test_four_real_clients_moving_client_changes_authoritative_position` — `RuntimeError: Controlled input did not move the authoritative client position` (4-client snow, 90 samples, displacement > 0.5 m) | 2 | 2026-11-19 01:46, [44372826235](https://github.com/phucle297/idunno/actions/runs/44372826235) attempt 1 | quarantined (T26) | Also failed [44352390724](https://github.com/phucle297/idunno/actions/runs/44352390724) attempt 1 (2026-11-18 23:56). No-code reruns passed: 44352390724 attempt 2 (2026-11-19 02:57), 44372826235 attempt 3 (2026-11-19 03:00). Trees were already green under `pull_request`. Listed in `tests/FLAKY.md`. Improvement due: fold into T21. |
| `test_action_audio` `toy_harbor:bomb_pickup` — one press must give 1..1 action cue(s), got 0 [] (`tests/test_action_audio.gd:191`) | 1 | 2026-11-19 01:48, [44372826235](https://github.com/phucle297/idunno/actions/runs/44372826235) attempt 1 (Godot job) | stays blocking (below RULES §7 bar) | toy_town bomb_pickup and toy_harbor bomb_throw were 1; F did pick the bomb up. No-code rerun passed: 44372826235 attempt 3 (2026-11-19 03:02). A second fail-then-pass quarantines it under T26 (no new card). |

## Follow-up cards

### F-T26-1 (low) — Make the quarantined 4-client movement test load-independent

- **Goal:** The 4-client snow moving-client check is reliable under CI load so it can leave `tests/FLAKY.md` and block merges again.
- **Owns:** Fold into factory card **T21** (not a separate SWE attempt on T26). Do not change the contract (authoritative displacement > 0.5 m).
- **Done when:** 10 local runs under load pass, then the id is removed from `tests/FLAKY.md`.
- **Status:** open.
