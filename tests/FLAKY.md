# Flaky tests (non-blocking CI)

Bare test ids below (one per line, no spaces) run in the visible
non-blocking "Flaky tests" job and are excluded from the blocking
"Python unit tests" job. Lines starting with `#` are comments.
Remove an id to make that test blocking again. Nothing listed here
is skipped or deleted; contracts stay unchanged.

# test_multiplayer_profile 4-client move
# Signature: RuntimeError: Controlled input did not move the authoritative client position
# Contract unchanged: moving client shifts authoritative position > 0.5 m
# Hits (failed on already-green trees, then passed on no-code rerun):
# - https://github.com/phucle297/idunno/actions/runs/44352390724
#   push T19 @3b59d713; attempt 1 FAIL (Python, 2026-11-18 23:56 ICT);
#   attempt 2 PASS (no-code rerun, 2026-11-19 02:57 ICT)
# - https://github.com/phucle297/idunno/actions/runs/44372826235
#   push M23.3 @6756d3c4; attempt 1 FAIL (Python, 2026-11-19 01:46 ICT);
#   attempt 2 cancelled; attempt 3 PASS (no-code rerun, 2026-11-19 03:00 ICT)
# Follow-up: T21 (load-independent). Audio toy_harbor:bomb_pickup is
# NOT listed (1 hit; stays blocking). See issues.md.

test_multiplayer_profile.MultiplayerProfileContract.test_four_real_clients_moving_client_changes_authoritative_position
