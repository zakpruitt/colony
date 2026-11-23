# 101 — What stands in a cave

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 100
- **Pull request:** —

## Intent

Spec 100 gave every room a shape, but what stands in the rooms is what stood in the boxes: a stalactite
here, a mushroom there, the same in every area but for a few glowing things deep down. Zak asked
(2026-11-22) for rooms "thematic to each zone, with stalagmites and other decor". This spec fills the
caves: stalagmites on the floors, stalactites gathered under the dips, columns where floor and ceiling
come close, and for each area things of its own, chosen from one table. It is drawing only.

## Requirements

- **R1. The simulation is untouched.** Nothing under `sim/` changes; state hashes and saves are as they
  are. Every new thing is decoration: drawn over the tiles and under the characters, lit and darkened as
  props are today, and in nobody's way.
- **R2. One table says what each area holds.** What a room is dressed with, beyond its torches and the
  props that say what kind of room it is (campfire, chest, bones, nest), comes from one table with a row
  per area: each kind of decoration, where it goes (floor, ceiling, floor to ceiling, back wall), and how
  often. The choices `ambience_level.gd` makes in code today (stalactite, mushroom, crate, puddle, glowing
  mushroom, crystal) become rows of it, and adding a kind to an area is adding a row.
- **R3. Stalagmites and columns.** A new sheet of stalagmites (three sizes, 8, 14 and 22 pixels high,
  a part for each look of earth as the stalactite has) stands on room floors. A stalactite and a
  stalagmite in one column make a pair; where the ceiling of a column is 4 or 5 rows over the floor a
  column (a new sheet, floor to ceiling, a part for each look and each height) may stand instead.
  Stalactites gather: under a dip of the ceiling they hang in groups of two to four of differing lengths.
- **R4. Each area has things of its own.** With the table's rows, across 20 rooms of each area:
  - Mossy Hollow: roots hanging from the ceiling (new sheet), mushrooms, stalactites and stalagmites,
    puddles.
  - The Claypits: urns and pots on the floor (new sheet), crates, puddles, a few squat stalagmites; no
    roots.
  - The Old Crypt: stone pillars floor to ceiling at even spacing in rooms 14 columns wide or more (new
    sheet), alcoves in the back wall holding a skull or a candle stub (new sheet, unlit), webs; no
    stalagmites, stalactites or mushrooms.
  - The Ember Deep: crystals singly and in clusters, glowing mushrooms, tall stalagmites and columns, the
    most stalactites of any area; no crates or urns.
  Each area shows at least two kinds no other area shows, and each "no" above holds.
- **R5. Nothing is in the way.** No decoration stands in a ladder's columns, in or over a doorway, in a
  tunnel's mouth, on a gate, a cache, a quest prop or a room's own props, within a tile of a torch's
  flame, or with any part in earth (the shape of the room, spec 100, is the truth). Nothing on the floor
  taller than 12 pixels stands in the middle third of a room 12 columns wide or less, where the fight is.
  No new prop gives light.
- **R6. A room is dressed to its size, and is its own.** A room holds between 1 and 1 per 2 columns of
  these decorations (tunable, in the table), never the same list as the room before it on the route more
  than 1 time in 10, and the same every time it is built, from the seed, the stage and the room alone.
  Cache rooms are dressed too, more sparsely. The ambience's budgets of lights and motes hold as they are.
- **R7. The new sheets are sprites like the rest.** Each is a `.px` in the master palette, baked, passes
  `python tools/art.py lint`, follows `docs/style-bible.md` for ambience props, and shows in the gallery.
  At most five new sheets: `stalagmite`, `column`, `roots`, `urn`, `crypt` (pillar and alcove parts).
- **R8. It looks like four places.** The lane looks, at 1280x720 and `--ui-room=960x540`, at three stages
  of each area and the gallery, and at 3x crops of a column, a stalactite group, a pillared crypt room, a
  root, and a fight in a small dressed room; and says what it saw, whether a fight is ever hard to read
  through the decoration, and which area is still thinnest.

## Interfaces

```gdscript
# game/ambience/ambience_decor.gd (new)
class_name AmbienceDecor
extends RefCounted
## What each area's rooms are dressed with: the table, and a room's list drawn from it.

## The kinds of decoration of the look at [param band], in the table's order.
static func kinds(band: int) -> Array[StringName]
```

The rest is the lane's. `ambience_level.gd` is 957 lines and gdlint stops a file at 1000: the dressing
of rooms moves out of it into the new script (or scripts) before anything is added.

Spec 099 (in review as this is written) owns `ambience.gd`, `ambience_rooms.gd`, `ambience_seen.gd`,
`ambience_darkness.gd`, `ambience_mood.gd` and the shaders: this spec touches none of them. Its black
covers whatever stands in an unseen room with no help from here.

## Acceptance

In `tests/acceptance/test_101_what_stands_in_a_cave.gd` (extends `ColonyTest`), on views made from a
winding simulation, 10 seeds, stages 1 to 4 unless said:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_simulation_is_as_it_was` | the state hash after 5 game minutes on 3 seeds equals the value recorded on `dev` before this spec |
| R2 | `test_r2_every_decoration_is_a_row_of_the_table` | every decoration placed in 20 rooms of each area is a kind of that area's row; a kind added to a copy of the table appears in rooms built from it |
| R3 | `test_r3_stalagmites_columns_and_groups` | stalagmites of three sizes on floor lines; a column's top on its column's ceiling and its bottom on the floor, only where they are 4 or 5 rows apart; under a dip, stalactites in twos to fours of more than one length |
| R4 | `test_r4_each_area_has_its_own` | over 20 rooms an area: each kind R4 names is seen, each "no" holds, and each area has two kinds no other has |
| R5 | `test_r5_nothing_is_in_the_way` | no decoration's rectangle meets a ladder's columns, a doorway, a tunnel's mouth, a gate, a cache, a quest prop, a room's own prop, a torch's flame tile or its neighbours, or earth; the middle third of small rooms holds nothing on the floor over 12 pixels; the count of lights is what it is without this spec's kinds |
| R6 | `test_r6_dressed_to_size_and_its_own` | counts within the bounds for every room and cache room; neighbouring rooms' lists differ 9 times in 10; a level built twice is dressed the same |
| R7 | (spec 002's tests, `art lint`) | the new sheets load, lint and show in the gallery |

R8 is the lane's report and Zak's playtest.

## Out of scope

- Anything in `sim/`, new tiles for the earth, changing how rooms are cut (`ZoneLook.CUTS`).
- New lights, new motes, animated decoration, sounds.
- What is seen and what is black (spec 099). Decoration in tunnels.
- Retuning the torches, the props that say a room's kind, or the things buried in the earth.

## Paths

- `game/ambience/ambience_decor.gd` (new) and other new scripts in `game/ambience/`,
  `game/ambience/ambience_level.gd`, `ambience_clearings.gd`, `ambience_prop.gd`, `ambience_mote_draw.gd`
- `assets/sprites/ambience/` (the five new sheets; `stalactite.px` if its parts must change)
- `game/art/gallery.gd`, `game/art/gallery.tscn` (only if a new sheet must be listed)
- `tests/acceptance/test_101_what_stands_in_a_cave.gd` (new), `tests/colony_test.gd`, `tests/support/`
- Existing tests that fail only because a room holds more or other decoration than it did, each repaired
  to prove what it proved, none removed, one line each in the report
- `docs/architecture.md`, `docs/standards.md` (a new kind of decoration is a row of the table; a new
  manner of cutting is a row of `ZoneLook.CUTS`), `docs/style-bible.md`, `docs/wiki/index.html`,
  `tools/test_times.json` (times for the 100 and 101 test scripts)

## Open questions

None.
