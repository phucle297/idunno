# Quaternius Animation Clip Inspection

## Verification status

The official Quaternius pack page was checked on 2026-10-05 and advertises 120+ animations with FBX, GLB, and Blend formats. The download is delivered through itch.io, which returned a Cloudflare browser challenge in this environment, so the official archive has **not** been downloaded or verified.

As secondary evidence only, commit `8456155dbae7eb861f553a2341871ccae633c857` of the third-party repository `IAFahim/quaternius.universalAnimationLibrary.standard` was inspected. That repository contains one 24 MB FBX, a CC0 license, and a link to the official pack page, but no original archive name, source checksum, version, download date, or unchanged-mirror claim. Its FBX SHA-256 is `05b7912f6926eb023b3bf5133012dca1ee27e41f453909857e1d471e9eacef12`.

Godot 4.7.2 imported that FBX successfully and enumerated these 45 embedded clips:

```text
Armature|A_TPose
Armature|Crouch_Fwd
Armature|Crouch_Idle
Armature|Dance
Armature|Death01
Armature|Driving
Armature|Fixing_Kneeling
Armature|Hit_Chest
Armature|Hit_Head
Armature|Idle
Armature|Idle_Talking
Armature|Idle_Torch
Armature|Interact
Armature|Jog_Fwd
Armature|Jump
Armature|Jump_Land
Armature|Jump_Start
Armature|PickUp_Table
Armature|Pistol_Aim_Down
Armature|Pistol_Aim_Neutral
Armature|Pistol_Aim_Up
Armature|Pistol_Idle
Armature|Pistol_Reload
Armature|Pistol_Shoot
Armature|Punch_Cross
Armature|Punch_Jab
Armature|Push
Armature|Roll
Armature|Roll_RM
Armature|Sitting_Enter
Armature|Sitting_Exit
Armature|Sitting_Idle
Armature|Sitting_Talking
Armature|Spell_Simple_Enter
Armature|Spell_Simple_Exit
Armature|Spell_Simple_Idle
Armature|Spell_Simple_Shoot
Armature|Sprint
Armature|Swim_Fwd
Armature|Swim_Idle
Armature|Sword_Attack
Armature|Sword_Attack_RM
Armature|Sword_Idle
Armature|Walk
Armature|Walk_Formal
```

## Required-clip coverage in the inspected FBX

| Design-bible requirement | Secondary evidence | Status |
| --- | --- | --- |
| Idle | `Armature\|Idle` | Present by name |
| Walk | `Armature\|Walk` | Present by name |
| Run | `Jog_Fwd`, `Sprint` | Candidate clips; tuning choice untested |
| Jump takeoff | `Jump_Start` | Present by name |
| Falling | `Jump` | Possible airborne loop; behavior untested |
| Landing | `Jump_Land` | Present by name |
| Crouch idle | `Crouch_Idle` | Present by name |
| Crouch walk | `Crouch_Fwd` | Present by name |
| Holding idle | None by name | Missing or unidentified |
| Holding walk | None by name | Missing or unidentified |
| Getting up | None by name | Missing or unidentified |

Do not import or retarget this third-party mirror as though it were the official archive. Obtain the official free download, preserve its bundled license, hash it, enumerate its embedded clips, and compare those results before selecting animation sources.
