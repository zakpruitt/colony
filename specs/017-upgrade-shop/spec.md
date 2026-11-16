# 017 — The upgrade shop on screen

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 011, 016
- **Pull request:** [#20](https://github.com/zakpruitt/colony/pull/20)

## Intent

Spec 016 lets gold buy upgrades; this spec lets the player do it. A small shop opens over the game without
stopping it, shows what each upgrade does, its rank and its price, and makes it obvious at a glance, even
with the shop closed, when something has become affordable. Read `docs/style-bible.md` (the UI section) and
look at the HUD first: `python tools/dev.py shot --name=before --seconds=5`.

## Requirements

Everything is in the pixel font and palette colours, on whole pixels, in the same hand-drawn panel and button
style as the HUD (`game/hud/hud_panel.gd`, `game/hud/hud_button.gd`).

- **R1. A shop button on the HUD.** In the top band, beside the gold, a `Shop` button opens and closes the
  shop. The `U` key does the same, and `Esc` closes it.
- **R2. It says when you can afford something.** While the shop is closed and at least one upgrade is
  affordable, the button shows a clear, animated marker (a pulsing dot or glint) and the number of affordable
  upgrades. With none affordable there is no marker.
- **R3. The shop lists every upgrade.** One row per upgrade in shop order: its name, its one-line
  description, its rank as `Rank n/max`, the current total bonus (for example `+15%`), and a buy button with
  the price. The game keeps running behind it and the shop does not cover the party frames or the top band.
- **R4. Rows show whether you can buy.** An affordable row's price is bright and its button is enabled; an
  unaffordable row's price is dim red and its button does nothing; a row at maximum rank shows `MAX` and has
  no price. Rows update as gold arrives, without reopening the shop.
- **R5. Buying works and feels like something.** Pressing an enabled buy button, or the number key of its row
  (`1` to `5`) while the shop is open, calls `Simulation.buy_upgrade`. When the purchase happens
  (`UPGRADE_BOUGHT`), the row flashes, its rank and price change, and the HUD's gold count drops to the
  party's real gold at once.
- **R6. It follows the simulation.** The shop reads ranks, prices and gold from the simulation every frame; it
  keeps no copy that can drift. A purchase made by anything else (a test, a loaded save) shows correctly.
- **R7. It does not eat the game's keys.** With the shop closed, the HUD's existing keys work as before. With
  it open, `1` to `5`, `U` and `Esc` belong to the shop and the others still work.

## Interfaces

```gdscript
# game/hud/shop_panel.gd
class_name ShopPanel
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func is_open() -> bool
func open() -> void
func close() -> void
func affordable_count() -> int

# game/hud/hud.gd gains
var shop: ShopPanel
```

`Hud.setup` creates the shop and `Hud.advance` advances it. It listens to `World.sim_event` for
`UPGRADE_BOUGHT`.

## Acceptance

In `tests/acceptance/test_017_upgrade_shop.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_button_and_keys_open_and_close` | The button, `U` and `Esc` |
| R2 | `test_r2_marker_when_affordable` | Marker and count appear when gold reaches a price, vanish when it does not or the shop is open |
| R3 | `test_r3_lists_every_upgrade` | One row per `Content.upgrade_ids()` in order with name, description, rank text, bonus text and price; the panel lies between the top band and the party frames; the simulation's tick advances while open |
| R4 | `test_r4_rows_show_affordability` | The three row states, and a row changing state as gold is added without reopening |
| R5 | `test_r5_buying` | Button and number key send the command; after the step the row flashed, rank and price changed, shown gold equals real gold; a disabled button sends nothing |
| R6 | `test_r6_follows_the_simulation` | Ranks set directly on the simulation show on the next advance |
| R7 | `test_r7_keys` | `-`, `=`, `A`, `F3` still work open and closed; `1` does nothing when closed |

**To look at, and for Zak:** shots of the HUD with the marker showing, the shop open with a mix of
affordable, unaffordable and maxed rows, and a row just bought. Give the party gold in a throwaway scene you
do not commit if the game is too slow to earn it. It must read at 640x360 and look like part of the HUD.

## Out of scope

- The upgrade rules, data and save (spec 016).
- Tooltips, scrolling, tabs, other shops, confirmation dialogs.
- Pausing the game.

## Paths

- `game/hud/`
- `assets/sprites/ui/`
- `tests/acceptance/test_017_upgrade_shop.gd`, `tests/unit/test_shop*.gd`
- `tests/acceptance/test_011_hud.gd` (only where the new button or panel breaks a layout assertion)
- `docs/style-bible.md` (the UI section), `docs/wiki/index.html`

## Open questions

None.
