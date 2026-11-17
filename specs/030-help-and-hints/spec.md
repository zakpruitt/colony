# 030 — Help, tooltips and live health

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 011, 017, 021, 026, 027
- **Pull request:** —

## Intent

The game now has a dozen keys and several panels, and nothing in it explains any of them: the only guide is
the wiki. Zak asked for ease. This spec adds the explaining to the game itself: a help panel that lists
what everything is and does, tooltips on the HUD, and a first-run welcome. It also fixes the one place the
HUD is wrong: hero frames do not move during a fight, because they read health that is only written back
when the fight ends.

## Requirements

Everything follows `docs/style-bible.md` and matches the existing HUD panels.

- **R1. Frames show live health.** During a fight a hero's frame shows that hero's health in the battle,
  easing as it does today, flashing on a hit; outside a fight it shows the hero's own health. A hero who
  dies in a fight is dimmed at once, not when the fight ends.
- **R2. A help panel.** A `?` button in the top band, and the `H` key, open and close a help panel; `Esc`
  closes it. It has two short parts that fit on one screen without scrolling:
  - **The idea**, in at most five lines: the party explores on its own; it pushes deeper once a depth is
    stable; a wipe sends it back to the last safe depth; gold buys upgrades; it keeps going while the game
    is closed.
  - **Keys**: every key the game responds to, with what it does. The list is built from one table in code
    that the input handling can be checked against, not written twice.
  The game does not pause. Opening help closes the shop, the hero sheet and the journal, and opening any of
  those closes help.
- **R3. Every key is listed.** Each key the HUD, world, sound player and panels handle appears in the help
  panel's list, and each listed key does something.
- **R4. Tooltips.** Resting the mouse on a HUD element for 0.4 seconds shows a small box with one plain
  sentence; moving off hides it. At least: the depth number, the status line, the stable countdown, the
  target depth `-` and `+`, the Auto button, the Shop button, the gold, each hero frame (`Click for
  details`), the boss bar and the `?` button. A tooltip never leaves the screen and never covers the element
  it explains.
- **R5. A welcome on first run.** In a played game with no save loaded, the help panel opens by itself
  once. Having seen it is remembered in the settings file (the one that remembers mute), so it never opens
  by itself again. Tests and screenshot runs never open it by themselves and never touch the real settings
  file.
- **R6. It fits and stays out of the way.** The help panel sits between the top band and the party frames,
  inside the screen, with every line legible at 640x360.

## Interfaces

```gdscript
# game/hud/help_panel.gd
class_name HelpPanel
extends Control
## The keys the game responds to, in the order shown: each entry is [key label, what it does].
const KEYS: Array[Array]
func setup(simulation: Simulation, world: World) -> void
func is_open() -> bool
func open() -> void
func close() -> void
func lines() -> Array[String]

# game/hud/hud_tooltip.gd
class_name HudTooltip
extends Control
func shown_text() -> String          # "" when hidden

# game/hud/hud.gd gains
var help: HelpPanel
var tooltip: HudTooltip
```

The settings file's class is `game/audio/sound_settings.gd`; give it the "help seen" flag (rename or move
the class only if you must, and say so).

## Acceptance

In `tests/acceptance/test_030_help_and_hints.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_frames_show_live_health` | A frame's shown health following the battle's during a fight and the hero's outside one; dimmed at the death event |
| R2 | `test_r2_help_panel` | The button, `H`, `Esc`; the idea lines and the keys list; the panels excluding one another; the tick advancing while open |
| R3 | `test_r3_every_key_is_listed` | Each listed key changes something when pressed in a real `Main`; each key constant handled in `game/` input code appears in `KEYS` |
| R4 | `test_r4_tooltips` | Each listed element's sentence after the delay; nothing before it; hidden on leaving; rectangles inside the screen and clear of the element |
| R5 | `test_r5_welcome_on_first_run` | With a test settings path: opens once for a new game, not again, not for a loaded save; a `Main` in a test run never opens it |
| R6 | `test_r6_it_fits` | The panel's rectangle and its labels |

**To look at, and for Zak:** take shots of the help panel open and of two tooltips (a throwaway scene may
place the mouse; do not commit it). Crop and enlarge. Would someone opening the game for the first time
know what to do? Describe the shots.

## Out of scope

- A tutorial that walks the player through steps, rebinding keys, a settings screen.
- Any change under `sim/`.
- New sprites or sounds.

## Paths

- `game/hud/help_panel.gd`, `game/hud/hud_tooltip.gd`, `game/hud/hud.gd`, `game/hud/hero_frame.gd`
- `game/hud/` panels only where they must close when help opens
- `game/audio/sound_settings.gd`, `game/main.gd` (the first-run welcome only)
- `tests/acceptance/test_030_help_and_hints.gd`, `tests/unit/test_hud*.gd`, `tests/unit/test_sound_settings.gd`
- Existing HUD tests only where they count HUD children or assert that frames ignore battle health (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
