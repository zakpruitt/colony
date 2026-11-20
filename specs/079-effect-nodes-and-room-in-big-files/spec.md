# 079 — One base type for effect nodes, and room in the two biggest game files

- **Status:** in-progress (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 076
- **Pull request:** —

## Intent

A pooled effect is "any node that happens to have `advance(delta) -> bool`": the pool calls it by name
and nothing tells a new effect what it must be. `combat_effects.gd` (999 lines) and `showcase.gd` (998) sit
on the lint's 1000-line limit, so the next effect or showcase moment cannot land. This spec gives effects
a base type to extend and splits the two files along their seams. Nothing in the game looks different.

## Requirements

- **R1. Normal play looks and sounds the same.** Existing tests pass, edited only to follow a moved name
  or `SoundPlayer.setup`'s new argument (list each). Showcase shots at both rooms match the baseline, paired by moment.
- **R2. A pooled effect is an `FxNode`.** `FxCoin`, `FxMote`, `FxParticle`, `FxResource`, `FxRing` and
  `FxText` extend `FxNode`, whose `advance(delta) -> bool` they override. `FxPool.add` takes an `FxNode`
  and the pool calls `advance` directly, not by name. A new effect is a class that extends `FxNode`.
- **R3. The pool tidies in place.** On a frame where effects finish, `FxPool.advance` makes no new array
  and does not rebuild every budget's list: finished nodes are dropped from the lists they are in. Order,
  budgets, `count`, `nodes`, `has`, `remove` and `clear` behave as they do today.
- **R4. `combat_effects.gd` has room.** It is at most 750 lines. Where a damage number may start so it
  clashes with no other (the step search, the clash test, their constants) lives in a class of its own,
  and so does one other part the lane finds along a seam (the gold coins' flight, or the loop's beats).
  `CombatEffects` keeps every public name tests and other code use today.
- **R5. `showcase.gd` has room.** It is at most 750 lines: how each moment begins and is known to have
  been seen moves out of `Showcase` into a class of its own beside it, and `Showcase.ROWS` stays one row a
  moment. `Showcase` keeps `skip_to`, `caption`, its signals and every name tests use.
- **R6. The showcase caption stays clear of the button bar.** At 960x540 the caption no longer runs under
  the bar: it is placed in the room the bar leaves. At 1280x720 it is where it is today.
- **R7. Sound is handed what it reads.** `SoundPlayer` is given the goals in its `setup` and no longer
  finds `Main` through its parent.
- **R8. The standards say so.** `docs/standards.md`'s effect row names `FxNode`; `CLAUDE.md` no longer
  lists the two files as near the cap.

## Interfaces

```gdscript
# game/effects/fx_node.gd
class_name FxNode
extends Node2D
## Moves the effect on by delta seconds; false once it has finished and may be freed.
func advance(delta: float) -> bool

# game/effects/fx_pool.gd
func add(node: FxNode, budget: StringName, allowance: int = 0) -> bool
```

`World`'s bolts (`game/world/bolt.gd`) are not pooled today; leave them as they are. Names of the new
classes are the lane's; report them.

## Acceptance

In `tests/acceptance/test_079_effect_nodes.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_every_pooled_effect_is_an_fx_node` | after a fight, a guardian's fall, a side quest and a resource gain, every node the pool held was an `FxNode`; `fx_pool.gd` has no `.call(` |
| R3 | `test_r3_the_pool_keeps_its_order_and_counts` | 300 nodes of mixed budgets finishing at scattered times: after every advance `count`, `count(kind)` and `nodes(kind)` equal a plain list kept by the test (written first, seen to pass on unchanged code) |
| R3 | `test_r3_tidying_makes_no_new_list` | the arrays the pool holds are the same arrays (`is_same`) before and after an advance in which nodes finish |
| R4, R5 | `test_r4_the_big_files_have_room` | both files are at most 750 lines |
| R4 | `test_r4_numbers_start_where_they_did` | for 40 seeded bursts of numbers over one target, each number's start equals the positions recorded in the test from unchanged code |
| R6 | `test_r6_the_caption_clears_the_bar` | at 960x540 the caption's rect on screen does not meet the bar's; at 1280x720 its rect is today's |
| R7 | `test_r7_sound_is_handed_its_goals` | reads `game/audio/`; no `get_parent(` |

**To look at:** the showcase at both rooms beside the baseline: a fight with several numbers at once, a
guardian's fall, a gold gain, and the caption at 960x540.

## Out of scope

- New effects, moments or sounds; changing how any effect looks or moves. Pooling `World`'s bolts.
- `game/hud/` and `game/ui/` (spec 080). Anything under `sim/`.

## Paths

- `game/effects/`, `game/dev/`, `game/audio/`, `game/main.gd` (handing `SoundPlayer` the goals only)
- `tests/` (R1's renames; `test_079_…` new)
- `docs/standards.md`, `docs/architecture.md` (its effects section), `CLAUDE.md` (the near-the-cap line)

## Open questions

