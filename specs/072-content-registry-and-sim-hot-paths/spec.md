# 072 — One content table, and less work per tick

- **Status:** draft
- **Milestone:** M8 (cleanup)
- **Depends on:** 069
- **Pull request:** —

## Intent

Adding a kind of content today means editing `Content` in five places, and the simulation redoes work
every tick that never changes: it hashes a string to find a shaft, re-sorts id lists and rebuilds
small arrays. This spec makes a new content kind one row in one table and takes the repeated work off
the tick, so later content and longer away-time catch-ups cost less. Nothing the game does changes.

## Requirements

- **R1. Nothing the simulation does changes.** Every existing test passes; a test file changes only
  where R3 says. The `dev.py sim` JSON for the baseline seeds is byte-identical. Hashes and saves do
  not move.
- **R2. One table drives loading.** `Content` has one table with a row per content kind (its folder,
  its def class, how its ids are ordered). Loading, the "is not a …" error and the id lists all come
  from it; the ten copied load blocks and the four copied "by order, then id" comparators are gone.
  The public getters (`Content.monster`, `Content.monster_ids`, …) keep their names and return types.
  Talent trees keep their rule of one tree per class, and resources their order by area.
- **R3. Id lists are built once.** Each `…_ids()` getter returns the same read-only array every call
  (`Array.make_read_only`): no sort and no copy per call. A caller that changes the list it gets must
  copy it first; fix such callers in `sim/` and `game/`, and in a test only by adding `.duplicate()`
  (list each).
- **R4. A shaft's column is worked out once per level.** `Labyrinth.shaft_column` gives the same
  answers as today and computes each level's at most once.
- **R5. Unchanging numbers are not recomputed every tick.** `Upgrades.multiplier` is recomputed only
  after a rank changes; a hero's paragon multiplier only after a paragon point is spent or a save is
  loaded. Values are bit-for-bit what they are today.
- **R6. No throwaway arrays on the tick.** With no battle on and the party walking, climbing, resting
  or holding, `Expedition.step` builds no new `Array` or `Dictionary`; in a battle, `Battle` does not
  join `heroes + monsters` or rebuild its projectile list each tick, and an ability's aim is worked
  out once per action. A 600-minute `dev.py sim --seed=5` run takes no longer than the baseline's 35 s.
- **R7. Save checks have a home.** The whole-number and known-id checks that `AreaSave`, `ResourceSave`
  and `TalentSave` borrow from `Simulation`'s private functions move to one class, `SaveChecks`; no
  class in `sim/` calls another's private function for them. Every save problem reads as it does today.

## Interfaces

```gdscript
# sim/save_checks.gd
class_name SaveChecks
static func whole(value: Variant, fallback: int = 0) -> int
static func is_whole(value: Variant) -> bool
static func check_whole(problems: PackedStringArray, data: Dictionary, key: String, least: int) -> void
static func check_counts(problems: PackedStringArray, data: Variant, what: String, known: Array[StringName], least: int) -> void
```

Signatures follow what the borrowed functions take today; report the final list.

## Acceptance

In `tests/acceptance/test_072_content_table.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_every_kind_of_content_is_one_row` | every folder under `res://data` is named by exactly one row, and every getter still returns what it did (ids compared with the files on disk) |
| R3 | `test_r3_an_id_list_is_the_same_list_each_time` | `is_same(Content.x_ids(), Content.x_ids())` for every kind, and the list is read-only |
| R4 | `test_r4_a_shaft_is_found_once_per_level` | columns for 200 levels equal a fresh labyrinth's, asked in another order |
| R5 | `test_r5_a_multiplier_follows_a_new_rank` | the multiplier before and after buying a rank, and a paragon point, equals the uncached sum |
| R7 | `test_r7_save_problems_read_as_before` | a save broken in each checked way reports the same text as on `dev` (texts written into the test) |

R1 and R6 are shown by the unedited suite, the `sim` JSON and the timed run, which the lane reports.

## Out of scope

- Events that carry ids, a single command queue, `Expedition`'s helpers and its private state, event
  order, renaming "training". New content. Anything under `game/` beyond R3's callers.

## Paths

- `sim/`
- `game/` and existing tests: only R3's `.duplicate()` fixes
- `tests/acceptance/test_072_content_table.gd` (new)
- `docs/architecture.md` (how to add a content kind)

## Open questions
