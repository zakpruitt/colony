# 111 — Skill paths: the window

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M8
- **Depends on:** 058, 060, 063, 064, 109, 110
- **Pull request:** —

## Intent

Specs 109 and 110 give each hero three skill paths that rank up through use. The Talents tab shows
them only as plain columns. This spec makes the tab a real feature, in the spirit of Skyrim's skill
screens. Three panels stand side by side, and each shows how far its path has grown and what its
rank still holds shut. A path ranking up, and a capstone learned, each feel like an event. Help, the
wiki and the showcase tell the new story.

## Requirements

- **R1. Three panels.**
  - The tab shows the class's three paths as three panels side by side across the window's width
    (`HeroWindow.WIDTH`, 600 UI pixels), in path order, with clear space between them.
  - Each panel has its banner on top (`PathBanner`, in the path's colour from `PathColours`): the
    path's name in bold, the summary line under it (on up to two lines, never cut), and on the name's
    line its rank, `Rank 3`.
- **R2. A bar to the next rank.**
  - Under each banner is a bar in the path's colour, filled by how far the path's XP has come from
    its rank's threshold toward the next.
  - At the top rank the bar is full and the banner says `Rank 10, top`.
  - Pointing at the bar shows a tooltip: `Guardian rank 3: 34 of 40 XP to rank 4. Won fights give
    path XP: one for each node held here, and one each time one of its abilities acts.` The numbers
    are read from the hero and the tree's `rank_xp`.
- **R3. Tier rows with lines.**
  - Under the bar, the path's nodes stand in four rows, one per tier: tier 1 centred, the two tier-2
    nodes side by side, tier 3 centred, the capstone centred.
  - Lines with arrowheads run from tier 1 to each tier-2 node, from each tier-2 node to tier 3, and
    from tier 3 to the capstone.
  - A line into a taken node is lit in the path's colour. A line into a node the rank holds shut is
    dark (`PathColours.dim()`). Any other line is plain.
  - The capstone is marked as the path's end: its name in bold and a ring in the path's colour round
    its slot in every state.
  - Each node is a large `UiIcon` (spec 063) with its name under it, centred, on one or two lines,
    never cut. Action and passive frames are as spec 064 R2 has them.
- **R4. The states read at a glance.**
  - Taken: the owned frame.
  - Can be taken now: the ready frame, pulsing.
  - Waits for a node above it, or for a point: locked.
  - Held shut by its path's rank: locked, with `Rank 5` written on the slot's corner (the slot's
    count label), so the player sees without pointing which rank opens it.
- **R5. Pointing and the strip tell all.**
  - Pointing at a node shows its card (spec 063 R3). The card's standing is one of:
    - `Learned`
    - `Click to learn`
    - `Take Whirlwind first`
    - `Take Bloodthirst or Reckless Swing first`
    - `No points: the next comes at level 12`
    - `Rank 5 in Guardian opens this (now rank 3)`
  - When a node waits for more than one thing, the standing names them in that order: the node
    above it, then the rank, then a point.
  - The strip at the tab's foot (spec 064 R6) shows the node under the mouse. With none, it shows
    the first node the hero can take now. With none of those, it shows the first node held shut only
    by its rank, with `34 of 150 XP to Rank 5`. With none of those either, it shows the first node
    not taken. `Learn` takes a node that can be taken.
- **R6. Points and paragon.**
  - The points row works as spec 064 R7 says, with the reset and its question.
  - Once all fifteen nodes are learned, the row says `All 15 learned`.
  - The paragon medallions and their keys work as spec 064 R9 says.
- **R7. A path ranks up: a moment.** Each case below is for a recent `PATH_RANKED`. A stale one, or
  one heard while catching up, changes the numbers with no burst, no banner and no sweep (spec 063
  R6).
  - The panel's rank number bursts (spec 063 R4). The bar fills, then starts again from empty for
    the next rank.
  - A rank that opens a tier for that path (one of the tree's `tier_ranks` above 0) also brings a
    banner: the picture of the first node it opens, `Knight: Guardian rank 5`, and under it
    `Bulwark can be learned now`, naming the tier's nodes. The newly opened nodes lose their `Rank`
    corner and pulse if a point waits.
  - The top rank also brings a banner, `Knight: Guardian at its top rank`.
  - Other rank-ups bring no banner, so four heroes ranking twelve paths do not crowd the screen.
  - The journal says `The Knight's Guardian reached rank 5` for each rank that opens a tier or is
    the top.
- **R8. A capstone learned: a bigger moment.** Each case below is for a recent `TALENT_TAKEN` of a
  tier-4 node. A stale one, or one heard while catching up, gets none of it.
  - The capstone's node bursts.
  - The lines of its path light up one after another, from tier 1 down, within 0.6 s.
  - Instead of the plain `learned` banner, the banner says `<Class> masters <Path>` with the
    capstone's picture and its description's first sentence.
  - The journal says `The Knight mastered Guardian`.
- **R9. Fits, and still compares.**
  - For all four classes, with the longest names and summaries in the data, no text is cut or
    overlapping at 960x540 and 1280x720.
  - The window is never taller than the room. The tab scrolls inside it as spec 060 lets it.
  - Two hero windows on Talents still sit side by side at 1280x720 (spec 060 R7, spec 064 R13), and
    cascade at 960x540.
- **R10. True in a crowded frame.** After a frame of 300 ticks holding a won fight that ranks a path,
  a node taken and a level-up, every open hero window's panels, ranks, bars, nodes, strip and points
  show the end state. A still tab words nothing (`HeroTalentsTab.worded`, spec 064).
- **R11. Help, wiki and showcase.**
  - Help (`help_panel.gd`) tells, in a line or two, that each hero has three skill paths, that
    winning fights with a path's abilities ranks it up, and that ranks open its deeper tiers.
  - The wiki's "Heroes, talents and paragon" section (`docs/wiki/index.html`) is rewritten for skill
    paths: the rules of points, tiers and ranks, the rank table as the data has it, and one table per
    class listing each path's nodes by tier with kind and description. The finished entries for
    specs 109, 110 and 111 are added.
  - The showcase's tree moment shows a node taken by a click, a path ranking up after a won fight,
    and a capstone learned, each as the player would see it. A watcher checks that the banner and the
    burst happened.
- **R12. Nothing lost.** The commands and their effects do not change; a reset is never charged at
  a price the player did not read; goals and the defeat note still open the right tab; the tags that
  count waiting points do not change. The tests of specs 055, 060 and 064 that cover the tab pass,
  amended only where they name a node, a pixel position or a word this spec changes (list each
  amendment and what still guards it).

## Interfaces

Built on spec 063's `UiIcon`, `UiMoment`, `UiTip` and on the pieces in `game/ui/windows/`:
`HeroTalentsTab`, `TalentTreeView`, `TalentNode`, `PathBanner`, `NextStrip`, `ParagonCell`,
`PathColours`. Reuse them. If one needs a new function, add it and say so in the pull request.
Nothing under `sim/` changes; the panels read `hero.ranks` and the tree's `rank_xp` and
`tier_ranks` (spec 110).

```gdscript
# game/ui/windows/path_banner.gd: what tests read
var rank_label: Label
var rank_bar: Control          # its fill share is readable as rank_bar.share() -> float, 0..1
func show_rank(rank: int, xp_into: int, xp_span: int, top: bool) -> void
```

## Acceptance

In `tests/acceptance/test_111_skill_paths_the_window.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail. Each test is driven by real clicks, keys and mouse
motion, and checks the simulation after each command.

- R1 and R3 measure rectangles: three panels within 600 pixels, apart by a stated gap; each tier's
  row below the one before; the tier-2 pair side by side and clear of each other.
- R7 and R8 check the recent case and the stale case both.
- `test_064` is at 976 of its 985 lines (spec 081). Checks this spec supersedes are removed from it,
  not added to it, and shared helpers go in `talent_tree_test_base.gd`.

A reviewer will break the code under each requirement.

**To look at, and for Zak:**

- Each class's tab: fresh; with tier 2 held shut by rank; half learned; and full with paragon.
- A card over a rank-held node; the bar's tooltip.
- Three frames each of a rank-up that opens a tier and of a capstone learned.
- Two heroes side by side at 1280x720, and cascaded at `--ui-room=960x540`.

Crop and enlarge small parts 3x, and describe every shot. Does each path read as something growing,
and does a capstone feel earned?

## Out of scope

- Any rule, number or save change (specs 109 and 110). New pictures (spec 109 made them). New
  sounds: banners and bursts use spec 063's two.
- A separate skills screen or window, new keys, dragging nodes, respec previews.
- The Stats and Skills tabs, beyond keeping them working.

## Paths

- `game/ui/windows/` (the hero window, its Talents tab and pieces, `HeroWindows`' moments,
  `help_panel.gd`; not the shop, map, tally or away windows), `game/ui/` (additions to shared classes
  only)
- `game/hud/journal.gd`
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_111_skill_paths_the_window.gd` and its `.uid`,
  `tests/acceptance/talent_tree_test_base.gd`, `hero_windows_test_base.gd`,
  `test_055_the_tree_on_the_sheet.gd`, `test_060_hero_windows.gd`,
  `test_064_the_talent_tree_as_a_tree.gd`, `test_063_pictures_and_the_moment.gd` (only if a banner it
  counts changes), `tests/unit/test_hud_talents.gd`
- `docs/architecture.md`, `docs/style-bible.md` (if the panel adds a convention),
  `docs/wiki/index.html`

## Open questions

None.
