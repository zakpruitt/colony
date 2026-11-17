# 034 — A hero sheet that fits: tabs

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 026, 028, 029
- **Pull request:** [#35](https://github.com/zakpruitt/colony/pull/35)

## Intent

Three specs each added a section to the hero sheet, and it is now 232x272: it covers a third of the screen,
hides the party it describes and has no room for anything more. This spec gives it back its shape. The
sheet becomes a compact panel with a header that is always there and three tabs under it, so each thing a
player does with a hero (look, train, read their microskills) has its own uncluttered page, and later
sections (equipment, talents) have somewhere to go.

## Requirements

Everything follows `docs/style-bible.md` and the existing sheet's look.

- **R1. Compact.** The sheet is at most 240 wide and 150 tall, for every hero and every tab.
- **R2. A header that never changes.** Portrait, class, role, level, the activity line, and the health and
  XP lines with their bars are always visible above the tabs, exactly as today.
- **R3. Three tabs.** `Stats`, `Training` and `Skills`, as a row of small tab buttons under the header; the
  open tab is lit. `Stats` holds the stat block, `Training` the three training rows, `Skills` the
  microskills list. Only the open tab's content is shown and only it takes clicks.
- **R4. Tabs are easy to reach.** Clicking a tab opens it; `Q` and `E` move to the previous and next tab
  while the sheet is open, wrapping. The open tab is remembered while moving between heroes with `Tab` and
  across closing and reopening the sheet within a session; a new session starts on `Stats`.
- **R5. Training tells you it is there.** When the shown hero can afford at least one training, the
  `Training` tab carries a small marker (as the Shop button does for affordable upgrades), whichever tab is
  open.
- **R6. Skills tell you they changed.** When the shown hero has learned a microskill since their `Skills`
  tab was last open, that tab carries a marker until it is opened.
- **R7. Number keys follow the tab.** `1`, `2` and `3` train only while the `Training` tab is open.
- **R8. Nothing is lost.** Every line the sheet exposed before (`HeroSheet.line` keys, the training rows,
  the microskills text) still exists with the same text and values, whichever tab is open; the tests of
  specs 026, 028 and 029 pass, updated only where they assert the sheet's size, a position, or press `1` to
  `3` without opening the Training tab first.
- **R9. It stays out of the way.** The sheet sits below the top band, at least 12 px above the party frames,
  inside the screen, with no labels overlapping, on every tab.

## Interfaces

```gdscript
# game/hud/hero_sheet.gd gains
enum Page { STATS, TRAINING, SKILLS }
func page() -> Page
func open_page(page: Page) -> void
func next_page() -> void
func previous_page() -> void
func page_marked(page: Page) -> bool      # the marker of R5 and R6
```

## Acceptance

In `tests/acceptance/test_034_hero_sheet_tabs.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_compact` | The sheet's size for each hero on each tab |
| R2 | `test_r2_header_never_changes` | The header lines and bars visible and unchanged on each tab |
| R3 | `test_r3_three_tabs` | Each tab's content visible only on that tab; the lit tab; clicks on a hidden tab's controls do nothing |
| R4 | `test_r4_easy_to_reach` | Click, `Q`, `E` and their wrap; the tab kept across `Tab`, close and reopen; `Stats` in a new HUD |
| R5 | `test_r5_training_marker` | The marker with and without enough gold, from each tab |
| R6 | `test_r6_skills_marker` | The marker after a microskill is learned, cleared by opening the tab |
| R7 | `test_r7_number_keys` | `1` trains on the Training tab and does nothing on the others |
| R8 | (the existing suite) | `python tools/dev.py check` passes |
| R9 | `test_r9_out_of_the_way` | Rectangles and label overlaps on each tab |

**To look at, and for Zak:** a shot of each tab for the rogue mid-fight with gold to spend (a throwaway
scene; do not commit it). Crop and enlarge. Is each page clean, and is it obvious there are other pages and
what is on them? Describe the shots.

## Out of scope

- New content in the sheet; any change under `sim/`.
- New sprites or sounds.

## Paths

- `game/hud/hero_sheet.gd` (and a new file beside it if the class nears gdlint's 1000 lines),
  `game/hud/hud.gd` (`Q`, `E` and the number keys only)
- `tests/acceptance/test_034_hero_sheet_tabs.gd`
- `tests/acceptance/test_026_hero_sheet.gd`, `test_028_seeing_side_quests.gd`, `test_029_hero_training.gd`
  only as R8 allows (say which)
- `game/hud/help_panel.gd` (the new key's row in `KEYS`) and `tests/acceptance/test_030_help_and_hints.gd` (the
  new key's case in `_check_entry`): the help panel lists every key, and its test fails otherwise
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
