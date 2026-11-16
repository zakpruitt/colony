# 024 — Guardian fights that feel like boss fights

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 010, 011, 020, 021
- **Pull request:** —

## Intent

Guardians exist (spec 020), but a guardian fight looks and sounds like any other: the same numbers, the same
burst, no sense of occasion, and no way to see how close the party is to breaking the wall. This spec gives
the game's biggest moments their weight: the guardian is announced, its health is on screen for the whole
fight, and its death is the loudest, brightest thing in the game. It changes no rules.

## Requirements

Everything follows `docs/style-bible.md`: pixel font, palette colours, whole pixels, effects that end by
shrinking, blinking or flying away.

- **R1. The guardian is announced.** When an encounter with a guardian starts, its name appears large in the
  middle of the upper screen (for example `SLIME KING`) with a smaller `GUARDIAN OF DEPTH 5` under it, for
  about 2 seconds, the camera shakes once, and a low `guardian_appears` sound plays.
- **R2. Its health is on screen.** For the whole guardian fight, a wide health bar with the guardian's name
  sits at the top centre of the screen, between the depth panel and the gold. It empties smoothly as the
  guardian is hurt, flashes when it is hit, and is removed when the fight ends, however it ends. It never
  overlaps the HUD's other panels, the shop button or the shop.
- **R3. Its death is the biggest thing in the game.** When a guardian dies: the camera shakes hard, animation
  freezes for about 0.2 seconds, the guardian bursts into at least 60 particles in its own colours in two or
  three waves over about a second, at least 20 coins pour out (the gold itself is still exactly what the
  simulation paid), `GUARDIAN SLAIN` shows in gold for about 2.5 seconds, and a rising `guardian_slain`
  fanfare plays. The ordinary monster burst and death sound are replaced, not doubled.
- **R4. Losing to one is marked too.** When the party is wiped by a guardian, the bar is removed and the
  usual `WIPED` shows; nothing claims a victory.
- **R5. It stays within budget.** The effects layer's caps (numbers and particles) may be raised for a
  guardian's death only as far as needed, everything frees itself, and after 5 quiet seconds the effects
  layer has no children. Old events (after a stall or time away) start none of this.
- **R6. The two sounds are baked like the rest** (`python tools/sfx.py`), pass the sfx lint, and obey the
  sound player's limits.

## Interfaces

```gdscript
# game/hud/boss_bar.gd
class_name BossBar
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func is_showing() -> bool
func shown_fraction() -> float      # the eased health fraction on screen, 0 to 1
func shown_name() -> String

# game/hud/hud.gd gains
var boss_bar: BossBar
```

A guardian encounter is one whose battle has a monster whose `MonsterDef.guardian` is true
(`Content.monster(combatant.def_id)`); `Expedition.guardian_of(depth)` names the one a depth has, and
`SimEvent.Kind.GUARDIAN_SLAIN` marks the victory. A guardian's display name is its `MonsterDef`'s name.

## Acceptance

In `tests/acceptance/test_024_guardian_fights.gd`. Tests put a strong party beside a guardian's chamber (as
the 020 tests do) or feed events through `World.sim_event`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_guardian_is_announced` | Name and depth line on screen for about 2 s, a camera shake, the sound started; an ordinary encounter shows none |
| R2 | `test_r2_boss_bar` | Showing with the right name during the fight only; fraction follows health and eases; flashes on a hit; inside the top band between the panels; gone after a win and after a wipe |
| R3 | `test_r3_guardian_death` | Shake, freeze of about 0.2 s, at least 60 particles in colours from its sheet over about a second, at least 20 coins whose shares sum to the gold paid, the text, the fanfare; no ordinary burst or `monster_die` for it |
| R4 | `test_r4_losing_is_marked` | After a wipe at a guardian: no bar, `WIPED`, no `GUARDIAN SLAIN` |
| R5 | `test_r5_within_budget` | Counts under the stated caps; layer empty after 5 s; an old `GUARDIAN_SLAIN` starts nothing but credits coins |
| R6 | `test_r6_sounds_exist` | Both sounds load and are played through the player's limits; `python tools/sfx.py lint` passes |

**To look at, and for Zak:** in a throwaway scene you do not commit, put a level-9 party beside the Slime
King and take a sequence through the announcement, the fight and the death
(`python tools/dev.py shot --scene=... --seconds=0.5 --count=40`). Judge honestly, cropping and enlarging:
does the death look like the best moment in the game? Describe the shots in your report. Nobody on this run
can hear: say so, and check the two sounds on paper as spec 021 did.

## Out of scope

- The simulation: no rule, data or reward changes.
- New guardian sprites or changes to them.
- Music.

## Paths

- `game/hud/boss_bar.gd`, `game/hud/hud.gd` (creating and advancing the bar only)
- `game/effects/`
- `game/audio/sound_player.gd`, `assets/audio/sfx/` (the two new sounds)
- `tests/acceptance/test_024_guardian_fights.gd`, `tests/unit/test_effects*.gd`, `tests/unit/test_hud*.gd`
- Existing effects, HUD or sound tests only where they count sounds, caps or HUD children (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
