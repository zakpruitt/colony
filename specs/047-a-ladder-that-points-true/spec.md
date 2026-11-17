# 047 — A ladder that points true: fixes from the review of the ladder

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 043
- **Pull request:** —

## Intent

A reviewer read the ladder change (spec 043, pull request 45) against its spec after it had landed. After a
wheel notch the hover hint stays on the rung that was under the mouse, so it can say `Within reach` over a
rung that is dangerous, which is the one thing the warning exists to prevent. The review also found ways
the ladder can stop following the party or start again unasked, and that the target's rung became harder
to find. This spec closes those. It adds no feature.

## Requirements

- **R1. The hover is the rung under the mouse.** Whenever the rungs move under a still mouse (a wheel
  notch, the ladder following the party, a flash), the outline and the hint are those of the rung now
  under it, on the same frame the rungs are drawn there.
- **R2. The ladder goes back to following.** Whether the mouse is over the ladder comes only from the
  mouse entering and leaving it, so a press on the ladder dragged off it, or the mouse leaving the window,
  does not stop the 5-second return.
- **R3. A scrolled ladder stays where it was put.** While scrolled away, the ladder returns to following
  only by the arrow's click or the 5-second return, not because the party's own view happens to reach
  the same rungs.
- **R4. A notch is a rung.** The first wheel notch while the party is between depths moves the ladder to
  the next whole rung in that direction, never more than one rung.
- **R5. The target's rung is easy to find.** The target's rung and the party's rung each carry a mark
  that does not depend on the number's colour and is at least as easy to find as before spec 043 (for
  example a yellow underline or frame for the target and a white one for the party); the three risk
  colours stay on the numbers. The party's diamond is never covered by the arrow that points back to
  the party.
- **R6. One rule for the lowest level.** The ladder, the goals tracker and the defeat note read the
  party's lowest hero level from one shared function.
- **R7. Tests that can fail.** The dangerous-click warning is tested to be written once per change of
  target: a second click on the same dangerous target writes nothing, and a change away and back writes
  again.

## Interfaces

None change, except the one shared function for R6 (place and name are the lane's choice, under `game/`).

## Acceptance

In `tests/acceptance/test_047_a_ladder_that_points_true.gd`, plus the amended 043 test.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_hover_follows_the_rungs` | A wheel notch under a still mouse: the hint and outline on the rung now under it once the rungs have settled, and never on a rung not under it for more than a frame |
| R2 | `test_r2_goes_back_to_following` | Mouse events with positions outside the ladder after an exit: the return still happens after 5 seconds |
| R3 | `test_r3_stays_where_put` | A ladder scrolled one notch ahead of a party that then descends: not following until the arrow or the timer |
| R4 | `test_r4_a_notch_is_a_rung` | A notch each way with the party part-way through a climb |
| R5 | `test_r5_target_is_easy_to_find` | The two marks' rectangles and colours; the arrow's box clear of the party's diamond at the top and bottom rows |
| R6 | `test_r6_one_rule` | The three callers agree, including for a party with a dead hero |
| R7 | (`test_043`, `test_r3_dangerous_click`) | The second click and the change away and back |

**To look at, and for Zak:** a shot of the ladder with the target three rungs below the party, cropped
and enlarged 3x, before and after. Is the target the first thing the eye finds? Describe it.

## Out of scope

- The risk rule itself; any change under `sim/`; new keys.

## Paths

- `game/hud/depth_ladder.gd`; `game/hud/goals.gd` and `game/hud/defeat_note.gd` (only the lowest-level
  helper; another lane is editing `defeat_note.gd`, so change only that function's body or its call)
- A new small file under `game/hud/` for the shared function, if needed
- `tests/acceptance/test_047_a_ladder_that_points_true.gd`, `tests/acceptance/test_043_a_ladder_that_warns.gd`,
  `tests/unit/test_hud*.gd`
- `tests/acceptance/test_033_depth_ladder.gd` only where it asserts a mark this spec changes (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
