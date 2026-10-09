# Disaster Party

A Godot 4 prototype for a casual multiplayer disaster-survival party game.

Development is specification-led:

- `docs/old-docs/PROMPT.md` archives the original development prompt.
- `docs/old-docs/{phase-slug}/` groups completed-phase checklists, decisions and immutable progress evidence; see `docs/old-docs/README.md`.
- `DESIGN.md` is the local Disaster Party Design Bible.
- `progress.json` is the single source of truth for only the active phase, milestone, optional task, validation evidence, blockers, and next action.
- `docs/implementation-checklist.md` indexes the individual phase checklists in `docs/checklists/`, without replacing the design plan.
- `NEED_REAL_CHECK.md` lists the user/device/Internet checks still needed, with matching-build instructions and a result-reporting format.

All work through the validated vertical slice is **Phase 0 — Init Project**. It is implemented and verified through 20-player playable-scene sessions and native Windows performance/audio checks. **Phase 1 — UI Identity and Feedback** adds the Toy Broadcast HUD, warnings, lobby, spectator/results presentation, local pause, saved settings, and continuous map perimeter with authoritative out-of-bounds elimination. Both phases are complete; detailed evidence is archived under `docs/old-docs/`. Root `progress.json` now tracks **Phase 3 — Player-Caused Chaos**, starting with safe interaction3.1. [Phase2 evidence](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) is frozen as deferred, not completed, under user-authorized continuation; no unfinished acceptance gate is passed. Current supported playtest scope stays1–4 players. See `GUIDE.md` for play instructions and current limitations.

Phase 2 now plans **Internet-hosted dedicated rooms joined by custom room ID**
before human playtesting. Start with one Linux server machine, a small HTTPS room
service and one headless Godot process per room; keep room discovery/allocation
separate from gameplay authority so additional machines can be introduced later
without changing room-ID joining. No mass-scale infrastructure or optimization
for hundreds of thousands/millions of users is planned. This is a roadmap change,
not completed Internet functionality. The source now supports playerless
dedicated hosting, room-owner controls, bounded room allocation/admission and
room-ID create/join UI with retry recovery. Managed-container validation and
matching Windows/Linux release packaging now pass locally. Public Internet
release-client sessions and physical listening remain unverified.
See `docs/implementation-checklist.md` for ordered tasks and gates.

The selected path now uses the **existing Tokyo EC2**, not Terraform provisioning.
See [pipeline prerequisites and operation](GUIDE.md#existing-ec2-pipeline-main-only):
main-only GitHub Actions validates/builds Linux, then deploys through OIDC/SSM.
No Windows ZIP, GitHub Release or Steam publication is part of this deployment.
The [earlier Terraform module](infra/ec2/README.md) is an optional reference only.
No EKS is needed; public deployment and Internet gameplay remain unverified.

## Windows playtest export

Use the official Godot **4.7.2 stable** Linux editor and its matching export
templates. The build command runs on Linux/WSL with Bash, Git, tar, ripgrep and
sha256sum. Native Windows is required to validate the resulting executable.

Download `Godot_v4.7.2-stable_export_templates.tpz` and `SHA512-SUMS.txt` from
[the official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
Keep downloads outside tracked source. In the download directory:

```bash
rg ' Godot_v4.7.2-stable_export_templates.tpz$' SHA512-SUMS.txt | sha512sum -c -
mkdir -p "$HOME/.local/share/godot/export_templates/4.7.2.stable"
unzip -j Godot_v4.7.2-stable_export_templates.tpz \
  templates/windows_release_x86_64.exe templates/windows_debug_x86_64.exe \
  templates/linux_release.x86_64 templates/linux_debug.x86_64 \
  templates/version.txt -d "$HOME/.local/share/godot/export_templates/4.7.2.stable"
```

Commit the desired source first; the exporter rejects tracked changes and builds
only committed `HEAD` in an isolated directory, without reusing editor caches.
Untracked files are not build inputs. Choose fresh output directories:

```bash
GODOT_BIN=$(command -v godot) tools/export_windows.sh .scratch/windows-a
GODOT_BIN=$(command -v godot) tools/export_windows.sh .scratch/windows-b
diff .scratch/windows-a/SHA256SUMS.txt .scratch/windows-b/SHA256SUMS.txt
GODOT_BIN=$(command -v godot) tools/export_playtest.sh linux-server .scratch/linux-a
GODOT_BIN=$(command -v godot) tools/export_playtest.sh linux-server .scratch/linux-b
diff .scratch/linux-a/SHA256SUMS.txt .scratch/linux-b/SHA256SUMS.txt
```

The package contains `DisasterParty.exe`, `DisasterParty.pck`, `BUILD.txt` and
`SHA256SUMS.txt`; import/export logs are developer evidence, not runtime
dependencies. Tests, generators, documentation, caches and downloaded tools are
excluded. The executable is unsigned; this is not a Steam or release package.

The Linux package substitutes `DisasterParty.x86_64` and adds the same-revision
`room_service.py`. It runs with `--headless` without an editor, import cache or
checkout. Python 3.10+ is required for room allocation. Both targets share the
isolated exporter; `export_windows.sh` preserves the original command. Export
both from the same HEAD, not merely the same tag name. See the
[operator runbook](GUIDE.md#packaged-server-operator-runbook-task-227) for local
startup, deployment boundaries and outstanding Internet/listening gates.

Copy those four files to a fresh directory on Windows and double-click
`DisasterParty.exe`. Keep the PCK beside the EXE. No Godot/editor/repository is
required. `BUILD.txt` identifies the full source revision and engine; the game
prints `DISASTER_PARTY_BUILD` on startup. For a standalone launch smoke check:

```powershell
$game = Start-Process .\DisasterParty.exe -ArgumentList '--log-file launch.log --quit-after 600' -Wait -PassThru
if ($game.ExitCode -ne 0) { throw "Launch failed: $($game.ExitCode)" }
Get-Content .\launch.log
Get-FileHash .\DisasterParty.exe, .\DisasterParty.pck, .\BUILD.txt -Algorithm SHA256
```

Compare hashes with `SHA256SUMS.txt`. Same-revision payload hashes must match;
any packaging-only differences must be investigated and documented, not ignored.
Internet-room multiplayer/settings/audio readiness belongs to Milestone 2.2;
this command does not prove it. Physical LAN smoke is optional legacy coverage,
not the new readiness gate.

## Local development

Use Godot 4.7.2 stable. If `godot` is not on `PATH`, substitute the path to the portable binary.

```bash
# Regenerate the deterministic Phase 0 reference assets.
godot --headless --path . --script res://tools/asset_generation/generate_assets.gd -- --seed=297

# Run the current automated checks.
# Or run all 27 suites, persistence restart and five network test groups together:
GODOT_BIN=$(command -v godot) tests/run_ui_regression.sh
# If another local session occupies the default ports, set PORT=29930 for this runner.
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_map_safety.gd
godot --headless --path . --script res://tests/test_player_integration.gd
godot --headless --path . --script res://tests/test_session_lifecycle.gd
godot --headless --path . --script res://tests/test_dedicated_server.gd
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
godot --headless --path . --script res://tests/test_lobby_presentation.gd
godot --headless --path . --script res://tests/test_spectator_presentation.gd
godot --headless --path . --script res://tests/test_results_table.gd
godot --headless --path . --script res://tests/test_results_actions.gd
godot --headless --path . --script res://tests/test_pause_settings.gd -- --settings-path=user://test-milestone-1-5.cfg
# Verify persisted settings in two separate processes (isolated from player preferences).
godot --headless --path . --script res://tests/test_pause_settings.gd -- --settings-path=user://test-milestone-1-5.cfg --save-for-restart
godot --headless --path . --script res://tests/test_pause_settings.gd -- --settings-path=user://test-milestone-1-5.cfg --verify-restart
# Repeat the milestone HUD/focus captures at 1280x720 and 1920x1080 (requires a display).
# Use an existing ignored output directory for --capture-dir.
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_milestone_1_1.gd -- --capture-dir=.amp/in/artifacts
# Render four-player and scrolled twenty-player lobby fixtures; repeat at 1920x1080.
# In a displayless Linux orb, prefix this command with xvfb-run -a (requires Xvfb).
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_lobby_roster.gd -- --capture-dir=.amp/in/artifacts
# Render four-player and scrolled twenty-player results; repeat at 1920x1080.
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_results_table.gd -- --capture-dir=.amp/in/artifacts
# Render actual out-of-bounds spectator feedback, perimeter corner and map overview.
godot --path . --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/test_map_safety.gd -- --capture-dir=.amp/in/artifacts
GODOT_BIN=/path/to/godot tests/run_network_authority_test.sh
# Run the separate-process multiplayer matrix (2, 4, 8, and 20 clients).
GODOT_BIN=/path/to/godot tests/run_four_client_match_test.sh
# Run production main.tscn sessions with 4, 8, and 20 total players.
GODOT_BIN=/path/to/godot tests/run_playable_scale_test.sh
# Load the real playable scene as one host and one client, including disconnect cleanup.
GODOT_BIN=/path/to/godot tests/run_playable_scene_network_test.sh
# Playerless dedicated server + two clients: actual movement, five rematches and recovery.
GODOT_BIN=/path/to/godot tests/run_dedicated_network_test.sh

# Regenerate the deterministic synthesized gameplay audio.
godot --headless --path . --script res://tools/audio_generation/generate_audio.gd

# Profile uncapped rendered throughput (requires a display/GPU).
# The profiler disables V-Sync and fails if p95 > 16.67 ms or UI nodes rebuild.
# Use native Windows Godot for the target-platform gate; llvmpipe is software rendering.
godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
  --script res://tests/profile_overlap.gd -- --four-player-demo --overlap-demo

# Play the core sandbox.
godot --path .

# Host or join the playable scene directly (default capacity: 20 total players).
godot --path . -- --host-port=29730
godot --path . -- --join-address=127.0.0.1 --join-port=29730

# Playerless dedicated server (unmanaged, unauthenticated development only).
godot --headless --path . -- --server-port=29730
# Join with two clients using the direct-IP command above. First connected client
# is OWNER; owner may start once everyone is ready, rematch and return to lobby.

# Managed rooms: start service, then launch clients in other terminals.
python3 tools/room_service.py --godot "$(command -v godot)"
godot --path . -- --room-service-url=http://127.0.0.1:29800
# Press L for Create Room / Join Room; remote service URLs require HTTPS.
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_room_service.py -v

# Inspect the reference assets together.
godot --path . res://scenes/asset_validation.tscn
```

Dedicated mode reserves no server-player slot, transfers ownership to the
longest-connected remaining player and rejects delayed session actions from
earlier rounds/owners. Matches retain normal survivor rules when someone leaves.
New arrivals during ACTIVE are rejected; reconnect/rejoin during an active round
is not supported yet. Server startup failure exits nonzero. This is unauthenticated
development transport: **do not expose unmanaged servers publicly**. Managed
rooms enforce pre-registration tickets; discovery/lifecycle and retry instructions
are in `GUIDE.md`. No public deployment or firewall changes are included.

Controls: WASD to move, Shift to sprint, Space to jump, C to crouch, F to grab or release a physics prop, mouse to orbit the camera, Escape to release the cursor, left click to recapture it, L to toggle the network lobby, R to trigger the current bounded knockdown/recovery prototype, Q/E to cycle spectator targets, and Enter to start a ready lobby or rematch from results.
