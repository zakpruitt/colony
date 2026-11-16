# 020 — Guardians: a boss at the bottom of every band

- **Status:** provisional
- **Milestone:** M3
- **Depends on:** 005, 007, 008, 013, 015
- **Pull request:** —

## Intent

Going deeper is a smooth ramp: every level is a little harder than the last and nothing marks an arrival.
This spec gives the descent landmarks. On every fifth level, the chamber that holds the way down is held by
a guardian: one very large, very tough monster the party must beat to go deeper. A guardian is a wall the
party throws itself at, falls back from, grows, and finally breaks, which is the loop of the whole game in
one fight, and beating one pays out like nothing else. Read `docs/design/base-game.md`, and look at the cast
(`python tools/dev.py shot --scene=res://game/entities/character_demo.tscn`).

## Requirements

- **R1. Four guardians exist as data,** each a valid `MonsterDef` of size `BOSS` under `data/monsters/`,
  flagged as a guardian so it never appears in an ordinary encounter:

  | Id | Guards depth | Character |
  |---|---|---|
  | `slime_king` | 5 | A huge crowned slime: enormous health, slow heavy slams |
  | `clay_colossus` | 10 | A towering clay giant: armoured, hits very hard and very slowly |
  | `bone_lord` | 15 | A giant armoured skeleton with a great blade: fast for its size, crits |
  | `deep_maw` | 20 and every fifth level below | A vast thing of the deep, all mouth and tentacles |

- **R2. A guardian holds the way down.** On every level whose depth is a multiple of 5, the chamber holding
  the shaft down contains that depth's guardian and nothing else, whatever the chamber's kind. The party
  cannot reach the shaft without fighting it. Levels that are not multiples of 5 are unchanged.
- **R3. Guardians stay beaten for a long time.** A beaten guardian's chamber stays empty for
  `GUARDIAN_RESPAWN_SECONDS` (1800) instead of the usual respawn time, so the party can pass up and down
  freely after a victory.
- **R4. Beating one pays.** A guardian gives XP and gold worth at least ten ordinary kills of its depth, and
  its death is followed by a `GUARDIAN_SLAIN` event (source: the guardian's id, amount: the depth).
- **R5. A guardian is a wall, then a milestone.** At depth 5, a party of four level-5 heroes with no upgrades
  loses to the Slime King at least 70% of the time, and a level-9 party beats it at least 70% of the time
  (200 seeds each, within the battle time limit). The same shape holds at depth 10 with levels 10 and 15.
- **R6. The loop still runs.** With `stable_seconds` 120 over one hour on five seeds, every run still
  becomes stable below depth 2, at least three of five runs beat the first guardian, and no run is stuck:
  after any wipe at a guardian the party revives, fights elsewhere and returns. Existing tests keep their
  numbers; if one fails only because guardians now gate the descent, tune the guardians (not the test)
  unless the test asserts the composition of the shaft chamber on a guardian level, which may be updated.
- **R7. Each has a sprite.** A baked, lint-clean `boss` sheet (64x64) per guardian under
  `assets/sprites/monsters/`, in the cast's style, built from parts that animate (a body, and at least one
  of head, arm, weapon or tentacle), unmistakably bigger and more dangerous than anything else in its band.
- **R8. They show in the game.** `CharacterSprite.for_monster` builds each guardian and it idles, attacks,
  flinches and dies without errors; in the main scene a guardian stands on the floor of its chamber (feet on
  the floor line, not sunk or floating, not clipped by the ceiling), and the cast demo shows all four.

## Interfaces

```gdscript
# sim/defs/monster_def.gd gains
@export var guardian: bool = false

# sim/expedition/expedition.gd gains
const GUARDIAN_EVERY: int = 5
const GUARDIAN_RESPAWN_SECONDS: float = 1800.0
## The id of the guardian that holds that depth's way down, or &"" if the depth has none.
func guardian_of(level_depth: int) -> StringName

# sim/sim_event.gd: Kind.GUARDIAN_SLAIN (source_id = the guardian's combatant id, amount = the depth)
```

Put `GUARDIAN_SLAIN` where it does not break the 005 test that expects every kind from `ENCOUNTER_STARTED`
onward to occur in a plain run (beside `UPGRADE_BOUGHT`, before `ENCOUNTER_STARTED`), or make sure a plain
one-hour run produces it. Chambers shorter than a guardian is tall: the generator's chambers are at least 4
tiles high and a boss sprite is 4 tiles; if a guardian chamber is too low for the sprite, report it rather
than changing the generator.

## Acceptance

In `tests/acceptance/test_020_guardians.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_four_guardians_are_valid` | Each loads, validates, is size BOSS and flagged; over 300 ordinary encounters at depths 1 to 25, none contains a guardian |
| R2 | `test_r2_guardian_holds_the_way_down` | At depths 5, 10, 15, 20, 25 (several seeds) the shaft chamber holds exactly its guardian; at depth 6 it does not; the party at depth 5 with a deeper target enters a battle with the guardian before it can climb |
| R3 | `test_r3_guardians_stay_beaten` | After a win the chamber is empty until `GUARDIAN_RESPAWN_SECONDS`, then holds the guardian again |
| R4 | `test_r4_beating_one_pays` | XP and gold against ten ordinary kills; the event with its fields |
| R5 | `test_r5_wall_then_milestone` | The four win-rate statements |
| R6 | `test_r6_the_loop_still_runs` | The five-seed statements |
| R7, R8 | `test_r8_guardians_build_and_animate` | Each builds in the boss category and runs idle, attack, hit, death without pushed errors; the demo lists all four |
| R8 | `test_r8_guardian_stands_in_its_chamber` | In a `World` at depth 5 the guardian's sprite has its feet on the floor line and its top below the chamber's ceiling |

**To look at, and for Zak:** the cast demo, and the guardian in the game: in a throwaway scene you do not
commit, put the party at depth 5 next to the guardian's chamber and take a sequence through the fight. Judge
honestly: is it a boss at a glance? Describe each guardian and the fight in your report.

## Out of scope

- Special boss attacks, phases, minions, or any new battle rule: a guardian fights by the existing rules.
- A boss health bar on the HUD, boss music, a bigger death effect (later specs).
- Changing the labyrinth generator, the existing monsters or the heroes.

## Paths

- `data/monsters/` (new files), `assets/sprites/monsters/` (new files)
- `sim/defs/monster_def.gd`, `sim/expedition/expedition.gd`, `sim/expedition/chamber_state.gd`, `sim/sim_event.gd`
- `game/entities/character_sprite.gd`, `game/entities/character_demo.gd`, `game/world/world.gd` (only what a
  boss-sized sprite needs to be built and stand correctly)
- `tests/acceptance/test_020_guardians.gd`, `tests/unit/test_expedition*.gd`
- Existing tests only where they count the whole cast or assert a guardian level's shaft chamber (say which)
- `docs/style-bible.md` (the cast table), `docs/wiki/index.html`

## Open questions

None.
