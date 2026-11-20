# 078 — A base type for content, a cheaper fight tick, and room in Expedition

- **Status:** in-progress (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 072
- **Pull request:** —

## Intent

The ten kinds of content share an id, a `validate()` and a place in `Content`, but nothing says so in
code: each def extends `Resource` on its own and `Content` finds its key by a property name in a string.
A fight still builds about sixteen small arrays every tick to choose targets, and `expedition.gd` is 13
lines from the lint's limit, so the next feature that touches it cannot land. This spec gives content one
base type to extend, takes the arrays off the fight tick, and makes room. Nothing the game does changes.

## Requirements

- **R1. Nothing the simulation does changes.** Every existing test passes with no file under `tests/`
  edited. The `dev.py sim` JSON for the five baseline runs is byte-identical. Hashes and saves do not move.
- **R2. Every definition is a `ContentDef`.** The ten def classes extend `ContentDef`, which declares
  `key()` (what `Content` finds the definition by: its `id`, or a talent tree's `class_id`) and
  `validate()`. `Content` asks `key()`, not a property named in a string, and its table has no `"key"`
  column. `tools/godot/validate_data.gd` validates every `ContentDef` it loads. Every `.tres` under `data/`
  loads unchanged and reports the problems it reports today.
- **R3. Choosing a target builds nothing.** `Battle.nearest_enemy` and the weakest and furthest aims of
  `BattleAbilities` pick their target in one pass with no array made, keeping today's choice on every tie;
  `Battle.aimable` is gone or no longer called on the tick. No function called every battle tick joins
  `heroes` and `monsters` into a new array (they read the list `Battle` already keeps), a healer's hurt ally
  is looked for once a tick, and `Expedition._fight` makes no dictionary per tick.
- **R4. `expedition.gd` has room.** It is at most 900 lines, with no public method added to `Expedition`
  and none removed: the chamber-bounds check, the drain-and-stamp loop and the "chamber key at x" lines
  each exist once, and read-only helpers move to small classes under `sim/expedition/`.
- **R5. A fight's passing state is not public.** `Battle.ready_target` and `Battle.chain` are no longer
  public mutable fields that another class writes for `Battle` to read back on the next line.
- **R6. Comments state no number that tuning can change.** The doc comments that repeat a tuning value
  ("30%", "80%", "100 gold", "25 … 30", "60/600/5", "500,000") name the constant instead.
  `Combatant.from_monster`'s `depth` parameter and the `level` comment beside it say what they hold now, a
  level. `docs/architecture.md` names no constant that is private.

## Interfaces

```gdscript
# sim/defs/content_def.gd
class_name ContentDef
extends Resource
## What Content finds this definition by.
func key() -> StringName
## One line per problem; empty when the definition is sound.
func validate() -> PackedStringArray
```

`ContentDef` declares no exported field: `id` and `display_name` stay on each def, so no `.tres` changes.

## Acceptance

In `tests/acceptance/test_078_sim_base_types.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_every_definition_is_a_content_def` | every resource `Content` holds is a `ContentDef` whose `key()` is the id it is listed under; a talent tree's is its class |
| R2 | `test_r2_data_reports_what_it_did` | a def of each kind broken in one way reports the problem text written in the test (written first, seen to pass on unchanged code) |
| R3 | `test_r3_targets_are_chosen_as_before` | for 200 seeded fights of mixed parties, with taunts and untouchable fighters, every tick's chosen target equals a reference picker written in the test the way `aimable` works today |
| R3 | `test_r3_nothing_joins_the_sides_on_the_tick` | reads `sim/combat/`; `heroes + ` and `+ monsters` appear only where `Battle` builds its list once |
| R4 | `test_r4_expedition_has_room` | `expedition.gd` has at most 900 lines and `Expedition` exactly the public methods written in the test (today's) |
| R6 | `test_r6_no_private_constant_is_documented` | every `Class.NAME` in `docs/architecture.md` that names a `sim/` class resolves to a public constant |

R1 is shown by the unedited suite and the `sim` JSON, which the lane reports with the 600-minute run's time
beside the same run on `dev` under the same load. R5 is for the reviewer.

## Out of scope

- Events that carry ids, a single command queue, event order, anything that moves a hash or a save.
- A shared `id` or `display_name` field on `ContentDef` (it would rewrite every `.tres`). New content.
- Anything under `game/` or existing tests.

## Paths

- `sim/`, `tools/godot/validate_data.gd`
- `tests/acceptance/test_078_sim_base_types.gd` (new)
- `docs/architecture.md` (its Content, Saving and combat sections), `docs/standards.md`, `CLAUDE.md` (the
  line on `expedition.gd`'s room)

## Open questions

