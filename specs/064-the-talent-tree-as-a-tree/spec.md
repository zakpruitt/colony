# 064 — The talent tree as a tree, with paragon and skills

- **Status:** landed (provisional: not yet reviewed by Zak) (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 028, 051, 055, 060, 063
- **Pull request:** [#66](https://github.com/zakpruitt/colony/pull/66)

## Intent

Zak wants talent trees "similarly set up to WoW with a clear diversion and graphics / icons for each
skill / talent node you slot in", the same for paragon, "clear what you're getting rather than some
text", and gains that "feel like bigger accomplishments". Today the Talents tab is a list of sentences
with a small picture beside each. This spec makes it a tree of pictures that visibly forks into two
paths, with the words one hover away, and makes taking a node an event.

This replaces spec 060 R5's rule that every description is written out in the tree.

## Requirements

- **R1. The shape.** The trunk's three nodes run down the middle from the top, joined by lines with
  arrowheads. Under the last one the line splits left and right into the two paths, each a column of
  four nodes under its own banner. The fork is the plainest thing on the tab: the two paths stand apart
  with clear space between them, each in its own colour (banner, lines and frame tint), the same two
  colours wherever that path is named in the window.
- **R2. A node is a picture.** Each node is a large `UiIcon` (spec 063) with the ability's name under
  it, centred, on one or two lines, never cut. An action has the square frame, a passive the cut one.
  No description is written in the tree.
- **R3. The states read at a glance.** Taken: owned frame, and the line into it lit in the path's
  colour. Can be taken now: ready frame, pulsing. Not yet: locked. On the path not chosen: closed, its
  banner dimmed with a padlock and `Not chosen`, its lines dark; its nodes can still be pointed at.
- **R4. A path says what it is.** Each banner carries the path's name in bold and one short line saying
  what a hero on it becomes (`Guardian: holds the line and keeps the party standing`). The line is data.
- **R5. Pointing tells all.** Pointing at a node shows a card (spec 063 R3): picture, name, `Action,
  every 8 s` or `Passive`, the whole description, and how it stands in words (`Click to learn`, `Take
  Whirlwind first`, `No points: the next comes at level 9`, `Learned`, `Guardian was not chosen`).
- **R6. What is next, without pointing.** A strip at the foot of the tree shows one node in full: its
  picture, name, kind, whole description and standing. It shows the node under the mouse; with none, the
  first node the hero can take now; with none of those, the first not yet taken on the hero's way. When
  it shows a node that can be taken, it has a `Learn` button that takes it.
- **R7. Points.** The top of the tab says how many points wait, as a number large enough to notice
  (`2 points to spend`), or when the next comes (`Next point at level 9`). The reset with its price and
  reasons, and both questions (before a path is chosen, before a reset), work as spec 055 rules; the
  question before a path shows that path's banner and its four pictures.
- **R8. Taking a node is a moment.** When the hero takes a node (click, the `Learn` button or the
  question's yes) and the event is recent: the node bursts (spec 063 R4), the line into it lights, and a
  banner says `<Class> learned <Ability>` with the ability's picture and its description's first
  sentence. Taking the first node of a path says `<Class> is now a <Path name>` with the path's line
  instead, and the other path closes before the player's eyes within 0.5 s. A stale event, or one heard
  while catching up, changes the tree with no burst and no banner.
- **R9. Paragon.** Under the tree, once the hero has paragon points or ranks: one medallion per paragon
  stat (a large `UiIcon` with the stat's picture and its rank as the count), the stat's name and the
  total it gives (`+6% damage`) under it, and the points waiting beside them. A click on a medallion, or
  `1` to `3` on the front hero window's Talents tab, spends a point; the medallion bursts and its count
  goes up. Every tenth rank of a stat gets a banner (`Knight: Power 10, +20% damage`).
- **R10. Skills.** The Skills tab's cards carry each microskill's picture in a large `UiIcon`: owned
  when learned, locked with its level (`Level 8`) when not. A microskill learned (a recent
  `MICROSKILL_LEARNED`) gets a banner, and a burst if the hero's window is open on Skills.
- **R11. Nothing lost.** `take_talent`, `spend_paragon` and `reset_talents` are sent with the same
  effect; a reset is never charged at a price the player did not read; the goals and the defeat note
  still open the hero's window on the right tab; the tags that count what waits are unchanged. The tests
  of specs 026, 028, 034, 037, 041, 042, 051, 055 and 060 that cover these tabs pass, amended only where
  they name a node, a pixel position or spec 060 R5's written descriptions (list each amendment and what
  still guards the behaviour).
- **R12. True in a crowded frame.** After a frame of 300 ticks holding level-ups, a node taken and
  paragon spent, every open hero window's tree, strip, points and medallions show the end state.
- **R13. Fits, and still compares.** For all four classes, both paths, with the longest names in the
  data: no text cut or overlapping at 960x540 and 1280x720, the window never taller than the room, and
  two hero windows on Talents still sit side by side at 1280x720 (spec 060 R7).
- **R14. Help, wiki and showcase.** True to it; the showcase's talent moment shows a node being taken
  and a path being chosen.

## Interfaces

Built on specs 058, 060 and 063, unchanged; if one needs a new function, add it and say so. A new view
hint on `TalentTreeDef`, checked by `validate()` (two, none empty, none over 60 characters), that no
rule reads and the state hash leaves out:

```gdscript
@export var path_summaries: Array[String] = []   # one line per path
```

The lane writes the eight lines from what each path's abilities do. Path colours are a view table keyed
by class and path, in `game/ui/windows/`. Nothing else under `sim/` changes.

## Acceptance

In `tests/acceptance/test_064_the_talent_tree_as_a_tree.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail, driven by real clicks, keys and mouse
motion, checking the simulation after each command. R1 measures the nodes' rectangles (trunk centred,
paths apart by a stated gap, no node of one path within the other's column). R8 checks both the recent
and the stale case. A reviewer will break the code under each.

**To look at, and for Zak:** each class's tree fresh, at the fork, on each path, and full with paragon;
a card over a node; the question before a path; three frames of a node being taken and of a path being
chosen; the Skills tab; two heroes side by side at 1280x720 and cascaded at 960x540. Describe every
shot. Does it read as a tree with a choice in it, and does taking a node feel like something?

## Out of scope

- The pictures and the slot, card, burst and banner themselves (spec 063). The shop (spec 065).
- New abilities, more ranks per node, or any change to what a talent costs or needs. The Stats tab.

## Paths

- `game/ui/windows/` (the hero window and its tabs, the talent, paragon and skill pieces; not the shop,
  map, tally or away windows), `game/ui/` (additions to shared classes only)
- `game/main.gd`, `game/dev/showcase.gd`, `game/hud/` (help text)
- `sim/defs/talent_tree_def.gd`, `data/talents/` (the `path_summaries` field only)
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
