# Disaster Party

A Godot 4 prototype for a casual multiplayer disaster-survival party game.

Development is specification-led:

- `docs/old-docs/PROMPT.md` archives the original development prompt.
- `docs/old-docs/progress-{phase-slug}.json` preserves immutable completed-phase evidence.
- `DESIGN.md` is the local Disaster Party Design Bible.
- `progress.json` is the single source of truth for only the active phase, milestone, optional task, validation evidence, blockers, and next action.
- `docs/implementation-checklist.md` is the human-readable roadmap and current execution checklist without replacing the design plan.

All work through the validated vertical slice is **Phase 0 — Init Project**. It is implemented and verified through 20-player playable-scene sessions and native Windows performance/audio checks. The playable scene includes an in-game direct-IP lobby, authoritative movement and match state, all six disasters and both combinations, shared prop and knockdown presentation, results, and host-controlled rematches. Future development uses `phase → milestone → optional task`; Phase 1 focuses on a richer, cohesive UI identity and gameplay feedback. See `GUIDE.md` for play instructions and current limitations.

## Local development

Use Godot 4.7.2 stable. If `godot` is not on `PATH`, substitute the path to the portable binary.

```bash
# Regenerate the deterministic Phase 0 reference assets.
godot --headless --path . --script res://tools/asset_generation/generate_assets.gd -- --seed=297

# Run the current automated checks.
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_player_integration.gd
godot --headless --path . --script res://tests/test_session_lifecycle.gd
godot --headless --path . --script res://tests/test_match_manager.gd
godot --headless --path . --script res://tests/test_rematch_integration.gd
godot --headless --path . --script res://tests/test_spectator_controller.gd
godot --headless --path . --script res://tests/test_grab_manager.gd
godot --headless --path . --script res://tests/test_meteor_shower.gd
godot --headless --path . --script res://tests/test_flood.gd
godot --headless --path . --script res://tests/test_tornado.gd
godot --headless --path . --script res://tests/test_earthquake.gd
godot --headless --path . --script res://tests/test_lightning.gd
godot --headless --path . --script res://tests/test_fire.gd
godot --headless --path . --script res://tests/test_disaster_combinations.gd
godot --headless --path . --script res://tests/test_disaster_director.gd
godot --headless --path . --script res://tests/test_phase7_polish.gd
godot --headless --path . --script res://tests/test_ui_theme.gd
godot --headless --path . --script res://tests/test_gameplay_hud.gd
godot --headless --path . --script res://tests/test_milestone_1_1.gd
godot --headless --path . --script res://tests/test_lobby_roster.gd
# Repeat the milestone HUD/focus captures at 1280x720 and 1920x1080 (requires a display).
# Use an existing ignored output directory for --capture-dir.
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_milestone_1_1.gd -- --capture-dir=.amp/in/artifacts
# Render four-player and scrolled twenty-player lobby fixtures; repeat at 1920x1080.
# In a displayless Linux orb, prefix this command with xvfb-run -a (requires Xvfb).
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_lobby_roster.gd -- --capture-dir=.amp/in/artifacts
GODOT_BIN=/path/to/godot tests/run_network_authority_test.sh
# Run the separate-process multiplayer matrix (2, 4, 8, and 20 clients).
GODOT_BIN=/path/to/godot tests/run_four_client_match_test.sh
# Run production main.tscn sessions with 4, 8, and 20 total players.
GODOT_BIN=/path/to/godot tests/run_playable_scale_test.sh
# Load the real playable scene as one host and one client, including disconnect cleanup.
GODOT_BIN=/path/to/godot tests/run_playable_scene_network_test.sh

# Regenerate the deterministic synthesized gameplay audio.
godot --headless --path . --script res://tools/audio_generation/generate_audio.gd

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

Controls: WASD to move, Shift to sprint, Space to jump, C to crouch, F to grab or release a physics prop, mouse to orbit the camera, Escape to release the cursor, left click to recapture it, L to toggle the network lobby, R to trigger the current bounded knockdown/recovery prototype, Q/E to cycle spectator targets, and Enter to start a ready lobby or rematch from results.
