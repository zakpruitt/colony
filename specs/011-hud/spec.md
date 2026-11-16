# 011 — HUD: the party, the purse and the depth

- **Status:** provisional
- **Milestone:** M4
- **Depends on:** 008, 009
- **Pull request:** —

## Intent

The player is the party's manager, and a manager needs to see, at a glance and from across the room, how the
party is doing: who is hurt, what level they are, how much gold there is, how deep they are and where they are
headed. This spec adds that readout, and the one control the base game has: choosing the target depth. It is
small, sits at the edges, and never covers the action. Read `docs/design/base-game.md` and
`docs/style-bible.md`.

## Requirements

Everything is in the pixel font and palette colours, on whole pixels, with no smooth gradients or rounded
shapes. The HUD occupies only the top 28 pixels and the bottom 40 pixels of the 640x360 screen.

- **R1. Party frames.** Along the bottom, one frame per hero in formation order, showing: a 16x16 class icon,
  the class name, the level, a health bar and an XP bar toward the next level. The health bar is green above
  half, yellow from a quarter to half, red below a quarter, and empties smoothly (it eases to the new value
  over about 0.3 s, never jumps).
- **R2. Frames react.** When a hero is hit, its frame flashes for an instant. When a hero is dead, its frame is
  dimmed and its icon replaced by a skull until it is alive again. When a hero levels up, its level number
  pulses and its XP bar restarts from empty.
- **R3. Gold.** Top right: a coin icon and the gold count with thousands separators. The count shown rises only
  as coins arrive (`CombatEffects.coin_collected`), ticking up and bumping slightly on each arrival; if the
  shown count is still behind the party's real gold 3 seconds after the last coin, it catches up at once. It
  never shows more than the party has. The HUD sets `CombatEffects.gold_screen_target` to the coin icon's
  position.
- **R4. Depth.** Top left: the current depth, the last stable depth, and the target depth, each labelled, with
  the current depth the most prominent. When the depth changes, the number changes with a brief emphasis.
- **R5. What the party is doing.** Next to the depth: one word for the expedition's state (`Travelling`,
  `Fighting`, `Resting`, `Climbing`, `Reviving`).
- **R6. Target depth control.** `-` and `+` buttons beside the target depth lower and raise it by one (never
  below 1), and an `Auto` toggle turns auto-push on and off, shown clearly as on or off. They act through
  `Simulation.set_target_depth` and `set_auto_push`, and the display follows the simulation (if auto-push
  raises the target, the HUD shows it). The keys `-`, `=` and `A` do the same.
- **R7. The clock is for developers.** The tick readout moves to the bottom-right corner in a dim colour and is
  hidden by default; `F3` toggles it.
- **R8. Readable over anything.** Every text and bar sits on a dark backing panel or has an `ink` outline, so it
  is readable over bright sky and dark stone alike.

## Interfaces

Text uses `PixelText` (spec 009). The font has only the characters listed in that spec, and its 1-pixel ink
shadow clogs on light backgrounds, so text always sits over the dark world or a dark panel.

The lead has already added the stub this spec fills in; `Main` creates it on the HUD layer and calls `setup`.

```gdscript
# game/hud/hud.gd
class_name Hud
extends Control

func setup(simulation: Simulation, world: World, effects: CombatEffects) -> void
## Brings the HUD up to date and advances its animations. Called every frame; tests call it.
func advance(delta: float) -> void
## The gold count currently displayed.
func shown_gold() -> int
```

The HUD reads the simulation and listens to `World.sim_event` (it must not call `drain_events`). Icons are
`.px` sources of category `ui` or `item` under `assets/sprites/ui/`.

## Acceptance

In `tests/acceptance/test_011_hud.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_party_frames` | Four frames in formation order with icon, name, level; health bar fraction and colour at 100%, 40% and 10%; the bar eases rather than jumps; XP bar fraction matches progress to the next level |
| R2 | `test_r2_frames_react` | Flash on a HIT event for that hero; dimmed with a skull while dead and normal after; pulse and XP reset on LEVEL_UP |
| R3 | `test_r3_gold_follows_the_coins` | Shown gold rises by each `coin_collected` share; never exceeds real gold; catches up after 3 s without coins; thousands separators; the gold target is set to the icon |
| R4 | `test_r4_depth_readout` | Current, stable and target depth shown and updated on change |
| R5 | `test_r5_state_word` | The word for each expedition state |
| R6 | `test_r6_target_depth_control` | Buttons and keys change the simulation's target and auto-push; never below 1; the display follows a change made by the simulation |
| R7 | `test_r7_dev_clock_hidden_until_f3` | Hidden by default; toggled by F3; still shows tick and seconds |
| R8 | `test_r8_stays_in_its_bands` | Every visible HUD control lies within the top 28 or bottom 40 pixels; every label has a backing or outline |

**To look at, and for Zak:** `python tools/dev.py shot --name=hud --seconds=5 --count=6`. The HUD must be
readable at 640x360 without squinting, must not look like default Godot controls, and must leave the action
clear. Compare a shot over the sky (depth 1) with one deeper. Describe the shots in your report.

## Out of scope

- Menus, settings, pause, tooltips, inventory, shop, talents, hero details on click.
- Health bars or names over characters in the world.
- Coins, numbers and other effects (spec 010).
- Changing the simulation. If the HUD needs state the simulation does not expose, report it.

## Paths

- `game/hud/`
- `assets/sprites/ui/`
- `game/ui/theme.tres` (button and panel styles only)
- `game/main.gd`, `game/main.tscn` (moving the clock label only)
- `tests/acceptance/test_011_hud.gd`, `tests/unit/test_hud*.gd`
- `tests/acceptance/test_001_sim_clock.gd`, `tests/acceptance/test_008_world_integration.gd` (only where the
  clock label's move breaks an assertion)
- `docs/style-bible.md` (a UI section), `docs/wiki/index.html`

## Open questions

None.
