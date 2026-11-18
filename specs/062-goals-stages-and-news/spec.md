# 062 — Goals, the stage list and the news on the sharp layer

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 019, 027, 031, 033, 037, 041, 042, 043, 047, 053, 058

## Intent

The last step of the UI overhaul Zak asked for. After spec 061 the frame of the screen is sharp; what is
left in the old 5-pixel font is what tells the player what is going on and what to do next: the goals,
the list of stages, the ticker, the note after a defeat and the report after time away. This spec moves
them, and with them the old HUD layer is gone.

## Requirements

- **R1. Goals** (`G`), on the sharp layer under the place panel: up to three goals, each a button with
  its text, a bar or a price, and the small `>` when it can be done now, as specs 037 and 042 define
  them; a goal done flashes and shows its tick. A click opens the window or tab where it is done.
- **R2. The stage list** (`L`), at the right edge: the stages of this area headed by its name, with the
  party's stage, the safe stage, the target (yellow frame and arrow), stages reached and never reached,
  each guardian with its name written beside its stage and struck through once beaten, and each stage's
  number coloured safe, within reach or dangerous, with the tooltip saying so as spec 043 rules
  (nothing for a safe stage). A click sets the target;
  the wheel scrolls; a small arrow returns to the party. Every rule of specs 033, 043 and 047 holds,
  except that the list no longer hides while the shop is open, nor the goals while the tally is:
  windows are drawn over them (R10).
- **R3. The ticker:** the newest journal line for 4 seconds, in the new font, above the hero frames,
  never over a window's title bar at the default places. A click on it opens the Journal.
- **R4. The note after a defeat** is drawn on the sharp layer above every window, so it can never be
  hidden: what beat the party and where, the plainest reason, and up to three buttons that would help
  (spec 058's buttons, each opening the right window or tab). Every rule of spec 041 and its later
  amendments holds (which buttons, when it goes, that a click does what the button said).
- **R5. The report after time away** is a window that opens by itself in the middle, above the others,
  with the story spec 031 defines laid out as a short list with the numbers right-aligned; windows left
  open last session open under it. A click on its button or `Esc` closes it; it no longer goes by
  itself while the mouse is on it.
- **R6. The catching-up bar** and its text are drawn on the sharp layer.
- **R7. The old layer is gone.** No node of the old HUD is drawn; `PixelText` and the old font remain
  only for the world's own text. The interim rules of spec 058 (old panels closing windows) are removed.
  The art lint, the font specimen and the gallery still pass and show the old font as the world's font.
- **R8. Nothing lost.** Every fact, click and key these pieces offered still works. The tests of the
  specs listed above pass, amended only where they name a node or a pixel position (list each amendment
  and what still guards the behaviour).
- **R9. True in a crowded frame.** After a frame of 300 ticks the goals, the stage list and the ticker
  show the end state. A defeat heard late but still recent (spec 046 R5 decides what is recent, and a
  wipe older than that is not told) shows the note for the lost fight: its stage and its monsters come
  from the event, not from where the party is by then.
- **R10. Fits both rooms.** At 960x540 and 1280x720 the goals, the stage list, the ticker and the
  catching-up bar overlap neither the frame of the screen (spec 061's pieces and the button bar), nor
  each other, nor the room's edges, and no text is cut with the longest names in the data. Windows are
  drawn over the goals and the stage list, as they are over the world; their default places do not change.
- **R11. Showcase, help and wiki** are true to it, and the wiki no longer says the overhaul is under way.
- **R12. Tags stay under windows.** The count tags on the bar's buttons (spec 059's `UiBadge`) are drawn
  over their buttons and under any window dragged across the bar; tooltips stay above everything.

## Interfaces

Built on spec 058's classes; new pieces go in `game/ui/frame/` and the report in `game/ui/windows/`. The
logic that decides what the goals, the stage list, the note and the report say stays where it is; only
the drawing moves. Old drawing classes under `game/hud/` that nothing uses any more are deleted. Nothing
under `sim/` changes.

## Acceptance

In `tests/acceptance/test_062_goals_stages_and_news.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail, driven by real clicks, keys and wheel events at both
rooms. R7 searches the running scene for any node of the old HUD's classes. A reviewer will break the
code under each.

**To look at, and for Zak:** the whole screen with nothing open, with every window open, after a defeat
and on return from time away, at both rooms; crops of the goals and the stage list enlarged 3x. Describe
every shot. Is there anything left on screen that is hard to read?

## Out of scope

- The world's own text. Rebinding keys. A settings screen. Resizing windows.

## Paths

- `game/ui/`, `game/hud/`, `game/main.gd`, `game/dev/showcase.gd`
- `assets/`
- `tests/`
- `CLAUDE.md` (rules that name old HUD classes), `.claude/skills/`, `docs/architecture.md`,
  `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
