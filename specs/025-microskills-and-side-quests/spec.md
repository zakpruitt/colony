# 025 — Microskills and side quests: more to do down there than fight

- **Status:** provisional
- **Milestone:** M4
- **Depends on:** 005, 020, 023
- **Pull request:** —

## Intent

Every chamber is a fight, so every minute of watching is the same minute. This spec gives the party other
things to come across (`docs/design/world.md`): **side quests**, small things in a chamber that the party
can only do if one of its heroes has the right **microskill**, a minor passive such as Lockpicker. Fights
stay the most common thing. Heroes pick microskills up as they level, so early on the party walks past
things it cannot yet do, and the player sees what a different or stronger party would unlock. This spec is
the simulation only; a later spec puts it on screen.

## Requirements

- **R1. Five microskills exist as data,** each a valid `MicroskillDef` under `data/microskills/` with a
  name and a one-line description. Each hero class lists the microskills it learns and the hero level at
  which it learns each:

  | Microskill | Class | Learned at level | What it is |
  |---|---|---|---|
  | `lockpicker` | rogue | 2 | Opens locks |
  | `strongarm` | knight | 3 | Forces what is stuck |
  | `mender` | cleric | 3 | Patches up strangers |
  | `runereader` | mage | 4 | Reads old runes |
  | `trapspotter` | rogue | 6 | Sees a trap before it sees you |

  A hero has a microskill when their level is at or above its level. Nothing new is saved.
- **R2. Five side quests exist as data,** each a valid `SideQuestDef` under `data/sidequests/`:

  | Id | Needs | With the microskill | Without it |
  |---|---|---|---|
  | `locked_chest` | lockpicker | Gold worth about three kills of that depth | The party walks past |
  | `stuck_door` | strongarm | Gold worth about two kills | The party walks past |
  | `hurt_wanderer` | mender | A gift of gold worth about two kills | The party walks past |
  | `rune_stone` | runereader | XP worth about two kills, to every living hero | The party walks past |
  | `tripwire` | trapspotter | Disarmed; gold worth about one kill | It springs: every living hero loses 20% of their maximum health (never below 1) |

- **R3. Some chambers hold a side quest instead of monsters.** On each visit, a plain chamber holds a side
  quest with probability `SIDE_QUEST_SHARE` (0.3) and monsters otherwise. Start chambers, dens, vaults and
  guardian chambers are unchanged. What a chamber holds on a visit depends only on the seed, depth, chamber
  and visit, and reading it changes nothing (as spec 023 requires). Over 2,000 plain-chamber visits at
  depths 1 to 20, side quests are 25% to 35% of them and every kind appears.
- **R4. With the microskill, the party does it.** Reaching a side quest that a living hero has the
  microskill for, the party stops and the expedition enters `WORKING`. That hero is the worker (the lowest
  hero id if several qualify). The work takes the quest's `work_seconds` (3 to 6). It always succeeds: the
  reward is given, the chamber counts as cleared (it refills after the usual respawn time) and the party
  travels on.
- **R5. Without it, the party passes.** If no living hero has the microskill, the party does not stop. A
  quest with no hazard stays where it is and can be done on a later pass once someone has learned the
  microskill; it is reported as missed once per visit, not on every pass. A hazard (the tripwire) springs
  when the party reaches it, deals its damage and is cleared.
- **R6. It is reported.** Events, placed before `ENCOUNTER_STARTED`:
  - `MICROSKILL_LEARNED`: source the hero, target the microskill's position in `Content.microskill_ids()`,
    amount the hero's level. Raised when a level-up crosses the level.
  - `SIDE_QUEST_STARTED`: source the worker, target the quest's position in `Content.side_quest_ids()`,
    amount the work in ticks.
  - `SIDE_QUEST_DONE`: same source and target, amount the gold or XP given.
  - `SIDE_QUEST_MISSED`: target the quest's position, amount the needed microskill's position, flag true
    when a hazard sprang.

  Gold, XP and trap damage also raise their usual events, so the HUD and effects follow without changes.
- **R7. The game is still the game.** A sprung tripwire can never wipe the party. In a one-hour run with
  `stable_seconds` 120 on five seeds: every run still becomes stable below depth 2, at least three of five
  beat the first guardian, every hero learns their first microskill, and every run completes at least five
  side quests and misses at least one. Existing tests keep their statements; one that pins a state hash, or
  assumes every populated plain chamber holds monsters, may be updated (say which).

## Interfaces

```gdscript
# sim/defs/microskill_def.gd
class_name MicroskillDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var description: String
func validate() -> PackedStringArray

# sim/defs/side_quest_def.gd
class_name SideQuestDef
extends Resource
enum Reward { GOLD, XP }
@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float
@export var reward: Reward
@export var reward_factor: float      # in kills of that depth
@export var miss_damage: float        # share of max health every living hero loses if nobody has the microskill; 0 for no hazard
func validate() -> PackedStringArray

# sim/defs/hero_class_def.gd gains
@export var microskills: Array[StringName]
@export var microskill_levels: Array[int]    # same length; the hero level each is learned at

# sim/party/hero.gd gains
func microskills() -> Array[StringName]      # the ones this hero has now
func has_microskill(id: StringName) -> bool

# sim/party/party.gd gains
## The living hero who would do a quest needing this microskill, or null.
func hero_with_microskill(id: StringName) -> Hero

# sim/defs/content.gd gains
static func microskill(id: StringName) -> MicroskillDef
static func microskill_ids() -> Array[StringName]
static func side_quest(id: StringName) -> SideQuestDef
static func side_quest_ids() -> Array[StringName]

# sim/expedition/expedition.gd gains
const SIDE_QUEST_SHARE: float = 0.3
# State gains WORKING (added at the end of the enum)
## The id of the side quest that chamber holds on its current visit, or &"".
func side_quest_in(level_depth: int, chamber_index: int) -> StringName
## While WORKING: the quest, the worker's hero id, and progress from 0 to 1. Otherwise &"", -1, 0.0.
func working_quest() -> StringName
func worker_id() -> int
func work_progress() -> float
```

The HUD has a dictionary of words and colours keyed by `Expedition.State` (`game/hud/hud.gd`): add
`WORKING` there ("Working") so the game compiles and reads sensibly. That is the only `game/` change.

## Acceptance

In `tests/acceptance/test_025_microskills_and_side_quests.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_microskills` | The five load and validate; each class's list; a hero has one exactly from its level |
| R2 | `test_r2_side_quests_are_valid` | The five load and validate; each row of the table, with and without the microskill, against kills of that depth |
| R3 | `test_r3_some_chambers_hold_side_quests` | The share and the kinds over 2,000 visits; other chamber kinds never hold one; reading in any order changes neither the answer nor the state hash |
| R4 | `test_r4_the_party_does_it` | The state, the worker and the tie rule, the duration, the reward, cleared afterwards and refilled after the respawn time |
| R5 | `test_r5_the_party_passes` | No stop; the quest still there and done on a later pass after the level is reached; one missed event per visit; the tripwire's damage and clearing |
| R6 | `test_r6_events` | Each event with its fields, and the usual gold, XP and hit events beside them |
| R7 | `test_r7_still_the_game` | A tripwire never takes a hero below 1 health; the five-seed statements |

## Out of scope

- Anything on screen beyond the one HUD word: no sprite, no effect, no sound.
- Choosing who is in the party, new classes, professions, pets.
- Side quests that change the route, items or loot.
- The away report mentioning side quests.

## Paths

- `sim/defs/microskill_def.gd`, `sim/defs/side_quest_def.gd`, `sim/defs/hero_class_def.gd`, `sim/defs/content.gd`
- `sim/party/hero.gd`, `sim/party/party.gd`
- `sim/expedition/expedition.gd`, `sim/expedition/chamber_state.gd`, `sim/sim_event.gd`
- `data/microskills/`, `data/sidequests/` (new), `data/heroes/` (the two new fields)
- `tools/` only if the `data` check step must learn the new folders
- `game/hud/hud.gd` (the `WORKING` word and colour only)
- `tests/acceptance/test_025_microskills_and_side_quests.gd`, `tests/unit/test_expedition*.gd`, `tests/unit/test_hero*.gd`
- Existing tests only where they pin a state hash, list every event kind or expedition state, or assume every
  populated plain chamber holds monsters (say which)
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
