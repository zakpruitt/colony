# 050 — Abilities in combat: the rules skill trees are made of

- **Status:** provisional (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 004, 015
- **Pull request:** —

## Intent

Zak wants every hero to have a skill tree in which each node is something the hero does: a new action, or
a passive with a visible effect, never a plain damage or health increase. Today a fighter can only walk,
strike and (for a healer) heal. This spec gives battles **abilities**: actions with cooldowns, passives
that answer to what happens in the fight, and the lasting effects they leave. It gives no hero an ability
yet, so the game plays exactly as before; spec 051 builds the trees from it and spec 055 shows them.

## Requirements

- **R1. Abilities are content.** An ability is a resource under `data/abilities` with a name, one line of
  description, and its rules below. `validate()` refuses one that could never do anything. The folder may
  be empty.
- **R2. Actions.** A fighter with an action uses it instead of its ordinary strike when the action is off
  cooldown, its condition holds and a target is in range. It winds up like a strike, then its effects
  land. An action names:
  - its **cooldown** and **wind-up** in seconds, and whether it is ready at the start of a fight;
  - whom it **aims at**: the nearest enemy, the weakest enemy (lowest share of health), the furthest
    enemy, the weakest ally, or the fighter itself;
  - its **range** in tiles (the fighter walks into range as for a strike), or anywhere;
  - an optional **condition**: an ally below a share of health, the fighter itself below a share, or at
    least N enemies alive.
- **R3. Passives.** A passive fires its effects when its trigger happens, with an optional chance and an
  optional limit of once per fight. Triggers: the fight starts; the fighter lands a hit; lands a critical
  hit; kills; is hit; falls below a share of health; an ally dies; every Nth strike.
- **R4. Effects.** An ability has one or more effects, applied in order. Each effect says where it lands
  (the target, everyone of the target's side within a radius of it, the fighter itself, every ally, every
  enemy) and what it does:
  - **Damage:** a multiple of the fighter's damage, optionally ignoring armor, optionally multiplied
    again when the target is below a share of health, optionally healing the fighter for a share of what
    was dealt.
  - **Heal:** a multiple of the fighter's healing power, or a share of the receiver's maximum health.
  - **Push:** move the receiver a number of tiles away from the fighter, inside the room.
  - **Revive:** stand a dead ally up with a share of its health.
  - **Status:** put a status on the receiver for a number of seconds.
- **R5. Statuses.** Stunned (does nothing); taunting (enemies that can reach it aim at it); shielded
  (the next N damage is absorbed); burning or bleeding (damage each second, ignoring armor); mending
  (healing each second); hasted or slowed (time between strikes multiplied); mighty or weakened (damage
  dealt multiplied); marked (damage taken multiplied); nimble (a chance for a strike to miss it). The same
  status applied again restarts its time and keeps the stronger amount; it does not stack. Every status
  ends when the fight ends.
- **R6. The view can follow it.** Events say when an ability starts its wind-up, when it lands (which
  ability, who, on whom), when a status begins and ends, when a strike misses or is absorbed, and when a
  fighter is revived. Damage and healing from abilities and statuses are reported as hits and heals with
  their true source, so the party tally counts them with no change.
- **R7. Nothing changes without abilities.** A battle in which nobody has an ability rolls, moves and ends
  exactly as before: the recorded-hash tests pass unchanged, and no file under `game/` needs to change.
- **R8. Still deterministic.** The same seed, fighters and abilities give the same battle.
- **R9. It can say what the trees will need.** These are built in the tests from the rules above, each
  shown working in a battle: *Shield Bash* (damage and a stun), *Taunt*, *Whirlwind* (every enemy within
  reach), *Last Stand* (below 30% health, once a fight: a shield and mending), *Backstab* (the furthest
  enemy, triple damage, bleeding), *Finisher* (double damage below 25% health), *Fireball* (damage and
  burning around the target), *Frost Nova* (enemies near the fighter pushed back and slowed), *Chain
  spark* on a critical hit (every enemy struck for a part), *Prayer* (heals every ally), *Guardian Angel*
  (when an ally dies, once a fight: it is revived), *Battle Hymn* at the start of a fight (every ally
  hasted).

## Interfaces

```gdscript
# sim/defs/ability_def.gd, one .tres per ability under res://data/abilities
class_name AbilityDef extends Resource
@export var id: StringName
@export var display_name: String
@export var description: String
func validate() -> PackedStringArray
# The remaining fields (kind, cooldown, aim, range, condition, trigger, chance, effects) are the lane's
# to shape; effects are sub-resources so one ability is one .tres file.

# sim/defs/content.gd
static func ability(id: StringName) -> AbilityDef
static func ability_ids() -> Array[StringName]

# sim/combat/combatant.gd
var abilities: Array[AbilityDef] = []         # empty for everyone today
func has_status(kind: <the lane's enum>) -> bool

# sim/sim_event.gd: new kinds, placed before ENCOUNTER_STARTED, and whatever field carries the ability
# or status id. ABILITY_STARTED, ABILITY_USED, STATUS_BEGAN, STATUS_ENDED, MISSED, REVIVED
```

`sim/combat/battle.gd` is 367 lines; put the new rules in new files under `sim/combat/` and keep
`Battle` under gdlint's limits.

## Acceptance

In `tests/acceptance/test_050_abilities_in_combat.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_abilities_are_content` | A saved `.tres` ability loads and validates (written under a per-process `user://` name); empty, effectless and contradictory ones are refused |
| R2 | `test_r2_actions` | Cooldown, wind-up, each aim, range and walking into it, each condition, ready or not at the start |
| R3 | `test_r3_passives` | Each trigger, the chance (from the battle's random stream), once per fight |
| R4 | `test_r4_effects` | Each effect and each place it can land, with exact amounts |
| R5 | `test_r5_statuses` | Each status's rule, reapplying, and none left after the fight |
| R6 | `test_r6_events` | The events for one action and one passive, in order, with ids; a status's damage credited to its source |
| R7 | `test_r7_nothing_changes` | A battle without abilities, event for event, against one recorded before the change |
| R8 | `test_r8_deterministic` | Two battles with abilities from one seed |
| R9 | `test_r9_the_twelve` | Each of the twelve abilities doing what its line says |

**To report for Zak:** nothing to look at (the view is spec 055). List anything in R9 that needed a rule
this spec did not name.

## Out of scope

- Giving any hero or monster an ability; talent points, trees, paragon (spec 051).
- Anything under `game/`: sprites, effects, sounds, the hero sheet (spec 055).
- Summoned creatures.

## Paths

- `sim/combat/`, `sim/defs/`, `sim/sim_event.gd`
- `data/abilities/` (a `.gitkeep` only)
- `tests/acceptance/test_050_abilities_in_combat.gd`, `tests/unit/test_ability*.gd`, `tests/unit/test_status*.gd`
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
