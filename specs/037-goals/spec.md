# 037 — Goals: what to look forward to

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 011, 020, 025, 027, 029, 030, 034
- **Pull request:** —

## Intent

The game shows what is happening but not what is coming. A player glancing at it cannot say what the party
is working toward or what would be worth doing next. This spec adds a small goals tracker: the next few
things within reach, each with its progress, read straight from the simulation. It also makes the hero
frames point at themselves when a hero has something for the player to do. It gives no rewards and changes
no rules: it is a signpost.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. A goals tracker.** A small panel under the depth panel on the left shows up to three goals, each a
  one-line sentence with a thin progress bar or a count. It can be hidden and shown with the `G` key and
  starts shown.
- **R2. The goals come from the game.** At any moment the tracker shows the first three of these that
  apply, in this order:
  1. `Beat the <guardian's name>` when the next guardian's depth is within 3 levels of the party's deepest
     depth and it has never been beaten: progress is the party's lowest hero level against the level the
     guardian is balanced for (shown as `level 6 of about 9`).
  2. `Reach depth N` for the next depth below the deepest ever reached: progress is the countdown to
     stable at the current depth when the party is at its deepest, otherwise the party's depth against it.
  3. `<Hero> learns <microskill> at level N` for the microskill nearest to being learned by any hero:
     progress is that hero's XP toward the level.
  4. `Train a hero` when gold is at least the cheapest training's price: no bar, the price shown.
  5. `Buy an upgrade` when gold is at least the cheapest camp upgrade's price: no bar, the price shown.
- **R3. A finished goal is celebrated and replaced.** When a shown goal is achieved (the guardian slain,
  the depth reached, the microskill learned) its line flashes, shows a tick for 3 seconds, the journal
  gains a line (`Goal: reached depth 6`), and the next applicable goal takes its place.
- **R4. Frames point at themselves.** A hero's frame carries a small marker (as the Shop button does) when
  that hero can afford a training or has learned a microskill the player has not yet seen in their sheet;
  it clears under the same rules as the sheet's tab markers (spec 034).
- **R5. It explains itself.** Each goal line has a tooltip (spec 030) saying in one sentence how to get
  there (`Hold this depth until it is stable, and the party moves on by itself.`). `G` is in the help
  panel's key list.
- **R6. It stays out of the way.** The tracker never covers the top band, the party frames, the ticker,
  the boss bar, the depth ladder or the shop. While a hero sheet or the journal is open on the left, the
  tracker hides, and returns when it closes.
- **R7. It follows the simulation.** Every goal and its progress is read from the simulation each frame;
  a loaded save shows the right goals at once, and old events (after time away) flash nothing.

## Interfaces

```gdscript
# game/hud/goals.gd
class_name Goals
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func is_shown() -> bool
func lines() -> Array[String]            # the goal sentences showing, top first
func progress(index: int) -> float       # 0 to 1, or -1.0 for a goal with no bar

# game/hud/hud.gd gains
var goals: Goals
```

"The level the guardian is balanced for" is not in the data. Use `guardian depth + 4` and state that rule in
a doc comment; it matches the tests of spec 020 (a level-9 party beats the depth-5 guardian).

## Acceptance

In `tests/acceptance/test_037_goals.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_tracker` | Up to three lines with bars; `G` hides and shows; shown at start; the panel's rectangle |
| R2 | `test_r2_goals_come_from_the_game` | Each goal's sentence and progress from a simulation put in that situation; the order; at most three |
| R3 | `test_r3_finished_goal` | The flash and tick, the journal line, the replacement, for a depth, a guardian and a microskill |
| R4 | `test_r4_frames_point_at_themselves` | The marker for affordable training and for a newly learned microskill; cleared as the sheet's markers are |
| R5 | `test_r5_explains_itself` | Each goal's tooltip; `G` in the key list and its case in the 030 test |
| R6 | `test_r6_out_of_the_way` | Rectangles against the top band, frames, ticker, boss bar, ladder and shop; hidden with the sheet or journal open |
| R7 | `test_r7_follows_the_simulation` | Goals after a loaded save; nothing flashing for old events |

**To look at, and for Zak:** shots of the tracker in a new game, near the first guardian, and just as a
goal completes (a throwaway scene; do not commit it). Crop and enlarge. Does it tell you what to look
forward to without getting in the way? Describe the shots.

## Out of scope

- Rewards for goals, achievements, a quest log, goals the player sets.
- Any change under `sim/`.
- New sprites or sounds (a finished goal may play the existing `depth_stable` sound).

## Paths

- `game/hud/goals.gd`, `game/hud/hud.gd`, `game/hud/hero_frame.gd` (the marker only), `game/hud/journal.gd`
  (the goal line only), `game/hud/hud_tooltip.gd`, `game/audio/sound_player.gd` (one sound for a finished goal)
- `game/hud/help_panel.gd` (the `G` row in `KEYS`) and `tests/acceptance/test_030_help_and_hints.gd` (its
  case in `_check_entry`)
- `tests/acceptance/test_037_goals.gd`, `tests/unit/test_hud*.gd`
- Existing HUD tests only where they count HUD children or walk every HUD child's rectangle (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
