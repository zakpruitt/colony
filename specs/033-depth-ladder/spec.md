# 033 — The depth ladder: see the whole expedition at once

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 011, 020, 027
- **Pull request:** —

## Intent

The player sees one screen of one level. Where the party is in the whole descent, how far it has ever been,
where it falls back to, where the next guardian waits and where it is heading are five separate numbers, some
of them not shown at all. This spec draws them as one picture: a ladder of depths down the side of the
screen. It is also the easy way to steer: click a depth to send the party there.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. A ladder of depths.** A narrow panel on the right edge, below the top band and above the party
  frames, shows a column of rungs, one per depth, shallow at the top. It shows 12 rungs at a time, chosen so
  the party's depth is always among them and scrolling smoothly as the party climbs.
- **R2. Each rung says what it is.** A rung shows its depth number and is marked by state:
  - the party's depth: a bright marker that bobs;
  - the safe depth (where the party falls back to): a green mark;
  - every depth at or above the safe depth: drawn as held (solid);
  - depths below it that the party has reached (down to the deepest ever): drawn as visited (outlined);
  - depths never reached: dim;
  - the target depth: an arrow pointing at the rung;
  - a guardian depth: a small skull drawn in code, crossed out while its guardian is beaten.
- **R3. Click to steer.** Clicking a rung sets the target depth to that rung's depth, exactly as the `-` and
  `+` buttons would by stepping there. A rung deeper than the simulation allows as a target is not
  clickable and says why in R4's tooltip words.
- **R4. Hover says it in words.** Resting the mouse on a rung shows one line beside it: `Depth 7: visited`,
  `Depth 5: Slime King (beaten)`, `Depth 10: Clay Colossus`, `Depth 12: not reached yet`, with `Click to
  send the party here` when it can be clicked. If the HUD has a tooltip (spec 030), use it; otherwise draw
  the line beside the ladder.
- **R5. It can be hidden.** The `L` key hides and shows the ladder; it starts shown. Hidden, it takes no
  clicks.
- **R6. It stays out of the way.** The ladder never covers the top band, the party frames, the journal's
  ticker, the shop or the boss bar. While the shop is open the ladder hides, and returns when it closes.
- **R7. It follows the simulation.** Every mark is read from the simulation each frame: after a wipe, a new
  stable depth, a guardian slain or respawned, or a loaded save, the ladder is right on the next frame.

## Interfaces

```gdscript
# game/hud/depth_ladder.gd
class_name DepthLadder
extends Control
const RUNGS: int = 12
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func is_shown() -> bool
func first_depth() -> int                      # the depth of the top rung
## What a rung shows, for tests: any of &"party", &"safe", &"held", &"visited", &"unreached",
## &"target", &"guardian", &"guardian_beaten".
func marks(depth: int) -> Array[StringName]
func hover_text(depth: int) -> String
func click_depth(depth: int) -> void           # what a click on that rung does

# game/hud/hud.gd gains
var ladder: DepthLadder
```

Whether a guardian is beaten is read from the expedition's public reads (`is_populated` on the guardian's
chamber, `guardian_of`); if that needs a new read-only accessor on `Expedition`, add one small one, keep
`expedition.gd` under gdlint's 1000 lines (it is at about 997: put any arithmetic elsewhere), and show that
reading it leaves the state hash unchanged.

## Acceptance

In `tests/acceptance/test_033_depth_ladder.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_ladder_of_depths` | Twelve rungs, the party's depth always among them at depths 1, 5, 13 and 40; the panel's rectangle |
| R2 | `test_r2_rungs_say_what_they_are` | Each mark from a simulation put in that situation, including a guardian before and after it is beaten |
| R3 | `test_r3_click_to_steer` | The target after the step following a click; an unclickable rung changes nothing |
| R4 | `test_r4_hover_says_it` | The line for each kind of rung |
| R5 | `test_r5_it_can_be_hidden` | `L` toggles; hidden takes no clicks; shown at start |
| R6 | `test_r6_stays_out_of_the_way` | Rectangles against the top band, frames, ticker and boss bar; hidden with the shop open |
| R7 | `test_r7_follows_the_simulation` | Marks after a wipe, a new stable depth and a loaded save |

**To look at, and for Zak:** shots at depth 1 of a new game, mid-descent around a guardian depth, and just
after a wipe. Crop and enlarge. Can you tell where the party is, where it is going, and what stands in the
way? Describe the shots.

## Out of scope

- A map of chambers within a level; scrolling the ladder by hand.
- Any rule change.
- New sprites or sounds.

## Paths

- `game/hud/depth_ladder.gd`, `game/hud/hud.gd` (creating, advancing, `L`, hiding with the shop)
- `sim/expedition/expedition.gd` (one read-only accessor, only if needed)
- `tests/acceptance/test_033_depth_ladder.gd`, `tests/unit/test_hud*.gd`
- Existing HUD tests only where they count HUD children (say which)
- `game/hud/help_panel.gd` (the new key's row in `KEYS`) and `tests/acceptance/test_030_help_and_hints.gd` (the
  new key's case in `_check_entry`): the help panel lists every key, and its test fails otherwise
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
