# Disaster Party Play Guide

This repository is a Godot prototype, not a packaged Steam build. Every player currently needs the same checkout and Godot 4.7.2 stable. Multiplayer uses direct ENet IP connections; there is no lobby browser or Steam invite flow yet.

## Play alone

Open `project.godot` in Godot and press **F5/Run Project**, or run:

```bash
godot --path .
```

The match starts automatically. The first disaster warning appears after about 10 seconds.

## Play with another member on the same LAN

### 1. Prepare every PC

1. Install Godot 4.7.2 stable.
2. Check out the same repository commit on every PC.
3. Allow Godot through Windows Firewall on private networks when prompted.
4. Keep UDP port `29730` available.

The host can find their LAN IPv4 address with:

```powershell
ipconfig
```

Use the address shown for the active Ethernet or Wi-Fi adapter, such as `192.168.1.25`. Do not give another PC `127.0.0.1`; that address only works when both processes run on the same PC.

### 2. Start the host

From the repository directory in PowerShell:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --host-port=29730
```

The host screen displays **ENTER TO START**. Wait until the top-right alive count includes everyone, then press **Enter**. At least one other player must be connected.

### 3. Join from each member's PC

Replace the sample address with the host's LAN IPv4 address:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --join-address=192.168.1.25 --join-port=29730
```

The client screen displays **WAITING FOR HOST** until the host starts the match.

For two processes on one development PC, join `127.0.0.1` instead.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Orbit camera |
| Shift | Sprint |
| Space | Jump |
| C | Crouch |
| F | Grab or release a nearby physics crate |
| R | Trigger the current knockdown test |
| Escape | Release the cursor |
| Left click | Recapture the cursor |
| Q / E | Previous/next spectator target after death |

The HUD shows health at bottom-left, match time at top-center, and alive players at top-right. Large centered text names active disaster warnings.

## Disaster timing

- About **0:10**: the first Meteor or Flood warning can begin.
- Before **2:00**: one Meteor or Flood runs at a time.
- At **2:00**: Tornado becomes eligible.
- At **5:00**: two compatible disasters can overlap, but only after both have completed alone at least once.
- At most two disasters overlap in the current prototype.

Implemented disasters are **Meteor Shower, Flood, and Tornado**. Earthquake, Lightning, Fire, and true cross-disaster interactions are not implemented yet. Current overlap means two disasters coexist; it does not yet include effects such as electrified floodwater.

To inspect the implemented visuals immediately without waiting for normal match timing, launch one of these local demo states:

```powershell
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --meteor-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --flood-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --tornado-demo
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path . -- --overlap-demo
```

These are presentation/debug launches, not accelerated competitive matches.

## Current multiplayer limitations

- LAN and same-PC direct-IP sessions are validated. Internet play requires router/firewall UDP forwarding and is not validated.
- The host owns match state, health, movement, disasters, and winner decisions.
- There is no in-game lobby browser, ready button, Steam integration, or packaged Windows build.
- Network rematch is not implemented; close and relaunch host/client processes after results.
- Audio is not implemented in the current prototype.

## Troubleshooting

- **Can connect but match does not start:** the host must press Enter after at least two players are present.
- **Cannot connect:** verify the host IP, UDP port `29730`, matching commits, and Windows Firewall permissions.
- **No disaster yet:** wait at least 10 seconds after the host starts the match. Overlap intentionally does not unlock until 5 minutes.
- **Mouse does not rotate the camera:** left-click the game window to capture the cursor.
- **HP is not changing:** damage only occurs when a disaster actually reaches the player; HP starts at 100.
