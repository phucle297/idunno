# Disaster Party — Playtest Notes

Short control and bug-report notes for the playtest bundles produced by
`tools/export_playtest.sh`. Keep the notes beside the package files; they are
not part of the game payload.

## Packages

- Windows client: `DisasterParty.exe`, `DisasterParty.pck`, `BUILD.txt`.
- Linux server: `DisasterParty.x86_64`, `DisasterParty.pck`, `room_service.py`,
  `BUILD.txt`.

Both packages ship the same `DisasterParty.pck`. `BUILD.txt` names the exact
source revision and engine; `SHA256SUMS.txt` covers the runtime files (PowerShell:
`Get-FileHash <file> -Algorithm SHA256`; Linux: `sha256sum -c SHA256SUMS.txt`).
Do not repair a package by copying files between revisions.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Orbit camera |
| Shift | Sprint |
| Space | Jump |
| C | Crouch |
| F | Grab / release a nearby physics crate |
| G | Shove (no damage; cooldown applies) |
| V | Wave emote |
| B | Cheer emote |
| L | Toggle the direct-IP lobby panel |
| Q / E | Previous / next spectator target after death |
| Escape | Pause / settings (the match keeps running) |
| Left click | Recapture the cursor |

Results: the host picks `REMATCH` / `RETURN TO LOBBY` / `SETTINGS`; clients see
waiting text until the host starts. In-world warning text and HUD chips name the
active disaster and how to react.

## Bug reports

Include: the `BUILD.txt` revision; steps to reproduce; expected versus actual
behavior; the log file (launch with `--log-file client.log` before `--`); a
screenshot or short video; player count and host/join setup; network conditions
(same LAN, Internet, VPN) and whether it reproduces after a restart. Keep failing
checks visible and do not edit package files to work around a problem.
