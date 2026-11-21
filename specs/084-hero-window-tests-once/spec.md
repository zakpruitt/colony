# 084 — The hero window and the talent tree, tested once

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** [#83](https://github.com/zakpruitt/colony/pull/83)

## Intent

The hero sheet was specified four times (026, 034, 055, then 060 and 064 rebuilt it as a window and a
tree), and each older test file was edited to keep passing. The audit of 2026-11-20 found the tree's look
asserted three times, a test whose main asserts never run, and a game function only a test calls. After
this spec `test_060` and `test_064` say what the window and the tree do, and the older files keep only
what they alone prove. Nothing the game does changes.

## Row rules

The row rules of spec 082 apply (line numbers at `a97d3c9`; open the survivor before cutting; a row that
cannot be confirmed is left and reported; a fix is seen to fail on broken code).

## Requirements

- **R1. A learned skill card is tested.** `test_060::test_r6_skills` (498-544) asserts a learned card's
  description, the side quests it answers and its white name only `if hero.level >= level`, with the hero
  at level 1 and no microskill before level 2. Run the per-card block at level 1 and again at level 30,
  so both branches are asserted. In `test_060::test_r3_tabs` (153-155) and `test_064::test_r10_skills`
  (733) an `if` that is always true today becomes an assert.
- **R2. `test_055` keeps what it alone proves.**
  - R1 `the_tree_is_drawn`: move the tab's text (133-135, 141), "the window keeps its size on Stats"
    (205-209) and the 32x32 icon (185) into `test_060::test_r3_tabs`; delete the rest. Survivors:
    `test_064::test_r1_the_shape` 24-73 and `test_r2_a_node_is_a_picture` 125-140. The joins (186-204) go
    only if `_check_joins` in `talent_tree_test_base.gd` asserts the same.
  - R2 `a_node_shows_its_state`: move "the pulse goes yellow then white" (228-232) and "the closed path's
    name in steel" (274-278) into `test_064::test_r3_the_states_read_at_a_glance`; delete the rest
    (survivor: that test, 195-227).
  - R3 `every_ability_can_be_read`: delete. Survivors: `test_064` R2 139-155, R5 317-336, and this file's
    R4 357-359. With it goes `HeroTalentsTab.reason()` in `game/ui/windows/hero_talents_tab.gd`, which
    nothing in `game/` calls.
  - R5: cut 413-417, 424 and 428 (`test_064::test_r7_points` 438-455); the tag on the tab's name and the
    level 5 to 6 step stay.
  - R7 `paragon`: move "Paragon points come after level 14", "0 paragon points" (526, 531) and
    `ParagonCell.text()` (547, 553) into `test_064::test_r9_paragon`; delete the rest (survivor: that
    test, 605-647, by a real click).
  - R9: cut 641-648 (`test_060::test_r2_the_header` line 95).
  - R11 `it_fits_and_is_explained`: keep only "every control has a one-sentence tooltip" (785-802).
    Survivors: `test_060::test_r10_fits` 773-803, `test_064::test_r13` 902-926, `test_074` R5.
  - R12 `in_the_showcase`: move "two trunk nodes taken at the start" (832-833) into
    `test_064::test_r14_help_wiki_and_showcase`; delete the rest.
- **R3. `test_060` hands the tree to `test_064`.**
  - R5 `the_tree_readable_without_pointing` (329-451): keep "keys 1 to 3 reach only the front window, and
    only on Talents" (429-441) as a test named for that; widen `test_064::test_r3`'s loop from knight and
    cleric to every class; delete the rest. Survivors: `test_064` R1, R2, R3, R7, R9, R11 at the lines its
    own comments name.
  - R8 `nothing_lost` (620-694): move "a fight starting drops the question, and `confirm()` then does
    nothing" (647-657) into `test_064::test_r11_nothing_lost`; delete the rest (survivor: that test,
    776-827, pair for pair).
  - R9: cut 738-747 and 767 (`test_064::test_r12` 865-873, 895) and the overwritten line 712.
  - R11: move "opens on Talents" and "the path is asked first" into `test_064` R14; cut 810-814
    (`test_030` R3); the wiki lines stay.
  - R1: cut line 18 and `OLD_SHEET` in `hero_windows_test_base.gd` (a deleted file stays deleted).
  - `test_064::test_r13_fits_and_still_compares`: cut 927-937 and 945-946 (`test_060::test_r7_compare`
    577-580); "the strip is in view" (938-944) stays.
- **R4. `test_026` and `test_034` keep what they alone prove.**
  - `test_026` R1 (80-156): keep the marked edge's colour (98-102), "Esc opens nothing" (117-118), the
    close button (120-126) and "the game runs behind it" (148-156); cut the rest. Survivors:
    `test_060::test_r1_a_window_per_hero` 20-53 and `::test_r3_keys_reach_only_the_front_window` 247-257.
  - `test_026` R3: keep "in a fight the health is the fighter's" (226-231) with the setup it needs; cut
    the rest (`test_060::test_r2_the_header` 100-118).
  - `test_026` R7 `it_fits`: add its extreme values (436-442) as a case of `test_060::test_r10_fits`;
    delete the rest.
  - `test_034` R1 `compact`: add "the window is the same size on every tab" to `test_060::test_r10_fits`;
    delete the rest.
  - `test_034` R2: cut 155-160 (pixel constants). R3: cut 171-177 (`test_060` R3 line 138). R4: cut
    239-259 and 267-272 (`test_060::test_r3_tabs` 156-175) and the direct calls at 250-252.
- **R5. Two more duplicates go.**
  - `test_063::test_r7_the_present_screens_show_the_pictures` (457-489), with `OLD_SHEET`. Survivors:
    `test_064` R2 line 131, R9 line 618, R10 line 701; `test_065::test_r1_a_card_per_upgrade` line 109.
  - `tests/unit/test_hud_talents.gd::test_every_tree_node_has_a_picture`. Survivor:
    `test_063::test_r1_its_own_picture`.
  - `test_063::test_r8_two_sounds`: cut 496-503 (`test_021::test_r2_every_sound_loads` and
    `sfx.py lint`).
- **R6. Dead setup is gone.** The audio-bus unmute in `after_each` of `test_034` and `test_055`;
  `test_034`'s unused `STAT_KEYS`.

## Interfaces

`HeroTalentsTab.reason()` is removed. Nothing else.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_060::test_r6_skills` | fails when a learned card's description or its "answers" line is left empty, passes on today's code |
| R2 to R6 | (lane's report) | each row as done or left, with the reason; the test names before and after; lines of `tests/` before and after |

## Out of scope

- `test_026` R4's stats helpers, `test_028` R7, the readout `HeroWindow.line(&"microskills")`.
- Splitting long tests, renaming files, any other change under `game/`.

## Paths

- `tests/acceptance/`: `test_026_hero_sheet.gd`, `test_034_hero_sheet_tabs.gd`,
  `test_055_the_tree_on_the_sheet.gd`, `test_060_hero_windows.gd`, `test_063_pictures_and_the_moment.gd`,
  `test_064_the_talent_tree_as_a_tree.gd`, `hero_windows_test_base.gd`, `talent_tree_test_base.gd`
- `tests/unit/test_hud_talents.gd`
- `game/ui/windows/hero_talents_tab.gd` (`reason()` only)

## Open questions
