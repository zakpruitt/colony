# 096 — The order to press on

- **Status:** draft
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 094, 095
- **Pull request:** —

## Intent

Since spec 093 the party takes every side path it can open. That is right most of the time, but a player
racing a stage's timer, or pushing for a guardian, wants the party to walk straight through. This spec adds
a third party order beside Pace and Guardians: **Side paths**, set to **Explore** (the default, what the
party does today) or **Press on** (walk past every gate). It is chosen in the Orders window and kept in the
save.

## Requirements

- **R1. Press on passes every gate.** Under Press on the party turns onto no side path and no `GATE_SEALED`
  is reported. A party already on a side path when the order is given finishes it and rejoins the main
  course. Under Explore the party does what it does before this spec.
- **R2. It is an order like the others.** `Simulation.set_side_paths(order)` applies from the next step and
  reports `ORDER_CHANGED` (order `PartyOrders.SIDE_PATHS`, 2; amount the new value); giving the value
  already held reports nothing. The order is in the state hash only when it is not Explore, so every run
  that never gives it hashes as it did.
- **R3. It is saved.** `SAVE_VERSION` becomes 9; `to_save()` carries `"side_paths"` as `"explore"` or
  `"press_on"`. A version 8 save (and every older one, through the steps there are) loads at Explore. A
  save with any other value is refused, the problem named as the other orders' are.
- **R4. It is chosen in the Orders window.** The window has a third row, `Side paths`, with the choices
  `Explore` and `Press on`, a line under each saying what it does (`Take every side path the party can
  open` / `Walk past every gate`), a tip, and the lit choice following the simulation, as the two rows
  above it. The window still fits its place at 1280x720 and with `--ui-room=960x540`.
- **R5. The journal says it changed.** `Orders: side paths, press on` (and `explore`), where the journal
  tells of a changed order today.
- **R6. A sealed gate is quiet under Press on.** With the order at Press on the world raises no "Needs a …"
  line and the journal writes no sealed-gate line (there is no event to write for); a closed gate's tip
  still says what would open it, and adds `The party is pressing on`.
- **R7. Away time obeys it.** Time away under Press on opens no caches, and the away report has no cache
  row.

## Interfaces

```gdscript
# sim/expedition/expedition.gd
enum SidePaths { EXPLORE, PRESS_ON }
var side_paths: SidePaths = SidePaths.EXPLORE
## Asks for a new value of one order (PartyOrders.PACE, GUARDIANS or SIDE_PATHS); it applies from
## the next tick, and a value the order does not have is ignored. Takes the place of command_pace
## and command_guardian_order, so the class keeps its 20 public methods.
func command_order(which: int, value: int) -> void

# sim/expedition/party_orders.gd
const SIDE_PATHS: int = 2
const SIDE_PATHS_SAVED: Array[String] = ["explore", "press_on"]

# sim/simulation.gd
const SAVE_VERSION: int = 9
func set_side_paths(order: Expedition.SidePaths) -> void
```

`Simulation.set_pace` and `set_guardian_order` keep their signatures. `expedition.gd` is at 897 of its 900
lines: the three orders' pending values and their applying move out of it first (into `PartyOrders` or a
script beside it), as their own commit that changes nothing, seen by the unedited suite.

## Acceptance

In `tests/acceptance/test_096_the_order_to_press_on.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_press_on_passes_every_gate` | a party that would open a gate walks past it with no stop and no gate event; given on a side path, the trip is finished first; back at Explore the next gate is opened |
| R2 | `test_r2_the_order_is_an_order` | the event and its numbers, none for the value held; a run at Explore has the hash recorded before this spec, one at Press on differs |
| R3 | `test_r3_the_order_is_saved` | the round trip of both values; a version 8 save loads at Explore; a bad value is refused by name |
| R4 | `test_r4_the_orders_window_has_the_row` | real clicks on both choices change the simulation; the lit choice follows a change made by the simulation; the window is inside the screen in both rooms |
| R5 | `test_r5_the_journal_says_it` | both lines |
| R6 | `test_r6_a_sealed_gate_is_quiet` | no rising line and no journal line under Press on; the tip's added words |
| R7 | `test_r7_time_away_presses_on` | an hour away under each order: caches and the row with Explore, neither with Press on |

## Out of scope

- Per-gate choices, an order by kind of gate, a key for the order.
- Retuning caches or gates.

## Paths

- `sim/expedition/expedition.gd`, `sim/expedition/party_orders.gd`, `sim/expedition/side_path_walk.gd`,
  `sim/simulation.gd`, and a new script under `sim/expedition/` for the orders' applying if one is needed
- `game/ui/windows/orders_panel.gd`, `game/hud/journal.gd`, and whatever spec 094 made that raises a sealed
  gate's line and tip (named when 094 has landed)
- `tests/acceptance/test_096_the_order_to_press_on.gd` (new), `tests/support/`
- Existing tests that name the save's version or call the two order commands, to follow the change only:
  `tests/acceptance/test_014_save_progress.gd`, `test_016_camp_upgrades.gd`, `test_022_auto_buy.gd`,
  `test_035_party_orders.gd`, `test_040_orders_that_hold.gd`, `test_051_talent_trees_and_paragon.gd`,
  `test_092_the_game_plays_winding_stages.gd`, `tests/unit/test_save_progress.gd`,
  `tests/unit/test_expedition_orders.gd`
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

- The Paths' two "named when … has landed" entries, and a fresh grep of the tests the save version touches,
  wait for 094 and 095.
