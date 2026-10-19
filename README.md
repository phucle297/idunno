# Disaster Party

A Godot 4 prototype for a casual multiplayer disaster-survival party game.

2026-10-19: **Phase18 Outfits and Original Music is deployed and published** at
`https://server.permees.com` from [741ae34](https://github.com/phucle297/idunno/commit/741ae3420da5b4c98c6d24b19344ffd5fbe6c341).
Download the matching Windows ZIP from the
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-19-741ae34).
[Build/deploy](https://github.com/phucle297/idunno/actions/runs/39184818543), final60-suite/42-Python
regression and public two-client exact-PCK smoke pass. Old clients are incompatible.
Includes fixed Outfit selection/equipment, four new free costumes and two original
menu/gameplay music loops with persisted Music volume. Continuous roof-correct
weather and rotating Town mechanisms, independent Home/Choose Map, Speed/Jump drops
and the enlarged furnished Toy Town remain included.
Package hashes/delivery evidence are in root [progress.json](progress.json);
the [Phase18 source checkpoint](docs/old-docs/phase-18-outfit-selection-and-costumes/progress.json)
is historical. Public profile storage remains disabled; local
profile-enabled package validation is not a public persistence claim.
Earlier delivery statements below describe historical snapshots.

Warned heavy meteors permanently remove bounded,
connected terrain districts, leaving real collision holes and authoritative instant
void-fall death. A removed district renders as pure absence — the sky background shows
through the hole. All nine districts are eligible, including center and warehouse.
Oracle lifecycle/rematch fixes are included. See the completed
[Phase11 archive](docs/old-docs/phase-11-meteor-terrain-collapse/checklist.md) and
[terrain-collapse rules](GUIDE.md#phase11-meteor-terrain-collapse).
Native Windows/GPU/audio/human/separate-network acceptance remains unverified.

The current source expands Toy Town to **144×144m**:19 enclosed buildings plus
garage, distinct interiors, four service courts, a connected outer walking circuit,
solid furniture/curbs, elevated breakable bridges and connected roof walks.
Harbor retains its64m footprint. Continuous rounded building shells, curved shop
canopies and shared paving preserve the toy-playset style.
Stairs have visible treads/rails/supports over smooth walking collision; hazard
warnings and flood coverage follow each map's actual extent/elevation.
The [owner's design reference](assets/references/phase7/rounded-town-camera-reference.png)
is checked into source, not used as runtime art. These corrections are included in
the [Phase 8 + Solid Environment Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-e68a912).
Concept parity and native GPU performance are not claimed. See
[correction evidence](docs/old-docs/phase-7-integrated-town/checklist.md).

Development is specification-led:

- `docs/old-docs/PROMPT.md` archives the original development prompt.
- `docs/old-docs/{phase-slug}/` groups completed-phase checklists, decisions and immutable progress evidence; see `docs/old-docs/README.md`.
- `DESIGN.md` is the local Disaster Party Design Bible.
- `progress.json` is the single source of truth for only the active phase, milestone, optional task, validation evidence, blockers, and next action.
- `docs/implementation-checklist.md` indexes the individual phase checklists in `docs/checklists/`, without replacing the design plan.
- `NEED_REAL_CHECK.md` lists the user/device/Internet checks still needed, with matching-build instructions and a result-reporting format.

Phases 0–1 established the vertical slice and UI; Phases 3–5 added player chaos, disaster compositions, map variety and session hardening. [Phase 6](docs/old-docs/phase-6-cosmetic-loot-box-drops-and-customization/checklist.md) is completed and archived with validated local packages: anonymous profiles, identity-bound admission, [transactional sealed rewards](GUIDE.md#transactional-reward-grants-task-622), authenticated opening, eight outfits and [collection/reveal/lobby equipment](GUIDE.md#collection-reveal-and-lobby-equipment-phase-6-source-builds). Boxes are free with saved equal odds and no duplicates; equipment waits for sender-bound authority acknowledgement, never midmatch. Offline play retains starters only. Profile-enabled 4/8/20 loopback clients agree through five rematches and owner/crash recovery; this is not production multi-room/Internet capacity evidence. No next phase, deployment or release is inferred. [Phase 2](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) remains deferred. Historical completion summaries are qualified by the [audit reconciliation](docs/old-docs/phase-5-validation-followup/decisions.md); native Windows, physical input/audio, real GPU and human acceptance remain unverified/nonblocking under the waiver. llvmpipe measurements did not meet 60 FPS. See `GUIDE.md` and `NEED_REAL_CHECK.md` for build-specific limits.

The implemented session path uses **dedicated rooms joined by custom room ID**.
It starts with one Linux server machine, a small HTTPS room
service and one headless Godot process per room; keep room discovery/allocation
separate from gameplay authority so additional machines can be introduced later
without changing room-ID joining. No mass-scale infrastructure or optimization
for hundreds of thousands/millions of users is planned. The source supports playerless
dedicated hosting, room-owner controls, bounded room allocation/admission and
room-ID create/join UI with retry recovery. Managed-container validation and
matching Windows/Linux release packaging have executed evidence. The owner-authorized
[Weather and Rockslides Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-c0a7800)
is deployed at `server.permees.com`; matching Windows/Linux packages are published.
Download `DisasterParty-Windows-Internet-c0a7800.zip`, extract all files and run
`DisasterParty.exe`; old client builds are incompatible. Staged pre-commit passed45
Godot suites,five network groups,managed20,settings restart and41 Python tests;
the exact-head build/deploy workflow passed backend readiness. Final Windows uses the
exact deployed CI PCK; downloaded release archives and tag were verified.
Public exact-PCK smoke passes two Linux editor-driven clients on one orb/upstream,
not native Windows or separate-network human acceptance. Earlier public build
`0d10b28` retains its user Internet/audio evidence; physical listening and measured
production demand for the new build remain unverified.
See `docs/implementation-checklist.md` for ordered tasks and gates.

The selected path now uses the **existing Tokyo EC2**, not Terraform provisioning.
See [pipeline prerequisites and operation](GUIDE.md#existing-ec2-pipeline-main-only):
main-only GitHub Actions validates/builds Linux, then deploys through OIDC/SSM.
Windows ZIP/GitHub pre-release publication is separate from the Linux deployment
workflow and was authorized on 2026-10-14. No Steam publication occurred.
The [earlier Terraform module](infra/ec2/README.md) is an optional reference only.
No EKS is needed; EC2 capacity/configuration is unchanged. GPU, audio and separate-network
Windows acceptance remain unverified; the completed public smoke is not a capacity claim.
Profile/reward persistence still requires an explicitly profile-enabled server;
this deployment does not enable new storage. Chunk streaming and meteor terrain collapse
zones are not included. [Phase8](docs/old-docs/phase-8-character-disaster-counterplay/checklist.md)
now completed its source/render/network/local-package technical gates: character
animation continuity, removal of crouch/temporary removal of grabbing/holding,
localized earthquake escape, environmental Fire/Flood cooling and area-aware frozen
meteor waves. The public e68a912 release includes these changes and matching
Windows/Linux packages; the earlier14be2c3 bundles remain historical local evidence.
Native Windows/GPU60FPS/audio/human difficulty/separate-network acceptance remains
unverified/nonblocking. [Phase9](docs/old-docs/phase-9-weather-rockslides/checklist.md)
now completes agent-owned weather/Rockslide source and local-package gates:
Rain wets exposed ground/suppresses Fire, bounded snow affects grounded traction,
and collision-backed rock slopes have lateral exits/solid cover on both maps.
Full45-suite/five-matrix/managed20 regression and Town/Harbor2/4/8/20 weather/reset
checks pass; matching local uncommitted Windows/Linux packages and inspected renders
remain in `.amp/in/artifacts/phase9-packages` and `phase9`. This is historical;
the subsequently authorized release/deployment is verified in root progress and
`.amp/in/artifacts/phase9-release`. Use the public release, not the historical
uncommitted snapshot, for Internet joining. Phase10 now adds source/local-build
bee pursuit with cover/water counters, bounded UFO capture with ordinary fall damage,
and authored volcanic collision/heat with local weather/Flood cooling. Matching
uncommitted local packages and inspected720p/1080p states are in
`.amp/in/artifacts/phase10-packages` and `phase10`; they are not deployed and
must not be mixed with the public Phase9 service. All six technical/local gates
pass; [Phase10 evidence](docs/old-docs/phase-10-swarms-ufo-volcano/progress.json)
is archived, root is idle, and source remains uncommitted/unpushed.
Native Windows/GPU/audio/human acceptance remains unverified.
The owner's subsequent volcanic-relief refinement replaces flat shelves with
collision-backed faceted peaks and shallow walking crowns. This source follow-up
is not included in the previously exported Phase10 packages; see root progress.
The subsequent [collision follow-up](docs/old-docs/phase-8-collision-followup/checklist.md)
adds solid rails, bushes/planters, lamps, vents and Harbor cargo.
Release validation corrected blocked ramp approaches/crate crossings by leaving
stair presentation rails decorative over solid ramp slabs; other rails remain solid.
Full CI and public admission/Ready/Start pass. [Phase12 movement drops](docs/old-docs/phase-12-match-powerup-drops/checklist.md)
have passed technical/local-package gates and source delivery: temporary random
Speed (+20% walk/sprint,12s) and Jump (+20% height,10s), not permanent cosmetic stats.
Collection is automatic and server-authoritative; one buff at a time, same type
refreshes and another type replaces. They are not in the public Phase11 build;
do not mix Phase12 local clients with that server. See root progress for delivery.
Held hammer/wood interactions are
[future backlog only](docs/implementation-checklist.md#explicitly-deferred).
Phase2 is suspended in old-docs and reopens only on owner request. Phase9 adds weather/
rockslides; Phase10 adds bees/UFO/volcano. Phase11 is now
[warned meteor terrain collapse](docs/old-docs/phase-11-meteor-terrain-collapse/checklist.md);
the rejected circle/gradual-HP-loss tracking is archived as superseded/cancelled.
The public Phase11 release includes the uneven volcanic-relief refinement and does
not include Phase12 movement drops.

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

Phase 6 matching local packages are in `.amp/in/artifacts/phase6-packages/`:
`DisasterParty-Windows-e978f6a.zip`, `DisasterParty-Linux-server-e978f6a.tar.gz`
and `PLAYTEST-NOTES.md`. Repeated exports/unpacked hashes/PCK and standalone Linux
profile-store restart pass; native Windows is not tested. They are not published or
deployed: the Phase 5 public build remains the historical download above. **Do not
join the old public service with a Phase 6 client.** Profile-enabled operation needs a separate durable
SQLite store outside release bundles; anonymous credentials are private and scoped
to the service URL, with no account recovery if lost. See the
[profile operations and backup/rollback guidance](GUIDE.md#phase-6-profile-foundation-task-611)
before configuring it. Future HTTPS profile routes require separate approval;
internal equipment/reward routes must never be publicly exposed. Existing human
acceptance waivers and unresolved gates are unchanged.

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

Runtime scripts are grouped by responsibility:

- `game/player/`: movement, tuning, character visuals, cosmetic ragdoll and shoving.
- `game/disasters/`: the disaster director, shared weather surfaces/precipitation and hazard implementations.
- `game/session/`: match state, room discovery/admission and spectating.
- `game/ui/`: HUD, lobby/results presentation and settings.
- `game/main.gd`: scene composition and orchestration. Standalone breakable-structure, gameplay-audio and asset-validation scripts remain at the root.

Keep a moved script's `.gd.uid` alongside it and update scene, test and generator references. Scenes stay in `scenes/`; reusable assets stay in `assets/`.

```bash
# Regenerate the deterministic Phase 0 reference assets.
godot --headless --path . --script res://tools/asset_generation/generate_assets.gd -- --seed=297

# Run the current automated checks.
# Run all current suites, persistence restart, five network groups and managed 20-client coverage:
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
are in `GUIDE.md`. This follow-up does not deploy, restart the shared server or change firewalls.

Controls: WASD to move, Shift to sprint, Space to jump, mouse to orbit the camera, Escape to release the cursor, left click to recapture it, L to toggle the network lobby, R to trigger the current bounded knockdown/recovery prototype, Q/E to cycle spectator targets, and Enter to start a ready lobby or rematch from results. Crouch and player grabbing/holding are removed; loose props still react to hazards.
