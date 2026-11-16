# 015 — Standing room: fights and climbs you can read

- **Status:** provisional
- **Milestone:** M2
- **Depends on:** 004, 005, 008
- **Pull request:** —

## Intent

Now that the simulation is on screen, two things it does read badly. In a fight, everyone who attacks the same
target stands on the same spot: the knight and rogue are drawn on top of each other, the cleric hides behind
the mage, and five monsters become one heap. On a ladder, the party climbs against the shaft's left wall,
half inside the rock. Both come from where the simulation puts people, so both are fixed there. The view is
not changed. Look first: `python tools/dev.py shot --name=before --seconds=4 --count=8`.

## Requirements

- **R1. Fighters keep their distance from their own side.** In a battle, two living combatants on the same
  side that are standing (not walking) are never closer than `Battle.MIN_SPACING` (0.6 tiles). A combatant
  whose way to its usual striking distance is taken by an ally stops behind that ally instead.
- **R2. Standing behind does not stop you fighting.** A melee combatant held back by R1 strikes its target
  from where it stands, over its ally's shoulder: nobody waits for a turn at the front, and nobody is locked
  out of a fight by its own side. Ranged combatants and healers keep their normal range.
- **R3. The front line makes sense.** Among heroes attacking the same target, the tank stands closest to the
  enemy, then other melee, then ranged, then the healer furthest back. Monsters stand in the order they
  arrived.
- **R4. Fighters stay in the chamber.** R1 never pushes anyone outside the battle's span. If a side truly
  cannot fit at that spacing in a small chamber, it closes up evenly rather than leaving the span, and that is
  the only case in which R1 gives way.
- **R5. The fight is the same fight.** Every existing test passes with its numbers unchanged: the win rates of
  spec 004, the one-hour statements of spec 005, and (if it has landed) the stone-band statements of spec 013.
  If spacing shifts a result outside a tested range, tune `MIN_SPACING` or how R2 is done, not the data and
  not the tests. One exception: `test_r14_events_cover_the_loop` in the 005 tests starts the knight at a
  health chosen so that one particular fight leaves it just under the rest threshold, which depends on the
  exact order of blows. Its starting health may be lowered so the party rests by a clear margin.
- **R6. Climbers are on the ladder.** While climbing, a hero's position is the middle of the shaft
  (`shaft_down.position.x + Labyrinth.SHAFT_WIDTH / 2.0`), so a sprite drawn with its feet at that position
  is centred on the ladder, clear of both walls. Where the party stands to start a climb and where it lands
  follow from that.
- **R7. It looks right.** In the running game, a fight shows four distinct heroes and countable monsters, and
  a climb shows the party on the ladder.

## Interfaces

```gdscript
# sim/combat/battle.gd
const MIN_SPACING: float = 0.6  # tiles between two standing combatants of one side
```

Nothing else changes shape: no new events, no new fields the view must read. `Combatant.x` and
`Expedition.hero_position` simply hold better positions.

## Acceptance

In `tests/acceptance/test_015_standing_room.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_same_side_keeps_spacing` | Over 50 seeded battles of the starting party against 3, 4 and 5 monsters in chambers at least 10 tiles wide, at every tick, every pair of living same-side combatants that are not walking is at least `MIN_SPACING` apart |
| R2 | `test_r2_held_back_fighters_still_strike` | With four melee monsters on one hero, all four land hits within their normal attack time plus a walk; a knight and rogue on one target both land hits |
| R3 | `test_r3_front_line_order` | Five seconds into a fight, the heroes' distances to the nearest monster are ordered tank, melee, ranged, healer |
| R4 | `test_r4_stays_in_the_span` | Five monsters and four heroes in a 4-tile span: nobody leaves it, at every tick |
| R5 | (the existing suite) | `python tools/dev.py check` passes with no existing test's numbers changed |
| R6 | `test_r6_climbers_are_centred` | Throughout a descent and an ascent, each climbing hero's x is the shaft's middle |

**To look at, and for Zak:** `python tools/dev.py shot --name=room --seconds=4 --count=10`, and a run long
enough to catch a climb (set a target depth, or use a throwaway scene you do not commit). Compare with the
"before" shots and describe both in your report: can you count the heroes and the monsters in a fight?

## Out of scope

- The view (`game/`): no visual offsets, no changes to how positions are drawn.
- New rules beyond spacing: flanking, blocking, knockback, formations the player chooses.
- Monster or hero data.

## Paths

- `sim/combat/battle.gd`, `sim/combat/combatant.gd`
- `sim/expedition/expedition.gd` (climb positions only)
- `tests/acceptance/test_015_standing_room.gd`, `tests/unit/test_battle*.gd`, `tests/unit/test_expedition*.gd`
- An existing test only where it asserts an exact position this spec moves (say which in your report)
- `docs/wiki/index.html`

## Open questions

None.
