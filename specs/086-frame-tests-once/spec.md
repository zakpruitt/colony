# 086 — The frame of the screen, tested once and on the screen the game shows

- **Status:** provisional
- **Milestone:** M8 (cleanup)
- **Depends on:** 081
- **Pull request:** —

## Intent

The place panel, hero frames, goals, stage list and defeat note were first tested on the old HUD (specs
011, 027, 030, 033, 037, 041, 042) and are now tested on the UI layer by 061 and 062. The audit of
2026-11-20 found old tests that lay out a HUD with no UI layer (a screen the game never shows, where
`_hud.shop.open()` does nothing), "hides when another panel opens" asserts flipped to "stays shown" and
copied in seven tests, and checks for classes and files that no longer exist. After this spec the older
files keep only what they alone prove. Nothing the game does changes.

## Row rules

The row rules of spec 082 apply (line numbers at `a97d3c9`; open the survivor before cutting; a row that
cannot be confirmed is left and reported; a fix is seen to fail on broken code).
`test_062::test_r8_nothing_lost` 583-597, `test_062::test_r4_defeat_note_over_every_window`,
`test_033::test_r4_hover_says_it` and `test_043::test_r2_hover_says_it` are survivors here and keep those
lines.

## Requirements

- **R1. `test_011` keeps what it alone proves.**
  - R1: cut 38-56 (`test_061::test_r5_hero_frames` 305-319; the centring is the test-only layout); the
    health bar's ease and colours and the XP bar (58-82) stay.
  - R2: cut 95-113 (`test_061` R5 345-352, `test_027::test_r4_frames_show_who_is_down`); the level's
    pulse and the XP bar restarting (115-129) stay.
  - R3: cut 166-169 and what `test_061::test_r3_the_purse` 176-184 asserts; "never more than the party
    has", the catch-up (146-153, 161-164) and the "1.2M" form (156) stay.
  - R4: keep the emphasis on a change of stage (179, 203-205), and assert the exact "Safe 3" that
    `test_028::test_r8_safe_depth` asserts; cut the rest (`test_061::test_r1_the_place_panel` 39-46).
  - R5 `state_word`: delete (`test_027::test_r1_status_line`, line 108 and every state's sentence).
  - R6: keep "two presses before a tick count twice" (246-249), "never below 1" (257-262), the A key and
    "the display follows the simulation" (286-291); cut the rest (`test_061` R1 54-69, 637-644).
  - R8 `stays_in_its_bands`: delete, with `_collect`, `_in_band`, `_backed` and `_fill_of` (353-390)
    (`test_061::test_r10_fits_both_rooms_and_clears_the_windows`).
- **R2. Layouts measured on a HUD with no UI layer go.**
  - `test_024::test_r2_boss_bar`: cut 113-125 and 127-146 (`test_061::test_r6_the_boss_bar` 421-426,
    450-460); the name, "gone after a win" and "none in an ordinary fight" (106-111, 148-154) stay.
  - `test_027::test_r1_status_line_fits`: delete, with `_check_depth_panel`. Survivor: `test_061` R10
    771-800; if its guardian is not the one with the longest name, add that case there first.
  - `test_027::test_r6_it_fits`: keep "the game goes on with the journal open" (520-526) under a name
    that says so; cut the rest.
- **R3. The flipped "stays shown" asserts are made once**, in `test_062` R8 583-597, `test_062` R4
  357-366 and `test_058_sharp_ui_and_windows::test_r8` 642-649. Cut the copies: `test_030` R2 148-160,
  `test_033` R6 342-348, `test_037` R6 598-619, `test_041` R5 343-373, `test_042` R1 232-240 and R4
  474-492.
- **R4. Other duplicates go.**
  - `test_027::test_r1_status_line_working` (`test_028::test_r6_journal_and_status` 393-395).
  - `test_028::test_r8_safe_depth` (after R1's "Safe 3"), and `test_r11_showcase`
    (`test_018::test_r2_showcase_plays_every_moment`). `test_028` R7: cut 472-496
    (`test_060::test_r10_fits`).
  - `test_030::test_r4_tooltips`: move the frame's literal "Click for details" and "the labels are inside
    the box" into `test_061::test_r7_tooltips`; delete the rest with `_tipped` and `_check_tip`.
    R2: also cut 120-123 and 142-146 (this file's R3, `test_074` R5). R5: cut 486-490
    (`tests/unit/test_sound_settings.gd::test_help_seen_round_trips_beside_the_mute_choice`).
  - `test_037` R1: cut 153-159 and 165-173 (`test_062::test_r1_goals` 39-43, 92-96). R5: cut 537-545
    (it reads `test_030`'s own source).
  - `test_041::test_r6_journal`: move the counted line (460-462) and an ordinary defeat's line (464-466)
    into `test_046::test_r6_journal_keeps_what_it_said`; delete the rest.
  - `test_042` R4: cut 510-517 (`test_030` R3).
  - `test_043` R1: cut 158-162 (a doc comment's wording). R4: cut 319-329
    (`test_047::test_r2_goes_back_to_following` 176-192). R6: cut 393-397
    (`test_033::test_r2_rungs_say_what_they_are` 119-134) and 400-405 (`test_030` R3).
  - `test_046::test_r4_panel_does_not_use_time` (`test_062` R4, `test_041` 99-109; it asserts the
    opposite of its name) and `::test_r9_help_row` (`test_074` R5). R8: cut 370-375
    (`test_059::test_r5_nothing_lost` 456-458).
  - `test_047::test_r6_one_rule`: cut 400-405 and the comparisons of `PartyLevels.lowest()` with the
    private wrappers that return it; "a dead hero counts" (392) and the list's "Dangerous" line
    (411-412) stay. R4: cut line 301.
  - `test_061` R3: cut 204 (`test_058` R3 line 255). R5: cut 361-362. `test_r5_the_bar_and_the_ticker`:
    cut 398-404 (`test_062::test_r3_ticker` 286-288). R11: cut 865-872.
  - `test_061::test_r8_nothing_drawn_twice_nothing_lost`: delete 615-633. Its keys (635-660) go too if
    `test_030`'s `_check_entry` presses `=`, `-` and `A` and sees each act; otherwise they stay as a test
    named for the keys.
  - `test_061::test_r7_a_frame_tip_is_drawn_over_everything`: use one copy of `_drawn_over`,
    `_in_draw_order` and `_z_of` (move `frame_062_test_base`'s down into `frame_061_test_base`).
  - `test_062` R5: cut 480. R7: cut 515-524 and 541 (deleted files and classes). R8: keep 583-597 only
    (this file's R1 92-96 and R2 248-251, `test_030` R3, `test_043` R3 line 209). R9: add "the drawn
    label says it" to `test_046::test_r1_one_frame_defeat`, then cut 650-681. R11: cut 785-790 and the
    `"under way"` check. R12: remove `tip_over` (832, 840), which is never filled.
  - `test_067` R2: cut 203-210 (`test_030` R3). R3: cut line 223.
  - `tests/unit/test_hud_help.gd::test_every_listed_key_names_a_key` (`test_030` `_check_entry`;
    `test_058` R8 676-692 for the fit).
- **R5. Three tests are fixed.**
  - `test_043::test_r5_flash_is_seen`: its last part asserts only `if ladder.is_flashing(2)`; assert that
    it is flashing first.
  - `test_037::test_r2_goals_come_from_the_game`: 218-222 sit behind an `if` that skips silently, and
    289-305 work out `nearest_line` for an `else` (319-320) that today's party never reaches. Make both
    asserted, on a party set up so that they run.
  - `test_033` and `test_037`: `if x == null: fail_test` on a typed field cannot run; remove them.
- **R6. Dead setup is gone.** `_ui.bar.set_process(false)` in `test_033` (20, 401) and `test_041` (22,
  427); the audio-bus unmute in `after_each` of `test_028`, `test_037` and `test_042`; `test_061` R9's
  `recent_hits`, written and never read.

## Interfaces

None.

## Acceptance

| Requirement | Test | What it shows |
|---|---|---|
| R1 to R4, R6 | (lane's report) | each row as done or left, with the reason; the test names before and after; lines of `tests/` before and after |
| R5 | `test_043::test_r5_flash_is_seen` | fails when the flash is not started, passes on today's code |
| R5 | `test_037::test_r2_goals_come_from_the_game` | fails when the nearest microskill's line is worded wrongly, passes on today's code |

## Out of scope

- The HUD-alone path in `game/hud/hud.gd`, and the other tests that build a `HudFixture` without a UI
  layer. `test_030` R1 and R3, `test_066`.
- Splitting long tests, renaming files. Anything under `sim/` or `game/`.

## Paths

- `tests/acceptance/`: `test_011_hud.gd`, `test_024_guardian_fights.gd` (R2 only),
  `test_027_reading_the_party.gd`, `test_028_seeing_side_quests.gd`, `test_030_help_and_hints.gd`,
  `test_033_depth_ladder.gd`, `test_037_goals.gd`, `test_041_after_a_defeat.gd`,
  `test_042_goals_you_can_click.gd`, `test_043_a_ladder_that_warns.gd`, `test_046_notes_that_stay_true.gd`,
  `test_047_a_ladder_that_points_true.gd`, `test_061_the_frame_of_the_screen.gd`,
  `test_062_goals_stages_and_news.gd`, `test_067_opens_at_a_size_you_can_read.gd`,
  `frame_061_test_base.gd`, `frame_062_test_base.gd`
- `tests/unit/test_hud_help.gd`

## Open questions
