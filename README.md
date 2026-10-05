# Disaster Party

A Godot 4 prototype for a casual multiplayer disaster-survival party game.

Development is specification-led:

- `PROMPT.md` contains the original development prompt.
- `DESIGN.md` is the local Disaster Party Design Bible.
- `progress.json` is the single source of truth for implementation and validation state across sessions.
- `docs/implementation-checklist.md` tracks the current short execution checklist without replacing the design plan.

Phase 4 is complete: a server-authoritative Disaster Director now randomizes Meteor, Flood, and Tornado, escalates intensity, and permits fair two-disaster overlap after solo introductions. Phase 6 multiplayer stabilization is in progress; authoritative state snapshots pass with 2, 4, 8, and 20 separate clients, and the playable scene now supports ENet host/join, authoritative spawning, and disconnect cleanup. Movement and disaster presentation replication remain open. Hardware-accelerated Windows profiling also remains open.

## Local development

Use Godot 4.7.2 stable. If `godot` is not on `PATH`, substitute the path to the portable binary.

```bash
# Regenerate the deterministic Phase 1 reference assets.
godot --headless --path . --script res://tools/asset_generation/generate_assets.gd -- --seed=297

# Run the current automated checks.
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_player_integration.gd
godot --headless --path . --script res://tests/test_match_manager.gd
godot --headless --path . --script res://tests/test_rematch_integration.gd
godot --headless --path . --script res://tests/test_spectator_controller.gd
godot --headless --path . --script res://tests/test_grab_manager.gd
godot --headless --path . --script res://tests/test_meteor_shower.gd
godot --headless --path . --script res://tests/test_flood.gd
godot --headless --path . --script res://tests/test_tornado.gd
godot --headless --path . --script res://tests/test_disaster_director.gd
GODOT_BIN=/path/to/godot tests/run_network_authority_test.sh
# Run the separate-process multiplayer matrix (2, 4, 8, and 20 clients).
GODOT_BIN=/path/to/godot tests/run_four_client_match_test.sh
# Load the real playable scene as one host and one client, including disconnect cleanup.
GODOT_BIN=/path/to/godot tests/run_playable_scene_network_test.sh

# Profile a rendered four-player Flood + Tornado overlap (requires an X display).
godot --path . --rendering-method gl_compatibility --max-fps 60 \
  --script res://tests/profile_overlap.gd -- --four-player-demo --overlap-demo

# Play the core sandbox.
godot --path .

# Host or join the playable scene directly (default capacity: 20 total players).
godot --path . -- --host-port=29730
godot --path . -- --join-address=127.0.0.1 --join-port=29730

# Inspect the reference assets together.
godot --path . res://scenes/asset_validation.tscn
```

Controls: WASD to move, Shift to sprint, Space to jump, C to crouch, F to grab or release a physics prop, mouse to orbit the camera, R to trigger the current bounded knockdown/recovery prototype, Q/E to cycle spectator targets, and Enter to rematch from results.
