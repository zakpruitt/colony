# 051 — Talent trees and paragon

- **Status:** landed (provisional: not yet reviewed by Zak) (direction agreed with Zak 2026-11-17; the trees below are the lead's, not yet read by him)
- **Milestone:** M6
- **Depends on:** 029, 049, 050
- **Pull request:** [#54](https://github.com/zakpruitt/colony/pull/54)

## Intent

Every hero gets a small skill tree in which each node is something the hero does. A tree has a short trunk
and then two paths; taking one path locks the other, so two knights can be different heroes. When the tree
is full, levels give paragon points instead, which is the only place plain strength is bought. Gold
training (spec 029) is removed. This spec is the rules and the content; the tree on the hero sheet and
what abilities look like are spec 055.

## Requirements

- **R1. Trees are content.** Each class has a tree under `data/talents`: three trunk nodes in order, then
  two named paths of four nodes each in order. A node gives the hero one ability (spec 050) under
  `data/abilities`. The four trees are the ones in "The trees" below.
- **R2. Points come from levels.** A hero earns one talent point at every even level (2, 4, 6 …) until it
  has earned seven, which fills a tree: three trunk nodes and four of one path. Level-ups say so in an
  event.
- **R3. Spending.** A command spends one of a hero's points on a node. It works only if the hero has an
  unspent point and the node is next: trunk nodes in order, then the first node of either path, then that
  path's nodes in order. Anything else does nothing.
- **R4. One path.** Once a hero has a node of one path, no node of the other path can be taken.
- **R5. Abilities take effect.** A hero fights with the abilities of its nodes from its next fight on.
  A hero with no nodes fights exactly as before.
- **R6. Paragon.** Once a hero has earned seven talent points, every level after gives one paragon point.
  A command puts a paragon point into Power (+3% damage and healing), Quickness (+3% attack speed) or
  Toughness (+3% maximum health), with no limit. These three are the old trainings, without prices.
- **R7. A fresh start for a hero.** A command resets one hero's tree for gold (100 times the hero's
  level): every talent point comes back unspent and both paths are open again. Paragon points are not
  touched. Not possible during a fight; it takes effect at once otherwise.
- **R8. Gold training is gone.** The command to train with gold is removed. A version 6 save loads with
  each hero's training ranks dropped and the gold they cost returned to the party, and each hero given
  the talent and paragon points its level has earned, all unspent.
- **R9. Saves carry it** (version 7): each hero's nodes, and its paragon points by stat. A node that
  breaks R3 or R4, an unknown node, or more points spent than earned is refused by name.
- **R13. A fight the expedition ends, ends its statuses.** When the expedition ends a fight itself (the
  90-second limit), it calls `Battle.end()` first, so every status ends with its event and no monster
  goes back to its chamber carrying one. (`test_r13_limit_ends_statuses`.)
- **R14. Every ability is seen.** (Added by the lead after the review of pull request 54, which found
  Frost Nova, Prayer, Miracle and Inferno never used in hours of play, and Whirlwind never used against
  a guardian.) Ordinary fights last a few seconds, so every action is ready as a fight starts and is
  held back only by its condition and, after its first use, its cooldown. In 30 minutes of headless play
  from level 1 on each of seeds 1 to 3, with each path spent in turn, every action a hero has had for
  ten minutes is used at least five times and every passive fires at least once; an ability may be
  excused only if it answers a rescue (Last Stand, Vanish, Guardian Angel, Miracle, Sanctuary, Rampage),
  and then it must fire in a fight built to need it. Whirlwind has no condition beyond an enemy in
  reach. Frost Nova becomes: a burst around the nearest enemy, enemies there pushed back and slowed;
  every 12 s (the mage does not walk in to cast it). (`test_r14_every_ability_is_seen`.)
- **R10. Auto-buy leaves heroes alone.** Auto-buy never spends talent or paragon points.
- **R11. Worth having.** With `--spend-talents` (trunk in order, then the first path; paragon into Power)
  the headless run reaches the first Slime King win sooner and with fewer wipes than without, on seeds 1
  to 5, and each path of each class wins a fight its bare class loses (one test per class).
- **R12. Still deterministic**, and the recorded-hash tests pass unchanged for runs that spend nothing.

## The trees

Numbers are starting points; the lane tunes them and reports what it changed. Every ability's one-line
description must say what it does in plain words.

**Knight.** Trunk: *Shield Bash* (strike that stuns for 1.5 s; every 8 s), *Taunt* (enemies aim at the
knight for 4 s; every 12 s), *Bottle-top Block* (when hit, 20% chance of a small shield).
- **Guardian:** *Hold the Line* (as a fight starts, a small shield on every ally); *Last Stand* (below
  30% health, once a fight: a large shield and mending); *Bulwark* (when an ally is below 40%: taunt and
  a shield on the knight; every 15 s); *Rallying Cry* (every ally shielded and mending; every 30 s).
- **Berserker:** *Whirlwind* (strikes every enemy within reach; every 6 s); *Bloodthirst* (on a kill,
  hasted for 4 s); *Reckless Swing* (every fourth strike hits double and heals the knight for half);
  *Rampage* (below 50% health, once a fight: mighty and hasted for 8 s).

**Rogue.** Trunk: *Backstab* (the furthest enemy, triple damage, bleeding; every 10 s), *Smoke Step*
(when hit, 25% chance to be nimble for 3 s), *Finisher* (double damage to an enemy below 25%; every 5 s).
- **Assassin:** *Poisoned Blades* (hits leave a bleed); *Mark for Death* (the weakest enemy takes 30%
  more damage for 6 s; every 12 s); *Ambush* (as a fight starts, the nearest enemy is stunned for 2 s);
  *Killing Spree* (on a kill, mighty for 5 s).
- **Trickster:** *Fan of Knives* (every enemy struck for a part; every 8 s); *Caltrops* (every enemy
  slowed for 5 s; every 14 s); *Dizzying Feint* (critical hits weaken the target); *Vanish* (below 30%
  health, once a fight: cannot be hit for 4 s and mends).

**Mage.** Trunk: *Fireball* (damage and burning around the target; every 8 s), *Frost Nova* (with an
enemy next to the mage: nearby enemies pushed back and slowed; every 12 s), *Chain Spark* (critical hits
strike every enemy for a part).
- **Pyromancer:** *Ignite* (hits have a 30% chance to burn); *Meteor* (heavy damage around the furthest
  enemy; every 20 s); *Wildfire* (on a kill, every enemy burns); *Inferno* (with three or more enemies:
  all burn and are marked; every 25 s).
- **Frostbinder:** *Ice Lance* (the weakest enemy, heavy damage and a 1 s stun; every 9 s); *Frost
  Armor* (as a fight starts, a shield on every ally); *Deep Freeze* (enemies around the target stunned
  for 2 s; every 18 s); *Blizzard* (every enemy slowed and frostbitten, damage each second, for 6 s;
  every 25 s).

**Cleric.** Trunk: *Prayer* (with an ally below 60%: heals every ally; every 12 s), *Blessing* (as a
fight starts, every ally mends for 6 s), *Smite* (damage, and the target is weakened for 4 s; every 8 s).
- **Lifebinder:** *Renewal* (the weakest ally mends for 8 s; every 6 s); *Sanctuary* (with an ally below
  30%: a large shield on the weakest ally; every 15 s); *Guardian Angel* (when an ally dies, once a
  fight: it stands up with 40% health); *Miracle* (with an ally below 25%: every ally healed for 40% of
  its health; every 45 s).
- **Sunpriest:** *Holy Fire* (damage and burning; every 6 s); *Battle Hymn* (as a fight starts, every
  ally hasted for 8 s); *Judgement* (every third strike marks the target); *Wrath* (every enemy struck
  and every ally healed; every 20 s).

## Interfaces

```gdscript
# sim/defs/talent_tree_def.gd, one .tres per class under res://data/talents
class_name TalentTreeDef extends Resource
@export var class_id: StringName
@export var trunk: Array[StringName]          # ability ids, in order
@export var path_names: Array[String]         # two
@export var path_a: Array[StringName]
@export var path_b: Array[StringName]
func validate() -> PackedStringArray

# sim/defs/content.gd
static func talent_tree(class_id: StringName) -> TalentTreeDef

# sim/party/hero.gd (or a helper beside it)
const TALENT_POINTS: int = 7
func talents() -> Array[StringName]           # nodes taken, in the order taken
func talent_points() -> int                   # unspent
func can_take(ability_id: StringName) -> bool
func path() -> int                            # -1 none yet, 0 or 1
func paragon_points() -> int                  # unspent
func paragon_rank(stat: TrainingDef.Stat) -> int

# sim/simulation.gd
func take_talent(hero_id: int, ability_id: StringName) -> void
func spend_paragon(hero_id: int, stat: TrainingDef.Stat) -> void
func reset_talents(hero_id: int) -> void
# train_hero goes.

# sim/sim_event.gd, before ENCOUNTER_STARTED
TALENT_POINT_GAINED, TALENT_TAKEN, PARAGON_SPENT, TALENTS_RESET     # HERO_TRAINED goes
```

`TrainingDef` keeps `id`, `display_name`, `description`, `order`, `stat` and `per_rank` (0.03); its price
fields go. The hero sheet's Training tab must keep working until spec 055 replaces it: make it list the
three paragon stats with a button that spends a point, and show unspent talent points as a number only.

## Acceptance

In `tests/acceptance/test_051_talent_trees_and_paragon.gd`; spec 029's tests are removed or amended (say
which).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_trees_are_content` | Four trees and 44 abilities load and validate; a tree naming a missing ability, or with a path of the wrong length, is refused |
| R2 | `test_r2_points_from_levels` | Points at levels 2 to 14, none at odd levels, none after seven; the event |
| R3 | `test_r3_spending` | The legal order; each illegal spend ignored |
| R4 | `test_r4_one_path` | The other path closed after the first path node |
| R5 | `test_r5_abilities_take_effect` | A hero's combatant carries its nodes' abilities; none without nodes, and that fight equals the old one |
| R6 | `test_r6_paragon` | Points from level 15 on; each stat's 3% in the combatant |
| R7 | `test_r7_fresh_start` | The price, the points back, both paths open, refused in a fight and without the gold |
| R8 | `test_r8_gold_training_is_gone` | A version 6 save with training: gold returned exactly, points unspent |
| R9 | `test_r9_saves` | A round trip; each bad value refused by name |
| R10 | `test_r10_auto_buy` | A long auto-buy run leaves points unspent |
| R11 | `test_r11_worth_having` | The headless comparison on five seeds; one fight per path |
| R12 | `test_r12_deterministic` | Two runs with spending agree; recorded hashes unchanged |

**To report for Zak:** for each class and path, one sentence on how it plays in the headless run, and
every number changed from "The trees".

## Out of scope

- The tree on the hero sheet, ability effects, names over heads, sounds (spec 055).
- New classes; abilities for monsters; talents that change side quests or gold.

## Paths

- `sim/`, `data/talents/`, `data/abilities/`, `data/training/`
- `game/hud/hero_sheet.gd` and what it needs to keep the Training tab truthful; `game/` to keep compiling
- `tools/dev.py`, `tools/godot/`, `tools/tests/`
- `tests/`
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md`

## Open questions

None.
