# 069 — Sim tidy

- **Status:** in-progress (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** none
- **Pull request:** —

## Intent

Zak asked for a cleaner, more maintainable codebase. A survey of `sim/` found almost no dead code, but
comments that tell history instead of contracts, public names nothing outside their file uses, and small
blocks copied where a helper already exists. This spec removes those and changes nothing the game does.

## Requirements

- **R1. Nothing the simulation does changes.** Every existing test passes with no file under `tests/`
  edited. `python tools/dev.py sim` prints byte-identical JSON before and after for seeds 1, 2 and 3 at
  60 minutes with `--timeline`, and for seed 4 with `--buy-upgrades --spend-talents`. Saves of every
  version still load. State hashes do not move: where code is shaped oddly to keep a hash, it stays.
- **R2. Comments follow the rule in `CLAUDE.md`.** No comment in `sim/` names a spec or requirement
  number or tells history ("since", "the old", "as it was", "before spec", "as it did before"), and none
  only restates the line under it. A comment that explains hash-keeping says so in one line, in the
  present tense. `sim_event.gd` says once, not seven times, why kinds sit before `ENCOUNTER_STARTED`.
  The stale note at `combatant.gd` ("empty for everyone today") is corrected.
- **R3. A name is public only if something outside its file uses it.** Constants in `sim/` used only in
  their own file (about 50: `Labyrinth`'s tuning, `Content`'s `_DIR` names, `ResourceDrops.DROP_*`, …)
  become private. A constant or function a test uses stays public and is not renamed.
- **R4. One way to turn seconds into ticks.** `Combatant.seconds_to_ticks` is the only place in `sim/`
  that multiplies by `TICKS_PER_SECOND` and rounds.
- **R5. Shared checks for a def's id, name and one more text.** The seven `validate()` functions that
  check them (`TrainingDef`, `MicroskillDef`, `ResourceDef`, `UpgradeDef`, `SideQuestDef`, `AbilityDef`,
  `AreaDef`) call one helper on `DefChecks`, and each still reports exactly the problems it reports
  today, in the same words and order. Five pass their description; `ResourceDef`, which has none,
  passes its `plural`; `AreaDef`, which has neither, passes no third text and reports two problems.
- **R6. Small copies merged**, each to the helper that already exists or one new one:
  `Battle.allies_of` at its inline copies; one heal path in `battle.gd`; one "floor columns of a
  chamber" helper for the eight sites that write `rect.position.x` / `rect.end.x - 1`; `Arrival.column`
  in place of its copy in `expedition.gd`. `Expedition` gains no public method.
- **R7.** `data/.gitkeep` is deleted.

## Interfaces

```gdscript
# sim/defs/def_checks.gd
static func naming_problems(id: StringName, display_name: String, text: String = "", text_field: String = "") -> PackedStringArray
```

With `text_field` empty there is no third check. Parameter names are the lane's to adjust.

`Combatant.seconds_to_ticks(seconds: float, least: int = 1) -> int` gains its floor as an argument, and
`LabyrinthChamber.floor_columns() -> Vector2i` is new and public: four files share it.

Nothing else other code relies on changes. No event, command, save field or resource field changes.

## Acceptance

In `tests/acceptance/test_069_sim_tidy.gd`:

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_no_comment_in_sim_tells_history` | reads every `.gd` under `sim/`; fails on a comment matching `spec \d`, `\bR\d+\b`, "since spec", "the old", "as it was", "as it did before" |
| R4 | `test_r4_seconds_become_ticks_in_one_place` | reads `sim/`; only `combatant.gd` has `roundi(` on a line with `TICKS_PER_SECOND` |
| R5 | `test_r5_every_def_reports_a_missing_name_the_same_way` | each of the seven defs, made with its id, name and third text empty, reports the problems it reports on `dev` (three, or two for `AreaDef`), with the texts written into the test |

R1 is shown by the unedited suite and by the lead comparing the `sim` JSON with the baseline. R3, R6 and
R7 are for the reviewer, who checks each renamed constant has no use outside its file.

## Out of scope

- Anything that changes a hash, a save or an event. `Content`'s loading and getters, caching, per-tick
  allocations and the save helpers (spec 072). Renaming "training" to "paragon".
- Deleting functions only tests use. Editing any existing test.

## Paths

- `sim/`
- `data/.gitkeep`
- `tests/acceptance/test_069_sim_tidy.gd` (new)

## Open questions
