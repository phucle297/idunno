# Flaky tests (non-blocking CI)

Bare ids below (one per line, no spaces) run in the visible
non-blocking "Flaky tests" job. Python unittest ids are excluded
from the blocking "Python unit tests" job; Godot suite names
(matching tests/<name>.gd) are excluded from the blocking
"Godot import + fast suites" job. Lines starting with `#` are
comments. Remove an id to make that test blocking again. Nothing
listed here is skipped or deleted; contracts stay unchanged.

# test_multiplayer_profile 4-client move (Python)
# Signature: RuntimeError: Controlled input did not move the authoritative client position
# Contract unchanged: moving client shifts authoritative position > 0.5 m
# Hits (failed on already-green trees, then passed on no-code rerun):
# - https://github.com/phucle297/idunno/actions/runs/44352390724
#   push T19 @3b59d713; attempt 1 FAIL (Python, 2026-11-18 23:56 ICT);
#   attempt 2 PASS (no-code rerun, 2026-11-19 02:57 ICT)
# - https://github.com/phucle297/idunno/actions/runs/44372826235
#   push M23.3 @6756d3c4; attempt 1 FAIL (Python, 2026-11-19 01:46 ICT);
#   attempt 2 cancelled; attempt 3 PASS (no-code rerun, 2026-11-19 03:00 ICT)
# Follow-up: T21 (load-independent).

test_multiplayer_profile.MultiplayerProfileContract.test_four_real_clients_moving_client_changes_authoritative_position

# test_action_audio (Godot suite). Assertions unchanged, including
# toy_harbor bomb_pickup and bomb_throw (one press -> exactly one cue).
# Two fail-then-pass signatures (suite quarantined under T26 / RULES §7):
# 1. toy_harbor:bomb_pickup got 0 cues (tests/test_action_audio.gd:191)
#    https://github.com/phucle297/idunno/actions/runs/44372826235
#    push M23.3 @6756d3c4; attempt 1 FAIL (Godot, 2026-11-19 01:48 ICT);
#    attempt 3 PASS (no-code rerun, 2026-11-19 03:02 ICT)
#    (toy_town bomb_pickup and toy_harbor bomb_throw were 1)
# 2. toy_harbor:bomb_throw got 0 cues (tests/test_action_audio.gd:191)
#    https://github.com/phucle297/idunno/actions/runs/44384131654
#    PR #11 T16 @3e6eef87; attempt 1 FAIL (Godot, 2026-11-19 02:53 ICT);
#    attempt 2 PASS (rerun of failed jobs, 2026-11-19 03:21 ICT)
#    (toy_town pickup/throw and toy_harbor bomb_pickup were 1)

test_action_audio
