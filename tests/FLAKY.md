# Flaky tests (non-blocking CI)

Bare ids below (one per line, no spaces) run in the visible
non-blocking "Flaky tests" job. Python unittest ids are excluded
from the blocking "Python unit tests" job; Godot suite names
(matching tests/<name>.gd) are excluded from the blocking
"Godot import + fast suites" job. Lines starting with `#` are
comments. Remove an id to make that test blocking again. Nothing
listed here is skipped or deleted; contracts stay unchanged.

# test_multiplayer_profile 4-client move: removed from this list by T21
# (blocking again). Cause: the >0.5 m check read only the server's fixed
# 90-frame trace (~0.6 s game time) while the strafe flipped every 30 client
# ticks, so the result depended on cross-process phase and load (unloaded
# margins 0.59-0.91 m). Now strafe legs end by distance (~2 m span, 120-tick
# cap) and the driver waits, input held, for the server's per-tick
# observation from the same origin (deadline --timeout). Assertion unchanged.
# History: runs 44352390724 and 44372826235, quarantined under T26.

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
