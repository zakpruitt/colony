# 058 — A sharp UI layer, a readable font and windows

- **Status:** landed (provisional: not yet reviewed by Zak) (direction and three choices from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 009, 011, 027, 030, 035

## Intent

Zak: "I want to overhaul the UI. Right now the font is hard to read, although thematic, but too hard to
read, and I want the UI to be sort of like WoW where you can have multiple screens open individually at
once and compare or put side by side or layer. Still add nice buttons and default keybinds, but getting
the UI to be friendly and nice will be paramount." He chose: a UI layer drawn sharper than the world; a
clean pixel font made for reading; windows that move, layer and remember where they were.

The whole game is drawn at 640x360 and scaled up, so text is 5 pixels tall and two panels do not fit
side by side. This spec is the foundation of the overhaul: the world stays chunky, the UI gets its own
finer layer and font, and a window system exists with the three simplest panels moved onto it. Specs 059
to 061 move the rest (the shop, map and tally; hero sheets, several at once; the fixed HUD).

## Requirements

- **R1. Two layers.** The world (labyrinth, characters, effects) is still drawn at 640x360 and scaled by
  a whole number with hard pixel edges. The new UI layer is drawn over it in *UI pixels*: one UI pixel is
  a whole number of screen pixels, chosen so the UI has between 960x540 and about 1280x720 of room
  (window 1280x720: scale 1, room 1280x720; 1920x1080: scale 2, room 960x540; 2560x1440: scale 2, room
  1280x720; 3840x2160: scale 3 or 4). Nothing on the UI layer is ever blurred or drawn on half pixels.
  Resizing the window re-fits both at once.
- **R2. The old HUD still works meanwhile.** Every HUD piece not yet moved keeps working and looking as
  it does, drawn with the world: its clicks, keys, tooltips and tests are unchanged. A piece moved to the
  new layer is removed from the old one, never shown twice.
- **R3. A font made for reading.** A new UI font, drawn in the project's own format, in the master
  palette's colours: capitals 9 UI pixels tall, lower case with a clear x-height (6 or 7) and real
  descenders, strokes one pixel wide, letters with their own widths, digits all one width so numbers do
  not jiggle, and the punctuation the game uses. `1 l I`, `0 O`, `5 S`, `rn m` are each told apart at a
  glance. A bold of the same size for titles and buttons. The font specimen scene shows both beside the
  old font. The old font stays for the world's damage numbers and the old HUD.
- **R4. A theme.** Windows, buttons, tabs, tooltips and scroll areas on the new layer share one look
  defined in one place: a dark panel with a one-pixel light edge and a slightly lighter title bar;
  buttons that show rest, hover, pressed and disabled differently, with at least 4 UI pixels of padding
  round their text and a hit area at least 20 UI pixels tall; a visible keyboard hint on buttons that
  have a key (`Shop  U`). Colours come from the master palette.
- **R5. Windows.** A window has a title bar with its name and a close button. It can be dragged by the
  title bar; clicking anywhere on it brings it to the front; `Esc` closes the front window only; it can
  never be dragged so far that its title bar leaves the screen, and a window that would be off screen
  after the window shrinks is moved back in. Any number can be open at once, overlapping. The game keeps
  running behind them, and a click on a window never reaches the world or a window under it.
- **R6. Remembered.** Each window's place and whether it was open are kept in the settings file (beside
  the sound setting, not in the save) and restored next session. A new game's default places do not
  overlap each other at 960x540. One control resets every window to its default place.
- **R7. A button bar.** A row of buttons on the new layer, at the bottom right above the hero frames'
  line, opens and closes each window: one per window, each with a small icon, its name and key in a
  tooltip, lit while its window is open. It shows a button only for windows that exist on the new layer.
- **R8. Three panels become windows:** Help (`H`), the Journal (`J`) and the Orders (`O`), with the same
  content and the same commands as today, laid out for the new font with room to breathe: the journal
  shows at least 20 entries and scrolls through all 50 with the mouse wheel; the help shows every key in
  two columns; the orders explain each choice in a full sentence. Their keys toggle them as before, and
  all three can be open at once. The old panels and their buttons are removed; the old ticker stays.
- **R9. Screenshots show what the player sees.** `python tools/dev.py shot` saves the whole composed
  window (world and UI layer) at 1280x720, and `--ui-room=960x540` saves it as a 1920x1080 window would
  show it. The harness and CLAUDE.md say so.
- **R10. True in a crowded frame.** The journal window shows the same lines in the same order whether its
  events arrived one tick a frame or 300 in one frame; dragging a window while the game runs at 4x drops
  no input.
- **R11. In the help list and the wiki.** `HelpPanel.KEYS` (or what replaces it) still lists every key;
  spec 030's R3 test passes or is amended in step (say how). The wiki says how windows work and that the
  overhaul is under way, panel by panel.

## Interfaces

- Layout is the lane's to design; the names below are what specs 059 to 061 will build on, so they are
  fixed: `game/ui/ui_root.gd` (`class_name UiRoot`: the layer; `ui_scale() -> int`, `room() -> Vector2i`,
  `world_to_ui(world_px: Vector2) -> Vector2` and `ui_to_world(...)` for effects that fly to the HUD,
  `set_room_for_test(room: Vector2i)`), `game/ui/ui_window.gd` (`class_name UiWindow`: `window_id:
  StringName`, `title: String`, `content` as a child `Control`, `open()`, `close()`, `is_open() -> bool`,
  `default_place: Vector2`), `game/ui/ui_windows.gd` (`class_name UiWindows`: registers windows, keeps
  their order, `toggle(id)`, `front() -> UiWindow`, `reset_places()`, saves and restores places),
  `game/ui/ui_theme.gd` or a `Theme` resource for R4, `game/ui/ui_text.gd` for measuring and drawing the
  new font (as `PixelText` does for the old).
- The new layer uses Godot `Control` nodes and the theme, so later windows get layout, focus and
  scrolling from the engine and not by hand.
- The new font is `assets/fonts/ui.px` and `assets/fonts/ui_bold.px`, baked by `tools/art.py` as
  `pixel.px` is; the art lint covers them.
- `project.godot`'s stretch settings may change for R1. `tools/dev.py` and the script it runs change for
  R9. Nothing under `sim/` changes.

## Acceptance

In `tests/acceptance/test_058_sharp_ui_and_windows.gd`, one test per requirement named `test_rN_…`, each
seen to fail first; a reviewer will break the code under each and expect it to fail.

| Requirement | What the test shows |
|---|---|
| R1 | For each window size listed: the world's scale, the UI scale and room; every UI node's screen position is whole pixels; a world sprite's pixels are the hard-edged multiple |
| R2 | Every old HUD test still passes untouched except those for the three moved panels (list them); a click on an old button at its old place still acts |
| R3 | Every character the game's texts use has a glyph; the heights, the equal digit widths; each confusable pair differs in at least 3 pixels |
| R4 | A button's four states draw differently; padding and hit height measured; the key hint shown |
| R5 | Real mouse drags and clicks: move, bring to front, `Esc` closes the front one only, the title bar kept on screen, a click on a window does not reach the world (the target stage and hero sheet unchanged) |
| R6 | Places written to a per-process settings file and restored by a new `Main`; default places measured for overlap at 960x540; the reset |
| R7 | One button per window, lit while open, toggling by click |
| R8 | For each of the three: its content against the simulation (journal lines, both orders' commands sent, every key listed), 20 entries visible, the wheel reaching the 50th, all three open together |
| R9 | (`tools/tests/`) the shot's size for both rooms |
| R10 | The journal's lines one tick a frame against 300 in a frame; a drag at 4x ends where the mouse did |
| R11 | Spec 030's R3 |

**To look at, and for Zak:** the font specimen (new, bold and old, enlarged 3x); the three windows open
together at 1280x720 and at 960x540; a window half dragged off each edge; the button bar. Describe every
shot. Is the text easy to read at a glance, and does it still feel like Colony?

## Out of scope

- The shop, the area map, the tally (spec 059); hero sheets (spec 060); the fixed HUD: top bar, hero
  frames, goals, ladder, tooltips, ticker, defeat note, away report, boss bar (spec 061).
- Resizing windows, locking them, rebinding keys, a settings screen.
- The world's own text (damage numbers, ability names, titles).

## Paths

- `project.godot`, `game/main.gd` and its scene, `game/ui/`, `game/hud/`
- `assets/fonts/`, `assets/` (button-bar icons), `tools/` and `tools/tests/`
- `tests/`
- `CLAUDE.md` (the shot command and what a UI lane must know), `.claude/skills/`, `docs/architecture.md`,
  `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
