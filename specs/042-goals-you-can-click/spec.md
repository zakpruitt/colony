# 042 — Goals you can click

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 034, 035, 037, 039
- **Pull request:** [#43](https://github.com/zakpruitt/colony/pull/43)

## Intent

The goals tracker says `Buy an upgrade, 25 gold` while the party holds 32 gold, and the player then has to
find the Shop button. Each goal already knows what the player would do about it. This spec makes a goal's
line a button that takes the player there, so the tracker is the one place to manage from. It changes no
rule.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. A goal's line can be clicked.** Clicking a goal's line does the one obvious thing:

  | Goal | Click |
  |---|---|
  | `Buy an upgrade` | Opens the shop |
  | `Train a hero` | Opens the sheet of the hero with the cheapest affordable training, on the Training tab |
  | `<Hero> learns <microskill> at level N` | Opens that hero's sheet on the Skills tab |
  | `Beat the <guardian>` | Opens the orders panel |
  | `Reach depth N` | Shows the depth ladder if it is hidden, and flashes the rung for depth N for about a second |

  A finished goal showing its tick does nothing when clicked.
- **R2. It looks clickable.** A line under the mouse is highlighted as the HUD's other buttons are, and
  the two gold goals (`Buy an upgrade`, `Train a hero`) show a small `>` at their right edge at all times,
  since they are things the player can do now.
- **R3. The tooltip says so.** Each goal's tooltip (spec 037) ends with what a click does, as a second
  short sentence (`Click to open the shop.`).
- **R4. Nothing else changes.** Opening a panel from a goal behaves exactly as opening it by its own
  button or key (the same exclusions between panels; the tracker hides behind a left-side panel as
  before). No change under `sim/`; no new key.

## Interfaces

```gdscript
# game/hud/goals.gd gains
func press(index: int) -> void          # what clicking that line does
func action(index: int) -> String       # the tooltip's click sentence, "" for a finished goal

# game/hud/depth_ladder.gd gains
func flash(level_depth: int) -> void
func is_flashing(level_depth: int) -> bool
```

## Acceptance

In `tests/acceptance/test_042_goals_you_can_click.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_click_a_goal` | Each row of the table, by `press` and by a real mouse click on the line; a finished goal doing nothing |
| R2 | `test_r2_looks_clickable` | The highlight under the mouse; the `>` on the gold goals only |
| R3 | `test_r3_tooltip_says_so` | Each kind of goal's tooltip ending with its click sentence |
| R4 | `test_r4_nothing_else_changes` | Panel exclusions after opening from a goal; the state hash unchanged by clicks that only open panels |

**To look at, and for Zak:** a shot of the tracker with the mouse over a line and with a gold goal showing
(a throwaway scene; do not commit it). Crop and enlarge. Describe it.

## Out of scope

- Buying or training straight from the tracker.
- Any change under `sim/`; new sprites, sounds or keys.

## Paths

- `game/hud/goals.gd`, `game/hud/hud.gd`, `game/hud/hud_tooltip.gd`, `game/hud/depth_ladder.gd` (the flash
  only)
- `tests/acceptance/test_042_goals_you_can_click.gd`, `tests/unit/test_hud*.gd`
- `tests/acceptance/test_037_goals.gd` only where it asserts a tooltip's exact text (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
