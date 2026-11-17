# 036 — A livelier start: the first half hour

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 005, 016, 020, 025, 029
- **Pull request:** [#38](https://github.com/zakpruitt/colony/pull/38)

## Intent

A new game is slow to the point of looking broken. Measured on seed 1 with default settings: 3 fights in the
first 2 minutes, 9 in the first 10, the first camp upgrade affordable after about 3 minutes, and depth 2
reached around minute 20. The party spends most of that time walking through chambers it has already
emptied, waiting ten minutes for depth 1 to count as stable. The first half hour is when a player decides
whether to keep the game open. This spec retunes the opening so something happens every few seconds and a
decision arrives every minute or two, and leaves the deep game's slow, idle pace as it is.

## Requirements

All statements are for a new game with default settings and no player input unless said, on seeds 1 to 5.

- **R1. Stability scales with depth.** The time a depth must be held to become stable is short near the
  surface and grows with depth, reaching today's 600 seconds at depth 10 and staying there. Depth 1 takes
  no more than 60 seconds. The curve is one function, stated in a doc comment, and `seconds_to_stable()`
  and the HUD's countdown follow it. A test or tool that sets `stable_seconds` itself still gets a flat
  time, as today.
- **R2. The opening is busy.** In the first 2 minutes the party fights at least 5 battles; in the first 10
  minutes at least 24 battles and side quests together. (Amended by the lead: the lane measured 24 to 31
  as the most these rules give, because many levels have only two or three chambers that can hold
  anything; reaching 30 needs a new rule near the surface, which is a later spec. Today's game gives 5
  to 16.)
- **R3. Little dead time.** Over the first 20 minutes, the party spends no more than 35% of its time
  travelling on a level where no chamber holds monsters or a side quest it can do. How that is achieved
  (faster respawn near the surface, moving on sooner, both) is the lane's choice.
- **R4. Progress comes early.** Every hero reaches level 2 within 90 seconds and level 5 within 12 minutes.
  The party first reaches depth 2 within 3 minutes and depth 5 within 20 minutes.
- **R5. Decisions come early.** The cheapest camp upgrade is affordable within 90 seconds, and with
  auto-buy on the party has bought at least 6 upgrade ranks by minute 10. A first training rank is
  affordable within 4 minutes (with nothing else bought).
- **R6. The first guardian is still a wall, briefly.** The party first meets the Slime King within 25
  minutes. On at least 3 of 5 seeds it loses to it at least once before beating it, and with auto-buy on
  it beats it within 60 minutes on at least 4 of 5 seeds.
- **R7. The deep game keeps its pace.** At depth 10 and below, the time to stable, respawn times and
  rewards per kill are unchanged, and a 3-hour run with auto-buy ends no deeper than depth 22 on any seed.
- **R8. Existing statements hold where they should.** Tests that set `stable_seconds` or the depth
  themselves keep their numbers. A test that relied on the default opening pace (a count, a depth or a
  stored hash from a default run) may be updated; say which and why.
- **R9. The tool reports it.** `python tools/dev.py sim` gains `--timeline`, which adds to the JSON the
  game time in seconds of each first: level 2, level 5, depth 2, depth 5, first upgrade affordable, first
  guardian met, first guardian beaten (null when it did not happen).

## Interfaces

```gdscript
# sim/expedition/expedition.gd (or a helper beside it; the file is near gdlint's 1000 lines)
## Seconds a depth must be held to become stable, when `stable_seconds` has not been set by hand.
static func stable_seconds_at(level_depth: int) -> float
```

Everything else is tuning: constants and data under `data/`. Change as little as reaches the requirements,
and list every number changed, before and after, in your report and in the pull request.

## Acceptance

In `tests/acceptance/test_036_a_livelier_start.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_stability_scales` | The curve at depths 1, 5, 10 and 30; the countdown following it; a hand-set value staying flat |
| R2 | `test_r2_opening_is_busy` | The two counts on five seeds |
| R3 | `test_r3_little_dead_time` | The share of dead time on five seeds |
| R4 | `test_r4_progress_comes_early` | The four times on five seeds |
| R5 | `test_r5_decisions_come_early` | The three statements |
| R6 | `test_r6_first_guardian` | The three statements |
| R7 | `test_r7_deep_game_keeps_pace` | The unchanged numbers at depth 10 and 20, and the 3-hour bound |
| R8 | (the existing suite) | `python tools/dev.py check` passes |
| R9 | `test_r9_timeline` (py, in `tools/tests/`) | The new keys in the tool's JSON |

Long runs make slow tests: share simulation runs between tests where you can, and keep this file's total
under two minutes of test time.

## Out of scope

- Anything on screen.
- New content, new rules beyond the stability curve and respawn near the surface.
- The deep game's balance.

## Paths

- `sim/expedition/`, `sim/party/hero.gd` (the XP curve, only if R4 needs it)
- Existing tests that hard-code the XP curve's values or wait `RESPAWN_SECONDS` at a shallow depth (say which)
- `data/` (numbers only)
- `tools/dev.py` and the Godot script it runs for `sim`, `tools/tests/`
- `tests/acceptance/test_036_a_livelier_start.gd`
- Existing tests only as R8 allows (say which)
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md` (the `sim` command's new flag)

## Open questions

None.
