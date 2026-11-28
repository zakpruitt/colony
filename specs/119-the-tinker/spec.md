# 119 — The Tinker: turrets, bombs and clockwork

- **Status:** approved (2026-11-27)
- **Milestone:** M9
- **Depends on:** 109, 110, 112, 113, 114, 115, 116, 117, 118 (it needs 112's artifact and request
  fields and 115's summons; its Paths share `game/ui/ui_icon.gd`, `pictures_artifacts.px`, the
  colour tables, the picture sheet scene, the showcase and the counting tests with specs 117 and
  118, so it starts once 118 has landed and builds on 117's helpers). Spec 120, the Witch Doctor,
  shares this spec's Paths and starts after it lands.
- **Pull request:** —

## Intent

The third class found by luck (spec 112). A cache may hold a Tinker's Wrench; a Tinker then waits
at camp until its request is paid, and can go down in place of any of the four. It stands at the
back and fights with what it builds: Turrets sets down a gun turret, a flame turret, a spark coil
and a siege cannon that fight beside the party (spec 115's summons); Demolition throws bombs,
firebombs and stunning charges; Gadgets snaps traps, sets a decoy that draws the blows and winds up
a clockwork guard. Three paths of five, as every class has since spec 109. It is drawn as the
Knight until Zak draws it, and its machines with spec 116's placeholder creature.

## Requirements

- **R1. The class, as data.** `data/heroes/tinker.tres`:

  | Field | Value | Why |
  |---|---|---|
  | `role` | `RANGED` | It throws and builds from the back, and is fielded in a Mage's place most often |
  | `max_health`, `health_per_level` | 50, 7 | Between the Mage (45, 6) and the Ranger (55, 7): it stays behind its machines. 141 at level 14 |
  | `damage`, `damage_per_level` | 6, 2 | 32 at level 14. Its machines' health and damage are shares of these (spec 115), so its own numbers size its turrets |
  | `attack_interval`, `windup` | 1.2, 0.4 | About 27 damage a second before armor at level 14, the Mage's is 28.5: a bare Tinker is no stronger than the Mage it replaces (R5 checks it) |
  | `attack_range` | 5.0 | A sling of nuts and bolts, a tile short of the Ranger's 6 |
  | `move_speed`, `crit_chance` | 2.5, 0.05 | The Mage's speed; the Cleric's crit |
  | `armor`, `heal_power` | 2, 0 | A leather apron and goggles: more than the Mage's 0 or the Ranger's 1 |
  | `microskills`, `microskill_levels` | `[lockpicker]`, `[3]` | A tinker opens locks; the Rogue learns it at 2. No new microskill (it would need its own quests, spec 025) |
  | `artifact_name` | `Tinker's Wrench` | |
  | `artifact_picture` | `tinkers_wrench` | R4 |
  | `artifact_chance` | 0.05 | Spec 112's suggestion |
  | `recruit_gold`, `recruit_resource`, `recruit_resource_count` | 800, `old_bones`, 30 | Dearer than the Bard's 500 gold and 25 clay, and asking for the Old Crypt's old bones gives that area a use: each class asks for the next area's resource (Ranger Glowcaps, Bard clay, Tinker old bones, Witch Doctor embers). The headless run never leaves Mossy Hollow, so this price is not measured: tunable data |
  | `looks_like` | `knight` | Stocky and armoured; drawn so, it reads apart from the Mage it most often replaces. The Rogue and the Cleric are the Ranger's and the Bard's |

  - It passes `HeroClassDef.validate()` and spec 112's checks, and `python tools/dev.py check
    --only=data` passes with it. It is not in `Party.STARTING_CLASSES`: a new game is the four.
- **R2. Three paths of five.** `data/talents/tinker.tres`, in this order, with the four trees'
  `rank_xp`, `tier_ranks` and `uses_counted` (spec 110 as built). Nodes are tier 1; tier 2 left /
  right; tier 3; tier 4.

  | Path | Summary (at most 60 characters) | T1 | T2 | T3 | T4 |
  |---|---|---|---|---|---|
  | Turrets | sets down turrets that shoot, burn and shell | gun_turret | flame_turret / overclock | spark_coil | siege_cannon |
  | Demolition | bombs, fire and blasts that stun whole packs | bomb | firebomb / chain_reaction | concussion_charge | powder_keg |
  | Gadgets | traps, a decoy and a clockwork guard | decoy | bear_trap / spring_glove | flash_powder | clockwork_guard |

  It passes `TalentTreeDef.validate()`. `PathColours` gives the paths `copper`, `brick` and `cyan`
  (no state's colour).
- **R3. The fifteen abilities do what they say.** Each is a file under `data/abilities`, built only
  from kinds that exist today (see "The abilities"), passes `AbilityDef.validate()`, and every
  action is `ready_at_start`. In a battle built for it, each does what its description says.
  Examples: Gun Turret's turret never moves and strikes only what is within 6 tiles, a second
  stands beside the first, and a third use replaces the oldest; the Flame Turret's hits set burning
  (its Ignite) and that burning ends when the turret does (spec 115 as built); the Spark Coil's
  fifth zap strikes every enemy (its Overload); the Siege Cannon's Meteor lands on the furthest
  enemy and those beside it; the Decoy never strikes, and taunts (its Bulwark) once another ally is
  below 80%; Chain Reaction strikes every enemy left when one is killed; Concussion Charge stuns
  one 2 tiles from its target and not one 2.5 away; Spring Glove pushes the enemy it hit and never
  fires on a miss.
- **R4. Pictures.** Each of the fifteen has its own 16x16 picture in a new sheet,
  `assets/sprites/ui/pictures_tinker.px`, listed in `UiIcon.SHEETS` after the Bard's; and the
  Wrench has one, `tinkers_wrench`, in `assets/sprites/ui/pictures_artifacts.px`. Spec 063 R1
  holds for each, as spec 117 R4 has it. They may be placeholders.
- **R5. Each path is worth having.** Spec 051's fight (a level-14 party against the Old Crypt's
  guardian at level 15, on five battle seeds), with the Tinker standing in the Mage's place
  (spec 117's `ColonyTest.stand_in`):
  - the bare party (no nodes) wins none of the five;
  - with the Tinker holding one path's five nodes and nothing else, the party wins at least three,
    for each path.
  - Probed on a scratch copy of `dev` with these numbers (and the Ranger's and the Bard's data):
    bare 0 (the party falls at 58 to 66 s); Turrets 5 (38 to 43 s), Demolition 5 (44 to 50 s),
    Gadgets 5 (47 to 49 s). In the same fight the Mage's own paths win 4, 4 and 3, the Ranger's
    5, 5 and 5.
- **R6. Every ability is seen.** As spec 117 R6, with the Tinker in the Mage's place from the start:
  - The nine 60-minute runs (seeds 1 to 3, winding stages, buying upgrades, one run per path put
    first by every hero): every action the Tinker has held for ten minutes is used at least five
    times, and every passive it has held that long fires at least once. The Tinker has no rescue:
    none is excused.
  - The level-30 party with all fifteen nodes each, 30 minutes from Mossy Hollow stage 18: every
    Tinker action used five times and every passive fired.
  - Probed: in the nine runs no party wiped and each reached stage 12; the fewest uses of an action
    held ten minutes were Concussion Charge's 5 in 10 minutes (seed 1, Turrets first) and the Spark
    Coil's 5 in 11 (seed 1, Demolition first); Spring Glove fired 44 to 67 times, Chain Reaction 30
    to 156, Overclock 27 to 134. In the full party's play every action was used 12 to 14 times.
    The lane may tune a number that falls short (those two cooldowns first) and lists each change.
- **R7. The Tinker on screen.**
  - Its tally bar is `orange` over `brick` (`TallyWindow.CLASS_BARS`), and its numbers and its
    machines' are drawn in that colour (spec 116 R2 reads it).
  - It is drawn as the Knight in the world, the frames, the hero window and the tally (spec 113
    R6), under its own name. Its machines are drawn with spec 116's placeholder sheet: no summon
    sheet is added.
  - Its bombs and charges show their move, their name and their statuses, as the Knight's physical
    abilities do. `SpellEffects.KINDS` gains nothing.
  - The showcase gains `tinker_actions` in `Showcase.CLASS_MOMENTS`, `CLASS_PATHS` giving it
    Turrets: the Tinker stands in for the Mage holding Turrets' five nodes, and the gun turret, the
    flame turret, the spark coil and the siege cannon are seen to arrive and fight.
  - The picture sheet scene (`PictureSpecimen`) shows the Tinker's group after the Bard's, wholly on
    the sheet at its room (spec 063 R9).
- **R8. The recorded runs.** As spec 117 R8: a recorded-hash test (`test_016`, `test_035`,
  `test_039`, `test_100`, `test_101`) may change only from the step a cache finds the Wrench, shown
  in the pull request, and is then re-recorded with a comment saying so. A difference before any
  find is a bug.
- **R9. The old tests follow.** The tests specs 117 and 118 amended for a fifth and sixth class are
  amended for a seventh (105 abilities), and no others (see "Tests that change"). Each change, and
  what still guards the behaviour, is listed in the pull request.
- **R10. The wiki.** `docs/wiki/index.html` gains the Tinker beside the Ranger and the Bard: how it
  is found, its price, its three paths in a line each.

## The abilities

Every one uses only aims, conditions, triggers, effects and statuses that exist today, and
spec 115's `SUMMON`. Self-aimed actions wait for an enemy within 9 tiles (`ENEMY_WITHIN`), so a
machine or a keg is not spent before the fight has someone in it. The numbers are the probed ones;
the lane may tune them for R5 and R6 and lists each change.

| Id | Name | Kind, move | How it is built | Description |
|---|---|---|---|---|
| gun_turret | Gun Turret | action, throw | aim SELF, ENEMY_WITHIN 9; SUMMON `gun_turret` x1, cap 2; cooldown 12, windup 0.4 | Sets down a gun turret that shoots the nearest enemy in reach for 20 s; a third replaces the oldest. Every 12 s. |
| flame_turret | Flame Turret | action, throw | aim SELF, ENEMY_WITHIN 9; SUMMON `flame_turret` x1, cap 1; cooldown 16, windup 0.4 | Sets down a flame turret near the front that sets what it hits burning, for 12 s. Every 16 s. |
| overclock | Overclock | passive, flourish | KILLS; HASTED 0.75 for 5 s on ALLIES | On a kill, every ally and machine strikes 25% faster for 5 s. |
| spark_coil | Spark Coil | action, throw | aim SELF, ENEMY_WITHIN 9; SUMMON `spark_coil` x1, cap 1; cooldown 16, windup 0.4 | Sets down a spark coil for 12 s that zaps the nearest enemy; every fifth zap arcs to every enemy. Every 16 s. |
| siege_cannon | Siege Cannon | action, channel | aim SELF, ENEMY_WITHIN 9; SUMMON `siege_cannon` x1, cap 1; cooldown 32, windup 0.6 | Wheels out a siege cannon for 16 s: heavy shots, and shells on the furthest enemy and those beside it. Every 32 s. |
| bomb | Bomb | action, throw | aim NEAREST_ENEMY, anywhere; DAMAGE x2.0 on AROUND_TARGET radius 1.5; cooldown 6, windup 0.4 | Throws a bomb at the nearest enemy: 2x damage to it and those beside it. Every 6 s. |
| firebomb | Firebomb | action, throw | aim FURTHEST_ENEMY, anywhere; DAMAGE x0.8 and BURNING 0.7 of damage for 5 s on AROUND_TARGET radius 1.5; cooldown 10, windup 0.4 | Throws a firebomb at the furthest enemy: 0.8x damage, and it and those beside it burn for 5 s. Every 10 s. |
| chain_reaction | Chain Reaction | passive, flourish | KILLS; DAMAGE x0.8 on ENEMIES | On a kill, the blast spreads: every enemy takes 0.8x damage. |
| concussion_charge | Concussion Charge | action, throw | aim NEAREST_ENEMY, anywhere; DAMAGE x1.5 and STUNNED 2 s on AROUND_TARGET radius 2; cooldown 12, windup 0.5 | A charge under the nearest enemy: 1.5x damage to it and those within 2 tiles, stunned for 2 s. Every 12 s. |
| powder_keg | Powder Keg | action, channel | aim SELF, ENEMY_WITHIN 9; DAMAGE x3.5 and BURNING 0.4 of damage for 5 s on ENEMIES; cooldown 28, windup 0.6 | Rolls a powder keg into the fight: every enemy takes 3.5x damage and burns for 5 s. Every 28 s. |
| decoy | Decoy | action, throw | aim SELF, ENEMY_WITHIN 9; SUMMON `decoy` x1, cap 1; cooldown 15, windup 0.3 | Sets a wind-up decoy near the enemy that draws their blows for 10 s. Every 15 s. |
| bear_trap | Bear Trap | action, throw | aim NEAREST_ENEMY, anywhere; DAMAGE x1.0 ignoring armor, then BLEEDING 0.5 of damage and SLOWED 1.5, each for 4 s, on TARGET; cooldown 10, windup 0.3 | Snaps a bear trap on the nearest enemy: 1x damage through armor, then it bleeds and strikes 50% slower for 4 s. Every 10 s. |
| spring_glove | Spring Glove | passive, flourish | LANDS_HIT, chance 0.25; PUSH 1.5 tiles on TARGET | A hit has a 25% chance to punch the enemy 1.5 tiles back. |
| flash_powder | Flash Powder | action, throw | aim SELF, ENEMY_WITHIN 9; STUNNED 1.5 s and WEAKENED 0.75 for 5 s on ENEMIES; cooldown 20, windup 0.4 | A flash: every enemy is stunned for 1.5 s and deals 25% less damage for 5 s. Every 20 s. |
| clockwork_guard | Clockwork Guard | action, channel | aim SELF, ENEMY_WITHIN 9; SUMMON `clockwork_guard` x1, cap 1; cooldown 30, windup 0.6 | Winds up a clockwork guard that walks to the front, draws blows and bashes for 15 s. Every 30 s. |

The machines, each a `SummonDef` inside the ability that brings it (spec 115). Shares are of the
Tinker's numbers when it builds them (at level 14: 141 health, 32 damage).

| Id | Name | Health, damage | Armor, crit | Interval, wind-up, range | Speed, ahead | Seconds | Abilities |
|---|---|---|---|---|---|---|---|
| gun_turret | Gun Turret | 0.6, 0.6 | 3, 0 | 0.8, 0.2, 6.0 | 0, 1.0 | 20 | none |
| flame_turret | Flame Turret | 0.8, 0.5 | 3, 0 | 1.0, 0.2, 3.0 | 0, 2.5 | 12 | `ignite` |
| spark_coil | Spark Coil | 0.6, 0.5 | 2, 0 | 0.6, 0.1, 4.0 | 0, 1.5 | 12 | `overload` |
| siege_cannon | Siege Cannon | 1.5, 1.5 | 5, 0 | 2.0, 0.4, 7.0 | 0, 1.0 | 16 | `meteor` |
| decoy | Decoy | 1.5, 0 | 3, 0 | 1.0, 0.2, 1.0 | 0, 4.0 | 10 | `bulwark` |
| clockwork_guard | Clockwork Guard | 2.0, 1.0 | 6, 0 | 1.2, 0.3, 1.2 | 2.5, 3.0 | 15 | `bulwark`, `shield_bash` |

These differ from the direction, because the engine cannot say what was asked or because a rule
would break:

- **The machines fight with abilities the others already have.** As spec 117's beasts: a summon's
  abilities must be under `data/abilities`, each a node of exactly one tree (spec 109 R1). The
  Flame Turret burns with the Mage's Ignite, the Spark Coil arcs with the Mage's Overload, the Siege
  Cannon shells with the Mage's Meteor, and the Decoy and the Clockwork Guard draw blows with the
  Knight's Bulwark (and the Guard bashes with Shield Bash). Their names over the machines read so.
- **The Decoy taunts with Bulwark, not Taunt.** Taunt waits for two enemies, so a decoy would stand
  idle against a guardian alone; Bulwark taunts once another ally is below 80% (counting heroes
  only, spec 115 as built) and shields the decoy. A decoy never strikes (damage share 0).
- **No trap lies in wait.** Nothing in the engine answers an enemy stepping on a place, so Bear Trap
  is thrown at the nearest enemy, as the Ranger's Snare is.
- **Spring Glove answers the Tinker's hits, not its being hit.** A "when hit" glove fired 0 times in
  53 minutes in the probe: a Tinker at the back is almost never struck.
- **Chain Reaction never fires in R5's fight**, which has one enemy; R6's runs see it (30 to 156
  times).
- **The machines are not drawn as machines.** Spec 116's placeholder creature stands in for every
  summon until Zak draws them.

## Interfaces

No code interface changes. Data only, plus these table rows:

```gdscript
# game/ui/ui_icon.gd: SHEETS gains, after pictures_bard.png
"res://assets/sprites/ui/pictures_tinker.png",
# game/ui/windows/path_colours.gd: COLOURS gains (SHADES gives copper clay and cyan blue;
# brick has no shade and is its own, as the Ranger's tawny and pine are)
&"tinker": [&"copper", &"brick", &"cyan"],
# game/ui/windows/tally_window.gd: CLASS_BARS gains
&"tinker": [&"orange", &"brick"],
# game/dev/showcase.gd
# CLASS_MOMENTS gains &"tinker_actions": &"tinker"; CLASS_PATHS gains &"tinker": 0
```

## Acceptance

In `tests/acceptance/test_119_the_tinker.gd`, one test per requirement named `test_rN_…`, each
written before its data and seen to fail; R6 in `test_119_every_ability_is_seen.gd`. Both use
spec 117's helpers on `ColonyTest` (`stand_in` and those moved from `test_109`).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_class_as_data` | The numbers of the table; it validates; not a starting class; a new game is the four |
| R2 | `test_r2_three_paths_of_five` | Names, summaries and nodes in order, tiers, the rank tables equal the Knight's, the colours |
| R3 | `test_r3_the_abilities_do_what_they_say` | One built battle per ability, checking its events: summons (count, cap, the replaced one, never moving, range kept, the machines' own Ignite, Overload, Meteor, Bulwark and Shield Bash, a decoy that never strikes), damage on whom, statuses on whom and for how long, the radius kept, the push, the kill that sets off Chain Reaction |
| R4 | `test_r4_pictures` | Fifteen pictures and the Wrench's, as spec 117's test |
| R5 | `test_r5_each_path_is_worth_having` | The bare party 0 of 5; each path at least 3 of 5 |
| R6 | `test_r6_every_ability_is_seen` | The nine runs and the full party |
| R7 | `test_r7_on_screen` | Through `make_main()` and the real frame, with the Tinker stood in: the tally bar's colours, the Knight's sheet and picture under the name `Tinker`, a machine drawn with the placeholder sheet; the showcase moment's watcher sees four machines arrive; the specimen's group on the sheet |
| R8 | the recorded-hash tests | Pass, or re-recorded only after a find, as R8 says |
| R9 | the amended suite | Every listed test passes |
| R10 | `test_r10_the_wiki` | The wiki names the Tinker, the Wrench and its three paths |

**To look at, and for Zak:** the picture sheet scene with the Tinker's group; its Talents tab fresh
and full at 1280x720 and `--ui-room=960x540`; the showcase's `tinker_actions` moment (three frames:
the turrets arriving, the coil arcing, the cannon); a fight with the Tinker on Demolition and on
Gadgets. Crop and enlarge small parts 3x, and describe every shot. Do turrets drawn as the
placeholder creature read as the Tinker's machines?

## Tests that change

The files specs 117 and 118 amended, each only for a seventh class and fifteen more abilities:
`test_004_combat_core.gd`, `test_025_microskills_and_side_quests.gd` (its `MICROSKILLS` table: the
Tinker learns Lockpicker at 3), `test_057_lively_moves.gd` (105 abilities),
`test_109_three_paths_of_five.gd` (105), `test_109_every_ability_is_seen.gd` (its `_rescues()`
keeps to the four classes' trees, as 118 left it; the Tinker has no rescue),
`test_063_pictures_and_the_moment.gd`, `test_072_content_table.gd`, `test_078_sim_base_types.gd`,
`test_059_shop_map_and_tally_windows.gd`, `tests/unit/test_hud_talents.gd` (the last five only if
they fail for the added class or abilities), and the recorded-hash tests only as R8 says
(`test_016`, `test_035`, `test_039`, `test_100`, `test_101`).

The lead's whole-suite run on a scratch copy of `dev` holding the Ranger's, the Bard's, the Tinker's
and the Witch Doctor's data had not finished when this spec was drafted: any further test it names
is added here before approval.

A test that fails for any other reason is a bug in the data or the lane's code.

## Out of scope

- A Tinker sheet, machine sheets, sounds, new spell visuals (`SpellEffects.KINDS` gains nothing).
- New aims, conditions, triggers, statuses or summon rules: traps that wait to be stepped on,
  machines the Tinker repairs, machines that stay between fights or grow with ranks.
- Recruiting in the headless run, a Tinker in the starting party, changing any other class.
- The Witch Doctor (spec 120).

## Paths

- `data/heroes/tinker.tres`, `data/talents/tinker.tres`, the fifteen new files under
  `data/abilities/`
- `assets/sprites/ui/pictures_tinker.px` and `assets/sprites/ui/pictures_artifacts.px` (the
  Wrench), with their baked `.png`, `.json` and `.png.import`
- `game/ui/ui_icon.gd` (`SHEETS` only), `game/ui/windows/path_colours.gd`,
  `game/ui/windows/tally_window.gd` (`CLASS_BARS` only), `game/ui/picture_specimen.gd` (to fit a
  seventh group), `game/dev/showcase.gd`, `game/dev/showcase_moments.gd` (and, if a class moment
  would carry it past gdlint's 1000 lines, a new `game/dev/showcase_class_moments.gd` with its
  `.uid` that the class moments move into)
- `tests/acceptance/test_119_the_tinker.gd`, `tests/acceptance/test_119_every_ability_is_seen.gd`
  and their `.uid`s, `tests/colony_test.gd` (only if a helper must take a class it does not), and
  the files in "Tests that change"
- `docs/wiki/index.html`, `docs/style-bible.md` (the cast: the Tinker drawn as the Knight for now)
- `tests/acceptance/test_107_the_quest_story.gd` (only where it counts or lists every class)

## Open questions

None.
