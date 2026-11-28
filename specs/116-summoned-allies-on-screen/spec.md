# 116 — Summoned allies on screen

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M9
- **Depends on:** 056, 057, 076, 115 (and 113, whose Paths hold `world.gd` and the tally)
- **Pull request:** —

## Intent

Spec 115 lets an ability bring a short-lived fighter onto the heroes' side, in the simulation only.
This spec shows it: a summon appears beside its summoner with a puff, walks or stands, strikes with
the moves heroes and monsters already have, shows its numbers in its summoner's colour, and is
counted to its summoner in the tally. Every summon is drawn with one placeholder sheet until a class
spec gives it its own; Zak draws the creatures later. No ability in `data/` summons yet, so the tests
and the look come from abilities built for them.

## Requirements

- **R1. A summon is drawn.**
  - For a recent `SUMMONED` heard while not catching up (`World.may_animate`), a sprite appears at
    the summon's place, facing the monsters, with a puff (`FxParticle.Shape.PUFF`, in `World.fx`).
    For a stale one, or while catching up, it appears with no puff if the summon still stands, and
    not at all if it has ended.
  - Its sheet is `assets/sprites/summons/<summon id>.png` when there is one, else
    `assets/sprites/summons/placeholder.png`: a small creature, at most 12 pixels tall, in the master
    palette, passing the art lint, with the poses `CharacterSprite` plays (idle, walk, strike, hit,
    fall).
  - It stands where the simulation has it each frame, walking when it moves, as a monster's sprite
    does.
- **R2. A summon fights on screen.** Its strikes, wind-ups, projectiles, hits taken, statuses and
  abilities play with the moves, effects and sounds a fighter's already have (specs 056 and 057).
  Its damage and healing numbers are drawn in its summoner's class colour.
- **R3. A summon ends on screen.** On `SUMMON_ENDED`, its sprite fades over 0.3 s with a puff and is
  removed: for every reason, including a fall (no death pose and no skull, since it is not a death).
  A stale one, or one heard while catching up, removes it at once. No summon's sprite stays after a
  fight, and none is in `World.effects_layer`.
- **R4. The tally credits the summoner.** A summon's damage, healing and kills count to its summoner
  (`Combatant.owner_id`, or the `SUMMONED` event's source), in every measure and both spans. In the
  summoner's line, opened by ability, the summon's share stands as its own line under its name
  (`Hawk 412`). Damage a summon takes is not the party's: it is not on the Taken tab.
- **R5. No view mistakes it.** Wherever the view names or colours the fighter an event comes from or
  lands on (the hero window's "Fighting" line, the journal, a status icon, a name over an ability),
  a summon is named by its `SummonDef.display_name` and coloured as its summoner, and nothing raises
  an error or reads a hero that is not there. The hero frames, hero windows and goals are for heroes
  only and show no summon.
- **R6. Light enough for the late game.** Summons are hot code: a fight at depth may hold a dozen.
  - Code that runs per summon per event or per frame does no text measuring, tree search, string
    key formatting or pixel reading (CLAUDE.md, "hot"). The reviewer checks this in the diff.
  - Over 300 ticks of a fight in which twelve summons come and go, each summon gets one sprite for
    its life (`CharacterSprite` sprites made equals summons summoned), and the puffs stay within
    their `FxPool` budget (no add refused).

## Interfaces

```gdscript
# game/entities/character_sprite.gd
const SUMMONS_DIR: String = "res://assets/sprites/summons"
## The summon [param summon_id]'s sheet, or the placeholder when it has none of its own.
static func for_summon(summon_id: StringName) -> CharacterSprite

# game/world/summon_sprites.gd (new): the listener that adds, moves and removes summons' sprites
# through the World, connecting its own _on_sim_event to World.sim_event. world.gd is 882 lines.
class_name SummonSprites
extends Node
```

## Acceptance

In `tests/acceptance/test_116_summoned_allies_on_screen.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail. A hero is given a summoning ability built
in the test (spec 115's test hawk and turret), through `make_main()` and the real frame.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_summon_is_drawn` | The sprite at the summon's place with the placeholder sheet, a puff for a recent one, none for a stale one, nothing for an ended one; it follows the simulation's place |
| R2 | `test_r2_fights_on_screen` | A strike move and a number in the summoner's colour; a status icon on it |
| R3 | `test_r3_ends_on_screen` | A fade and a puff for each reason, no death pose; none left after the fight; the effects layer empty after quiet seconds |
| R4 | `test_r4_the_tally_credits_the_summoner` | The summoner's damage and kills include the summon's; the summon's line by ability; nothing on Taken |
| R5 | `test_r5_no_view_mistakes_it` | The events of a fight with summons pass through every listener with no error, and each name and colour read is the summon's or its summoner's |
| R6 | `test_r6_light_enough` | Twelve summons over 300 ticks: one sprite each, no puff refused by the pool |

`python tools/art.py lint` passes with the new sheet.

**To look at, and for Zak:** a throwaway scene under `.shots/` that `extends Main` and gives the
Knight a summoning ability built in code: three frames of a hawk arriving, striking and ending, and a
turret holding its place, at 1280x720 (cropped and enlarged 3x where small); the tally with a
summon's line. Describe each shot.

## Out of scope

- A class's own creature sheets (each class spec draws its own; until then the placeholder).
- New sounds, a new effect beyond the puff, a death pose for summons.
- A showcase moment: the first class spec with a summon adds one, with its own creature.
- Any rule change (spec 115).

## Paths

- `game/world/summon_sprites.gd` (new, with its `.uid`), `game/world/world.gd` (only the summons'
  sprites: making the listener and letting it add, move and remove sprites),
  `game/world/fight_moves.gd`
- `game/entities/character_sprite.gd`
- `assets/sprites/summons/placeholder.px` and its baked `.png` and `.json`
- `game/hud/tally.gd`, `game/ui/windows/tally_window.gd`
- `game/effects/ability_effects.gd`, `game/hud/status_icons.gd`, `game/ui/windows/hero_window.gd`,
  `game/hud/journal.gd` (each only where R5 needs it)
- `tests/acceptance/test_116_summoned_allies_on_screen.gd` and its `.uid`
- `docs/architecture.md` (summons in the view), `docs/style-bible.md` (only if the placeholder adds a
  convention)

## Open questions

None.
