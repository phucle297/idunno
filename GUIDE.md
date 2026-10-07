# Disaster Party Play Guide

This is an unsigned Windows x86_64 playtest prototype, not a Steam release.
Players use the packaged executable; no Godot editor or repository checkout is
needed. Multiplayer uses direct ENet IP connections, with no lobby browser,
Steam invites or NAT traversal. Same-PC checks do not prove physical LAN play.

## Prepare and verify the package

1. Extract the ZIP to a local folder on every PC. Keep `DisasterParty.exe`,
   `DisasterParty.pck`, `BUILD.txt` and `SHA256SUMS.txt` together; do not run from
   inside the ZIP or mix files from different builds.
2. Compare **Source revision** and **Engine** in `BUILD.txt` on every PC.
3. Open PowerShell in that folder and verify the delivered files:

```powershell
foreach ($line in Get-Content .\SHA256SUMS.txt) {
    $parts = $line -split '\s+', 2
    $actual = (Get-FileHash $parts[1] -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $parts[0]) { throw "Checksum mismatch: $($parts[1])" }
}
Get-Content .\BUILD.txt
```

Stop on any mismatch and replace the complete package. Windows may warn about
an unsigned app; verify its source and checksums before choosing to run it.
Do not disable antivirus or firewall protection globally.

## Play alone

Double-click `DisasterParty.exe`, or launch from its package folder:

```powershell
.\DisasterParty.exe --log-file solo.log
```

The solo match starts automatically and continues until death or timeout; having
one player does not immediately declare a winner. The first warning can appear
after about 10 seconds. Use **L** to open the lobby for network play.
Developers can still run `godot --path .`; see `README.md` for build commands.

## Play with another member on the same LAN

### 1. Prepare every PC

1. Verify the same package revision/checksums on every PC.
2. Connect the PCs to the same trusted LAN; guest Wi-Fi/client isolation can prevent peers connecting.
3. Allow **DisasterParty.exe** through Windows Firewall on the trusted private network when prompted. The host must accept inbound UDP on the selected port; do not change shared firewall policy without permission.
4. Keep UDP port `29730` available.

The host can find their LAN IPv4 address with:

```powershell
ipconfig
```

Use the address shown for the active Ethernet or Wi-Fi adapter, such as `192.168.1.25`. Do not give another PC `127.0.0.1`; that address only works when both processes run on the same PC.

### 2. Start or join in game

Press **L** (or select **LOBBY**) to open the direct-IP panel. The host leaves the default UDP port or enters another port and selects **CREATE**. Each other player enters the host's LAN IPv4 address and the same port, then selects **JOIN**.

Each connected player selects **READY**. The panel lists every player as ready or waiting. When at least two players are connected and all are ready, the host selects **START MATCH** or presses **Enter**.

You can also launch directly from PowerShell. To host:

From the package directory in PowerShell:

```powershell
.\DisasterParty.exe --log-file host.log -- --host-port=29730
```

The host still uses the in-game lobby to mark ready and start the match.

Replace the sample address with the host's LAN IPv4 address:

```powershell
.\DisasterParty.exe --log-file client.log -- --join-address=192.168.1.25 --join-port=29730
```

The client marks ready in the in-game lobby and waits for the host to start the match.

Engine flags such as `--log-file` go **before** `--`; game/session flags go
**after** it. For two processes on one PC, join `127.0.0.1` instead. That tests
localhost transport only, even when using Windows executables.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Orbit camera |
| Shift | Sprint |
| Space | Jump |
| C | Crouch |
| F | Grab or release a nearby physics crate |
| L | Toggle the direct-IP lobby panel |
| R | Trigger the current knockdown test |
| Escape / controller B | Open local pause; Back from settings; Resume from pause (match keeps running) |
| Left click | Recapture the cursor |
| Q / E | Previous/next spectator target after death |

The HUD shows health at bottom-left, match time at top-center, and alive players at top-right. Large centered text names active disaster warnings.

When a match ends, every peer sees the same ranked results with winner, survival time, disasters survived, damage taken, and death cause. Gameplay HUD and local gameplay input are suppressed, and the cursor is released. The host selects **REMATCH** or presses **Enter** to start another round; clients remain connected and display **WAITING FOR HOST TO START REMATCH**. Tab or controller left/right moves between rankings and available actions; controller A confirms.

The host can instead select **RETURN TO LOBBY** to bring the session back to readiness without disconnecting anyone. All players must ready up again before the host starts. Solo results offer the same two actions; the returned offline lobby includes **START MATCH** to resume solo play. Every peer can open **SETTINGS** from results or the local pause menu. Master, effects and warning volume, mouse sensitivity, invert-Y, camera shake, fullscreen and reduced motion save automatically across restarts. Opening the menu blocks only your input: hazards, networking and the match timer keep running. Reduced motion disables UI transitions and camera shake; warning identity and audio remain available.

Warnings, impacts, jumping, death, and victory have synthesized placeholder audio. Flood, Meteor, and Tornado use distinct warning cues. Warning audio has a reserved voice so overlapping impact effects cannot silence it.

## Disaster timing

- About **0:10**: the first Meteor or Flood warning can begin.
- Before **2:00**: one Meteor or Flood runs at a time.
- At **2:00**: Tornado, Earthquake, and Lightning become eligible.
- At **5:00**: two compatible disasters can overlap, but only after both have completed alone at least once.
- At most two disasters overlap in the current prototype.

Implemented disasters are **Meteor Shower, Flood, Tornado, Earthquake, Lightning, and Fire**.

- **Flood:** ordinary water does not damage you while your head remains above the surface. A bottom danger card distinguishes wading, the two-second breathing grace, and `DROWNING` at 12 HP/s, with a head-above-water escape instruction. There is no full-screen blue overlay. Electrified water is a separate danger: even shallow foot contact causes damage, so leave the water entirely.
- **Flood + Lightning:** a strike in active floodwater electrifies the connected water for three seconds. Violet ripples and the `ELECTRIFIED WATER` warning identify it. Get onto raised ground immediately.
- **Tornado + Fire:** Tornado wind doubles Fire's spread frequency and carries one visibly flaming debris body. Keep away from both the funnel and orange Fire-zone rings.

Earthquake, Lightning, and Tornado become eligible as intensity rises after 2:00. Fire and two-disaster overlaps unlock at 5:00. A disaster must complete alone before the director can use it in an overlap.

To inspect the implemented visuals immediately without waiting for normal match timing, launch one of these local demo states:

```powershell
.\DisasterParty.exe -- --meteor-demo
.\DisasterParty.exe -- --flood-demo
.\DisasterParty.exe -- --flood-grace-demo
.\DisasterParty.exe -- --flood-damage-demo
.\DisasterParty.exe -- --tornado-demo
.\DisasterParty.exe -- --earthquake-demo
.\DisasterParty.exe -- --lightning-demo
.\DisasterParty.exe -- --fire-demo
.\DisasterParty.exe -- --electric-flood-demo
.\DisasterParty.exe -- --fire-tornado-demo
.\DisasterParty.exe -- --overlap-demo
.\DisasterParty.exe -- --results-demo
```

These are presentation/debug launches, not accelerated competitive matches.

## Current multiplayer limitations

- Source-project localhost sessions are validated. The package has passed standalone Windows launch; physical two-PC LAN and Internet play remain unverified. Do not infer these from native editor-driver checks against the exported PCK. Internet play may require UDP forwarding; router/shared-network changes require permission and are not part of the LAN smoke check.
- The host owns match state, health, movement, disasters, and winner decisions.
- There is a packaged Windows build, but no public lobby browser, Steam integration or NAT traversal; create/join uses direct IP.
- Only the host can initiate a network rematch; readiness is required before the initial network match, not between rematches.
- Audio is synthesized placeholder content rather than final authored sound design.

## Troubleshooting

- **Can connect but match does not start:** every player must select **READY**, then the host selects **START MATCH** or presses Enter.
- **Cannot connect:** verify host LAN IPv4, matching UDP port, matching package checksums, private-network firewall permission and Wi-Fi isolation. A failed join restores editable lobby fields; correct them and select **JOIN** again. Allow ENet time to detect a closed/unreachable host; recovery is not necessarily instant.
- **Host disconnects:** clients return to an offline lobby with cleared remote players and hazards. Restart/create the host, then use **JOIN** to retry. There is no host migration or automatic competitive-match resume.
- **Files/resources missing or build identity wrong:** re-extract the complete package, keep PCK beside EXE and rerun checksum checks. Do not repair a package by copying individual files from another revision.
- **Need logs:** launch with `--log-file host.log` / `client.log` before `--`; attach both logs and `BUILD.txt` when reporting a failure. The startup `DISASTER_PARTY_BUILD` line must agree with the build notes.
- **No disaster yet:** wait at least 10 seconds after the host starts the match. Overlap intentionally does not unlock until 5 minutes.
- **Mouse does not rotate the camera:** left-click the game window to capture the cursor.
- **HP is not changing:** damage only occurs when a disaster actually reaches the player; HP starts at 100.

## Physical LAN readiness checklist (Milestone 2.2 gate)

Use **two separate Windows PCs**, the same package, and the host's LAN address—not
localhost. This requires an actual person/PC session; automation cannot certify it.

- Record date, revision/checksums, host/client OS/GPU, resolution, network type,
  input devices, UDP port and logs. Keep private IPs/logs private when sharing publicly.
- Join, compare both rosters, ready both players and start from the host. Confirm
  clients cannot start; move both players and contend for/release a prop.
- Observe actual warnings and damage, death/spectating where survivors remain,
  and matching results. Complete **five host-initiated rematches** without restarting
  applications; check restored health/players/props and cleared stale hazards.
- On each PC, edit settings, close/relaunch, and verify persistence. Listen on real
  output devices: independent warning/effect volume and warnings during impacts.
  Record loudness/clarity complaints; WASAPI initialization alone proves neither.
- Close the host, observe client lobby recovery, recreate it and retry from the
  same client. Also try an unavailable port and confirm actionable failure/retry.
- Record pass/fail and reproduction details for each item. Leave the gate blocked
  if PCs/people are unavailable; do not advance to baseline human research on a
  localhost-only claim.

## Developer checks against the exported payload

The release template does **not** execute external `--script` fixtures. The
following uses the matching native Windows **editor** only as an external driver
for the exact shipped PCK (no source-project `--path` and no tests added to the
package). It covers settings restart/routing, session state and five rematches,
but does not replace release-runtime UI or physical LAN/audio testing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run_windows_package_checks.ps1 `
  -PackageDir C:\playtest\DisasterParty `
  -GodotEditor C:\tools\Godot_v4.7.2-stable_win64.exe `
  -OutputDir C:\playtest\checks-new -Port 29740
```

Run from the development checkout. Use the editor executable directly, not its
`_console.exe` launcher, and place it on a Windows-local drive rather than a WSL
UNC path. Output must be a fresh directory. The policy
override applies only to this process, not the machine. Logs identify the payload,
engine, test markers and evidence limitations; keep any failed checks visible.
