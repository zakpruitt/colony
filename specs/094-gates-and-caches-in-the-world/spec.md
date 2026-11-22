# 094 — Gates and caches in the world

- **Status:** draft
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 093
- **Pull request:** —

## Intent

Spec 093 lets the party open gates and caches, but the world draws nothing for them: the party stops at a
bare wall, walks into an empty room and comes back richer. This spec shows it: each kind of gate standing
where its side path leaves, closed or open; the hero who can open it working at it; the cache glinting at
the end of the path and bursting open; and a gate nobody can open saying what it wants. Spec 095 tells the
same things in words (the journal, the tally, the away report).

## Requirements

- **R1. A gate stands where its side path leaves.** On the stage shown, every side path's gate is drawn on
  its room's floor at the gate's place (`SidePath.at` on the main course), by its kind: a barred door with
  a lock (`locked_gate`), a heap of rubble (`rubble`), a slab cut with a glowing rune (`rune_seal`), a
  cracked wall with a draught of motes (`hidden_crack`). While its cache is full the gate is closed; from
  `GATE_OPENED` until the cache refills it is drawn open (the door ajar, the rubble cleared to the sides,
  the slab dark and split, the crack widened), and the party walks through it. The four are new sprites in
  the palette, each with a closed and an open part.
- **R2. The opener is seen working.** While a gate is worked the worker stands beside it on the side the
  party came from and swings on the slow repeat a side quest uses, a bar over the gate fills with
  `Expedition.work_progress()`, and the microskill's name shows over the worker, as for a side quest.
- **R3. A cache waits and glints.** The cache room holds a cache prop at its middle on its floor (a new
  sprite: a banded strongbox, with a closed and an open part). Full and outside the party's light it
  carries the glint a waiting side quest carries; empty it stands open with no glint until it refills.
- **R4. Opening a cache is a moment.** On a fresh `CACHE_OPENED` the cache opens with a burst of sparks
  under the quest budget, and that tick's gains leave from it: the coins fly to the purse, the resource
  icons to their count and the XP motes to each hero's frame, as a kill's do from a monster. One sound
  plays for a gate opening and one for a cache (two new recipes). A hero levelled by it gets the usual
  level-up.
- **R5. A gate nobody can open says what it wants.** On a fresh `GATE_SEALED` a line rises from the gate
  for about two seconds: `Needs a <microskill name>`. A closed gate under the mouse shows a tip with its
  name, its description, and either who will open it (`The Rogue can open this`) or what would
  (`A Runereader could open this: the Mage learns it at level 4`), named from the party's own heroes and
  their classes; with no hero of a class that learns it, `Nobody in the party learns this`.
- **R6. Nothing plays for a stale event.** Every move, effect and sound here asks `World.may_animate`; a
  stall or the time away leaves the gates and caches in their true state (open or closed, full or empty)
  with nothing playing, and a change of stage or area clears and rebuilds them.
- **R7. The showcase shows them.** `Showcase.ROWS` gains three moments, each begun and seen as its
  neighbours are: a gate being opened, a cache opening, a gate nobody can open.
- **R8. It reads at a glance.** The lane looks at each gate closed and open, the work, the cache full,
  opening and empty, and the sealed line and the tip, in 3x crops and whole at 1280x720 and
  `--ui-room=960x540`, in two areas, and says what it saw. The sprites are placeholders in the style
  bible's rules; Zak makes final art.

## Interfaces

A gate's and a cache's sprite is found by its id (`assets/sprites/props/<gate id>.png`, `cache.png`), as a
side quest's prop is; no rule or data field names a picture. What draws them is the lane's (extending
`QuestProps` or a class beside it); it reads `LabyrinthLevel.side_paths`, `SidePathRules.is_full` and the
events of spec 093, and changes nothing in `sim/`.

## Acceptance

In `tests/acceptance/test_094_gates_and_caches_in_the_world.gd` (extends `ColonyTest`), on a winding world:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_each_gate_stands_closed_then_open` | every side path of 5 stages has its gate's sprite at its place on its room's floor; closed before, the open part after `GATE_OPENED`, closed again after the refill; each of the four kinds is seen |
| R2 | `test_r2_the_opener_works_at_the_gate` | the worker's place and side, the bar's fraction against `work_progress()`, the name shown, in rooms walked both ways |
| R3 | `test_r3_a_cache_glints_until_it_is_opened` | the prop on its floor, the glint outside the light and none inside, open and dark after, back after the refill |
| R4 | `test_r4_a_cache_bursts_and_pays_from_where_it_stands` | effects under the quest budget start at the cache; coins, icons and motes leave from it; the two sounds are asked for once each |
| R5 | `test_r5_a_sealed_gate_says_what_it_wants` | the rising line's words; the tip's three wordings with parties that can, will later, and never will |
| R6 | `test_r6_nothing_plays_for_old_events` | after a stall and after time away: states true, no effect, no sound; the effects layer is empty a few seconds after a cache |
| R7 | (spec 018's test) | every showcase row plays, the three new ones among them |

R8 is the lane's report and Zak's playtest.

## Out of scope

- Words in the journal, the ticker, the tally and the away report: spec 095. An order to press on: 096.
- Anything in `sim/` or `data/`. New kinds of effect beyond a burst of the existing particles.
- Darkness over unexplored rooms.

## Paths

- `game/world/`, `game/effects/`, `game/audio/`, `game/dev/` (the showcase's rows and moments)
- `assets/sprites/props/` (five new `.px` with their baked sheets), `assets/audio/` (two new `.sfx` with
  their baked sounds), the art's reference lists if the lint needs them
- `tests/acceptance/test_094_gates_and_caches_in_the_world.gd` (new), `tests/colony_test.gd`, `tests/support/`
- Existing tests that count every prop sheet, every sound or every showcase row, to add the new ones only
  (named in the report)
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None, once 093 has landed and its events are checked against this text.
