# 005 — Expedition loop: travel, fights, rewards, rest and the fallback rule

- **Status:** provisional
- **Milestone:** M3
- **Depends on:** 001, 003, 004
- **Pull request:** —

## Intent

This spec is the game's core loop as simulation: a party that walks the labyrinth by itself, fights what it
finds, earns XP and gold, rests when hurt, goes deeper, and falls back to its last stable depth when it
wipes. After it, the simulation plays Colony end to end with nobody touching it, and a command prints what
happened over any stretch of game time. Nothing is drawn here; the view specs read this state and these
events. Read `docs/design/base-game.md`, "The loop".

## Requirements

Positions are world tiles: x right, y down, as in the labyrinth spec. Durations are given in seconds of game
time and converted to ticks. Every number named in CAPITALS is a constant in Interfaces.

- **R1. The simulation owns an expedition.** A new `Simulation` has a labyrinth made from its seed, a party of
  four level-1 heroes (knight, rogue, mage, cleric, with hero ids 1 to 4 in that order) at full health, 0 gold,
  and an expedition that starts at depth 1, standing in the middle of the START chamber, facing the level's
  shaft. Each `Simulation.step()` advances the expedition by one tick.
- **R2. Travel.** While travelling, the party's anchor moves along the floor at `PARTY_SPEED` toward where it is
  going. Heroes walk in a column behind the anchor, 1 tile apart, in formation order (tank first).
- **R3. Where it is going.** The party has a target depth.
  - Above the target depth, it walks to its level's shaft and climbs down at `CLIMB_SPEED`, arriving on the
    floor of the next level at the shaft's column.
  - Below the target depth, it walks to the column where the shaft from the level above lands, and climbs up.
  - At the target depth, it patrols: it walks to the far end of the level's last chamber, turns round, walks to
    the far end of the first chamber, and so on.
- **R4. Encounters.** Chambers hold monsters, except the START chamber, the chamber a level's shaft down leaves
  from, and the chamber the shaft from above lands in, which are always empty. The first time the party enters
  a populated chamber, and again each time it enters after the chamber has refilled, a battle starts with the
  heroes entering from the side they walked in from and the battle span set to the chamber's floor.
- **R5. What is in a chamber.** The monsters of an encounter are chosen from those whose `min_depth` is no
  deeper than the level's depth, created at that depth: 2 or 3 in a PLAIN chamber, 4 or 5 in a DEN,
  2 or 3 in a VAULT. Deeper-dwelling monsters (higher `min_depth`) are more likely than shallow ones once
  available. The choice is deterministic for a given seed, depth, chamber and visit number.
- **R6. Health carries over.** Heroes enter a battle with the health they have, not full health. After a
  battle their health is what the battle left them with.
- **R7. Rewards.** When a monster dies, every living hero gains the monster's `xp`, and the party gains gold
  rolled between the monster's `gold_min` and `gold_max` (doubled in a VAULT). Gold and XP never decrease.
- **R8. Levels.** A hero whose XP reaches `Hero.xp_for_level(level + 1)` gains a level (several at once if it
  has enough), with the health and damage growth of its class from then on, and is healed by the health it gained.
- **R9. Rest.** After a won battle, if any hero is dead or below `REST_BELOW` of its health, the party rests
  where it stands: every hero, dead ones included, regains `REST_HEAL_PER_SECOND` of its maximum health per
  second until all are full; then travel resumes. Otherwise travel resumes at once.
- **R10. Refill.** A cleared chamber refills `RESPAWN_SECONDS` after it was cleared.
- **R11. Wipe and fallback.** If every hero is dead, the party is wiped: after `REVIVE_SECONDS` it stands, at
  full health, in the arrival chamber of the last stable depth (the START chamber at depth 1; otherwise where
  the shaft from above lands), and the target depth becomes the last stable depth. The chamber it died in keeps
  its surviving monsters, healed to full. XP, gold and levels are untouched.
- **R12. Last stable depth.** It starts at 1. When the party has been on one depth for `stable_seconds`
  (default 600) without a wipe, and that depth is deeper than the last stable depth, it becomes the last
  stable depth. Leaving a depth or wiping restarts the count.
- **R13. Auto-push.** With auto-push on (the default), whenever the party has been at its target depth for
  `stable_seconds` without a wipe, the target depth increases by one. `set_target_depth` sets the target to
  any depth from 1 upward and applies from the next tick; `set_auto_push` turns auto-push on or off.
- **R14. Everything is reported.** Battle events are passed on, stamped with the simulation tick. The
  expedition adds events for: an encounter starting and ending (which chamber; whether the heroes won), XP
  gained (hero, amount), gold gained (amount, the dead monster's id), level up (hero, new level), rest starting
  and ending, the depth changing (new depth), a wipe, a revival (depth), a new last stable depth, and the
  target depth changing. `Simulation.drain_events()` returns them once, in order.
- **R15. Ids the view can rely on.** In battles, a hero's combatant id is its hero id. Monster ids start at 100
  and are never reused within a simulation.
- **R16. Where everyone is.** At any tick the expedition can give the world position of each hero's feet:
  on the floor in column formation while travelling or resting, at its battle position while fighting, and on
  the shaft while climbing.
- **R17. Deterministic and endless.** Two simulations with the same seed and the same commands at the same ticks
  have equal `state_hash()` at every tick, and the hash covers party, expedition and battle state. One hour of
  game time runs without errors from any seed.
- **R18. It plays like the design says.** With the shipped data, over one hour of game time on each of 5 seeds,
  with `stable_seconds` at 120: the party fights at least 30 battles, gains gold and levels, becomes stable on
  depth 2 or deeper, and wipes at least once somewhere (auto-push must eventually outrun the party) without
  the wipe ever reducing gold, XP or levels.
- **R19. A command shows a run.** `python tools/dev.py sim --seed=N --minutes=M [--target-depth=D]
  [--stable-seconds=S]` runs that much game time headless and prints one JSON object: seed, minutes, final
  depth, last stable depth, target depth, deepest depth reached, battles won and lost, wipes, gold, each
  hero's class, level and XP, and kills per monster id.

## Interfaces

```gdscript
# sim/party/hero.gd
class_name Hero
extends RefCounted
var id: int
var class_id: StringName
var level: int = 1
var xp: int = 0
var health: int
func max_health() -> int
func is_alive() -> bool
## Total XP needed to be this level: 25 * (level - 1) * level.
static func xp_for_level(level_number: int) -> int
```

```gdscript
# sim/party/party.gd
class_name Party
extends RefCounted
var heroes: Array[Hero]   # in formation order: tank first
var gold: int
func hero(id: int) -> Hero
```

```gdscript
# sim/expedition/expedition.gd
class_name Expedition
extends RefCounted

enum State { TRAVELLING, FIGHTING, RESTING, CLIMBING, REVIVING }

const PARTY_SPEED: float = 3.0          # tiles per second
const CLIMB_SPEED: float = 4.0          # tiles per second
const REST_BELOW: float = 0.6
const REST_HEAL_PER_SECOND: float = 0.04
const RESPAWN_SECONDS: float = 90.0
const REVIVE_SECONDS: float = 5.0
const FIRST_MONSTER_ID: int = 100

var state: State
var depth: int
## The party anchor: column on the floor, and which way it faces (1 right, -1 left).
var x: float
var facing: int
var target_depth: int
var auto_push: bool = true
var last_stable_depth: int = 1
var deepest_depth: int = 1
## Seconds on one depth without a wipe before it counts as stable. Tunable.
var stable_seconds: float = 600.0
## The fight in progress, or null.
var battle: Battle
## The chamber the party is in or fighting in, or null in a tunnel or shaft.
func chamber() -> LabyrinthChamber
## Feet position of a hero in world tiles.
func hero_position(hero_id: int) -> Vector2
## True if this chamber currently holds monsters waiting for the party.
func is_populated(level_depth: int, chamber_index: int) -> bool
```

```gdscript
# sim/simulation.gd (additions)
var labyrinth: Labyrinth
var party: Party
var expedition: Expedition
func set_target_depth(depth: int) -> void
func set_auto_push(enabled: bool) -> void
func drain_events() -> Array[SimEvent]
```

`SimEvent.Kind` gains, at the end and in this order: `ENCOUNTER_STARTED` (amount: chamber index),
`ENCOUNTER_ENDED` (amount: chamber index; flag: heroes won), `XP_GAINED` (target: hero; amount),
`GOLD_GAINED` (source: monster id; amount), `LEVEL_UP` (target: hero; amount: new level), `REST_STARTED`,
`REST_ENDED`, `DEPTH_CHANGED` (amount: new depth), `PARTY_WIPED`, `PARTY_REVIVED` (amount: depth),
`STABLE_DEPTH_REACHED` (amount: depth), `TARGET_DEPTH_CHANGED` (amount: depth).

A monster is eligible for an encounter when `min_depth <= depth`.

The `sim` command is a SceneTree script `tools/godot/run_sim.gd` plus a `sim` command in `tools/dev.py`.

## Acceptance

In `tests/acceptance/test_005_expedition_loop.gd`. Tests may set the expedition's public fields (depth, x,
target, `stable_seconds`) and hero health directly to reach a situation quickly.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_new_simulation_starts_an_expedition` | Party of four as specified, 0 gold, depth 1, in the START chamber, facing the shaft; stepping moves it |
| R2 | `test_r2_party_walks_in_formation` | Anchor speed is `PARTY_SPEED`; heroes trail 1 tile apart, tank first, on the floor row |
| R3 | `test_r3_descends_ascends_and_patrols` | Target below: reaches the next depth at the shaft column; target above: climbs back; at target: turns at both ends of the level |
| R4 | `test_r4_battle_starts_on_entering_a_populated_chamber` | Battle begins with the right span and entry side; none in START, shaft or landing chambers |
| R5 | `test_r5_encounter_composition` | Counts per kind; no monster above its depth; same seed, depth, chamber and visit give the same monsters; over many, deeper monsters are favoured |
| R6 | `test_r6_health_carries_into_and_out_of_battle` | A hero at 10 health enters with 10; survivors keep battle health |
| R7 | `test_r7_kills_pay_xp_and_gold` | Each living hero gains the xp; gold within the roll range, doubled in a vault; a dead hero gains none |
| R8 | `test_r8_levels` | XP thresholds match `xp_for_level`; multi-level jump; stats grow; heal by gained health |
| R9 | `test_r9_rest_heals_then_moves_on` | Rest starts below the threshold, heals at the rate including a dead hero, ends at full; no rest when healthy |
| R10 | `test_r10_cleared_chamber_refills` | Not populated before `RESPAWN_SECONDS`, populated after |
| R11 | `test_r11_wipe_falls_back_and_keeps_progress` | After a forced wipe at depth 3 with last stable 2: revived at depth 2 in the landing chamber at full health after the delay, target 2, gold, XP and levels unchanged |
| R12 | `test_r12_last_stable_depth` | Becomes stable after the time; not if the party left or wiped first; never moves shallower |
| R13 | `test_r13_auto_push_and_commands` | Target rises after the stable time with auto-push; not with it off; `set_target_depth` applies next tick |
| R14 | `test_r14_events_cover_the_loop` | One scripted encounter yields the expected expedition events with the right ids and amounts, battle events included and stamped with simulation ticks; drained once |
| R15 | `test_r15_ids` | Hero combatant ids equal hero ids; monster ids from 100, unique across encounters |
| R16 | `test_r16_hero_positions` | Positions in each state: column on the floor, battle x, and moving down the shaft |
| R17 | `test_r17_deterministic_and_endless` | Equal hashes tick by tick for two same-seed runs with a mid-run command; one hour on 3 seeds without an error |
| R18 | `test_r18_plays_like_the_design` | The statements in R18 |
| R19 | `test_r19_sim_command_output` (Python, `tools/tests/`) | The command prints valid JSON with the listed fields for a 2-minute run |

## Out of scope

- Anything drawn; the HUD; input beyond the two commands.
- Saving and loading; offline catch-up.
- Loot items, gear, talents, the shop; anything gold is spent on.
- Changing battle rules (spec 004) or labyrinth generation (spec 003). If either makes a requirement here
  impossible, stop and report.
- Retuning hero or monster data beyond what R18 needs; if it needs large changes, report what and why.

## Paths

- `sim/party/`, `sim/expedition/`
- `sim/simulation.gd`, `sim/sim_event.gd` (the additions above only)
- `data/heroes/`, `data/monsters/` (number changes for R18 only)
- `tools/godot/run_sim.gd`, `tools/dev.py` (the `sim` command), `tools/tests/test_sim_command.py`
- `tests/acceptance/test_005_expedition_loop.gd`, `tests/unit/test_expedition*.gd`, `tests/unit/test_party*.gd`
- `tests/acceptance/test_001_sim_clock.gd` only if a new `Simulation` field breaks an existing assertion
- `CLAUDE.md` (the `sim` command), `docs/wiki/index.html`

## Open questions

None.
