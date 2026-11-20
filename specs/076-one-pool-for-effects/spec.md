# 076 — One pool for effects, one gate for old events

- **Status:** in-progress (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** 070, 071
- **Pull request:** —

## Intent

Four effect classes each keep their own particle list, cap and clean-up loop (one has no cap), and
fifteen listeners each decide in their own way whether an event is too old to animate: ten check only
half of what `CLAUDE.md` asks. This spec gives effects one pool and listeners one gate, so a new
effect or listener gets both right by using them. What plays on screen in normal play is unchanged.

## Requirements

- **R1. Normal play looks and sounds the same.** Existing tests pass, edited only to follow a moved
  name (list each). The showcase shots at both rooms match the baseline.
- **R2. One pool.** `CombatEffects`, `AbilityEffects`, `SpellEffects`, `QuestEffects` and
  `ResourceEffects` make and free their particles, texts, flashes and other passing nodes through one
  `FxPool` on the `World`. It advances everything once per frame, frees what has finished, and holds
  the budgets: each effect class keeps the particle cap it has today (combat 300, ability 150, spell
  120) and quest effects, which have none, get 120. A guardian's death may still go over combat's cap
  by its allowance, and the caps on numbers and names (`MAX_NUMBERS`, `MAX_NAMES`) stay as they are. The fifteen copied advance-and-free loops are gone. `World.effects_layer` is still
  empty after a few quiet seconds.
- **R3. One gate.** `World.may_animate(event)` is true only when the event is recent and the world is
  not catching up. Every view that starts a move, an effect, a sound or a flash for an event asks it
  and nothing else. Where a listener checked only one half before, it now checks both: that is the
  one intended change, and it only stops things playing for events long past.
- **R4. Listeners are named and wired one way.** A handler connected to `World.sim_event` is named
  `_on_sim_event` and connected in its own `setup`: `AreaNews.hear`, `Milestones.hear` and
  `HeroWindows.hear` are renamed, and neither `Main` nor `AreaMapWindow` connects one for someone else.
  `FightMoves.heard` and `ZoneCrossing.heard` are called by `World` itself and keep their names.
- **R5. One reader per fact.** Sound and combat effects share one record of which fighters are
  guardians, updated from events, not scanned each frame. (`AbilityEffects` and `Tally` keep an
  `AbilityCredit` each: sharing one would show shield and burn amounts in tooltips that show none today.)
- **R6. Still things are not redrawn.** `AmbienceLevel` redraws buried details only when the level
  changes, `AmbienceDarkness` sorts and allocates only when its lights change, `CrossingVeil` does no
  work while hidden, and `StageList` redraws a layer only when what it shows changed.
- **R7. A showcase moment is one row.** `Showcase` has one table with each moment's name, caption,
  linger, how it begins and how it is known to have been seen; the three parallel tables and the two
  long `match` ladders are gone. The moments play in the same order with the same captions.

## Interfaces

```gdscript
# game/effects/fx_pool.gd
class_name FxPool
extends RefCounted
func setup(layer: Node2D) -> void
func add(node: Node2D, budget: StringName, allowance: int = 0) -> bool   # false when the budget is spent
func advance(delta: float) -> void
func count(kind: StringName = &"") -> int
func clear() -> void

# game/world/world.gd
func may_animate(event: SimEvent) -> bool
```

A pooled node has `advance(delta: float) -> bool` (false when finished), as `FxParticle` does today.
`CombatEffects.live_particles` and the other counts tests read keep their names and answer from the pool.

## Acceptance

In `tests/acceptance/test_076_one_pool_for_effects.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_every_kind_stops_at_its_budget` | asking for one more than each cap adds nothing, quest effects included |
| R2 | `test_r2_the_layer_empties_after_quiet` | after a fight and five quiet seconds the pool and the effects layer hold nothing |
| R3 | `test_r3_nothing_starts_for_an_old_event` | each listener, sent an old event of a kind it animates, starts nothing; sent a fresh one, it does |
| R3 | `test_r3_nothing_starts_while_catching_up` | the same, with the world catching up |
| R3 | `test_r3_listeners_ask_the_gate` | reads `game/`; outside `world.gd`, `is_recent(` is called nowhere and `catching_up()` only by `Main.is_catching_up` and by code that clears what is running when the world catches up |
| R4 | `test_r4_handlers_have_one_name` | reads `game/`; no `func hear(`, and no file connects another object's handler to `sim_event` |
| R6 | `test_r6_a_still_level_is_not_redrawn` | the buried-detail layer's draw count does not rise over 60 quiet frames |
| R7 | `test_r7_every_moment_is_one_row` | the table's names, captions and order equal today's, written in the test |

**To look at:** a fight, a guardian fight and a side quest in the showcase at both rooms, beside the
baseline; and the game after `F` at 4x for a minute, to see nothing lingering.

## Out of scope

- New effects or moments, changing any effect's look, tweens. The HUD's per-frame refresh (075).
- Window and key lists (074). Anything under `sim/`.

## Paths

- `game/effects/`, `game/world/`, `game/audio/`, `game/ambience/`, `game/entities/`, `game/dev/showcase.gd`
- `game/main.gd` (wiring only)
- In `game/hud/` and `game/ui/`: only the stale-event checks and handler names (R3, R4), and
  `stage_list.gd` and `crossing_veil.gd` for R6, and the one line in `ui_root.gd` that hands
  `HeroWindows.setup` the world. Lane 074 works in the same folders: touch nothing else there.
- `tests/` (R1's renames; `test_076_…` new)
- `CLAUDE.md` (its stale-event rule names `may_animate`), `docs/architecture.md`

## Open questions
