# 070 — Game tidy

- **Status:** in-progress (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** none
- **Pull request:** —

## Intent

Zak asked for a cleaner, more maintainable codebase. A survey of `game/` found a dozen names nothing
uses, 536 comment lines that cite specs or tell history, and small helpers written again in file after
file. This spec removes those and changes nothing on screen.

## Requirements

- **R1. Nothing the player sees or does changes.** Every existing test passes with no file under
  `tests/` edited. Shots of the main scene (10 seconds in) and of the showcase, at 1280x720 and at
  `--ui-room=960x540`, show the same screen as the baseline shots.
- **R2. Dead names are gone:** `ZoneCrossing.is_crossing`, `UiWindows.is_waiting`,
  `Tally.lines_by_ability`, `WindowContent.made_by`, `DepthLadder.risk_word`, `UiTip.title_for`,
  `Hud.TOP_Y`, `Hud.TOP_HEIGHT`, `Hud.FRAMES_HEIGHT`, `Hud.GAP`, `TalentNode.NAME_LINES`. Before deleting
  each, grep the whole repository; one that turns out to be used stays and is reported.
- **R3. Comments follow the rule in `CLAUDE.md`.** No comment in `game/` names a spec or requirement
  number or tells history ("since spec", "the old", "as it was", "as the old … did"), and none only
  restates the line under it. A class's doc comment says what the class is for now. Start with
  `hud/hud.gd` and the wiring in `main.gd`.
- **R4. One way to set a label's text.** The eight private `_set_text` copies (`countdown.gd`,
  `goal_row.gd`, `hero_frame_view.gd`, `place_panel.gd`, `area_map_row.gd`, `area_map_window.gd`,
  `shop_row.gd`, `tally_window.gd`) are replaced by `WindowText.set_text`, and the five `_ink` copies
  (`boss_bar_view.gd`, `defeat_note_view.gd`, `hero_frame_view.gd`, `place_panel.gd`, `purse.gd`) by one
  `WindowText.ink`. If a copy differs in what it does, keep the difference and say so in the report.
- **R5. One way to measure a sprite's height.** The eight `find_children("*", "Sprite2D", …)` scans
  (`combat_effects.gd`, `ability_effects.gd`, `fx_guardian_wave.gd`, `world/sprite_bounds.gd`) call one
  helper on `SpriteBounds`.
- **R6. One way to find a fight's guardian.** `BossBarView._guardian` and the inline copy in
  `Hud._fight_text` call `CombatEffects.battle_guardian`; `GuardianSpacing.fighting_guardian` keeps its
  "and alive" check on top of it.

## Interfaces

```gdscript
# game/ui/windows/window_text.gd
static func ink(label: Label) -> float
```

`CombatEffects.battle_guardian` keeps its name and signature (tests call it). No signal, scene or
public method that a test uses changes.

## Acceptance

In `tests/acceptance/test_070_game_tidy.gd`:

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_the_dead_names_are_gone` | reads `game/`; none of the listed names is declared |
| R3 | `test_r3_no_comment_in_game_tells_history` | reads every `.gd` under `game/`; fails on a comment matching `spec \d`, `\bR\d+\b`, "since spec", "the old", "as it was" |
| R4 | `test_r4_labels_are_set_one_way` | reads `game/`; no `func _set_text` and no `func _ink` remains |
| R5 | `test_r5_sprites_are_measured_one_way` | reads `game/`; `find_children("*", "Sprite2D"` appears only in `sprite_bounds.gd` |

R1 is shown by the unedited suite and the shots; R6 is for the reviewer.

**To look at:** the four shots named in R1 beside the baseline ones. Describe each.

## Out of scope

- Moving `Hud`'s formatting statics, splitting `Hud`, the window and key lists, effect pools, the
  stale-event checks and per-frame refresh work (specs 074 to 076).
- Deleting anything a test uses, including test-only getters and signals. Editing any existing test.
- The demo and specimen scenes. Any change under `sim/`.

## Paths

- `game/`
- `tests/acceptance/test_070_game_tidy.gd` (new)

## Open questions
