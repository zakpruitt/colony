# 117 — The Ranger: a bow and the beasts of the hollow

- **Status:** draft
- **Milestone:** M9
- **Depends on:** 109, 110, 112, 113, 114, 115, 116 (it needs 112's artifact and request fields and
  115's summons; its Paths share `game/ui/ui_icon.gd` and `pictures_artifacts.px` with 114,
  `game/ui/windows/tally_window.gd` with 116, and the showcase with 114, so it starts once all of
  them have landed). Spec 118, the Bard, shares this spec's Paths and starts after it lands.
- **Pull request:** —

## Intent

Zak chose on 2026-11-27 to grow Colony by classes, every new one a lucky find (spec 112). The
Ranger is the first. A cache down a side path may hold a Ranger's Whistle; a Ranger then waits at
camp until its request is paid, and can go down in place of any of the four. It shoots from the
back of the line and has three paths of five, as every class has since spec 109: Beastcaller fights
beside field mice, a hedgehog, a hawk and an old badger (spec 115's summons); Marksman shoots
through armor, marks and finishes; Trapper snares, nets and drops deadfalls. It is drawn as the
Rogue until Zak draws it, and its beasts with spec 116's placeholder creature.

## Requirements

- **R1. The class, as data.** `data/heroes/ranger.tres`:

  | Field | Value | Why |
  |---|---|---|
  | `role` | `RANGED` | It stands behind the melee, as the Mage does, and is fielded in a Mage's place most often |
  | `max_health`, `health_per_level` | 55, 7 | Between the Mage (45, 6) and the Rogue (60, 8): it stands back but is not a glass cannon. 146 at level 14 |
  | `damage`, `damage_per_level` | 7, 2 | 33 at level 14. Many smaller shots than the Mage's 57: armor takes more of each (the Old Crypt guardian's 6 takes 18%, the Mage's 11%), which is what Marksman answers |
  | `attack_interval`, `windup` | 1.1, 0.3 | About 27 damage a second before armor at level 14, the Mage's is 28.5; a bare Ranger is no stronger than the Mage it replaces (R5 checks it) |
  | `attack_range` | 6.0 | A bow, one tile short of the Mage's 7 |
  | `move_speed` | 3.0 | Lighter on its feet than the 2.5 of the Knight, Mage and Cleric; the Rogue has 3.5 |
  | `crit_chance` | 0.1 | The Mage's |
  | `armor`, `heal_power` | 1, 0 | The Rogue's |
  | `microskills`, `microskill_levels` | `[trapspotter]`, `[4]` | A ranger sees snares; the Rogue learns it at 6. No new microskill: the five cover what a ranger does off the fight, and a sixth needs its own quests (spec 025) |
  | `artifact_name` | `Ranger's Whistle` | |
  | `artifact_picture` | `rangers_whistle` | R4 |
  | `artifact_chance` | 0.08 | Spec 112's suggestion: with the Bard's 0.06, a find within 30 minutes on most seeds |
  | `recruit_gold`, `recruit_resource`, `recruit_resource_count` | 300, `glowcaps`, 40 | Spec 112's example. On seed 1 (`dev.py sim --winding`) the party holds 1813 gold and 304 Glowcaps at 30 minutes with auto-buy off, and 385 gold at 45 with it on |
  | `looks_like` | `rogue` | Hooded and quick; drawn so, it reads apart from the Mage it most often replaces |

  - It passes `HeroClassDef.validate()` and spec 112's checks, and `python tools/dev.py check
    --only=data` passes with it. It is not in `Party.STARTING_CLASSES`: a new game is the four.
- **R2. Three paths of five.** `data/talents/ranger.tres`, in this order, with the same `rank_xp`,
  `tier_ranks` and `uses_counted` as the four trees (spec 110 as built). Nodes are tier 1; tier 2
  left / right; tier 3; tier 4.

  | Path | Summary (at most 60 characters) | T1 | T2 | T3 | T4 |
  |---|---|---|---|---|---|
  | Beastcaller | fights beside mice, a hedgehog and a hawk | field_mice | hedgehog / pack_howl | hawk | call_of_the_wild |
  | Marksman | shoots through armor, marks and finishes foes | aimed_shot | hunters_mark / piercing_arrow | called_shot | arrow_rain |
  | Trapper | snares, nets and thorns that hold foes fast | snare | net_throw / thornfield | bramble_pit | deadfall |

  It passes `TalentTreeDef.validate()`. `PathColours` gives the paths `tawny`, `crimson` and
  `pine` (no state's colour).
- **R3. The fifteen abilities do what they say.** Each is a file under `data/abilities`, built only
  from kinds that exist today (see "The abilities"), passes `AbilityDef.validate()`, and every
  action is `ready_at_start`. In a battle built for it, each does what its description says.
  Examples: Field Mice brings three mice beside the Ranger and a fourth use replaces the oldest;
  the Hedgehog taunts when two enemies stand; the Hawk stuns the nearest enemy as it arrives;
  Call of the Wild's might reaches the badger it brings; Called Shot deals twice as much below 35%
  health; Hunter's Mark lands on the nearest enemy as the fight starts; Bramble Pit holds the
  target and those beside it but not one 2 tiles away.
- **R4. Pictures.** Each of the fifteen has its own 16x16 picture in a new sheet,
  `assets/sprites/ui/pictures_ranger.px`, listed in `UiIcon.SHEETS` after the Cleric's; and the
  Whistle has one, `rangers_whistle`, in `assets/sprites/ui/pictures_artifacts.px` (spec 114's
  sheet). Spec 063 R1 holds for each: the master palette, more than 40 opaque pixels, unlike every
  other picture, baked and linted, and the Ranger's fifteen plainly apart from each other. They may
  be placeholders.
- **R5. Each path is worth having.** Spec 051's fight (a level-14 party against the Old Crypt's
  guardian at level 15, on five battle seeds, `ColonyTest._path_wins`), with the Ranger standing in
  the Mage's place:
  - the bare party (no nodes) wins none of the five;
  - with the Ranger holding one path's five nodes and nothing else, the party wins at least three,
    for each path.
  - Probed on a scratch copy of `dev` with these numbers: bare 0; Beastcaller 5 (each in 36 to
    40 s), Marksman 5 (38 to 45 s), Trapper 5 (49 to 52 s).
- **R6. Every ability is seen.** As spec 109 R8, with the Ranger in the Mage's place from the start:
  - Nine runs: 60 minutes of headless play from level 1 on seeds 1 to 3, winding stages, buying
    upgrades, one run for each path with every hero putting that path first (`TalentSpender`).
    Every action the Ranger has held for ten minutes is used at least five times; every passive it
    has held that long fires at least once. The Ranger has no rescue: none is excused.
  - The level-30 party with all fifteen nodes each (spec 109 R8's `_full_party`, with the Ranger in
    the Mage's place), 30 minutes from Mossy Hollow stage 18: every Ranger action used five times
    and every passive fired.
  - Probed: in the nine runs no party wiped, each reached stage 12, and the fewest uses of an
    action held ten minutes were the Hawk's 5 in 12 minutes (seed 1, Marksman first), then Called
    Shot's 7 in 11; Piercing Arrow fired 25 to 114 times. In the full party's play every action was
    used 12 or 13 times. The lane may tune a number that falls short (the Hawk's cooldown first)
    and lists each change.
- **R7. The Ranger on screen.**
  - Its tally bar is `forest` over `pine` (`TallyWindow.CLASS_BARS`), and its numbers and its
    beasts' are drawn in that colour (spec 116 R2 reads it).
  - It is drawn as the Rogue in the world, the frames, the hero window and the tally (spec 113 R6),
    under its own name. Its beasts are drawn with spec 116's placeholder sheet: no creature sheet
    is added.
  - The showcase gains a moment, `ranger_actions`, in `Showcase.CLASS_MOMENTS`, with
    `CLASS_PATHS` giving it Beastcaller: the Ranger stands in for the Mage (as the showcase's
    stand-in Cleric does), holding Beastcaller's five nodes, and the mice, the hedgehog, the hawk
    and the badger are seen to arrive and fight. This is the summons' moment spec 116 left to the
    first class with one.
  - The picture sheet scene (`PictureSpecimen`) shows the Ranger's group after the Cleric's, wholly
    on the sheet at its room (spec 063 R9).
- **R8. The headless run and the recorded runs.**
  - `dev.py sim` does not recruit (spec 112), so its summaries are unchanged.
  - From now on a cache may find the Whistle, and spec 112 R7 puts a find in the state hash. A
    recorded-hash test whose run opens a cache can change from the step of the find. The lane runs
    every recorded-hash test (`test_016`, `test_035`, `test_039`, `test_100`, `test_101`). For one
    that fails, it shows in the pull request that the first differing hash comes after an
    `ARTIFACT_FOUND` in that run, and only then records the new hashes, with a comment saying the
    run finds the Ranger's Whistle. A difference before any find is a bug.
- **R9. The old tests follow.** Tests that count or list every class or every ability are amended
  for a fifth class, and no others. The list was found by running the whole suite on a scratch copy
  of `dev` holding both the Ranger's and the Bard's data (see "Tests that change"). Each change, and what still guards
  the behaviour, is listed in the pull request.
- **R10. The wiki.** `docs/wiki/index.html` gains the Ranger in its classes: how it is found, its
  price, its three paths in a line each.

## The abilities

Every one uses only aims, conditions, triggers, effects and statuses that exist today, and
spec 115's `SUMMON`. Self-aimed actions wait for an enemy within 9 tiles (`ENEMY_WITHIN`), so a
summon or a volley is not spent before the fight has someone in it. The numbers are the probed
ones; the lane may tune them for R5 and R6 and lists each change.

| Id | Name | Kind, move | How it is built | Description |
|---|---|---|---|---|
| field_mice | Field Mice | action, shout | aim SELF, ENEMY_WITHIN 9; SUMMON `field_mouse` x3, cap 3; cooldown 12, windup 0.3 | Whistles up three field mice that nip at the nearest enemy for 8 s. Every 12 s. |
| hedgehog | Hedgehog | action, shout | aim SELF, ENEMY_WITHIN 9; SUMMON `hedgehog` x1, cap 1; cooldown 16, windup 0.3 | Calls a hedgehog that taunts the enemies near it for 10 s. Every 16 s. |
| pack_howl | Pack Howl | passive, shout | KILLS; MIGHTY 1.3 for 5 s on ALLIES | On a kill, every ally and beast deals 30% more damage for 5 s. |
| hawk | Hawk | action, throw | aim SELF, ENEMY_WITHIN 9; SUMMON `hawk` x1, cap 1; cooldown 18, windup 0.3 | Sends a hawk that stuns the nearest enemy as it comes and strikes from the air for 12 s. Every 18 s. |
| call_of_the_wild | Call of the Wild | action, channel | aim SELF, ENEMY_WITHIN 9; SUMMON `old_badger` x1, cap 1; then MIGHTY 1.25 for 8 s on ALLIES; cooldown 30, windup 0.5 | An old badger joins the fight for 15 s, and every ally and beast deals 25% more damage for 8 s. Every 30 s. |
| aimed_shot | Aimed Shot | action, heavy_swing | aim NEAREST_ENEMY, reach 6; DAMAGE x2.5 ignoring armor on TARGET; cooldown 6, windup 0.5 | Shoots the nearest enemy for 2.5x damage through its armor. Every 6 s. |
| hunters_mark | Hunter's Mark | passive, flourish | FIGHT_STARTS; MARKED 1.4 for 12 s on NEAREST_ENEMY | As a fight starts, the nearest enemy is marked: it takes 40% more damage for 12 s. |
| piercing_arrow | Piercing Arrow | passive, flourish | LANDS_HIT, chance 0.4; DAMAGE x0.8 ignoring armor on AROUND_TARGET radius 1.5 | A hit has a 40% chance to pierce: 0.8x damage through armor to the target and those beside it. |
| called_shot | Called Shot | action, heavy_swing | aim WEAKEST_ENEMY, reach 6; DAMAGE x2.5, low_health_below 0.35, low_multiplier 2.0, on TARGET; cooldown 9, windup 0.5 | Shoots the weakest enemy for 2.5x damage, 5x below 35% health. Every 9 s. |
| arrow_rain | Arrow Rain | action, channel | aim SELF, ENEMY_WITHIN 9; DAMAGE x2.0 ignoring armor on ENEMIES; cooldown 20, windup 0.6 | Arrows fall on every enemy: 2x damage through armor. Every 20 s. |
| snare | Snare | action, throw | aim NEAREST_ENEMY, anywhere; DAMAGE x0.8 and STUNNED 1.5 s on TARGET; cooldown 9, windup 0.3 | Throws a snare at the nearest enemy: 0.8x damage and held fast (stunned) for 1.5 s. Every 9 s. |
| net_throw | Net Throw | action, throw | aim FURTHEST_ENEMY, anywhere; SLOWED 1.6 for 5 s on AROUND_TARGET radius 1.5; cooldown 12, windup 0.3 | Nets the furthest enemy and those beside it: they strike 60% slower for 5 s. Every 12 s. |
| thornfield | Thornfield | passive, flourish | FIGHT_STARTS; BLEEDING 0.5 of damage for 6 s on ENEMIES | As a fight starts, thorns spring up: every enemy bleeds for 6 s. |
| bramble_pit | Bramble Pit | action, throw | aim NEAREST_ENEMY, anywhere; STUNNED 2 s and BLEEDING 0.6 of damage for 4 s on AROUND_TARGET radius 1.5; cooldown 16, windup 0.4 | A bramble pit under the nearest enemy: it and those beside it are held for 2 s and bleed for 4 s. Every 16 s. |
| deadfall | Deadfall | action, channel | aim NEAREST_ENEMY, anywhere; DAMAGE x3.0 and STUNNED 2 s on AROUND_TARGET radius 2; cooldown 25, windup 0.6 | Drops a deadfall on the nearest enemy: 3x damage to it and those beside it, stunned for 2 s. Every 25 s. |

The beasts, each a `SummonDef` inside the ability that brings it (spec 115). Shares are of the
Ranger's numbers when it calls them.

| Id | Name | Health, damage | Armor, crit | Interval, wind-up, range | Speed, ahead | Seconds | Abilities |
|---|---|---|---|---|---|---|---|
| field_mouse | Field Mouse | 0.15, 0.3 | 0, 0 | 0.7, 0.1, 1.0 | 4.5, 2.0 | 8 | none |
| hedgehog | Hedgehog | 1.0, 0.3 | 4, 0 | 1.4, 0.3, 1.0 | 2.5, 3.0 | 10 | `taunt` |
| hawk | Hawk | 0.3, 0.7 | 0, 0.15 | 1.0, 0.2, 4.0 | 5.0, 2.0 | 12 | `ambush` |
| old_badger | Old Badger | 1.2, 1.0 | 4, 0 | 1.3, 0.3, 1.2 | 2.5, 3.0 | 15 | `whirlwind` |

These differ from the direction, because the engine cannot say what was asked or because a rule
would break:

- **The beasts fight with abilities the four already have.** A summon's abilities must be under
  `data/abilities` (spec 115), and spec 109 R1 holds every ability there to be a node of exactly one
  tree. A beast-only ability would need that rule changed. So the Hedgehog taunts with the Knight's
  Taunt (only when two enemies stand), the Hawk stuns with the Rogue's Ambush (a summon's
  fight-start passives answer its arrival, spec 115 as built) and the Badger spins with the
  Knight's Whirlwind. Their names over the beasts read `Taunt`, `Ambush`, `Whirlwind`.
- **Snares stun.** There is no root (held in place, still striking); Snare, Bramble Pit and
  Deadfall hold a foe with `STUNNED`.
- **Arrow Rain does not mark.** A second `MARKED` restarts the first's time at the stronger amount
  (`BattleStatuses.apply`), so a short mark from Arrow Rain cut Hunter's Mark from 12 s to 5 s in
  the probe. Arrow Rain deals damage through armor instead.
- **Piercing Arrow answers any hit, not every third shot.** With five actions and a plain swing
  after each (spec 109 R4), the Ranger rarely made three plain shots in a fight, and an
  every-third-strike passive fired 0 times in 21 minutes in the probe.

## Interfaces

No code interface changes. Data only, plus these table rows:

```gdscript
# game/ui/ui_icon.gd: SHEETS gains, after pictures_cleric.png
"res://assets/sprites/ui/pictures_ranger.png",
# game/ui/windows/path_colours.gd: COLOURS gains
&"ranger": [&"tawny", &"crimson", &"pine"],
# game/ui/windows/tally_window.gd: CLASS_BARS gains
&"ranger": [&"forest", &"pine"],
# game/dev/showcase.gd
# CLASS_MOMENTS gains &"ranger_actions": &"ranger"; CLASS_PATHS gains &"ranger": 0
```

## Acceptance

In `tests/acceptance/test_117_the_ranger.gd`, one test per requirement named `test_rN_…`, each
written before its data and seen to fail. R6 goes in its own script,
`test_117_every_ability_is_seen.gd`, as spec 109's did. The Ranger stands in the Mage's place by a
helper on `ColonyTest` (`stand_in(party, class_id, place)`: a hero of that class with the place's
id and the party's upgrades; spec 118 uses it too). Where `test_109`'s helpers serve (`_full_party`,
`_play_and_count`, `_unseen_of`), they move to `ColonyTest` or a test base rather than being copied.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_class_as_data` | The numbers of the table; it validates; not a starting class; a new game is the four; a broken artifact chance and a `looks_like` of `no_such_class` are refused by name |
| R2 | `test_r2_three_paths_of_five` | Names, summaries and nodes in order, tiers, the rank tables equal the Knight's, the colours |
| R3 | `test_r3_the_abilities_do_what_they_say` | One built battle per ability, checking its events: summons (count, cap, the replaced one, the beasts' own Taunt, Ambush and Whirlwind), damage through armor, the low-health bonus, statuses on whom and for how long, the radius kept |
| R4 | `test_r4_pictures` | Fifteen pictures and the Whistle's: 16x16, over 40 opaque pixels, in the palette, unlike any other, the Ranger's apart from each other |
| R5 | `test_r5_each_path_is_worth_having` | The bare party 0 of 5; each path at least 3 of 5 |
| R6 | `test_r6_every_ability_is_seen` | The nine runs and the full party |
| R7 | `test_r7_on_screen` | Through `make_main()` and the real frame, with the Ranger stood in: the tally bar's colours, the Rogue's sheet and picture under the name `Ranger`, a summon's sprite with the placeholder sheet; the showcase moment's watcher sees four beasts arrive; the specimen's group on the sheet |
| R8 | the recorded-hash tests | Pass, or re-recorded only after a find, as R8 says |
| R9 | the amended suite | Every listed test passes |
| R10 | `test_r10_the_wiki` | The wiki names the Ranger, the Whistle and its three paths |

**To look at, and for Zak:** the picture sheet scene with the Ranger's group; the Ranger's Talents
tab fresh and full at 1280x720 and `--ui-room=960x540`; the showcase's `ranger_actions` moment
(three frames: mice and hedgehog arriving, the hawk, the badger); a fight with the Ranger on
Marksman and on Trapper. Crop and enlarge small parts 3x, and describe every shot. Does a Ranger
drawn as the Rogue read apart in a fight?

## Tests that change

These count or list every class or every ability, or name the four as all there are. Each may
change only for a fifth class and its fifteen abilities.

- `tests/acceptance/test_004_combat_core.gd` (R1: "four hero classes" becomes the four starting
  classes, each checked by role as today, among all classes)
- `tests/acceptance/test_025_microskills_and_side_quests.gd` (its `MICROSKILLS` table: the Ranger
  learns Trapspotter at 4)
- `tests/acceptance/test_057_lively_moves.gd` (its count of 60 abilities becomes 75)
- `tests/acceptance/test_109_three_paths_of_five.gd` (R1: 75 abilities; "a node of exactly one
  tree" counts every class's tree, not only the four; its `CLASSES` and `PATHS` stay the four's)
- `tests/acceptance/test_063_pictures_and_the_moment.gd` (only if the specimen's groups or a count
  of pictures name the four)
- `tests/acceptance/test_078_sim_base_types.gd` (R3's mixed fights draw random abilities, so they
  now bring summons; its reference picks of nearest, weakest and furthest look only at
  `battle.heroes` and must take in `battle.summons` too, as spec 115 R3 has monsters aim at them.
  In the probe it failed exactly so: `fighter 101 aim 1: 50, not 3`)
- `tests/acceptance/test_072_content_table.gd`, `test_059_shop_map_and_tally_windows.gd`,
  `tests/unit/test_hud_talents.gd` (only if they fail for the added class or abilities; with both
  new classes added in the probe they passed)
- The recorded-hash tests, only as R8 says: `test_016_camp_upgrades.gd`, `test_035_party_orders.gd`,
  `test_039_the_countdown.gd`, `test_100_rooms_shaped_like_caves.gd`,
  `test_101_what_stands_in_a_cave.gd`

A test that fails for any other reason is a bug in the data or the lane's code.

## Out of scope

- A Ranger sheet, beast sheets, sounds, new spell visuals (`SpellEffects.KINDS` gains nothing: its
  shots show their move, name and statuses, as the Knight's physical abilities do).
- New aims, conditions, triggers, statuses or summon rules; abilities only a beast has; beasts that
  grow with ranks or stay between fights.
- Recruiting in the headless run, a Ranger in the starting party, changing any of the four classes.
- The Bard (spec 118), the Tinker and the Witch Doctor.

## Paths

- `data/heroes/ranger.tres`, `data/talents/ranger.tres`, the fifteen new files under
  `data/abilities/`
- `assets/sprites/ui/pictures_ranger.px` and `assets/sprites/ui/pictures_artifacts.px` (the Whistle),
  with their baked `.png`, `.json` and `.png.import`
- `game/ui/ui_icon.gd` (`SHEETS` only), `game/ui/windows/path_colours.gd`,
  `game/ui/windows/tally_window.gd` (`CLASS_BARS` only), `game/ui/picture_specimen.gd` (to fit a
  fifth group: with six groups in the probe, the Rogue's pictures fell off the sheet at its room), `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_117_the_ranger.gd`, `tests/acceptance/test_117_every_ability_is_seen.gd`
  and their `.uid`s, `tests/colony_test.gd` (`stand_in` and the helpers moved from `test_109`),
  `tests/acceptance/test_109_every_ability_is_seen.gd` (only to use the moved helpers), and the
  files in "Tests that change"
- `docs/wiki/index.html`, `docs/style-bible.md` (the cast: the Ranger drawn as the Rogue for now)

## Open questions

None.
