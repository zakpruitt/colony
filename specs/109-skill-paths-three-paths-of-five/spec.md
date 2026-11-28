# 109 — Skill paths: three paths of five

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M8
- **Depends on:** 050, 051, 055, 057, 060, 063, 064
- **Pull request:** —

## Intent

Zak asked on 2026-11-27 for the talent tree to become skill paths, as in Skyrim. A class no longer
picks one path and loses the other. Each class has three paths of five abilities, and a hero learns
all fifteen in time. Points come every two levels until level 30. This spec changes the rules, the
content and the save, and makes the Talents tab show three columns. Path ranks earned by use are
spec 110. The finished window is spec 111.

## Requirements

- **R1. Three paths of five, as content.**
  - Each class's tree (`data/talents/<class>.tres`) has three named paths, in the order of "The paths"
    below. Each path has one short summary line and five nodes.
  - A path's nodes sit in four tiers: tier 1 has one node, tier 2 has two, tier 3 has one and tier 4
    (the capstone) has one.
  - The data check refuses each of these by name:
    - a tree without exactly three paths, or a path without exactly five nodes;
    - an empty path name, or a summary that is empty or over 60 characters;
    - an ability that is missing, or that appears twice in a tree;
    - an action that is not `ready_at_start`. That rule stays: fights last seconds, so an action
      waits only for its condition.
  - There are 60 abilities under `data/abilities` (44 today, plus the 16 new ones in "The new
    abilities"). Each is a node of exactly one tree.
  - Each new ability has its own 16x16 picture in its class's `assets/sprites/ui/pictures_<class>.px`
    (spec 063 R1: unlike every other picture, more than 40 opaque pixels, baked and linted). Pictures
    may be placeholders.
- **R2. Points come from levels.**
  - A hero earns one talent point at every even level from 2 to 30: 15 in all, enough to learn
    every node. `TALENT_POINT_GAINED` reports each point.
  - From level 31, each level gives one paragon point instead (today this starts at level 15).
  - Paragon stats, their 3% per point, their commands and their keys do not change.
- **R3. Taking a node.**
  - `take_talent` takes a node only if the hero has an unspent point and the node is open:
    - a tier-1 node is always open;
    - a tier-2 node needs that path's tier-1 node;
    - the tier-3 node needs either of that path's tier-2 nodes;
    - the capstone needs that path's tier-3 node.
  - Nothing closes a path. A hero may take nodes of all three paths in any order the rules allow, and
    hold all fifteen.
  - A command for anything else does nothing and sends no event: a node not in the tree, one already
    taken, one not yet open, or a node when the hero has no point.
- **R4. The order a hero tries its abilities.**
  - A hero's combatant carries its nodes' abilities with the highest tier first. Within a tier, the
    first path comes first; within a path's tier 2, the left node comes first. Today the newest node
    comes first.
  - Among the actions that are ready and have a target, a hero uses the one that has been ready the
    longest. A tie (every action is ready as a fight starts) goes to the action this hero used least
    recently, across fights (one never used counts as least recent); a tie after that goes by the
    order above. So a hero with fifteen nodes still turns to every action in time, not only to its
    highest tiers, even when fights are short.
  - The hero keeps its order of use (ability ids, least recent first) and gives it to each
    combatant; it is saved with the hero (`"used"`, a list of ability ids, in version 10) so a game
    saved and loaded fights on exactly as one played straight on. The check refuses an id that is
    not one of the hero's nodes; a reset clears it.
  - After an action, a hero's next swing is a plain strike: it uses no action until it has struck
    once. So passives set off by strikes still fire for a hero with many actions.
  - A hero with no nodes fights exactly as before.
- **R5. A fresh start.**
  - `reset_talents` still costs 100 gold times the hero's level and gives every talent point back.
  - Paragon ranks stay as they are.
  - It is still refused during a fight, without the gold, or with no node taken.
- **R6. Saves (version 10).**
  - The save keeps each hero's nodes in the order taken and its paragon ranks. A round trip keeps
    both.
  - A save of version 9 or earlier loads with every hero's talents given back: no nodes, every point
    its level earned unspent. Its paragon ranks are kept, even above what its level earns under R2.
    A hero's unspent paragon points are never below 0.
  - The check refuses each of these by name (`heroes[1].talents[2]`, `heroes[0].paragon`):
    - an unknown node;
    - a node taken before the node R3 says it needs;
    - more nodes than the hero's level earns;
    - more paragon points spent than the hero's level less 14 (the most any version of the game
      has let a hero earn).
- **R7. The new abilities do what they say.**
  - Each of the 16 abilities in "The new abilities" passes `AbilityDef.validate()`.
  - In a battle built for it, each does what its description says. Examples: Charge's stun lands on
    the target and on the enemies beside it; Plague starts every living enemy bleeding when the
    rogue kills; Overload fires on every fifth strike; Resurrection stands every fallen ally up with
    50% health, once a fight.
- **R8. Every ability is seen.** This is spec 051 R14, for three paths.
  - Runs: 60 minutes of headless play from level 1 on each of seeds 1 to 3, on winding stages with
    auto-buy on (as `dev.py sim --spend-talents --buy-upgrades --winding` plays). There is one run
    for each path, with each hero putting that path first (R12's spender). That is nine runs.
  - In those runs, every action a hero has held for ten minutes is used at least five times. Every
    passive it has held that long fires at least once.
  - Rescues are excused from those counts, but each must fire in a fight built to need it. The
    rescues are Last Stand, Vanish, Guardian Angel, Miracle, Sanctuary, Rampage and Resurrection,
    and every action whose condition waits for a hurt ally (Bulwark, Prayer and Rallying Cry among
    them; the test lists them from the data, not by hand): easy fights rarely hurt anyone.
  - If, after R4's choice of action, a few abilities still fall short, the lane may tune their
    numbers (cooldown, condition, chance) and lists each change. If a whole kind of ability still
    falls short, the lane stops and asks.
  - Whirlwind is still used on a guardian.
  - Because of R4, a party at level 30 with all fifteen nodes is checked too. It plays 30 minutes
    from Mossy Hollow stage 18, with the camp upgrades that
    `dev.py sim --seed=1 --minutes=120 --buy-upgrades --spend-talents --winding` has bought; the lane
    reads them from that summary and writes them into the test. In that play every action is used at
    least five times and every passive fires, rescues aside. This checks that a tier-1 action is not
    starved by the actions tried before it.
- **R9. Still worth having, still fair.**
  - Spec 051 R10 to R12 hold: auto-buy never spends talent or paragon points; play with
    `--spend-talents` reaches the first Slime King win sooner, and with fewer wipes, than play
    without, on seeds 1 to 5; two runs with spending agree; the recorded-hash tests pass unchanged
    for runs that spend nothing.
  - Each of the twelve paths still wins a fight its bare party loses. The fight is spec 051's: a
    level-14 party against the Old Crypt's guardian (level 15), on five battle seeds. The bare party
    wins none of the five; with the path's class's hero holding that path's five nodes and nothing
    else, the party wins at least three.
  - **Sunpriest's holy damage comes from healing power.** A cleric's own damage is small, so
    Smite, Holy Fire, Radiance and Wrath deal damage as a multiple of the cleric's healing power,
    not of its damage. This is one new field on `AbilityEffect`, checked by `validate()` (allowed
    only on DAMAGE) and read where an ability's damage is worked out:
    `@export var damage_from_healing: bool = false  # DAMAGE: multiplier times the fighter's healing power`.
    Their multipliers are tuned for the fight above (starting near 0.6x of today's). Radiance's
    mend lands on every ally within 2 tiles of the cleric, not only on the cleric (ALLIES_NEAR or
    the nearest existing kind; its description says so).
- **R10. The Talents tab, three paths wide.** This is the least that keeps the tab working. Spec
  111 makes it the real window.
  - The tab shows the class's three paths as three columns side by side within the window's width
    (`HeroWindow.WIDTH`, 600 UI pixels). Each column has its banner (name and summary, in the path's
    colour) and the path's nodes in four rows, one per tier, with the two tier-2 nodes side by side.
  - A line joins each node to each node that needs it.
  - Each node is in one of three states: taken, can be taken now (ready, pulsing), or not yet.
  - There is no closed path, no "Not chosen", and no question before a path. A click on a node that
    can be taken takes it.
  - Pointing at a node shows its card, which states where the node stands: `Learned`,
    `Click to learn`, `Take Whirlwind first` (for a tier-3 node, `Take Bloodthirst or Reckless Swing
    first`), or `No points: the next comes at level N`.
  - The strip and the points row work as spec 064 R6 and R7 say, except for the question before a
    path, which is gone. The reset, its question, the paragon medallions and keys 1 to 3 do not
    change.
  - Names show on one or two lines and are never cut. Two hero windows on Talents still sit side by
    side at 1280x720 (spec 060 R7), and the tab fits at 960x540 (scrolling as it does today).
  - Taking a node shows a burst and the banner `<Class> learned <Ability>`, as spec 064 R8 has it for
    a node.
  - Taking a path's tier-1 node writes the journal line `The Knight takes up the Guardian path`
    instead of `is now a`.
  - A hero's title (`Knight, Guardian`, on its window and its frame's tooltip) names the path where
    it holds the most nodes. A tie goes to the earlier path. A hero with no node has no path in its
    title.
  - Each class has a third path colour in `PathColours`: knight blue, red, copper; rogue red, forest,
    orchid; mage orange, cyan, orchid; cleric pink, tan, cyan. None of these is a colour a node state
    uses.
  - The help line about the tree, the picture sheet scene (`PictureSpecimen`, every class's paths in
    order) and the showcase's tree moment say what is true now. The showcase moment takes a tier-1
    node, then a tier-2 node, by clicks. `CLASS_PATHS` names one of three paths.
  - The new abilities that are spells show the existing visuals: `SpellEffects.KINDS` entries, using
    only kinds already in `REACHING`. Lightning Bolt, Static Field, Overload and Thunderstorm show
    `chain_spark`. Radiance shows `holy_beam`. Aegis, Hallowed Ground and Resurrection show
    `light_column`. Toxic Cloud, Plague and Shadowstep show `shadow`. Earthshaker, War Banner,
    Challenge, Charge and Envenom show only their move, their name and their statuses, as other
    physical abilities do.
- **R11. The old tests follow.** Tests of the two-path tree are rewritten for three paths, or
  removed where their rule is gone. Each change and what still guards the behaviour is listed in the
  pull request. "Tests that change" below lists every file.
- **R12. The headless run spends as a player might.**
  - `TalentSpender.spend(sim, path)` keeps its signature. For each unspent point it takes the first
    node the hero can take now, in this order: path `path` (default 0), tier by tier, left before
    right; then the other paths, in path order.
  - It puts every paragon point into Power.
  - `run_sim.gd`'s summary lists each hero's nodes as today.

## The paths

Paths in order. In each path the nodes are listed tier 1; tier 2 left / right; tier 3; tier 4. NEW
marks an ability in "The new abilities". The others keep their data as it is today.

| Class | Path | Summary (the line on its banner) | T1 | T2 | T3 | T4 |
|---|---|---|---|---|---|---|
| Knight | Guardian | holds the line and keeps the party standing | taunt | hold_the_line / bottle_top_block | bulwark | rallying_cry |
| Knight | Berserker | fights hurt and heals by hitting | whirlwind | bloodthirst / reckless_swing | rampage | earthshaker NEW |
| Knight | Warlord | leads the charge and calls out foes | shield_bash | last_stand / war_banner NEW | challenge NEW | charge NEW |
| Rogue | Assassin | bleeds, marks and finishes the weakest foe | backstab | mark_for_death / finisher | ambush | killing_spree |
| Rogue | Venom | spreads bleeding and weakness through packs | poisoned_blades | fan_of_knives / toxic_cloud NEW | envenom NEW | plague NEW |
| Rogue | Shadow | slows, stuns and slips away from every blow | smoke_step | caltrops / dizzying_feint | shadowstep NEW | vanish |
| Mage | Pyromancer | sets whole packs burning and drops meteors | fireball | ignite / wildfire | meteor | inferno |
| Mage | Frostbinder | freezes foes in place and shields the party | ice_lance | frost_nova / frost_armor | deep_freeze | blizzard |
| Mage | Stormcaller | strikes through armor and stuns whole packs | lightning_bolt NEW | chain_spark / static_field NEW | overload NEW | thunderstorm NEW |
| Cleric | Lifebinder | mends and shields the party through every hurt | prayer | renewal / blessing | sanctuary | miracle |
| Cleric | Sunpriest | burns and judges foes with holy light | smite | holy_fire / judgement | radiance NEW | wrath |
| Cleric | Warden | hastens, shields and stands the fallen back up | battle_hymn | guardian_angel / aegis NEW | hallowed_ground NEW | resurrection NEW |

## The new abilities

Every one uses only kinds that exist today (`AbilityDef`, `AbilityEffect`, `BattleAbilities`): no
new aim, condition, trigger, effect or status. Every action is `ready_at_start`. The numbers are
starting points. The lane may tune them, and its report lists each change. A description is one
plain line, as the others are.

| Id | Name | Kind, move | How it is built | Description |
|---|---|---|---|---|
| earthshaker | Earthshaker | action, leap | aim NEAREST_ENEMY, reach 1.2; DAMAGE x2.0 on ENEMIES (radius 0); STUNNED 1 s on ENEMIES; cooldown 25, windup 0.5 | Leaps in: every enemy takes 2x damage and is stunned for 1 s. Every 25 s. |
| war_banner | War Banner | passive, shout | FIGHT_STARTS; HASTED 0.85 for 10 s on ALLIES | As a fight starts, every ally strikes 15% faster for 10 s. |
| challenge | Challenge | action, shout | aim NEAREST_ENEMY, anywhere; MARKED 1.3 for 6 s on TARGET; cooldown 14, windup 0.2 | Calls out the nearest enemy: it takes 30% more damage for 6 s. Every 14 s. |
| charge | Charge | action, dash | aim FURTHEST_ENEMY, reach 1.2; DAMAGE x2.5 on TARGET; PUSH 1.5 tiles and STUNNED 1 s on AROUND_TARGET radius 1.5; cooldown 20, windup 0.4 | Charges the furthest enemy for 2.5x damage, pushing back and stunning it and those beside it for 1 s. Every 20 s. |
| toxic_cloud | Toxic Cloud | action, throw | aim NEAREST_ENEMY, anywhere; BLEEDING 0.3 of damage for 4 s and WEAKENED 0.7 for 4 s, both on AROUND_TARGET radius 1.5; cooldown 12, windup 0.3 | The target and the enemies beside it bleed and are weakened (30% less damage) for 4 s. Every 12 s. |
| envenom | Envenom | action, heavy_swing | aim NEAREST_ENEMY, reach 1.2; DAMAGE x2.0 ignoring armor on TARGET; BLEEDING 0.4 of damage for 4 s on TARGET; cooldown 7, windup 0.3 | Strikes the nearest enemy for 2x damage through its armor and leaves it bleeding for 4 s. Every 7 s. |
| plague | Plague | passive, flourish | KILLS; BLEEDING 0.3 of damage for 4 s on ENEMIES | On a kill, every enemy starts bleeding for 4 s. |
| shadowstep | Shadowstep | action, dash | aim FURTHEST_ENEMY, reach 1.2; DAMAGE x2.0 and STUNNED 1 s on TARGET; cooldown 10, windup 0.3 | Steps to the furthest enemy, strikes it for 2x damage and stuns it for 1 s. Every 10 s. |
| lightning_bolt | Lightning Bolt | action, cast | aim NEAREST_ENEMY, reach 7.0; DAMAGE x1.8 ignoring armor on TARGET; cooldown 6, windup 0.4 | Strikes an enemy for 1.8x damage through its armor. Every 6 s. |
| static_field | Static Field | passive, cast | FIGHT_STARTS; SLOWED 1.3 for 6 s on ENEMIES | As a fight starts, every enemy strikes 30% slower for 6 s. |
| overload | Overload | passive, flourish | EVERY_NTH_STRIKE, trigger_every 5; DAMAGE x0.6 on ENEMIES (not on_strike) | Every fifth strike also strikes every enemy for 0.6x damage. |
| thunderstorm | Thunderstorm | action, channel | aim SELF, condition ENEMY_WITHIN 8 tiles; DAMAGE x1.5 and STUNNED 1 s on ENEMIES; cooldown 28, windup 0.6 | Every enemy takes 1.5x damage and is stunned for 1 s. Every 28 s. |
| radiance | Radiance | action, cast | aim NEAREST_ENEMY, reach 2.0 (the cleric walks in); DAMAGE x0.7 on ENEMIES radius 2; MENDING 0.25 of healing power for 6 s on SELF; cooldown 10, windup 0.4 | Strikes every enemy within 2 tiles for 0.7x damage and mends the cleric for 6 s. Every 10 s. |
| aegis | Aegis | action, cast | aim WEAKEST_ALLY, anywhere; SHIELDED 0.15 of the receiver's health for 8 s on TARGET; cooldown 10, windup 0.3 | Shields the weakest ally for 15% of its health for 8 s. Every 10 s. |
| hallowed_ground | Hallowed Ground | passive, prayer | FIGHT_STARTS; WEAKENED 0.8 for 10 s on ENEMIES | As a fight starts, the ground is blessed: every enemy deals 20% less damage for 10 s. |
| resurrection | Resurrection | passive, prayer | ALLY_DIES, once_per_fight; REVIVE 0.5 on ALLIES | Once a fight, when an ally dies, every fallen ally stands back up with 50% health. |

These differ from the direction in three places, because today's engine cannot express what was
asked:

- **Challenge** marks the nearest enemy, not the strongest. `AbilityDef.Aim` has nearest, weakest
  and furthest, and no strongest.
- **Envenom** strikes the nearest enemy through its armor and makes it bleed. It cannot pick a
  bleeding enemy, because no aim or condition reads a target's statuses.
- **Resurrection** is a once-a-fight passive set off by a death, not an action every 60 s. No
  condition waits for a fallen ally, so an action that is ready at the start would spend its
  cooldown on nobody as the fight begins. Battle sets the cooldown before `BattleAbilities.use` finds
  no one to revive. Fights last seconds, so "every 60 s" would come to once a fight anyway.

  By R4, Resurrection is tried before Guardian Angel (tier 4 before tier 2). The first death
  revives every fallen ally. Guardian Angel then finds its target already standing, so it is not
  spent and waits for the next death.

## Interfaces

`TalentTreeDef` keeps its class name, its folder and `Content.talent_tree(class_id)`. Its shape
changes:

```gdscript
# sim/defs/skill_path_def.gd: a sub-resource of a TalentTreeDef, as AbilityEffect is of an AbilityDef
class_name SkillPathDef
extends Resource
@export var display_name: String
## One short line saying what a hero on this path becomes. A view hint: no rule reads it.
@export var summary: String
## Five ability ids: tier 1, tier 2 left, tier 2 right, tier 3, tier 4.
@export var nodes: Array[StringName] = []

# sim/defs/talent_tree_def.gd
const PATH_COUNT: int = 3
const PATH_LENGTH: int = 5
## The tier of each place in SkillPathDef.nodes.
const TIERS: Array[int] = [1, 2, 2, 3, 4]
@export var class_id: StringName
@export var paths: Array[SkillPathDef] = []
# trunk, path_names, path_a, path_b and path_summaries go.
func path(index: int) -> SkillPathDef             # null outside 0..2
func path_of(ability_id: StringName) -> int       # 0..2, or -1
func tier_of(ability_id: StringName) -> int       # 1..4, or 0
func has_node(ability_id: StringName) -> bool
## The nodes any one of which must be taken before ability_id; empty for tier 1.
func needs(ability_id: StringName) -> Array[StringName]
## The nodes not in taken whose needs taken meets, by path, then tier, then left to right.
func open_nodes(taken: Array[StringName]) -> Array[StringName]
## "" if taken is a legal order (R3), else the first node that breaks it, by its place.
func order_problem(taken: Array[StringName]) -> String
## taken in the order a fighter tries them (R4).
func fight_order(taken: Array[StringName]) -> Array[StringName]
## The path holding the most of taken (ties to the earlier), or -1 for none.
func main_path(taken: Array[StringName]) -> int
# next_nodes and path_nodes go.

# sim/party/hero.gd
const TALENT_POINTS: int = 15        # TALENT_EVERY stays 2
# path() goes (callers use TalentTreeDef.main_path(hero.talents())); Hero drops to 19 public methods.
```

`Simulation.SAVE_VERSION` becomes 10, with `TalentSave.upgrade_9_to_10`. `TalentRules` keeps its
functions; `paragon_points_at` counts levels after 30. The commands, events and `TalentSpender.spend`
keep their signatures.

## Acceptance

In `tests/acceptance/test_109_three_paths_of_five.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail. R8 goes in its own script,
`test_109_every_ability_is_seen.gd`, as 051's did. Both take helpers from `ColonyTest` or a test base,
not copies.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_three_paths_of_five` | Four trees and 60 abilities load and validate. Each ability is in exactly one tree, and each path's names and tiers are as in "The paths". A tree with two paths, a path of four nodes, a long summary, a repeated node and an action not ready at the start are each refused by name. Each new ability has its own picture |
| R2 | `test_r2_points_from_levels` | Points at 2, 4 … 30, none at odd levels and none after 30. The event fires. Paragon starts at 31 |
| R3 | `test_r3_taking_a_node` | Each tier needs what R3 says, and either tier-2 node opens tier 3. All fifteen can be held. Each illegal command is ignored with no event |
| R4 | `test_r4_fight_order` | A combatant's abilities are ordered by tier, path and side. With no nodes, the fight equals the bare one tick for tick |
| R5 | `test_r5_fresh_start` | The price, the points back, paragon kept, and the refusals |
| R6 | `test_r6_saves` | A round trip. A version 9 save with spec 051 talents and paragon at level 20 loads with no nodes, its paragon kept and none unspent. Each bad value is refused by name |
| R7 | `test_r7_new_abilities_do_what_they_say` | One built battle per new ability, checking its events: damage, status, push or revive, on whom |
| R8 | `test_r8_every_ability_is_seen` | The nine runs, the rescues, Whirlwind on a guardian, and the level-30 party with all fifteen |
| R9 | `test_r9_worth_having` and one per class | Spec 051's comparison on seeds 1 to 5, and each path's fight |
| R10 | `test_r10_the_tab_three_paths_wide` | Real clicks and mouse motion. Three columns within 600 pixels, the four tier rows, the lines, the states, the card's words, a click that takes a node, the journal line and the title. Two windows side by side at 1280x720 |
| R11 | the amended suite | Every listed test passes |
| R12 | `tools/tests/godot/test_051_sim_talents.py` (amended) | Points are spent, tier 1 of path 0 first, up to 15 |

**To look at, and for Zak:** each class's tab fresh, half spent and full, at 1280x720 and with
`--ui-room=960x540` (cropped and enlarged where small); two heroes side by side; the picture sheet
scene with the 16 new pictures; a fight with each new spell visual. Describe every shot.

## Tests that change

The lane rewrites or amends these, and no others, for the new shape. Old asserts on trunk, fork,
closing or the question before a path go. Asserts that hold for any shape stay.

- `tests/colony_test.gd` (`_spend_talents`): path 0's nodes, then path 1's, up to the hero's points.
- `tests/acceptance/frame_062_test_base.gd`: its `_level` copies that spending. It calls
  `ColonyTest._spend_talents` instead.
- `tests/acceptance/hero_windows_test_base.gd`, `tests/acceptance/talent_tree_test_base.gd`.
- `tests/acceptance/test_051_talent_trees_and_paragon.gd`: R1 to R4 move to `test_109` and are
  removed here. R5 to R13 are amended for three paths, the levels of R2, and saves going to version
  10.
- `tests/acceptance/test_051_every_ability_is_seen.gd`: removed; `test_109_every_ability_is_seen.gd`
  takes its place.
- `tests/acceptance/test_055_the_tree_on_the_sheet.gd`, `test_060_hero_windows.gd` and
  `test_064_the_talent_tree_as_a_tree.gd`: no question before a path, no closed path, three columns,
  the title. `test_064` is at 976 of its 985 lines (spec 081). Checks that grow move into
  `talent_tree_test_base.gd`.
- `tests/acceptance/test_034_hero_sheet_tabs.gd`, `test_056_abilities_on_screen.gd`,
  `test_057_lively_moves.gd` (its count of 44 abilities becomes 60), `test_063_pictures_and_the_moment.gd`,
  `test_080_frame_pieces.gd`, `tests/unit/abilities_on_screen_test_base.gd`,
  `tests/unit/lively_moves_test_base.gd` and `tests/unit/test_hud_talents.gd`: they name `trunk`,
  `path_a`, `path_b`, `path_nodes` or `path()`.
- `tests/acceptance/test_014_save_progress.gd`, `test_093_side_paths_and_caches.gd` and
  `test_096_the_order_to_press_on.gd`: their asserts that `SAVE_VERSION` is 9. In `test_014`, the
  pass-through test's version.
- `tests/acceptance/test_037_goals.gd`, `test_041_after_a_defeat.gd` and
  `test_046_notes_that_stay_true.gd` compute the first paragon level from `Hero.TALENT_POINTS` and
  `TALENT_EVERY`. They should pass unedited and may be amended only if they do not.
- `tools/tests/godot/test_051_sim_talents.py`.

## Out of scope

- Path ranks, rank gates on tiers, and path XP (spec 110).
- The window's real design: rank bars, moments for a rank or a capstone, the showcase's new beats,
  and the wiki's full rewrite (spec 111). This spec changes only the wiki lines that would be false.
- New aims, conditions, triggers or statuses. Changing any of the 44 existing abilities, except a
  number the lane must tune for R8 or R9 (reported).
- New keys, a new class, sounds.

## Paths

- `sim/defs/talent_tree_def.gd`, `sim/defs/skill_path_def.gd` (new, with its `.uid`),
  `sim/party/hero.gd`, `sim/party/talent_rules.gd`, `sim/talent_save.gd`, `sim/simulation.gd` (the
  version and the upgrade step only)
- `data/talents/`, `data/abilities/` (the 16 new files, and numbers tuned under R8 or R9)
- `assets/sprites/ui/pictures_knight.px`, `pictures_rogue.px`, `pictures_mage.px`, `pictures_cleric.px`
  and their baked `.png` and `.json`
- `game/ui/windows/` (the Talents tab and its pieces, `PathColours`, `HeroWindow`'s and
  `HeroWindows`' path title and banner, `help_panel.gd`'s line), `game/ui/picture_specimen.gd`,
  `game/hud/journal.gd`, `game/effects/spell_effects.gd` (the `KINDS` table only),
  `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `sim/defs/ability_effect.gd` (the `damage_from_healing` field) and the sim code that works out an
  ability's damage and chooses a fighter's action (`sim/combat/battle_abilities.gd`,
  `sim/combat/battle.gd`, `sim/combat/combatant.gd`), for R4 and R9 only
- `tools/godot/talent_spender.gd`, `tools/godot/run_sim.gd`, `tools/dev.py` (the `--spend-talents`
  help text only)
- `tests/colony_test.gd` may hold the worth-having helpers shared by `test_051` and `test_109`
  (the Slime King comparison and the path fight), not only `_spend_talents`
- `tests/acceptance/test_109_three_paths_of_five.gd`, `tests/acceptance/test_109_every_ability_is_seen.gd`
  and their `.uid`s, plus the files in "Tests that change"
- `docs/design/world.md` (the "Skill trees" section, rewritten for skill paths: three paths of five
  per class, nothing locks, a point every two levels to 30, paragon after, ranks by use (spec 110)),
  `docs/architecture.md` (the talent and save lines), `docs/wiki/index.html` (the lines this makes
  false)
- `tests/acceptance/test_092_the_game_plays_winding_stages.gd` (the save version it asserts as a literal, 9, becomes the new version; nothing else)
- `tests/unit/test_save_progress.gd` (the per-hero `"used"` field), `tests/acceptance/test_072_content_table.gd`
  (a party raised to a level that earns paragon under R2), `tests/unit/test_ability_fixes.gd` (the
  reapplied-bleed test's dummy and ticks, for R4's strike after an action; its bleed asserts stay)
- `tests/colony_test.gd`'s `_spend_talents` spends path 0, then 1, then 2

## Open questions

None.
