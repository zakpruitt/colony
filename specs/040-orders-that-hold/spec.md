# 040 — Orders that hold: fixes from the review of party orders

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 035, 039
- **Pull request:** [#41](https://github.com/zakpruitt/colony/pull/41)

## Intent

A reviewer read the party-orders change (spec 035, pull request 36) against its spec after it had landed
and found one way the Hold order can be broken, one way the orders panel can show the wrong choice, and
tests that would pass with the behaviour broken. This spec closes those. It adds no feature.

## Requirements

- **R1. Hold holds on the ladder.** If the order becomes `Hold` while the party is climbing up toward a
  chamber whose guardian is alive, the party does not fight it: it reverses the climb and returns to the
  level it left, and from there obeys Hold as usual. A climb down is unaffected. With the order at
  `Challenge` the climb behaves exactly as before.
- **R2. The panel always shows the simulation.** After the step that follows a click, each row of the
  orders panel lights the simulation's own value, whatever it is: a clicked choice never stays lit when the
  simulation holds a different value.
- **R3. The rest rule's test tells the readings apart.** A test shows the party resting when one hero is
  below the pace's share of their own health while the party's total is above it, and not resting when
  every hero is above their own share.
- **R4. The status-line test always checks.** The 035 test's checks of the status line outside holding
  (`Heading down`, `Hunting on depth N`) run on a party that is certainly travelling, not only if it
  happens to be.
- **R5. Display names live in the view.** The pace and guardian-order names shown on the panel are defined
  under `game/`, not under `sim/`.
- **R6. Defaults still change nothing.** The recorded-hash tests pass unchanged.

## Interfaces

None change, except that `PartyOrders.PACE_NAMES` and `GUARDIAN_NAMES` move to `OrdersPanel`.

## Acceptance

In `tests/acceptance/test_040_orders_that_hold.gd`, plus the amended 035 tests.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_hold_on_the_ladder` | The order set mid-climb up toward a living guardian: no battle with it, the party back on the level it left; a climb down and a climb under Challenge unchanged |
| R2 | `test_r2_panel_shows_the_simulation` | A click followed by a different command before the step: the panel lights what the simulation holds |
| R3 | `test_r3_rest_rule_is_per_hero` | The two cases |
| R4 | (`test_035`, `test_r8_status_and_journal`) | The checks no longer sit behind a condition |
| R5 | `test_r5_names_live_in_the_view` | Nothing under `sim/` defines the names; the panel's text is unchanged |
| R6 | (the existing suite) | `python tools/dev.py check` passes |

## Out of scope

- Making pace matter more to wipes (a design question for Zak).
- A guardian respawning while the party rests inside its chamber (not shown to be reachable).

## Paths

- `sim/expedition/` (the climb under Hold; the names leaving `party_orders.gd`)
- `game/hud/orders_panel.gd`
- `game/hud/journal.gd` (only the line that reads the pace names; added by the lead when the lane found it)
- `tests/acceptance/test_040_orders_that_hold.gd`, `tests/acceptance/test_035_party_orders.gd`,
  `tests/unit/test_expedition_orders.gd`
- `docs/wiki/index.html` only if a sentence there becomes untrue

## Open questions

None.
