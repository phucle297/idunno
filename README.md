# Disaster Party

A Godot 4 prototype for a casual multiplayer disaster-survival party game.

Development is specification-led:

- `PROMPT.md` contains the original development prompt.
- `DESIGN.md` is the local Disaster Party Design Bible.
- `progress.json` is the single source of truth for implementation and validation state across sessions.
- `docs/implementation-checklist.md` tracks the current short execution checklist without replacing the design plan.

The project is currently in Phase 4: implementing randomized disaster direction and overlap after independently validating Meteor, Flood, and Tornado.

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
GODOT_BIN=/path/to/godot tests/run_network_authority_test.sh

# Play the core sandbox.
godot --path .

# Inspect the reference assets together.
godot --path . res://scenes/asset_validation.tscn
```

Controls: WASD to move, Shift to sprint, Space to jump, C to crouch, F to grab or release a physics prop, mouse to orbit the camera, R to trigger the current bounded knockdown/recovery prototype, Q/E to cycle spectator targets, and Enter to rematch from results.
