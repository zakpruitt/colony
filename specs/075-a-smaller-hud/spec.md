# 075 — A smaller Hud that works only when something changed

- **Status:** in-progress (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** 074, 076
- **Pull request:** —

## Intent

`Hud` is 935 lines and does six jobs, thirteen files borrow its number formatting, and most of the UI
re-formats its text and re-sets its colours every frame whether or not anything changed. This spec
leaves `Hud` with the frame of the screen, gives the formatting a home, and makes the UI do work only
on a change, so new UI has a pattern to follow and an idle screen costs little. Nothing on screen changes.

## Requirements

- **R1. Nothing the player sees or does changes.** Existing tests pass, edited only to follow a moved
  name (list each). Shots of the main scene and showcase at both rooms match the baseline.
- **R2. Formatting has a home.** `group_thousands`, `short_count`, `clock` and `on_screen` live in
  `UiFormat`; `Hud` no longer has them and no file reaches into `Hud` for a static helper or a path.
- **R3. `Hud` is the frame of the screen.** It lays out and advances the frame's pieces (place panel,
  purse, hero frames, boss bar, ticker, goals, stage list). It still makes and advances the shop, the
  map and the tally, because 29 test files build a `Hud` alone and read them through it; it makes no
  other window content and has no key handling for windows. No file finds the `Hud` with `get_parent() as Hud`,
  looks a node up by name, or emits another object's signal: each is handed what it needs in `setup`.
  `Hud` has at most 15 public methods (it has 21, one over gdlint's cap counting statics).
- **R4. Text and colour are set on change.** Over 120 frames with the simulation stopped, no label's
  text is set, no theme override is added and no control redraws, in: the hero frames, an open hero
  window (each tab), the place panel, the goals, the shop, the purse and the button bar. When a value
  does change, what is shown follows on the next frame as it does today.
- **R5. A closed window does no work.** A closed shop, map, tally or hero window formats nothing and
  refreshes no row; it is right the moment it opens. A hero window refreshes only the tab showing, and
  no frame builds a `Combatant` to show a number that has not changed.
- **R6. Badges are told, not polled.** A window's badge on the bar changes when its content says so
  (a signal), and `UiButtonBar` has no `_process`.
- **R7. A label's colour is set one way.** The 30 `add_theme_color_override(&"font_color", …)` calls
  in 20 files go through one helper beside `WindowText.set_text`, which sets a colour only when it
  differs from the one showing. Every colour on screen is the one it is today.

## Interfaces

Spec 074 left `KeyBook` (`game/ui/key_book.gd`) and `WindowBook`/`WindowEntry`
(`game/ui/windows/`) in place, and spec 076 left `World.may_animate` and `World.fx`: use them as they are.

```gdscript
# game/ui/ui_format.gd
class_name UiFormat
static func group_thousands(value: int) -> String
static func short_count(value: int) -> String
static func clock(seconds: float) -> String
static func on_screen(node: CanvasItem, point: Vector2) -> Vector2

# game/ui/windows/window_text.gd
static func set_colour(of: Label, colour: StringName) -> void

# game/ui/windows/window_content.gd
signal badge_changed(text: String)
```

Signatures follow today's functions; report the final list.

## Acceptance

In `tests/acceptance/test_075_a_smaller_hud.gd` (extends `ColonyTest`), both rooms:

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_nobody_borrows_from_the_hud` | reads `game/`; no `Hud.` followed by a lower-case name outside `hud.gd` |
| R3 | `test_r3_the_hud_is_handed_what_it_needs` | reads `game/`; no `get_parent() as Hud`, no `.emit(` on another object's signal from the map window |
| R3 | `test_r3_the_hud_has_few_public_methods` | counts the public methods of `hud.gd` |
| R4 | `test_r4_an_idle_screen_sets_nothing` | as R4 says, counting through a counter the shared text and colour setters keep |
| R4 | `test_r4_a_change_shows_on_the_next_frame` | gold, health, XP, level, a goal's progress and the place each change and are shown one frame later |
| R5 | `test_r5_a_closed_window_does_no_work` | the same counter stays still for closed windows over 120 busy frames; opened, each shows current values at once |
| R6 | `test_r6_a_badge_follows_its_content` | the shop's and the map's tags appear and go with what they count, and the bar has no `_process` |
| R7 | `test_r7_a_labels_colour_is_set_one_way` | reads `game/`; no `font_color` override outside the shared setter, and setting the same colour twice counts once |

**To look at:** main scene at 10 s and 120 s, an open hero window on each tab, the shop and the map,
at both rooms, beside the baseline; enlarge the hero frames 3x.

## Out of scope

- Named colour roles in `UiTheme` in place of the 473 palette names in `game/ui/` and `game/hud/`: a
  spec of its own, if Round 3's survey still wants it.
- Moving the shop, the map and the tally out of `Hud` (it would mean rewriting the setup of 29 test
  files for no gain a player or a later spec would feel).
- Any change to how the UI looks or is laid out. New windows or HUD pieces. Splitting `World`,
  `StageList` or the effects files. Anything under `sim/` (if `Hero.combatant()` must be avoided, do it
  by not calling it, not by changing it).

## Paths

- `game/hud/`, `game/ui/`, `game/main.gd`, `game/save/` and `game/effects/` (callers of the moved
  formatting helpers only)
- `tests/` (R1's renames; `test_075_…` new)
- `CLAUDE.md`, `docs/architecture.md`

## Open questions
