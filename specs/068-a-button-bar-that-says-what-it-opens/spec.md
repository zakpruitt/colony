# 068 — A button bar that says what it opens

- **Status:** provisional (direction from Zak 2026-11-19; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 058, 059, 062
- **Pull request:** —

## Intent

Zak asked to keep making the UI friendlier and easier to understand. The row of window buttons at the
bottom right shows a 16-pixel icon and a single grey letter each (`H`, `J`, `O`, `U`, `W`, `T`): a new
player cannot tell what any of them opens without resting the mouse on each. This spec makes every
button say its name, and makes the keys make sense beside them.

## Requirements

- **R1. A name on every button.** Each window button shows its icon, its window's name in words
  (`Help`, `Journal`, `Orders`, `Camp`, `Map`, `Tally`) and its key, set apart as a small key cap. The
  reset button keeps its icon and gets the word `Reset`.
- **R2. One name per window everywhere.** The name on the button, the window's title, the help's key
  list and every tooltip, goal, note and caption that names a window use the same word for the same
  window. The shop's window is titled
  `Camp upgrades`; its button and the help say `Camp`.
- **R3. It still reads when lit, tagged and disabled.** A button is plainly lit while its window is
  open, its amber tag (spec 059 R6) sits on the corner of its icon without covering its name or key and
  reaches no more than 2 pixels outside the button, so a window standing beside the bar at its default
  place never cuts it, and
  the tooltip still says what the window is for in one sentence (not just its name again).
- **R4. Fits both rooms.** At 960x540 and 1280x720 the bar with all its names is one row, wholly on
  screen, above the hero frames' line, and overlaps none of them, the stage list or the goals. If the
  names and keys cannot fit side by side at 960x540, each button there is its icon over its name with
  the key as a small key cap at the button's top right corner; only if that cannot fit either are the
  keys dropped from the buttons there, before any name is shortened, and the tooltip still names the key.
- **R5. Nothing lost.** Every click and key of the bar works as before, the tags stay under windows
  (spec 062 R12), and the older tests pass, amended only where they measure a button's size or place
  or read a window's old name (list each).
- **R6. Help and wiki** are true to it.

## Interfaces

`UiButtonBar` changes; `UiWindow` keeps a short name beside its title if it needs one
(`short_name: String`). Nothing under `sim/` changes.

## Acceptance

In `tests/acceptance/test_068_a_button_bar_that_says_what_it_opens.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail, measuring rectangles at both rooms and
driving real clicks and keys. A reviewer will break the code under each.

**To look at, and for Zak:** the bar at both rooms with nothing open, with two windows open and with
the shop's and the map's tags showing, enlarged 3x. Describe every shot. Can you tell what each button
opens without touching the mouse?

## Out of scope

- Rebinding keys or changing which key opens what. New windows. Moving the bar elsewhere.

## Paths

- `game/ui/ui_button_bar.gd`, `game/ui/ui_button.gd`, `game/ui/ui_window.gd`, `game/ui/ui_theme.gd`
- `game/hud/hud.gd`, `game/hud/help_panel.gd`, `game/hud/goals.gd`, `game/hud/defeat_note.gd`,
  `game/hud/area_news.gd`, `game/dev/showcase.gd`, `game/ui/ui_root.gd` (names only)
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
