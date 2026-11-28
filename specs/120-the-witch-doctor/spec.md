# 120 — The Witch Doctor: hexes, totems and cold spirits

- **Status:** approved (2026-11-27)
- **Milestone:** M9
- **Depends on:** 109, 110, 112, 113, 114, 115, 116, 117, 118, 119 (it needs 112's artifact and
  request fields and 115's summons; its Paths share `game/ui/ui_icon.gd`, `pictures_artifacts.px`,
  the colour tables, the picture sheet scene, the showcase and the counting tests with specs 117
  to 119, so it starts once 119 has landed and builds on 117's helpers)
- **Pull request:** —

## Intent

The fourth and rarest class found by luck (spec 112). A cache may, rarely, hold a Witch Doctor's
Mask; a Witch Doctor then waits at camp until its request is paid. It is a healer of a stranger
kind, and goes down in a Cleric's place: Hexer lays hexes that mark, weaken and slow every foe;
Totems plants totems that mend, hex, ward and rouse the party (spec 115's summons, most of them
pure auras that never strike); Spirits sends cold spirits that chill foes and drain their life
into the party. Zak's direction: flavourful, never best in slot, about 10% under the others in the
path fight. Three paths of five, as every class has since spec 109. It is drawn as the Mage until
Zak draws it, and its totems with spec 116's placeholder creature.

## Requirements

- **R1. The class, as data.** `data/heroes/witch_doctor.tres`:

  | Field | Value | Why |
  |---|---|---|
  | `role` | `HEALER` | Its ordinary swing heals the most hurt ally, as the Cleric's does, and it is fielded in a Cleric's place. A healer holds back every action aimed at an enemy while an ally is hurt (`BattleAbilities.ready_action`), so every Witch Doctor action is aimed at itself and lands on the nearest enemy, every enemy or every ally (see "The abilities") |
  | `max_health`, `health_per_level` | 60, 9 | Under the Cleric's 70, 10. 177 at level 14 (the Cleric 200) |
  | `damage`, `damage_per_level` | 3, 1 | The Cleric's. 16 at level 14: what hurts comes from its healing power, as the Cleric's Holy Fire does |
  | `attack_interval`, `windup` | 1.2, 0.4 | The Cleric's |
  | `attack_range`, `move_speed` | 6.0, 2.5 | The Cleric's |
  | `armor`, `crit_chance` | 1, 0.05 | The Cleric's |
  | `heal_power` | 16 | Under three quarters of the Cleric's 22: a weaker mender, whose worth is in its hexes, totems and spirits. It also sizes its chills, its drains and its totems' mending |
  | `microskills`, `microskill_levels` | `[mender]`, `[4]` | A witch doctor knows herbs and keeps the Cleric's microskill when it goes down in the Cleric's place (the Cleric learns it at 3). No new microskill (spec 025) |
  | `artifact_name` | `Witch Doctor's Mask` | |
  | `artifact_picture` | `witch_doctors_mask` | R4 |
  | `artifact_chance` | 0.02 | Spec 112's suggestion: the rarest find |
  | `recruit_gold`, `recruit_resource`, `recruit_resource_count` | 1200, `embers`, 25 | The dearest request, and Ember Deep's embers, the last area's resource: each class asks for the next area's (Ranger Glowcaps, Bard clay, Tinker old bones). Not measured (the headless run never leaves Mossy Hollow): tunable data |
  | `looks_like` | `mage` | Robed, with a staff; drawn so, it reads apart from the Cleric it most often replaces. The Knight, the Rogue and the Cleric are the Tinker's, the Ranger's and the Bard's |

  - It passes `HeroClassDef.validate()` and spec 112's checks, and `python tools/dev.py check
    --only=data` passes with it. It is not in `Party.STARTING_CLASSES`.
- **R2. Three paths of five.** `data/talents/witch_doctor.tres`, in this order, with the four trees'
  `rank_xp`, `tier_ranks` and `uses_counted`. Nodes are tier 1; tier 2 left / right; tier 3; tier 4.

  | Path | Summary (at most 60 characters) | T1 | T2 | T3 | T4 |
  |---|---|---|---|---|---|
  | Hexer | hexes that spread marks and weakness | hex | spreading_curse / evil_eye | voodoo_doll | doom |
  | Totems | totems that heal, hex and ward | healing_totem | hex_totem / ward_totem | war_totem | great_totem |
  | Spirits | cold spirits that chill foes and drain life | chilling_spirit | drain_life / restless_dead | soul_harvest | spirit_storm |

  It passes `TalentTreeDef.validate()`. `PathColours` gives the paths `orchid`, `tan` and `cyan`.
- **R3. The fifteen abilities do what they say.** Each is a file under `data/abilities`, built only
  from kinds that exist today (see "The abilities"), passes `AbilityDef.validate()`, and every
  action is `ready_at_start`. In a battle built for it, each does what its description says.
  Examples: Hex is used while an ally is below 80% (a healer's self-aimed action is not held back)
  and both its statuses land on the nearest enemy only; Doom's three statuses land on every enemy;
  Evil Eye slows the nearest enemy as the fight starts; the Healing Totem never strikes and mends
  the weakest hurt ally (its Renewal) with its own healing power, 0.8 of the Witch Doctor's; the Hex
  Totem's Hallowed Ground weakens every enemy as it arrives; the Ward Totem shields the weakest ally
  (its Aegis); the Great Totem's Blessing and Hallowed Ground answer its arrival and its Prayer
  waits for an ally below 80%; Voodoo Doll's damage is 1.5x the healing power through armor; Drain
  Life heals the Witch Doctor by what it dealt and every ally by the healing power; Restless Dead's
  chill ticks at half the healing power a second.
- **R4. Pictures.** Each of the fifteen has its own 16x16 picture in a new sheet,
  `assets/sprites/ui/pictures_witch_doctor.px`, listed in `UiIcon.SHEETS` after the Tinker's; and
  the Mask has one, `witch_doctors_mask`, in `assets/sprites/ui/pictures_artifacts.px`. Spec 063 R1
  holds for each, as spec 117 R4 has it. They may be placeholders.
- **R5. Each path is worth having, and none is the best.** Spec 051's fight, with the Witch Doctor
  standing in the Cleric's place (spec 117's `ColonyTest.stand_in`):
  - the bare party wins none of five;
  - with the Witch Doctor holding one path's five nodes and nothing else, the party wins at least
    three, for each path;
  - never best in slot: its three paths together win no more of their fifteen fights than the
    Cleric's three paths win of theirs (the Cleric in its own place, holding one path each), and
    their mean time to a win is longer than the Cleric's.
  - Probed on a scratch copy of `dev` with these numbers (and the Ranger's, the Bard's and the
    Tinker's data): bare 0 (the party falls at 41 to 59 s); Hexer 5 (45 to 51 s), Totems 5 (51 to
    63 s), Spirits 4 (49 to 72 s): 14 of 15, a mean win in 52.7 s. The Cleric's Lifebinder,
    Sunpriest and Warden win 5, 5 and 5 (mean 53.0, 44.8, 52.9 s): 15 of 15, a mean win in 50.2 s.
    So the Witch Doctor wins one fight fewer and about 5% slower, about 10% under in all. The lane
    may tune toward that, and lists each change.
- **R6. Every ability is seen.** As spec 117 R6, with the Witch Doctor in the Cleric's place:
  - The nine 60-minute runs: every action held ten minutes used at least five times, every passive
    fired. The Witch Doctor has no rescue (no action of its waits for a hurt ally): none is excused.
  - The level-30 party with all fifteen nodes each, 30 minutes from Mossy Hollow stage 18: every
    Witch Doctor action used five times and every passive fired.
  - Probed: no run wiped and each reached stage 12; the fewest uses of an action held ten minutes
    were the War Totem's 5 in 12 minutes (seed 1, Hexer first) and Voodoo Doll's 5 in 13 (seed 1,
    Totems first); Evil Eye fired 89 to 155 times and Restless Dead 144 to 162. In the full party's
    play every action was used 11 or 12 times. The lane may tune a number that falls short (those
    two cooldowns first) and lists each change.
- **R7. The Witch Doctor on screen.**
  - Its tally bar is `tan` over `clay` (`TallyWindow.CLASS_BARS`), and its numbers and its totems'
    are drawn in that colour (spec 116 R2 reads it).
  - It is drawn as the Mage in the world, the frames, the hero window and the tally (spec 113 R6),
    under its own name. Its totems are drawn with spec 116's placeholder sheet: no summon sheet is
    added.
  - Its hexes and spirits show their move, their name and their statuses, as the Knight's shouts
    do. `SpellEffects.KINDS` gains nothing.
  - The showcase gains `witch_doctor_actions` in `Showcase.CLASS_MOMENTS`, `CLASS_PATHS` giving it
    Totems: the Witch Doctor stands in for the Cleric (as the showcase's stand-in Cleric does),
    holding Totems' five nodes, and the five totems are seen to arrive and their statuses on the
    heroes and the monsters.
  - The picture sheet scene shows the Witch Doctor's group after the Tinker's, wholly on the sheet.
- **R8. The recorded runs.** As spec 117 R8: a recorded-hash test may change only from the step a
  cache finds the Mask, shown in the pull request, and is then re-recorded with a comment saying so.
- **R9. The old tests follow.** The tests specs 117 to 119 amended for a fifth to seventh class are
  amended for an eighth (120 abilities), and no others (see "Tests that change").
- **R10. The wiki.** `docs/wiki/index.html` gains the Witch Doctor beside the other three found
  classes: how it is found (and that it is the rarest), its price, its three paths in a line each.

## The abilities

Every one uses only aims, conditions, triggers, effects and statuses that exist today, and
spec 115's `SUMMON`. Every action is aimed at the Witch Doctor itself and waits for an enemy within
9 tiles (`ENEMY_WITHIN`); what lands on one foe lands on `NEAREST_ENEMY`. Healing power is 16; the
numbers are the probed ones; the lane may tune them for R5 and R6 and lists each change.

| Id | Name | Kind, move | How it is built | Description |
|---|---|---|---|---|
| hex | Hex | action, cast | MARKED 1.15 and WEAKENED 0.8, each for 6 s, on NEAREST_ENEMY; cooldown 10, windup 0.3 | Hexes the nearest enemy: it takes 15% more damage and deals 20% less for 6 s. Every 10 s. |
| spreading_curse | Spreading Curse | action, channel | MARKED 1.2 for 6 s on ENEMIES; cooldown 16, windup 0.4 | The curse spreads: every enemy takes 20% more damage for 6 s. Every 16 s. |
| evil_eye | Evil Eye | passive, flourish | FIGHT_STARTS; SLOWED 1.3 for 10 s on NEAREST_ENEMY | As a fight starts, the evil eye falls on the nearest enemy: it strikes 30% slower for 10 s. |
| voodoo_doll | Voodoo Doll | action, cast | DAMAGE x1.5 from healing power, ignoring armor, and STUNNED 1 s on NEAREST_ENEMY; cooldown 14, windup 0.4 | Pricks a voodoo doll: the nearest enemy takes 1.5x the healing power through its armor and is stunned for 1 s. Every 14 s. |
| doom | Doom | action, channel | MARKED 1.3, WEAKENED 0.6 and SLOWED 1.4, each for 8 s, on ENEMIES; cooldown 30, windup 0.6 | Every enemy is doomed: it takes 30% more damage, deals 40% less and strikes 40% slower for 8 s. Every 30 s. |
| healing_totem | Healing Totem | action, prayer | SUMMON `healing_totem` x1, cap 1; cooldown 15, windup 0.4 | Plants a healing totem that mends the weakest hurt ally for 15 s. Every 15 s. |
| hex_totem | Hex Totem | action, prayer | SUMMON `hex_totem` x1, cap 1; cooldown 22, windup 0.4 | Plants a hex totem: as it lands, every enemy deals 20% less damage for 10 s. Every 22 s. |
| ward_totem | Ward Totem | action, prayer | SUMMON `ward_totem` x1, cap 1; cooldown 20, windup 0.4 | Plants a ward totem that shields the weakest ally every 10 s, for 15 s. Every 20 s. |
| war_totem | War Totem | action, prayer | SUMMON `war_totem` x1, cap 1; cooldown 25, windup 0.4 | Plants a war totem: as it lands, every ally strikes 15% faster for 10 s. Every 25 s. |
| great_totem | Great Totem | action, channel | SUMMON `great_totem` x1, cap 1; cooldown 35, windup 0.6 | Raises a great totem for 20 s: every ally mends, every enemy deals 20% less, and it heals the hurt. Every 35 s. |
| chilling_spirit | Chilling Spirit | action, cast | CHILLED 0.6 of healing power and SLOWED 1.3, each for 6 s, on NEAREST_ENEMY; cooldown 10, windup 0.3 | A cold spirit seizes the nearest enemy: chilled and striking 30% slower for 6 s. Every 10 s. |
| drain_life | Drain Life | action, channel | DAMAGE x1.5 from healing power, life_steal 1.0, on NEAREST_ENEMY; HEAL 1.0 of healing power on ALLIES; cooldown 9, windup 0.4 | Drains the nearest enemy for 1.5x the healing power, healing itself by as much and every ally by the healing power. Every 9 s. |
| restless_dead | Restless Dead | passive, flourish | FIGHT_STARTS; CHILLED 0.5 of healing power for 8 s on ENEMIES | As a fight starts, cold spirits gather: every enemy is chilled for 8 s. |
| soul_harvest | Soul Harvest | action, channel | DAMAGE x1.0 from healing power, ignoring armor, on ENEMIES; MENDING 0.5 of healing power for 6 s on ALLIES; cooldown 16, windup 0.5 | Every enemy takes the healing power through its armor, and every ally mends for 6 s. Every 16 s. |
| spirit_storm | Spirit Storm | action, channel | CHILLED 0.6 of healing power and SLOWED 1.5, each for 8 s, on ENEMIES; HEAL 1.5 of healing power on ALLIES; cooldown 28, windup 0.6 | A storm of spirits: every enemy is chilled and strikes 50% slower for 8 s, and every ally heals by 1.5x the healing power. Every 28 s. |

The totems, each a `SummonDef` inside the ability that plants it (spec 115). None moves (speed 0)
and none strikes (damage share 0, spec 115 as built: a pure aura acting only through its
abilities); each has interval 1.2, wind-up 0.2 and range 1.0, which only a striker uses. Shares are
of the Witch Doctor's numbers when it plants them (at level 14: 177 health, healing power 16).

| Id | Name | Health, healing | Armor | Ahead | Seconds | Abilities |
|---|---|---|---|---|---|---|
| healing_totem | Healing Totem | 0.6, 0.8 | 2 | 0.5 | 15 | `renewal` |
| hex_totem | Hex Totem | 0.6, 0 | 2 | 1.5 | 15 | `hallowed_ground` |
| ward_totem | Ward Totem | 0.6, 0 | 2 | 0.5 | 15 | `aegis` |
| war_totem | War Totem | 0.6, 0 | 2 | 1.0 | 15 | `war_banner` |
| great_totem | Great Totem | 1.5, 1.0 | 4 | 1.0 | 20 | `blessing`, `hallowed_ground`, `prayer` |

These differ from the direction, or settle what it left open:

- **A healer whose every action is aimed at itself.** Aimed at an enemy, a hex would wait while any
  ally stood below 80%, which in a hard fight is most of it. Aimed at itself with its effects on
  `NEAREST_ENEMY` or `ENEMIES`, it is never held back.
- **The totems fight with abilities the others already have.** As spec 117's beasts: the Cleric's
  Renewal, Hallowed Ground, Aegis, Blessing and Prayer, and the Knight's War Banner. Their names over
  the totems read so. A totem's fight-start passive answers its arrival (spec 115 as built), so the
  Hex Totem, the War Totem and the Great Totem act as they are planted and then stand as targets
  the monsters may strike.
- **Hexes do not spread from foe to foe.** No trigger answers a hexed foe's death or a status
  landing; Spreading Curse spreads by landing on every enemy. A second mark of one kind does not add
  to the first (the stronger is kept, `BattleStatuses.apply`), so Hex's 15% under Spreading Curse's
  20% or Doom's 30% adds nothing: the tooltips say no more than each does.
- **Draining is life steal.** No status drains; Drain Life is damage with `life_steal` 1.0 and a heal
  on every ally, and Soul Harvest mends.
- **Chill is measured in healing power.** The Witch Doctor's own damage is 16 at level 14, so its
  chills and drains are sized by its healing power (`scale` FIGHTER_HEALING, `damage_from_healing`),
  as the Cleric's Holy Fire and Wrath are.
- **"About 10% under" is R5's third bullet.** The probe's way of reading it: against the Cleric in
  its own place, one fight fewer of fifteen and a win about 5% slower.

## Interfaces

No code interface changes. Data only, plus these table rows:

```gdscript
# game/ui/ui_icon.gd: SHEETS gains, after pictures_tinker.png
"res://assets/sprites/ui/pictures_witch_doctor.png",
# game/ui/windows/path_colours.gd: COLOURS gains
&"witch_doctor": [&"orchid", &"tan", &"cyan"],
# game/ui/windows/tally_window.gd: CLASS_BARS gains
&"witch_doctor": [&"tan", &"clay"],
# game/dev/showcase.gd
# CLASS_MOMENTS gains &"witch_doctor_actions": &"witch_doctor"; CLASS_PATHS gains &"witch_doctor": 1
```

## Acceptance

In `tests/acceptance/test_120_the_witch_doctor.gd`, one test per requirement named `test_rN_…`,
each written before its data and seen to fail; R6 in `test_120_every_ability_is_seen.gd`. Both use
spec 117's helpers on `ColonyTest` (`stand_in` and those moved from `test_109`), with the Cleric's
place.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_class_as_data` | The numbers of the table; it validates; not a starting class; a new game is the four |
| R2 | `test_r2_three_paths_of_five` | Names, summaries and nodes in order, tiers, the rank tables, the colours |
| R3 | `test_r3_the_abilities_do_what_they_say` | One built battle per ability, checking its events: an action used while an ally is hurt; statuses on whom and for how long; damage from healing power through armor; the life stolen and the heals; summons that never move or strike, their own Renewal, Hallowed Ground, Aegis, War Banner, Blessing and Prayer, and a totem's healing power its share |
| R4 | `test_r4_pictures` | Fifteen pictures and the Mask's, as spec 117's test |
| R5 | `test_r5_each_path_is_worth_having` | The bare party 0 of 5; each path at least 3 of 5; the fifteen fights against the Cleric's fifteen, wins and mean time |
| R6 | `test_r6_every_ability_is_seen` | The nine runs and the full party |
| R7 | `test_r7_on_screen` | Through `make_main()` and the real frame: the tally bar's colours, the Mage's sheet and picture under the name `Witch Doctor`, a totem drawn with the placeholder sheet; the showcase moment's watcher sees five totems arrive and their statuses; the specimen's group |
| R8 | the recorded-hash tests | As spec 117 R8 |
| R9 | the amended suite | Every listed test passes |
| R10 | `test_r10_the_wiki` | The wiki names the Witch Doctor, the Mask and its three paths |

**To look at, and for Zak:** the picture sheet scene with the Witch Doctor's group; its Talents tab
fresh and full at 1280x720 and `--ui-room=960x540`; the showcase's `witch_doctor_actions` moment;
a fight with the Witch Doctor on Hexer and on Spirits. Describe every shot. Do totems drawn as the
placeholder creature read as totems?

## Tests that change

The files specs 117 to 119 amended, each only for an eighth class and fifteen more abilities:
`test_004_combat_core.gd`, `test_025_microskills_and_side_quests.gd` (the Witch Doctor learns
Mender at 4), `test_057_lively_moves.gd` (120 abilities), `test_109_three_paths_of_five.gd` (120),
`test_109_every_ability_is_seen.gd` (its `_rescues()` keeps to the four classes' trees; the Witch
Doctor's actions wait for no hurt ally, though its totems' Renewal and Prayer do: they are summons'
uses, not a hero's), `test_063_pictures_and_the_moment.gd`, `test_072_content_table.gd`,
`test_078_sim_base_types.gd`, `test_059_shop_map_and_tally_windows.gd`,
`tests/unit/test_hud_talents.gd` (the last five only if they fail for the added class or
abilities), and the recorded-hash tests only as R8 says (`test_016`, `test_035`, `test_039`,
`test_100`, `test_101`).

The lead's whole-suite run on a scratch copy of `dev` holding the Ranger's, the Bard's, the Tinker's
and the Witch Doctor's data had not finished when this spec was drafted: any further test it names
is added here before approval.

A test that fails for any other reason is a bug in the data or the lane's code.

## Out of scope

- A Witch Doctor sheet, totem sheets, sounds, hex or spirit visuals (`SpellEffects.KINDS` gains
  nothing).
- New aims, conditions, triggers or statuses: hexes that jump from a dying foe, a status that
  drains, stacking marks, totems that stay between fights or grow with ranks.
- Recruiting in the headless run, changing any other class, making the Witch Doctor stronger than
  R5 allows.

## Paths

- `data/heroes/witch_doctor.tres`, `data/talents/witch_doctor.tres`, the fifteen new files under
  `data/abilities/`
- `assets/sprites/ui/pictures_witch_doctor.px` and `assets/sprites/ui/pictures_artifacts.px` (the
  Mask), with their baked `.png`, `.json` and `.png.import`
- `game/ui/ui_icon.gd` (`SHEETS` only), `game/ui/windows/path_colours.gd`,
  `game/ui/windows/tally_window.gd` (`CLASS_BARS` only), `game/ui/picture_specimen.gd` (to fit an
  eighth group), `game/dev/showcase.gd`, `game/dev/showcase_moments.gd` and, if spec 119 made it,
  `game/dev/showcase_class_moments.gd`
- `tests/acceptance/test_120_the_witch_doctor.gd`,
  `tests/acceptance/test_120_every_ability_is_seen.gd` and their `.uid`s, `tests/colony_test.gd`
  (only if a helper must take a class or place it does not), and the files in "Tests that change"
- `docs/wiki/index.html`, `docs/style-bible.md` (the cast: the Witch Doctor drawn as the Mage for
  now)

## Open questions

None.
