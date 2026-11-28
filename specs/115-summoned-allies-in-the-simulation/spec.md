# 115 — Summoned allies in the simulation

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M9
- **Depends on:** 050, 110 (its Paths hold `battle.gd`, `battle_abilities.gd`, `combatant.gd` and
  `sim_event.gd`; this starts after 110 has landed, and may run beside 111, 113 and 114)
- **Pull request:** —

## Intent

Three of the four classes Zak has asked for fight beside things they bring: the Ranger's mice,
hedgehog and hawk, the Tinker's turrets and the Witch Doctor's totems. Spec 050 left summoned
creatures out of scope without a rule for them (its twelve test abilities needed none), and its
battle assumes the sides never change once a fight starts. This spec adds the rule: an ability
effect that brings a short-lived fighter onto the heroes' side, with its numbers as data, a lifetime
and a cap. It is the simulation only, built and proven in tests. No ability in `data/` summons yet,
so nothing the game does changes. Spec 116 puts summons on screen; each class's spec then gives them
to its abilities.

## Requirements

- **R1. A summon is data inside an ability.**
  - `AbilityEffect` gains `SUMMON` (added at the end of `Does`, so the abilities saved today keep
    their values). The effect carries a `SummonDef` sub-resource, how many come per use (`count`,
    1 or more) and the most of that summon its summoner may have at once (`summon_cap`, 1 or more).
  - A `SummonDef` has an id (it names the summon's sheet and its line in the tally), a name, and its
    numbers: health and damage as shares of the summoner's, healing power as a share of the
    summoner's (0 for none), armor, crit chance, strike interval, wind-up, range, move speed (0 for
    one that never moves, as a turret or totem), how far ahead of the summoner it appears, its
    lifetime in seconds, and the ids of abilities it fights with (empty for none).
  - A summon lands on `SELF`: it appears beside its summoner.
  - The data check refuses each of these by name: a summon effect with no `SummonDef`, a `count` or
    `summon_cap` below 1, or landing anywhere but `SELF`; an empty id or name; a health or damage
    share of 0 or less; a healing share below 0; a lifetime of 0 or less; a negative move speed,
    armor or distance ahead; a strike interval, wind-up or range of 0 or less; an unknown ability; and
    an ability of the summon's that itself summons.
- **R2. A summon arrives and fights.**
  - When the effect lands, each summon is made with its health, damage and healing worked out from
    the summoner's numbers at that moment (each at least 1, healing 0 when its share is 0), at the
    summoner's level, and placed `ahead` tiles from the summoner toward the enemy, inside the room.
  - It acts from the next tick, after the heroes and before the monsters, in the order summoned. It
    strikes, walks (unless its move speed is 0), winds up and uses its abilities exactly as any
    fighter does. One that never moves strikes only what is in its range, and otherwise waits.
  - Statuses land on it and its strikes set off its own passives as any fighter's do.
  - `SUMMONED` reports it: its source is the summoner, its target the summon's id, its amount the
    lifetime in ticks, its `ability_id` the summoning ability.
- **R3. Monsters fight it.**
  - A summon is an enemy to every monster: it can be the nearest, weakest or furthest target, an
    area effect on the heroes' side reaches it, and it can taunt.
  - Effects that land on `ALLIES` or `AROUND_TARGET` of the heroes reach it.
  - A healer's choice of whom to heal, an action aimed at the weakest ally, and a revive pick only
    heroes, so no cleric spends a heal on a turret.
- **R4. A summon ends.**
  - It ends when its lifetime runs out, when it falls to 0 health, when a new summon over its
    summoner's cap replaces it (the oldest of that summoner's summons of that id goes), and when the
    fight ends (`Battle.end`, which every way a fight stops already calls).
  - Its end is never a death: it sends no `DIED`, sets off no `ALLY_DIES` or `KILLS` passive, is
    never revived, and leaves the expedition's count of heroes standing as it was.
    `SUMMON_ENDED` reports it: its source is the summon, its target its summoner, its amount why
    (0 time, 1 fell, 2 replaced, 3 the fight ended).
  - A summon outlives its summoner if the summoner falls first.
  - No summon is left in a battle once it has ended.
- **R5. Who wins, and who is credited.**
  - The heroes lose when every hero has fallen, whatever summons still stand. Summons never win a
    fight alone.
  - A monster a summon kills rewards the party exactly as one a hero kills (the XP, gold and
    resources of today's rules).
  - The summon's hits, heals and statuses carry the summon as their source. Who summoned it is
    `Combatant.owner_id`, so a view or the tally can credit the summoner.
  - The summoning ability's own `ABILITY_USED` counts for its summoner's path XP (spec 110) as any
    ability's does. The summon's own abilities do not.
- **R6. Ids.** Summons take ids from 50 to 99, in the order summoned in a fight, starting again at 50
  after 99. The ids of the summons alive at once are always distinct: a summon past the fiftieth
  alive at once replaces the oldest summon in the fight. Hero ids are below 50 (one hero a class,
  spec 112) and monster ids are from `Expedition.FIRST_MONSTER_ID` (100), so `id <
  Expedition.FIRST_MONSTER_ID` still means the heroes' side in every view.
- **R7. Nothing changes without summons.** A battle in which no ability summons rolls, moves and ends
  exactly as before: the recorded-hash tests and spec 050's recorded battle pass unchanged.
  `Battle.heroes` is still exactly the party's fighters, so nothing in `sim/expedition/` changes.
- **R8. Still deterministic.** The same seed, fighters and abilities give the same battle, summons
  and all.

## Interfaces

```gdscript
# sim/defs/summon_def.gd: a sub-resource of an AbilityEffect, as AbilityEffect is of an AbilityDef
class_name SummonDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var health_share: float = 0.3
@export var damage_share: float = 0.3
@export var heal_share: float = 0.0
@export var armor: int = 0
@export var crit_chance: float = 0.0
@export var attack_interval: float = 1.2
@export var windup: float = 0.2
@export var attack_range: float = 1.0
@export var move_speed: float = 0.0
@export var ahead: float = 1.0
@export var seconds: float = 10.0
@export var abilities: Array[StringName] = []
func validate() -> PackedStringArray

# sim/defs/ability_effect.gd
enum Does { DAMAGE, HEAL, PUSH, REVIVE, STATUS, SUMMON }
@export var summon: SummonDef
@export var count: int = 1
@export var summon_cap: int = 1

# sim/combat/combatant.gd
## The summoner's id for a summon; -1 for a hero or a monster.
var owner_id: int = -1
## The battle tick a summon's lifetime runs out on; -1 for others.
var ends_tick: int = -1
static func from_summon(def: SummonDef, summoner: Combatant, combatant_id: int) -> Combatant
func is_summon() -> bool

# sim/combat/battle.gd
const FIRST_SUMMON_ID: int = 50
const LAST_SUMMON_ID: int = 99
## The summons standing in the fight, in the order summoned. Heroes stay in heroes.
var summons: Array[Combatant] = []
## allies_of and enemies_of return the heroes' side, heroes then summons, for a fighter of either
## side: one list kept as summons come and go, so no call makes a list.
func add_summon(made: Combatant) -> void

# sim/combat/battle_summons.gd (new): the summon rules, as BattleAbilities holds the ability rules,
# so battle.gd (607 lines) grows little.
class_name BattleSummons
extends RefCounted
static func summon(battle: Battle, summoner: Combatant, effect: AbilityEffect, ability: AbilityDef) -> void
static func pulse(battle: Battle) -> void          # ends the summons whose time is up
static func end_all(battle: Battle, why: int) -> void

# sim/sim_event.gd: two kinds among the rarer ones, before ENCOUNTER_STARTED
SUMMONED
SUMMON_ENDED
```

`Battle` has 18 public methods and gains one.

## Acceptance

In `tests/acceptance/test_115_summoned_allies.gd`, one test per requirement named `test_rN_…`, each
written before its code and seen to fail. It extends `tests/unit/ability_kit_test_base.gd` and builds
its abilities and summons in the test, as spec 050's tests do. The test abilities are a hawk (moves,
strikes from 4 tiles, 8 s), a turret (never moves, range 5, 12 s, cap 2), and a totem (never moves,
heals, with Battle Hymn as its ability).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_summon_is_data` | A saved ability with a summon loads and validates (under a per-process `user://` name); each bad field refused by name |
| R2 | `test_r2_arrives_and_fights` | Numbers from the summoner's, the place ahead, acting from the next tick in its order, the turret striking only in range, the totem healing and hasting, the event |
| R3 | `test_r3_monsters_fight_it` | A monster strikes the nearer summon; a heroes' `ALLIES` status reaches it; a healer and a weakest-ally action pass it over |
| R4 | `test_r4_a_summon_ends` | Each of the four ends with its reason; no `DIED`, no Guardian Angel, no revive; outliving its summoner; none left after the fight |
| R5 | `test_r5_who_wins_and_credit` | A fight lost with a turret standing; a kill by a summon rewarding the party in an expedition run; sources and `owner_id`; path XP for the summoning ability only |
| R6 | `test_r6_ids` | Ids from 50, wrapping after 99, distinct while alive, and the fifty-first replacing the oldest |
| R7 | `test_r7_nothing_changes` | Spec 050's recorded battle and the recorded hashes, unchanged |
| R8 | `test_r8_deterministic` | Two battles with summons from one seed, event for event |

**To report for Zak:** nothing to look at (spec 116 is the view). Say anything a class's summon will
want that this rule cannot say.

## Out of scope

- Anything under `game/` (spec 116). Any summoning ability in `data/` (the class specs).
- Monsters that summon. Summons that are not fighters (a trap on the ground, a mine): an ability
  with an area effect does that today.
- A summon's kill counting as its summoner's for `KILLS` passives; summons that grow with ranks;
  summons that stay between fights.

## Paths

- `sim/defs/summon_def.gd` (new), `sim/combat/battle_summons.gd` (new), each with its `.uid`
- `sim/defs/ability_effect.gd`, `sim/defs/ability_def.gd` (only its checks of where an effect lands)
- `sim/combat/battle.gd`, `sim/combat/battle_abilities.gd`, `sim/combat/combatant.gd`,
  `sim/combat/battle_statuses.gd` (only if statuses must end with a summon)
- `sim/sim_event.gd`
- `tests/acceptance/test_115_summoned_allies.gd` and its `.uid`,
  `tests/unit/ability_kit_test_base.gd` (helpers to build a summon, if a second test needs them)
- `docs/architecture.md` (summons in a battle)

## Open questions

None.
