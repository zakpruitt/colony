# 021 — Sound effects, made the way the art is

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 008, 010
- **Pull request:** —

## Intent

The game is silent, and half of how a hit feels is how it sounds. This spec adds the first sounds: short,
chunky, 8-bit style effects for the moments the effects layer already marks. Like the sprites, they are made
inside the repository from small text recipes by a standard-library tool, so they can be reviewed, changed
and regenerated, and nothing is downloaded or licensed. Quiet by default, never harsh, and easy to mute:
this is an idle game that sits open for hours.

## Requirements

- **R1. Sounds are baked from recipes.** `python tools/sfx.py bake` turns every recipe under
  `assets/audio/sfx/*.sfx` (a small text format of the lane's design: waveform, pitch and pitch slide,
  length, volume envelope, optional noise) into a 16-bit mono WAV beside it, deterministically: baking twice
  gives identical bytes. `python tools/sfx.py lint` fails if a WAV is missing or stale, if a sound is longer
  than 1.2 seconds, or if its peak is above -3 dB. The lint runs in the check's `art` step.
- **R2. The first sounds exist:** `hit`, `crit`, `hero_hurt`, `heal`, `monster_die`, `hero_die`, `coin`,
  `level_up`, `bolt`, `wipe`, `revive`, `depth_stable`, `ui_click`, `ui_buy`. Each is recognisably different
  from the others and suits its moment (a coin is bright and short, a wipe falls, a level up rises).
- **R3. They play at the right moments.** Listening to `World.sim_event` and to the effects and HUD signals
  that exist, a sound plays for: a hit on a monster (`hit`, or `crit` on a crit), a hit on a hero
  (`hero_hurt`), a heal of at least 1, a monster's death, a hero's death, each coin collected, a level up, a
  projectile launched, a wipe, a revival, a new stable depth, and an upgrade bought (`ui_buy`). Events that
  are not recent (`World.is_recent`) play nothing.
- **R4. It never becomes noise.** The same sound does not start more than once every 0.05 seconds, at most 8
  sounds play at once, and repeated sounds vary slightly in pitch (within 6%) so a long fight does not drone.
  A burst of 500 hits in one frame plays at most one `hit`.
- **R5. Quiet, and mutable.** Sounds play on their own `SFX` audio bus at a modest default volume (-12 dB).
  The `M` key mutes and unmutes that bus, and the choice survives closing the game: it is kept in a small
  settings file under `user://`, separate from the save. Tests and screenshot runs never touch the real
  settings file.
- **R6. Silent where it should be.** While the game catches up on time away, and in headless runs, nothing
  plays and nothing errors.

## Interfaces

```gdscript
# game/audio/sound_player.gd
class_name SoundPlayer
extends Node
func setup(world: World, effects: CombatEffects, simulation: Simulation) -> void
## Plays a sound by name, subject to the limits of R4. Returns whether it started.
func play(sound: StringName) -> bool
func set_muted(muted: bool) -> void
func is_muted() -> bool
## How many sounds are playing now, and the names started since the last call (for tests).
func playing_count() -> int
func drain_started() -> Array[StringName]
```

`Main` creates the player after the world, effects and HUD exist (that is, after any catch-up) and calls
`setup`. Where the settings file lives and who owns it is the lane's choice (a small class under `game/`),
following `SaveStore`'s pattern of taking its path when created.

## Acceptance

In `tests/acceptance/test_021_sound_effects.gd`, plus Python tests for R1 in `tools/tests/`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_bake_and_lint` (py) | Baking a recipe twice gives identical bytes; lint fails for a missing WAV, a stale WAV, a sound over 1.2 s and a peak over -3 dB, naming the file |
| R2 | `test_r2_every_sound_loads` | Each named sound loads as an audio stream of the right length; no two have identical samples |
| R3 | `test_r3_sounds_follow_events` | Each listed event or signal starts its sound (read through `drain_started`); an old event starts none |
| R4 | `test_r4_never_noise` | The 0.05 s rule, the cap of 8, pitch within 6% and varying, and the 500-hit burst |
| R5 | `test_r5_quiet_and_mutable` | The bus exists at -12 dB; `M` toggles mute; a second player given the same settings path starts muted |
| R6 | `test_r6_silent_while_catching_up` | No player exists and nothing starts during a replay; the headless test run pushes no audio errors |

**To listen to, and for Zak:** nobody on this run can hear. Say so plainly in your report. Check what can be
checked without ears: plot or print each waveform's envelope and pitch contour, confirm no clipping, no
click at the start or end (the first and last samples are near zero), and that each sound's character matches
R2 on paper. Zak will judge them by ear.

## Out of scope

- Music, ambience loops (torches, drips), footsteps.
- A volume slider or settings screen.
- Audio files from anywhere outside the repository.

## Paths

- `tools/sfx.py`, `tools/tests/`, `tools/dev.py` (calling the sfx lint in the `art` step only)
- `assets/audio/`
- `game/audio/`, `game/main.gd` (creating the player and the `M` key only)
- `project.godot` or a bus layout resource (the `SFX` bus only)
- `tests/acceptance/test_021_sound_effects.gd`, `tests/unit/test_sound*.gd`
- `CLAUDE.md` (the sfx commands), `docs/style-bible.md` (a sound section), `docs/wiki/index.html`

## Open questions

None.
