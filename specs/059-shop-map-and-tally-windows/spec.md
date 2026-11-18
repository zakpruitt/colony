# 059 — The shop, the area map and the tally as windows

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 017, 022, 045, 052, 053, 056, 058

## Intent

Second step of the UI overhaul Zak asked for ("multiple screens open individually at once ... side by
side or layer ... friendly and nice will be paramount"). Spec 058 made the sharp layer, the font and the
window system. This spec moves the three management panels onto it, each laid out afresh for the room
and the font it now has, so the shop can stay open beside the map while the tally runs.

## Requirements

- **R1. Three windows.** The Shop (`U`), the Area map (`W`) and the Party tally (`T`) are windows of spec
  058: movable, layered, remembered, each with a button on the bar, all three able to be open at once with
  Help, the Journal and the Orders. The old panels and the old Shop button are removed; the old tally
  button is removed. A click on the area's name at the top left still opens the map.
- **R2. The shop reads at a glance.** One row per upgrade: its name in bold, what one rank gives in a full
  sentence, its rank as `3 / 20` with a thin bar, the bonus it gives now, and one buy button showing the
  whole price (gold, and from rank 4 the resource with its icon). The button is in its normal state when
  the party can pay, disabled when it cannot, and under a disabled one the row says what is missing in
  words (`Needs 12 more clay, from The Claypits`). At the top rank the button reads `Max`. The window's
  foot holds the Auto-buy switch with a sentence saying what it does. Keys `1` to `5` and `B` work while
  the shop is the front window.
- **R3. The map reads at a glance.** One card per area: its name in bold, its monsters and guardian as
  sprites with names on hover, the guardian ticked once beaten, the level of its first stage, `Safe 3,
  furthest 5`, its resource with the count held, and `Here` or `On the way, 7 s`. A closed area's card is
  dimmed and says which guardian opens it and what it gives. Choosing a card shows the stage chooser
  (`-`, the stage, `+`, coloured safe, within reach or dangerous, with that word beside it) and a `Go`
  button whose text says what it will do (`Travel to The Claypits 3`, `Set target: stage 4`).
- **R4. The tally reads at a glance.** Tabs for Damage, Healing and Taken; the `Last fight` / `Session`
  switch; one bar per hero in its colour with the number and share, right-aligned numbers in the equal-
  width digits; a click on a hero's line opens its abilities under it, indented, each with its own thin
  bar. `Q` and `E` change tab while the tally is the front window.
- **R5. Nothing lost.** Every command the three old panels sent is sent by the new ones with the same
  effect on the simulation, and every fact they showed is still shown: the tests of specs 017, 022, 045,
  052, 053 and 056 that cover them pass, amended only where they name a node or a pixel position (list
  each amendment and what still guards the behaviour).
- **R6. The amber tag survives.** The bar's Shop button carries the count of upgrades the party can pay
  for; the bar's Map button carries the mark for a newly opened area until the map is opened.
- **R7. True in a crowded frame.** Each window shows the simulation's state after a frame of 300 ticks
  exactly as after the same ticks one a frame: ranks, prices, counts, area progress, tally numbers.
- **R8. Fits both rooms.** At 960x540 and at 1280x720, all three open at their default places overlap
  neither each other nor the hero frames' line, no text is cut or overlaps, and each fits its content
  with the longest names in the data.
- **R9. Help, wiki and showcase.** The help's keys are still true; the wiki describes the three windows;
  the showcase's shop and map moments use the windows.

## Interfaces

Built on spec 058's `UiWindow`, `UiWindows`, `UiRoot`, theme and `UiText`, unchanged; if one of them needs
a new function, add it and say so. New window contents go in `game/ui/windows/` (`shop_window.gd`,
`area_map_window.gd`, `tally_window.gd`), one class each, built from `Control` nodes and the theme.
`game/hud/tally.gd` (the counting) is kept and read by the new window. Nothing under `sim/` changes.

## Acceptance

In `tests/acceptance/test_059_shop_map_and_tally_windows.gd`, one test per requirement named `test_rN_…`,
each seen to fail first on broken code, driven by real clicks and keys and checking the simulation after
each command. R8 measures rectangles at both rooms. A reviewer will break the code under each.

**To look at, and for Zak:** each window alone, and all six windows open together, at both rooms; the shop
with a row the party cannot pay; the map with a closed area and with an area chosen; the tally with a
hero's abilities open. Describe every shot. Is each one friendly to read at a glance?

## Out of scope

- Hero sheets (spec 060). The fixed HUD (spec 061). New rules, upgrades or areas. Resizing windows.

## Paths

- `game/ui/`, `game/hud/`, `game/main.gd`, `game/dev/showcase.gd`
- `assets/` (bar icons)
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
