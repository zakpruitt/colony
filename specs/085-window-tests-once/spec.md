# 085 — The shop, the map, the tally and the bar, tested once

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** [#85](https://github.com/zakpruitt/colony/pull/85)

## Intent

The shop was specified in 017, became a window in 059 and cards in 065; the button bar in 058 and again in
068; each older test was edited to keep passing. The audit of 2026-11-20 found whole tests whose every
assert is made in the newer file, and tests named for things that are gone ("beside the old HUD"). After
this spec each window's behaviour is asserted in one place. Nothing the game does changes.

## Row rules

The row rules of spec 082 apply (line numbers at `a97d3c9`; open the survivor before cutting; a row that
cannot be confirmed is left and reported). `test_059::test_r1_three_windows` and
`test_065::test_r8_nothing_lost` are survivors for several rows here and are not touched.

## Requirements

- **R1. `test_017` keeps what it alone proves.**
  - R1: keep the button's tooltip (46), "Esc does not open" (62-63) and "opening the shop closes the away
    report" (65-71); cut the rest (`test_059::test_r1_three_windows` 101-116).
  - R3: keep "the game runs behind the open shop" (167-175); cut the rest (`test_065::test_r8` 587-605,
    `test_059::test_r8_fits_both_rooms` 656-661).
  - R4 `rows_show_affordability`: add "the buy button is enabled once gold arrives" (206) to
    `test_065::test_r1_a_card_per_upgrade`; delete the rest (that test 121-137 and 146-153,
    `test_065::test_r4` 277-286).
  - R5: keep "the command waits for the step" (228), "the HUD's gold drops at once" (237, 248) and "a
    disabled button and its key send nothing" (250-257); cut the rest (`test_065` R5 331-338, R7 545-554).
  - R7: cut 334-341 (`test_065` R7 535-547).
  - `before_each`: `_ui.bar.set_process(false)` (13) does nothing; remove it.
- **R2. `test_058`'s two files keep what they alone prove.**
  - `test_r2_the_old_hud_still_works`: move "exactly one HelpPanel, OrdersPanel and JournalView on the
    layer" (192-194) into `test_r8_three_panels_become_windows`; delete the rest (`test_061` R1 line 54,
    `test_068` R3 and R5, `test_060` R1).
  - `test_r5_windows`: cut 498-503 (`test_058_windows_beside_the_old_hud::test_r5_a_window_is_moved_wholly_back_when_the_room_shrinks`).
  - `test_r7_a_button_bar`: move "at the right" (593), "just above" (591), the tip box on screen (627-629)
    and `hinted_width` (609-611) into `test_068::test_r4_fits_both_rooms`; delete the rest (`test_068` R1
    135-147, R3 283-312, R4 396-403, R5 511-512; `test_074` R2 154-155).
  - `test_r9_screenshots_show_what_the_player_sees`: cut 771-774 (text of `tools/godot/shot.gd`; 778-801
    prove it by behaviour).
  - `test_r11_in_the_help_list_and_the_wiki`: delete, with `_key_names_in`, `KEY_PATTERN` and `WIKI`
    (`test_030::test_r3_every_key_is_listed` 356-368, `test_074` R5; its wiki check matches a word that
    now sits in a "Built" row).
  - Beside file, `test_r6_default_places_beside_the_old_hud`: it now loops over the goals alone. Rename
    it `test_r6_default_places_clear_the_goals` and drop `_old_panels`.
  - Beside file, `test_r5_nothing_closes_the_windows_but_the_player`: keep "a window closed and reopened
    by its key keeps its place" (145-154) under a name that says so; delete the rest.
  - Beside file, `test_r6_windows_left_open_wait_for_the_away_report`: delete
    (`test_062::test_r5_away_report_window` 431-433, 461-464; its name says the opposite of its asserts).
- **R3. `test_059` hands each window to its own file.**
  - R2 `the_shop_reads_at_a_glance`: move "the name in bold" (146), the literal sentence "Each rank
    gives ..." (151) and "no icon before rank 4" (168) into `test_065::test_r1_a_card_per_upgrade`; delete
    the rest (`test_065` R8 592-605, R3 234-235, R4 line 278, R1 133 and 136, R7 542-569).
  - R3 `the_map_reads_at_a_glance`: cut 224-250 (`test_053::test_r1_a_map_of_every_area`,
    `::test_r2_closed_areas`) and 274-279 (`test_053` R3 197-199, R5 line 333).
  - R4: lines 378-379 assert only inside an `if`; make the condition an assert.
  - R5 `nothing_lost`: cut 406-433 (`test_065::test_r8_nothing_lost` 606-624).
  - R6: cut what `test_017::test_r2_marker_when_affordable` asserts (the tag counting at 25 gold, hidden
    while open); the pulse (482-484) and the Map button's mark (492-505) stay.
  - R9: cut 742-747 (`test_074` R5, `test_068::test_r2` 206-207).
- **R4. Repeats in the tally, the map and the bar are cut.**
  - `test_045` R1: cut 176-194 (`test_059` R1 100-104, `::test_r8_beside_the_hero_windows` 700-726).
    R2: cut 229-231 (`amount >= 0` cannot fail). R6: cut 524-532 (`test_074` R5; and it reads
    `test_030`'s own source).
  - `test_052_resources` R2: cut 169-177 (`test_052_resources_kept::test_r11_still_deterministic`
    158-177 checks the same sample).
  - `test_053` R8: cut 517-527 (`test_074` R5, `test_068::test_r5_nothing_lost` 513-516) and 555.
  - `test_065` R11: cut the `not contains("+15% now")` check; remove the unused `PURSE`.
  - `test_068` R1: cut 146-147 (`test_074::test_r2_bar_tips_and_help_come_from_the_list` 150-153).
    R2: cut 196 and 251-257 (`test_074::test_r6` 314-318). R4: cut 425-430 and 443-444 (this file's R1
    164-165 and R3 299, `test_074` R2). R5: cut 525-532 (`test_062::test_r12_tags_stay_under_windows`).
    R6: cut 546-547 (this file's R2 206-207).

## Interfaces

None.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 to R4 | (lane's report) | each row as done or left, with the reason; the test names before and after; lines of `tests/` before and after |
| R3 | `test_059::test_r4_the_tally_reads_at_a_glance` | still passes with the `if` made an assert; if it does not, the row is reported, not forced |

After any change to `test_068`, CLAUDE.md's bar rule applies: `test --only=test_06` and `test_059`.

## Out of scope

- `test_059` R1, `test_065` R8, `test_053` R1 to R7, `test_056` R6, `test_046`.
- The vocabulary scan in `test_068` R2 (218-238). Splitting long tests, renaming files.
- Anything under `sim/` or `game/`.

## Paths

- `tests/acceptance/`: `test_017_upgrade_shop.gd`, `test_045_the_party_tally.gd`, `test_052_resources.gd`,
  `test_053_the_area_map.gd`, `test_058_sharp_ui_and_windows.gd`, `test_058_windows_beside_the_old_hud.gd`,
  `test_059_shop_map_and_tally_windows.gd`, `test_065_camp_upgrades_you_can_see.gd`,
  `test_068_a_button_bar_that_says_what_it_opens.gd`

## Open questions
