# 031 — The away report tells the whole story

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 019, 020, 022, 025
- **Pull request:** —

## Intent

"While you were away" is the first thing a returning player reads, and for an idle game it is the moment
that pays for leaving it running. Today it is short and now also wrong: it counts every gain of gold as a
kill, and side quests pay gold. This spec fixes the count and makes the report tell what actually happened
down there: guardians beaten, side quests done and missed, microskills learned.

## Requirements

- **R1. Kills are kills.** The report's `kills` counts monsters that died (a `DIED` event whose source is a
  monster), not gains of gold. Over an hour's replay it equals the number of monster deaths in the same
  simulation stepped by hand.
- **R2. It counts the rest.** The report gains: guardians slain (with the deepest one's name), side quests
  done, side quests missed, and the microskills learned (hero and microskill, in order).
- **R3. The panel says it plainly.** The panel adds a line for each of these only when its count is above
  zero: `Guardians slain 2 (deepest: Clay Colossus)`, `Side quests done 14`, `Side quests missed 3`, and one
  line per microskill learned (`Rogue learned Lockpicker`), at most four such lines followed by `and N more`.
  With none of them, the panel reads exactly as it did before this spec.
- **R4. Misses teach.** When side quests were missed, the panel adds one line naming the microskill most
  often needed: `Most needed: Trapspotter`.
- **R5. It still fits.** With every line showing, the panel stays inside the screen and clear of the party
  frames and the top band, with every line legible at 640x360.
- **R6. Nothing else changes.** The replay's result (the simulation's state hash after catching up) is the
  same as before this spec for the same save and time away.

## Interfaces

```gdscript
# game/save/away_report.gd gains
var guardians_slain: int
var deepest_guardian: StringName            # the monster def id, or &""
var side_quests_done: int
var side_quests_missed: int
var most_needed_microskill: StringName      # &"" when nothing was missed
var microskills_learned: Array[Vector2i]    # (hero id, position in Content.microskill_ids())
```

## Acceptance

In `tests/acceptance/test_031_away_report.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_kills_are_kills` | The count against monster deaths from stepping the same save by hand, on a run that includes side quests |
| R2 | `test_r2_it_counts_the_rest` | Each new field against the events of the same run stepped by hand |
| R3 | `test_r3_the_panel_says_it` | Each line's text from a report built by hand; the cap of four and `and N more`; the unchanged text with none |
| R4 | `test_r4_misses_teach` | The most-needed line, and its absence without misses |
| R5 | `test_r5_it_still_fits` | The panel's rectangle with every line showing |
| R6 | `test_r6_nothing_else_changes` | The state hash after a replay equals the hash from stepping by hand |

**To look at, and for Zak:** a shot of the panel with every line showing (a throwaway scene with a report
built by hand; do not commit it). Crop and enlarge. Describe it.

## Out of scope

- Any change under `sim/`.
- The journal (spec 027) and anything else in the HUD.

## Paths

- `game/save/away_report.gd`, `game/save/away_replay.gd`, `game/hud/away_panel.gd`
- `tests/acceptance/test_031_away_report.gd`, `tests/unit/test_away*.gd`
- Existing away tests only where they assert the kill count or the panel's exact text (say which)
- `docs/wiki/index.html`

## Open questions

None.
