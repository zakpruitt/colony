# 061 — The frame of the screen on the sharp layer

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 011, 024, 027, 030, 032, 039, 049, 052, 056, 058

## Intent

After specs 058 to 060 the windows are sharp and readable but the things always on screen (the place
panel, the countdown, the gold and resources, the hero frames, the boss bar and every tooltip) are still
drawn chunky in the old 5-pixel font. Zak: "the font is hard to read ... getting the UI to be friendly
and nice will be paramount." This spec redraws the frame of the screen on the sharp layer in the new
font, so the text the player reads most is the easiest to read.

## Requirements

- **R1. The place panel** (top left), on the sharp layer: the area's name (a click opens the map, with
  the mark for a newly opened area), the stage in large digits, `Safe 3`, the target with `-` and `+`
  buttons, the Auto switch, and the line for what the party is doing and why. Buttons are spec 058's
  buttons, at least 20 UI pixels tall.
- **R2. The countdown** beside it: `Stable in 8:29` over its bar, `Stable`, `Further in 0:42` with what
  comes next, `staying on stage 3`, `Holding`, exactly as specs 027 and 039 define them.
- **R3. The purse** (top right): gold with its coin, then each resource the party holds with its icon and
  count, in the equal-width digits, shortened from 10,000 as spec 052 says, counting up as coins and
  resource icons arrive. The game-speed button sits with it and is lit above 1x.
- **R4. Things still fly to it.** Coins fly to the gold, resource icons to their counter and XP motes to
  each hero's frame, arriving at the counter's or frame's real place on screen at every window size
  (through `UiRoot.world_to_ui` and back), and the count rises as they land.
- **R5. Hero frames** (bottom), on the sharp layer, in marching order: portrait, class in bold, level,
  the health bar with its number on it (`34 / 40`), the XP bar, up to three status icons, the tag for
  points to spend, the yellow edge while the hero's window is open, the flash when hit, the skull and
  `Down` or `Recovering`. A click opens the hero's window (spec 060). The health bar still follows a
  fight blow by blow.
- **R6. The boss bar** (top centre, in a guardian fight): the guardian's name in bold over a wide bar with
  its health as a number, draining smoothly and flashing on a hit.
- **R7. Tooltips** for everything on the sharp layer are spec 058's tooltips in the new font: a title in
  bold where there is one, then one or two sentences, wrapped, never off screen, never over what they
  explain, after 0.4 s. Every tooltip text the old pieces had is kept.
- **R8. Nothing drawn twice, nothing lost.** Each piece moved is removed from the old HUD. Every fact,
  click and key the old pieces offered still works. The tests of the specs listed above that cover them
  pass, amended only where they name a node or a pixel position (list each amendment and what still
  guards the behaviour).
- **R9. True in a crowded frame.** After a frame of 300 ticks every piece shows the simulation's end
  state (stage, safe stage, target, status line, countdown, gold, resources, each hero's level, health
  and statuses), with no stale flash or half-played change.
- **R10. Fits both rooms and clears the windows.** At 960x540 and 1280x720 no piece overlaps another, no
  text is cut with the longest area, monster and class names in the data, and the default places of every
  window clear every piece of the frame.
- **R11. Showcase, help and wiki** are true to it.

## Interfaces

Built on spec 058's classes; new pieces go in `game/ui/frame/` (`place_panel.gd`, `countdown.gd`,
`purse.gd`, `hero_frame_view.gd`, `boss_bar_view.gd`), one class each, made of `Control` nodes and the
theme. The texts stay where they are made today (`game/hud/place_text.gd` and the like); only the drawing
moves. Nothing under `sim/` changes.

## Acceptance

In `tests/acceptance/test_061_the_frame_of_the_screen.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail, driven by real clicks and keys, at both rooms where a
place matters. R4 measures where a coin, a resource icon and an XP mote end against the counter's and
the frame's screen rectangles at three window sizes. A reviewer will break the code under each.

**To look at, and for Zak:** the whole screen in a quiet moment, in a busy fight and in a guardian fight,
at both rooms, with crops of the place panel, the purse and a hero frame enlarged 3x; a tooltip on each.
Describe every shot. Can everything be read at a glance from where you sit?

## Out of scope

- Goals, the stage list, the ticker, the defeat note, the away report (spec 062).
- The world's own text (damage numbers, ability names, titles). Rebinding keys. A settings screen.

## Paths

- `game/ui/`, `game/hud/`, `game/effects/` (where effects fly to), `game/main.gd`, `game/dev/showcase.gd`
- `assets/`
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
