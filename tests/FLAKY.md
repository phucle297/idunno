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

# test_action_audio: removed from this list by T25 (blocking again).
# Causes found under 8-busy-loop load (evidence in the T25 ledger):
# - bomb 0 cues: the emitter played once, but the per-frame is_playing()
#   poll can miss a 0.09 s generated tone (its observed active window under
#   the headless dummy audio driver ranged from under one frame to ~70 ms); the
#   probe reads HotPotatoVisuals.cue_play_count, 1..1 still asserted.
# - bomb_throw 2 cues: the pass returned to the thrower (0.3 s game time)
#   inside a 24-frame window; the window now ends with the flight.
# - toy_harbor toy_use 0 cues: the fixture swaps maps inside one match, so
#   toy effect ids restart while toy audio dedup keeps Town's id:kind keys;
#   the fixture now does the match-state presentation reset.
# History: runs 44372826235 (bomb_pickup) and 44384131654 (bomb_throw),
# quarantined under T26.
