# 055 — The tree on the hero sheet

- **Status:** provisional (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 034, 037, 041, 042, 051
- **Pull request:** —

## Intent

Spec 051 gave every hero a talent tree but only a number on the sheet. This spec draws the tree, lets the
player read every ability, take a node, choose a path knowing what it closes, and spend paragon points.
Zak asked for trees that are "very interesting yet simple": the whole tree for a hero fits one tab with
nothing to scroll.

## Requirements

- **R1. The tree is drawn.** The hero sheet's Training tab becomes **Talents**. It shows the hero's tree:
  the three trunk nodes in a row, then the two paths side by side under their names, four nodes each,
  joined by lines. Each node has a small picture and its ability's name.
- **R2. A node shows its state.** Taken (bright, ticked); can be taken now (framed in yellow and gently
  pulsing when the hero has a point); not yet reachable (plain); closed because the other path was
  chosen (dark, with the path's name struck through).
- **R3. Every ability can be read.** Pointing at or selecting a node shows, in a fixed place on the tab,
  its name, its one-line description, whether it is an action (with its cooldown in seconds) or a
  passive, and why it cannot be taken when it cannot (`Take Taunt first`, `The Guardian path is closed`,
  `No talent point`).
- **R4. Taking a node.** A click on a node that can be taken takes it. The first node of a path asks
  first, in the same fixed place: `Choose Berserker? This closes Guardian.` with `Choose` and `Not yet`;
  only `Choose` sends the command.
- **R5. Unspent points are shown** on the tab's name and at the top of the tab (`2 talent points`), and
  the next level that gives one when there is none (`Next point at level 6`).
- **R6. A fresh start.** A `Reset` button shows its price, is greyed with the reason when it cannot be
  used (not enough gold, in a fight, nothing to reset), and asks before it acts.
- **R7. Paragon.** Once the hero has earned every talent point, the tab shows the three paragon stats
  under the tree with their bonus so far and a `+1` each, and the unspent paragon points. Before then
  the place says `Paragon points come after level 14`.
- **R8. The game points at it.** A hero with an unspent talent point has a mark on its frame; a goal
  appears (`Spend the Knight's talent point`) that opens that hero's Talents tab when clicked; the
  journal notes a point gained and a path chosen (`The Knight is now a Berserker`); the defeat note
  offers `Spend talent points` when any hero has one, ahead of its other advice.
- **R9. The hero's path is part of who it is.** Once a path is chosen its name shows beside the class on
  the hero's frame tooltip and at the top of the sheet (`Knight, Berserker`).
- **R10. True in a crowded frame.** Points, nodes and the goal follow events in order; a frame that holds
  three level-ups and a command shows the end state with no stale mark.
- **R11. It fits and is explained.** The tab fits the sheet at 640x360 with the longest names in the
  content; every control has a tooltip; the help panel's text about training is replaced.
- **R12. In the showcase.** A moment opens a hero's tree with one trunk node taken and a point to spend,
  takes a node, and chooses a path.

## Interfaces

None in `sim/`. `game/hud/hero_sheet.gd` is near gdlint's 1000 lines: the tab is a new class
(`game/hud/talent_tab.gd`) the sheet hosts. Node pictures are one plain 12x12 icon per ability *kind*
(strike, guard, heal, fire, frost, shadow, light, rally), not 44 drawings; art is placeholder.

## Acceptance

In `tests/acceptance/test_055_the_tree_on_the_sheet.gd`, one test per requirement named `test_rN_…`,
driven by real clicks where the requirement is a click, and checking the simulation after each command.
R2 covers all four states for both paths of two classes. R11 measures every node's label against its
box for all four classes.

**To look at, and for Zak:** the tab for a new hero, for one with a point at the fork, for one on a path,
and for one with a full tree and paragon points; each also cropped and enlarged 3x. Can you read the
whole tree at a glance, and is it clear what choosing a path costs? Describe every shot.

## Out of scope

- What abilities look like in a fight (spec 056). Any rule under `sim/`. New abilities.

## Paths

- `game/hud/`, `game/dev/showcase.gd`
- `assets/` (the eight icons)
- `tests/acceptance/test_055_the_tree_on_the_sheet.gd`, `tests/unit/test_hud*.gd`, older HUD tests where
  they assert the Training tab (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
