# 118 — The Bard: songs for the party, lullabies for the foe

- **Status:** draft
- **Milestone:** M9
- **Depends on:** 109, 110, 112, 113, 114, 117 (it needs 112's artifact and request fields; its
  Paths share `game/ui/ui_icon.gd`, `pictures_artifacts.px`, the colour tables, the showcase and
  the counting tests with spec 117, so it starts once 117 has landed and builds on its helpers)
- **Pull request:** —

## Intent

The second class found by luck (spec 112). A cache may hold a Bard's Lute; a Bard then waits at
camp until its request is paid. The Bard fights weakly itself and makes the others better: songs
that quicken and strengthen the party, lullabies that stun, slow and weaken every foe, and ballads
that mend, shield and sing the fallen back up. It brings no summons. Three paths of five, as every
class has since spec 109. It is drawn as the Cleric until Zak draws it.

## Requirements

- **R1. The class, as data.** `data/heroes/bard.tres`:

  | Field | Value | Why |
  |---|---|---|
  | `role` | `RANGED` | It stands at the back but strikes with its own swing, not the Cleric's heal: a `HEALER` heals with every swing and spends no action on an enemy while an ally is hurt (`BattleAbilities.ready_action`), which would starve Valor and Lullaby. It is fielded in a Mage's place most often |
  | `max_health`, `health_per_level` | 65, 8 | Between the Mage (45, 6) and the Cleric (70, 10). 169 at level 14 |
  | `damage`, `damage_per_level` | 4, 1 | 17 at level 14, a third of the Mage's 57: its worth is in its songs. Above the Cleric's 3, 1 |
  | `attack_interval`, `windup` | 1.0, 0.3 | A steady beat: every strike is a note, and Drumbeat and Refrain count them |
  | `attack_range` | 5.0 | Within earshot, a step nearer than the Cleric's 6 |
  | `move_speed`, `armor`, `crit_chance` | 2.5, 1, 0.05 | The Cleric's |
  | `heal_power` | 10 | Under half the Cleric's 22. It only sizes Soothing Song's mending and Refrain's heal: the Bard's swing never heals |
  | `microskills`, `microskill_levels` | `[runereader]`, `[4]` | A bard knows the old songs and the runes they were written in, and so keeps the Mage's microskill when it goes down in the Mage's place. No new microskill (it would need its own quests, spec 025) |
  | `artifact_name` | `Bard's Lute` | |
  | `artifact_picture` | `bards_lute` | R4 |
  | `artifact_chance` | 0.06 | Spec 112's suggestion |
  | `recruit_gold`, `recruit_resource`, `recruit_resource_count` | 500, `clay`, 25 | Dearer than the Ranger's 300 gold and 40 Glowcaps, and asking for the Claypits' clay gives that area a use. The headless run never leaves Mossy Hollow, so this price is not measured: tunable data |
  | `looks_like` | `cleric` | Robed; drawn so, it reads apart from the Mage it most often replaces |

  - It passes `HeroClassDef.validate()` and spec 112's checks, and `python tools/dev.py check
    --only=data` passes with it. It is not in `Party.STARTING_CLASSES`.
- **R2. Three paths of five.** `data/talents/bard.tres`, in this order, with the four trees'
  `rank_xp`, `tier_ranks` and `uses_counted`. Nodes are tier 1; tier 2 left / right; tier 3; tier 4.

  | Path | Summary (at most 60 characters) | T1 | T2 | T3 | T4 |
  |---|---|---|---|---|---|
  | Valor | songs of haste and might for the whole party | marching_song | rousing_anthem / drumbeat | overture | crescendo |
  | Lullaby | lulls, slows and weakens every foe | lullaby | dirge / discord | slumber | requiem |
  | Ballad | mends, shields and sings the fallen back up | soothing_song | warding_verse / refrain | stand_fast | song_of_return |

  It passes `TalentTreeDef.validate()`. `PathColours` gives the paths `orange`, `blue` and `pink`.
- **R3. The fifteen abilities do what they say.** Each is a file under `data/abilities`, built only
  from kinds that exist today (see "The abilities"), passes `AbilityDef.validate()`, and every
  action is `ready_at_start`. In a battle built for it, each does what its description says.
  Examples: Marching Song hastes every hero; Drumbeat fires on the fourth strike and not the third;
  Overture marks every enemy as the fight starts; Discord's slow lands on about 30% of hits over a
  long fight; Requiem's three statuses land on the weakest enemy only; Stand Fast waits until
  another ally is below 50%; Song of Return stands the first ally to fall back up once a fight.
- **R4. Pictures.** Each of the fifteen has its own 16x16 picture in a new sheet,
  `assets/sprites/ui/pictures_bard.px`, listed in `UiIcon.SHEETS` after the Ranger's, and the Lute
  has one, `bards_lute`, in `assets/sprites/ui/pictures_artifacts.px`. Spec 063 R1 holds for each,
  as spec 117 R4 has it. They may be placeholders.
- **R5. Each path is worth having.** Spec 051's fight, with the Bard standing in the Mage's place
  (spec 117's `ColonyTest.stand_in`): the bare party wins none of five; with the Bard holding one
  path's five nodes and nothing else, the party wins at least three, for each path.
  - Probed on a scratch copy of `dev` with these numbers: bare 0; Valor 4 (38 to 46 s), Lullaby 5
    (53 to 59 s), Ballad 5 (61 to 66 s).
  - The Bard is not a Cleric: with it in the Rogue's or the Knight's place the party loses with any
    path, 0 or 1 of 5 in the probe. That is not a requirement, and nothing
    needs it to win there.
- **R6. Every ability is seen.** As spec 117 R6, with the Bard in the Mage's place:
  - The nine 60-minute runs: every action held ten minutes used at least five times, every passive
    fired, rescues aside. The rescues are Stand Fast (its condition waits for a hurt ally, so
    spec 109's test already lists it from the data) and Song of Return (named, as spec 109's named
    rescues are). Each fires in spec 109's rescue fight (three ogres, the party at level 14, the
    ogres at 14 and 18, three seeds each), with the Bard holding Ballad.
  - The level-30 party with all fifteen nodes each, 30 minutes from Mossy Hollow stage 18: every
    Bard action used five times and every passive fired, rescues aside.
  - Probed: no run wiped but one (seed 1, Ballad first: one wipe); the fewest uses of an action
    held ten minutes were Slumber's 8 in 12 minutes, then Requiem's 15 in 18; Drumbeat fired 4 to
    16 times. In the rescue fights Stand Fast and Song of Return each fired 6 times. In the full
    party's play every action was used 19 to 25 times. The lane may tune a number that falls short
    and lists each change.
- **R7. The Bard on screen.**
  - Its tally bar is `pink` over `plum` (`TallyWindow.CLASS_BARS`).
  - It is drawn as the Cleric in the world, the frames, the hero window and the tally (spec 113
    R6), under its own name.
  - Its songs show their move, their name and their statuses, as the Knight's shouts do.
    `SpellEffects.KINDS` gains nothing.
  - The showcase gains `bard_actions` in `Showcase.CLASS_MOMENTS`, `CLASS_PATHS` giving it Valor:
    the Bard stands in for the Mage holding Valor's five nodes, and its songs' statuses are seen on
    the heroes.
  - The picture sheet scene shows the Bard's group after the Ranger's, wholly on the sheet.
- **R8. The recorded runs.** As spec 117 R8: a recorded-hash test may change only from the step a
  cache finds the Lute, shown in the pull request, and is then re-recorded with a comment saying so.
- **R9. The old tests follow.** The tests spec 117 amended for a fifth class are amended for a
  sixth (90 abilities), and no others.
- **R10. The wiki.** `docs/wiki/index.html` gains the Bard beside the Ranger: how it is found, its
  price, its three paths in a line each.

## The abilities

Every one uses only aims, conditions, triggers, effects and statuses that exist today. Songs aimed
at the Bard itself wait for an enemy within 9 tiles (`ENEMY_WITHIN`). `ALLIES` reaches every hero
and any summon standing (spec 115 R3), so a Ranger's beasts are sung to too. The numbers are the
probed ones; the lane may tune them for R5 and R6 and lists each change.

| Id | Name | Kind, move | How it is built | Description |
|---|---|---|---|---|
| marching_song | Marching Song | action, flourish | aim SELF, ENEMY_WITHIN 9; HASTED 0.85 for 6 s on ALLIES; cooldown 12, windup 0.3 | Every ally strikes 15% faster for 6 s. Every 12 s. |
| rousing_anthem | Rousing Anthem | action, cast | aim SELF, ENEMY_WITHIN 9; MIGHTY 1.2 for 6 s on ALLIES; cooldown 14, windup 0.3 | Every ally deals 20% more damage for 6 s. Every 14 s. |
| drumbeat | Drumbeat | passive, flourish | EVERY_NTH_STRIKE, trigger_every 4; HASTED 0.8 for 3 s on ALLIES | Every fourth note quickens every ally: 20% faster strikes for 3 s. |
| overture | Overture | passive, flourish | FIGHT_STARTS; MARKED 1.2 for 10 s on ENEMIES | As a fight starts, the overture rattles every enemy: 20% more damage taken for 10 s. |
| crescendo | Crescendo | action, channel | aim SELF, ENEMY_WITHIN 9; MIGHTY 1.5 and HASTED 0.7 for 8 s on ALLIES; cooldown 30, windup 0.6 | Every ally deals 50% more damage and strikes 30% faster for 8 s. Every 30 s. |
| lullaby | Lullaby | action, cast | aim NEAREST_ENEMY, anywhere; STUNNED 2 s on TARGET; cooldown 10, windup 0.3 | Sings the nearest enemy to sleep: stunned for 2 s. Every 10 s. |
| dirge | Dirge | action, channel | aim SELF, ENEMY_WITHIN 9; WEAKENED 0.75 for 6 s on ENEMIES; cooldown 14, windup 0.4 | Every enemy deals 25% less damage for 6 s. Every 14 s. |
| discord | Discord | passive, flourish | LANDS_HIT, chance 0.3; SLOWED 1.4 for 3 s on TARGET | A sour note: every hit has a 30% chance to slow the enemy's strikes by 40% for 3 s. |
| slumber | Slumber | action, channel | aim SELF, ENEMY_WITHIN 9; STUNNED 2 s on ENEMIES; cooldown 24, windup 0.6 | Every enemy nods off: stunned for 2 s. Every 24 s. |
| requiem | Requiem | action, channel | aim WEAKEST_ENEMY, anywhere; MARKED 1.4, WEAKENED 0.6 and SLOWED 1.4, each for 6 s, on TARGET; cooldown 20, windup 0.5 | Dreads the weakest enemy: it takes 40% more damage, deals 40% less and strikes 40% slower for 6 s. Every 20 s. |
| soothing_song | Soothing Song | action, cast | aim SELF, ENEMY_WITHIN 9; MENDING 0.4 of healing power for 6 s on ALLIES; cooldown 12, windup 0.3 | Every ally mends for 6 s. Every 12 s. |
| warding_verse | Warding Verse | action, cast | aim SELF, ENEMY_WITHIN 9; SHIELDED 0.08 of the receiver's health for 6 s on ALLIES; cooldown 15, windup 0.3 | Every ally gets a shield of 8% of its health for 6 s. Every 15 s. |
| refrain | Refrain | passive, flourish | EVERY_NTH_STRIKE, trigger_every 3; HEAL 0.5 of healing power on ALLIES | Every third note heals every ally by half the healing power. |
| stand_fast | Stand Fast | action, prayer | aim SELF, OTHER_ALLY_BELOW 0.5; HEAL 0.15 of the receiver's health and SHIELDED 0.1 of it for 6 s on ALLIES; cooldown 25, windup 0.4 | With another ally below 50%: heals every ally for 15% of its health and shields it (10%) for 6 s. Every 25 s. |
| song_of_return | Song of Return | passive, prayer | ALLY_DIES, once_per_fight; REVIVE 0.4 on TARGET; MIGHTY 1.3 for 8 s on ALLIES | Once a fight, when an ally falls, sings it back up with 40% health, and every ally deals 30% more damage for 8 s. |

These differ from the direction, or settle what it left open:

- **No song lasts while the Bard plays.** No status is tied to its giver acting, so every song is
  an action with a cooldown, a passive, or a status of a few seconds.
- **Overture marks the foe rather than hasting the party.** War Banner and Battle Hymn already
  haste everyone as a fight starts, and statuses of one kind do not stack (the stronger is kept,
  `BattleStatuses.apply`), so a third fight-start haste would add nothing beside them. Marked is a
  different multiplier and adds to Valor's might.
- **Song of Return is a rescue, not an action.** As spec 109's Resurrection: no condition waits for
  a fallen ally.
- **Two Bards' or a Bard and a Cleric's buffs of one kind do not add up.** That is the engine's
  rule for every status, and the tooltips say no more than each song does.

## Interfaces

No code interface changes. Data only, plus these table rows:

```gdscript
# game/ui/ui_icon.gd: SHEETS gains, after pictures_ranger.png
"res://assets/sprites/ui/pictures_bard.png",
# game/ui/windows/path_colours.gd: COLOURS gains
&"bard": [&"orange", &"blue", &"pink"],
# game/ui/windows/tally_window.gd: CLASS_BARS gains
&"bard": [&"pink", &"plum"],
# game/dev/showcase.gd
# CLASS_MOMENTS gains &"bard_actions": &"bard"; CLASS_PATHS gains &"bard": 0
```

## Acceptance

In `tests/acceptance/test_118_the_bard.gd`, one test per requirement named `test_rN_…`, each
written before its data and seen to fail; R6 in `test_118_every_ability_is_seen.gd`. Both use
spec 117's helpers on `ColonyTest` (`stand_in` and those moved from `test_109`).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_class_as_data` | The numbers of the table; it validates; not a starting class; a new game is the four |
| R2 | `test_r2_three_paths_of_five` | Names, summaries and nodes in order, tiers, the rank tables, the colours |
| R3 | `test_r3_the_abilities_do_what_they_say` | One built battle per ability, checking its events: statuses on whom and for how long, the fourth and third strikes, the chance over many hits, the condition held and met, the revive once a fight, a summon reached by `ALLIES` |
| R4 | `test_r4_pictures` | Fifteen pictures and the Lute's, as spec 117's test |
| R5 | `test_r5_each_path_is_worth_having` | The bare party 0 of 5; each path at least 3 of 5 |
| R6 | `test_r6_every_ability_is_seen` | The nine runs, the rescue fights and the full party |
| R7 | `test_r7_on_screen` | The tally bar's colours, the Cleric's sheet and picture under the name `Bard`, the showcase moment's watcher seeing its statuses, the specimen's group |
| R8 | the recorded-hash tests | As spec 117 R8 |
| R9 | the amended suite | Every listed test passes |
| R10 | `test_r10_the_wiki` | The wiki names the Bard, the Lute and its three paths |

**To look at, and for Zak:** the picture sheet scene with the Bard's group; its Talents tab fresh
and full at 1280x720 and `--ui-room=960x540`; the showcase's `bard_actions` moment; a fight with
the Bard on Lullaby and on Ballad. Describe every shot. Do songs read in a fight without a visual
of their own?

## Tests that change

The files spec 117 amended, each only for a sixth class and fifteen more abilities:
`test_004_combat_core.gd`, `test_025_microskills_and_side_quests.gd` (the Bard learns Runereader
at 4), `test_057_lively_moves.gd` (90 abilities), `test_109_three_paths_of_five.gd` (90),
`test_063_pictures_and_the_moment.gd`, `test_072_content_table.gd`, `test_078_sim_base_types.gd`,
`test_059_shop_map_and_tally_windows.gd`, `tests/unit/test_hud_talents.gd` (the last five only if
they fail for the added class or abilities), and the recorded-hash tests only as R8 says
(`test_016`, `test_035`, `test_039`, `test_100`, `test_101`). And two of its own, found by running
the whole suite on a scratch copy of `dev` with the Bard's data:

- `tests/acceptance/test_107_the_quest_story.gd` uses `&"bard"` as a class that does not exist
  (`bad_class.lines[0].class_id`); it becomes `&"no_such_class"`.
- `tests/acceptance/test_109_every_ability_is_seen.gd`: `_rescues()` lists every action under
  `data/abilities` whose condition waits for a hurt ally, so Stand Fast joins the four classes'
  rescues and its assert fails, since no party there holds it. `_rescues()` keeps to the abilities
  of the four classes' trees; `test_118` checks the Bard's (R6).

## Out of scope

- A Bard sheet, sounds, song visuals (notes in the air): a later spec, with Zak's art.
- New aims, conditions, triggers or statuses; songs held while the Bard plays; stacking buffs.
- Summons, recruiting in the headless run, changing any other class.

## Paths

- `data/heroes/bard.tres`, `data/talents/bard.tres`, the fifteen new files under `data/abilities/`
- `assets/sprites/ui/pictures_bard.px` and `assets/sprites/ui/pictures_artifacts.px` (the Lute),
  with their baked `.png`, `.json` and `.png.import`
- `game/ui/ui_icon.gd` (`SHEETS` only), `game/ui/windows/path_colours.gd`,
  `game/ui/windows/tally_window.gd` (`CLASS_BARS` only), `game/ui/picture_specimen.gd` (a sixth
  group did not fit in the probe), `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_118_the_bard.gd`, `tests/acceptance/test_118_every_ability_is_seen.gd` and
  their `.uid`s, `tests/colony_test.gd` (only if a helper must take a class it does not), and the
  files in "Tests that change"
- `docs/wiki/index.html`, `docs/style-bible.md` (the cast: the Bard drawn as the Cleric for now)

## Open questions

None.
