# 053 — The area map: choosing where the party goes

- **Status:** provisional (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 030, 037, 042, 049
- **Pull request:** —

## Intent

Spec 049 gave the simulation areas but no way to choose one. This spec gives the player a map: every
area, what lives there, how far the party has got, and a way to send the party to a stage of it. Zak asked
for "difference and intentionality of where you go"; this is where that choice is made.

## Requirements

- **R1. A map of every area.** A panel, opened with <kbd>W</kbd> or by clicking the area's name in the
  depth panel, lists every area in order. Each shows its name, the monsters that live there (their
  sprites, with names on hover), its guardian and whether the party has beaten it, the party's safe and
  furthest stage there, and the level of its first stage. The area the party is in is marked `Here`.
- **R2. Closed areas say how to open them.** An area that is not open is dimmed, cannot be chosen, and
  says which guardian opens it (`Beat the Slime King in Mossy Hollow`).
- **R3. Sending the party.** Choosing an open area shows a stage, starting at that area's safe stage,
  with buttons to change it between 1 and one past its furthest stage, and a `Go` button. `Go` sends the
  party (`Simulation.set_destination`) and closes the map. For the area the party is in, `Go` sets the
  target stage as the ladder does.
- **R4. The warning travels.** The stage shown is coloured safe, within reach or dangerous by the ladder's
  rule (spec 043), judged by that area's levels, and a dangerous `Go` writes the same warning in the
  journal.
- **R5. On the way.** While the party is on a journey the map marks the destination `On the way` and the
  seconds left. A new choice during a journey redirects it.
- **R6. The game tells you when there is somewhere new.** When an area opens, the journal says so, a goal
  appears (`Visit The Claypits`) that opens the map when clicked and is done when the party first
  arrives there, and the map's button shows a mark until the map has been opened.
- **R7. True in a crowded frame.** Everything the map and its goal show follows events in the order they
  happened, so a frame that steps many ticks at once (4x, a hitch, a return from time away) leaves them
  right. One test steps a guardian's death, a journey and an arrival before a single frame.
- **R8. Found and explained.** <kbd>W</kbd> is in the help list; the map closes with <kbd>Esc</kbd> and
  with <kbd>W</kbd>; every control has a tooltip; the panel fits 640x360 with four areas and has room
  for six.
- **R9. In the showcase.** The showcase gains a moment that opens the map with two areas open and one
  closed, and a moment for a journey and arrival.

## Interfaces

```gdscript
# game/hud/area_map.gd (new)
class_name AreaMap extends HudPanel
func open() -> void
func choose(area_id: StringName) -> void
func stage_shown() -> int
func go() -> void
```

Anything else is the lane's. `game/hud/hud.gd` (912 lines) and `game/hud/goals.gd` (766) are near
gdlint's 1000: add little to them and put the rest in new files.

## Acceptance

In `tests/acceptance/test_053_the_area_map.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_map_of_every_area` | Each area's row holds the listed things, from a simulation with known progress; `Here` |
| R2 | `test_r2_closed_areas` | The dimming, the line, and a click that does nothing |
| R3 | `test_r3_sending_the_party` | The stage's start and limits; `Go` to another area and within this one |
| R4 | `test_r4_the_warning_travels` | The three colours for a party of known level; the journal's warning once |
| R5 | `test_r5_on_the_way` | The mark, the seconds, a redirect |
| R6 | `test_r6_somewhere_new` | The journal line, the goal's life, the mark on the button |
| R7 | `test_r7_true_in_a_crowded_frame` | The batch described |
| R8 | `test_r8_found_and_explained` | The keys, tooltips, and the panel's rectangle with four and six areas |
| R9 | (`test_showcase`) | The two moments exist and run |

**To look at, and for Zak:** shots of the map with one area open, with three open, and during a journey,
each also cropped and enlarged 3x. Can you tell at a glance where the party is, where it could go and
why you might? Describe them.

## Out of scope

- Resources on the map (spec 052 adds them); new areas; any rule under `sim/`.
- Changing the ladder, beyond what R3 shares with it.

## Paths

- `game/hud/`, `game/dev/showcase.gd`, `game/main*`
- `tests/acceptance/test_053_the_area_map.gd`, `tests/unit/test_hud*.gd`, `tests/unit/test_showcase*.gd`,
  spec 030's key test only where it lists keys
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
