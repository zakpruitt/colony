# 060 — Hero sheets as windows, several at once

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 026, 028, 034, 051, 055, 058

## Intent

Zak wants to "have multiple screens open individually at once and compare or put side by side". The
thing most worth comparing is two heroes: their stats, and above all their talent trees. Today one sheet
shows one hero, 240 pixels wide. This spec makes each hero's sheet its own window on the sharp layer,
with the tree given the room to show what every ability does without pointing at it.

## Requirements

- **R1. A window per hero.** Clicking a hero's frame opens that hero's window; clicking it again closes
  it. Up to four can be open at once, one per hero, each a window of spec 058 (movable, layered,
  remembered per hero). `Tab` opens the next hero's window and brings it to the front without closing the
  others; `Shift+Tab` closes the front hero window. The frame of every hero whose window is open has the
  yellow edge. The old sheet is removed.
- **R2. The header.** Portrait at twice the size, the class and path in bold (`Knight, Berserker`), role,
  level, what the hero is doing now, and health and XP as bars with numbers, as today.
- **R3. Tabs.** Stats, Talents and Skills, with the tags that count what waits there; `Q` and `E` change
  the front hero window's tab. Each hero window remembers its own tab.
- **R4. Stats with reasons.** Each stat on a line with its value, and beside it in green what raises it
  and by how much in words (`Damage 14   +15% Sharp Blades, +6% Power`).
- **R5. The tree, readable without pointing.** The Talents tab shows the trunk and both paths with every
  node's picture, name, whether it is an action or a passive, and its one-line description in the text
  beside or under the node, wrapped, never cut. The four node states of spec 055 are kept (taken, can be
  taken now, not yet, closed) and a closed path's descriptions stay readable, dimmed. The unspent points,
  the next point's level, the reset with its price and reasons, the question before a path is chosen and
  before a reset, and the paragon stats with `+1` and keys `1` to `3` (front hero window, Talents tab)
  all work as in spec 055.
- **R6. Skills.** The class's microskills as cards: learned ones with what they do and which side quest
  they answer, the ones to come dimmed with their level.
- **R7. Compare.** Two hero windows at their default places sit side by side at 1280x720 without
  overlapping each other or the hero frames' line; at 960x540 they cascade (each offset so both title
  bars show). The default place of a hero's window depends on which hero it is.
- **R8. Nothing lost.** Every command the old sheet sent (`take_talent`, `spend_paragon`,
  `reset_talents`) is sent with the same effect, a reset is never charged at a price the player did not
  read (spec 055's rule: the question goes away when the price changes or a fight starts), and the goals
  and the defeat note that opened the old sheet on a tab open the hero's window on that tab. The tests of
  specs 026, 028, 034, 037, 041, 042 and 055 that cover the sheet pass, amended only where they name a
  node or a pixel position (list each amendment and what still guards the behaviour).
- **R9. True in a crowded frame.** After a frame of 300 ticks holding level-ups, a talent taken and a
  fight, every open hero window shows the end state: points, nodes, stats, health, doing-now.
- **R10. Fits.** With the longest ability names and descriptions in the data, for all four classes, no
  text on any tab is cut or overlaps, at both rooms; a hero window is never taller than the room.
- **R11. Help, wiki and showcase.** The help lists `Shift+Tab`; the wiki describes hero windows and
  comparing; the showcase's talent moment uses the window.

## Interfaces

Built on spec 058's classes, unchanged; if one needs a new function, add it and say so. New contents go
in `game/ui/windows/` (`hero_window.gd` and one class per tab). Window ids are per hero
(`&"hero_0"` … `&"hero_3"`). `TalentNode.KINDS` (which picture an ability gets) moves to data: a
`picture: StringName` field on `AbilityDef`, checked by `validate()`, a view hint like spec 057's `move`
that no rule reads and the state hash leaves out. Nothing else under `sim/` changes.

## Acceptance

In `tests/acceptance/test_060_hero_windows.gd`, one test per requirement named `test_rN_…`, each seen to
fail first on broken code, driven by real clicks and keys and checking the simulation after each
command. R5 and R10 cover both paths of all four classes. A reviewer will break the code under each.

**To look at, and for Zak:** one hero's three tabs; a fresh hero, one at the fork, one on a path, one
with a full tree and paragon points; two heroes side by side on Talents at 1280x720 and cascaded at
960x540. Describe every shot. Can you read a whole tree without touching the mouse, and compare two?

## Out of scope

- The shop, map and tally (spec 059). The fixed HUD and the hero frames themselves (spec 061).
- New abilities or rules. Equipment. Resizing windows.

## Paths

- `game/ui/`, `game/hud/`, `game/main.gd`, `game/dev/showcase.gd`
- `sim/defs/ability_def.gd`, `data/abilities/` (the `picture` field only)
- `assets/`
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
