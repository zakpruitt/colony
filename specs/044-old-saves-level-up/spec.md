# 044 — Old saves level up: fixes from the review of a livelier start

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 014, 029, 036
- **Pull request:** —

## Intent

A reviewer read the pacing change (spec 036, pull request 38) against its spec after it had landed. The
change made every level cheaper, but a save made before it keeps each hero's old level: a hero can load
already holding enough XP for the next level, and the hero sheet then shows a negative amount still to earn
until the next kill. This spec makes a loaded game consistent at once, and closes two smaller gaps the
review found. It changes no balance number.

## Requirements

- **R1. A loaded hero has the level its XP earns.** After a save is loaded, no hero holds XP at or above
  the cost of its next level: a hero owed levels has them, with the health and microskills of the new
  level, before the first step. Loading raises no level-up or microskill events (nothing flashes and the
  away report does not count them), and a save that was already consistent loads exactly as before.
- **R2. The sheet never shows a negative amount.** The hero sheet's XP line and the frame's bar are right
  on the first frame after loading such a save.
- **R3. A chamber cannot be made without its depth.** `ChamberState` takes its depth when it is created,
  so no code can make one that silently refills on depth 1's timing.
- **R4. The deep refill is tested for real.** A test shows a chamber at depth 10 or below refilling after
  90 seconds inside a running expedition, not only the helper's arithmetic.
- **R5. Nothing else changes.** The recorded-hash tests pass unchanged and the save version stays as it
  is unless R1 cannot be done without raising it (say why if so).

## Interfaces

None change, except `ChamberState`'s constructor.

`sim/expedition/expedition.gd` is at gdlint's limit of 1000 lines: the `ChamberState` change must not add
a line there.

## Acceptance

In `tests/acceptance/test_044_old_saves_level_up.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_loaded_hero_has_its_level` | A saved level 4 hero with 450 XP loads at level 5 with that level's health and microskills; no events; a consistent save round-trips unchanged |
| R2 | `test_r2_sheet_is_right_at_once` | The sheet's XP line and the frame's bar on the first frame after that load |
| R3 | `test_r3_chamber_needs_its_depth` | Every `ChamberState` in a running expedition carries its level's depth; the constructor has no default |
| R4 | `test_r4_deep_refill` | A cleared chamber at depth 10 empty at 89 s and refilled at 90 s |
| R5 | (the existing suite) | `python tools/dev.py check` passes |

## Out of scope

- Any balance number, including the XP curve itself.
- Whether side-quest gold should be multiplied by the Fat Purse upgrade (a design question for Zak).

## Paths

- `sim/simulation.gd` (loading only), `sim/party/hero.gd` (only if loading needs a helper),
  `sim/expedition/chamber_state.gd`, `sim/expedition/expedition.gd` (the one place a chamber is made)
- `tests/acceptance/test_044_old_saves_level_up.gd`, `tests/unit/test_save*.gd`
- Existing tests only where they construct a `ChamberState` (say which)
- `docs/wiki/index.html` only if a sentence there becomes untrue

## Open questions

None.
