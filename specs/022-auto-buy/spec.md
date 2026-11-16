# 022 — Auto-buy: let the camp spend its own gold

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M3
- **Depends on:** 016, 017, 019
- **Pull request:** [#23](https://github.com/zakpruitt/colony/pull/23)

## Intent

Colony is meant to be left running, and now it also runs while closed, but upgrades only happen when the
player presses a button. A party left alone for eight hours comes back with a mountain of gold and none of
the strength it could have bought. This spec adds one switch: when auto-buy is on, the camp buys upgrades by
itself, so an idle party keeps growing. It is off by default, because choosing upgrades is the player's one
real decision so far.

## Requirements

- **R1. A switch in the simulation.** `Simulation.set_auto_buy(enabled)` takes effect at the next step, and
  `Simulation.auto_buy` reads it. It is off in a new game.
- **R2. What auto-buy does.** While it is on, at most once per second of game time, if any upgrade is
  affordable the camp buys the cheapest affordable one (ties go to shop order), exactly as a `buy_upgrade`
  command would: gold taken, rank raised, an `UPGRADE_BOUGHT` event. It never buys while off, never spends
  more gold than the party has, and stops by itself when everything is at maximum rank.
- **R3. It works while away.** A game closed with auto-buy on and replayed for an hour (spec 019) ends with
  ranks above where it started, and the "While you were away" report says how many upgrades were bought.
- **R4. It is saved.** The switch is in the save; the save version becomes 3, and a version 2 save loads with
  auto-buy off through the upgrade step. A value that is not true or false is refused by name.
- **R5. Off changes nothing.** With auto-buy off, a simulation's state hash is the same, tick for tick, as
  before this spec, and every existing test passes (apart from assertions about the save version or the
  exact saved dictionary, which may be updated).
- **R6. A toggle in the shop.** The shop panel has an `Auto-buy` toggle, shown clearly as on or off in the
  style of the HUD's `Auto` button, and the `B` key toggles it while the shop is open. It follows the
  simulation: a loaded save with auto-buy on shows it on.
- **R7. Auto-buys are visible.** A row bought by auto-buy flashes like any purchase while the shop is open,
  and the HUD's gold count drops at once, as for a manual purchase.

## Interfaces

```gdscript
# sim/simulation.gd gains
var auto_buy: bool            # read-only outside the class
func set_auto_buy(enabled: bool) -> void
const AUTO_BUY_SECONDS: float = 1.0

# game/save/away_report.gd gains
var upgrades_bought: int
```

## Acceptance

In `tests/acceptance/test_022_auto_buy.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_switch` | Off in a new game; on after the step following the command; off again likewise |
| R2 | `test_r2_buys_the_cheapest` | With gold for several ranks: one purchase per second, each the cheapest affordable at that moment, each with its event; nothing bought while off; gold never negative; no purchases once all are at maximum |
| R3 | `test_r3_works_while_away` | A replayed hour with auto-buy on raises ranks, and the report's `upgrades_bought` equals the `UPGRADE_BOUGHT` events of the replay; the panel shows the number |
| R4 | `test_r4_saved` | Round trip of true and false; a version 2 dictionary loads with it off; a non-boolean is refused by name |
| R5 | `test_r5_off_changes_nothing` | Hashes at sampled ticks over 20 minutes on two seeds equal values recorded before the change |
| R6 | `test_r6_toggle_in_the_shop` | The toggle and `B` send the command; the display follows the simulation; `B` does nothing with the shop closed |
| R7 | `test_r7_auto_buys_are_visible` | With the shop open and auto-buy on, the bought row flashes and shown gold equals real gold after the step |

For R5, record the hashes of an untouched simulation before changing any `sim/` code.

**To look at, and for Zak:** a shot of the shop with the toggle off and one with it on (a throwaway scene you
do not commit). It must read at 640x360 and match the HUD.

## Out of scope

- Choosing what auto-buy prefers (priorities, per-upgrade switches, a gold reserve).
- Auto-buy for anything but camp upgrades.

## Paths

- `sim/simulation.gd`, `sim/party/upgrades.gd`
- `game/hud/shop_panel.gd`, `game/hud/hud.gd` (the `B` key only), `game/hud/away_panel.gd`
- `game/save/away_report.gd`, `game/save/away_replay.gd`
- `tests/acceptance/test_022_auto_buy.gd`, `tests/unit/test_upgrades*.gd`
- Existing save, upgrade, shop and away tests only where they assert the save version, the exact saved
  dictionary, the report's fields or the shop's layout (say which)
- `docs/architecture.md` (the "Saving" section), `docs/wiki/index.html`

## Open questions

None.
