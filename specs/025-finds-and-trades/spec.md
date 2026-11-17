# 025 — Finds and trades: more to do down there than fight

- **Status:** draft
- **Milestone:** M4
- **Depends on:** 005, 014, 020, 023
- **Pull request:** —

## Intent

Every chamber is a fight, so every minute of watching is the same minute. This spec gives the party other
things to come across (`docs/design/world.md`): **finds**, which one hero works on with their **trade**.
Fights stay the most common thing; a find is a change of pace with its own risk and reward, and trades that
grow with use give each hero a second reason to be in the party. This spec is the simulation only; spec 026
puts it on screen.

## Requirements

- **R1. Four trades, one per class.** Each hero class has one trade: knight `digging`, rogue `trapwork`,
  mage `lore`, cleric `herbalism`. A hero starts at level 1 in their class's trade and level 0 in the rest.
- **R2. Four finds exist as data,** each a valid `FindDef` under `data/finds/`:

  | Id | Trade | On success | On failure |
  |---|---|---|---|
  | `trapped_cache` | trapwork | Gold worth about three kills of that depth | The trap springs: every living hero loses 20% of their maximum health (never below 1) |
  | `ore_vein` | digging | Gold worth about one and a half kills | Half the gold |
  | `rune_stone` | lore | XP worth about two kills, to every living hero | Nothing |
  | `herb_patch` | herbalism | Every living hero is healed by 30% of their maximum health | Nothing |

- **R3. Some chambers hold a find instead of monsters.** On each visit, a plain chamber holds a find with
  probability `FIND_SHARE` (0.3) and monsters otherwise. Start chambers, dens, vaults and guardian chambers
  are unchanged. What a chamber holds on a visit depends only on the seed, depth, chamber and visit, and
  reading it changes nothing (as spec 023 requires for monsters). Over 2,000 plain-chamber visits at depths
  1 to 20, finds are 25% to 35% of them and every find kind appears.
- **R4. The party works a find.** Reaching a find, the party stops and the expedition enters `WORKING`. The
  living hero with the highest level in the find's trade does the work (ties go to the lowest hero id). The
  work takes the find's `work_seconds` (4 to 8), shortened by 5% for each level the worker is above the
  find's difficulty, to no less than half. Then one roll decides success or failure, the result is applied,
  the chamber counts as cleared (it refills after the usual respawn time) and the party travels on.
- **R5. Skill against depth decides the odds.** A find's difficulty is its depth's (the lane sets the curve;
  it starts at 1 on depth 1 and rises by about 1 every two levels). The chance of success rises with the
  worker's level over the difficulty and is always between 10% and 95%. Over 500 attempts each: a level-1
  worker at depth 1 succeeds at least 80% of the time; a level-0 worker at depth 1 at most 40%; a worker
  whose level equals the difficulty succeeds 70% to 85% at depths 5, 10 and 20.
- **R6. Trades grow with use.** Each attempt gives the worker trade experience, more for a success than a
  failure, and levels rise at growing thresholds. In a one-hour run with `stable_seconds` 120 on three
  seeds, every hero's own trade reaches at least level 3, and no trade the hero does not practise rises.
- **R7. It is reported.** Events: `FIND_STARTED` (source: the worker, target: the find's position in
  `Content.find_ids()`, amount: the work in ticks), `FIND_ENDED` (same source and target, flag: success,
  amount: the gold, XP or healing given, or the damage dealt on a sprung trap) and `TRADE_LEVEL_UP` (source:
  the hero, target: the trade's position in `Trades.IDS`, amount: the new level). Gold, XP, healing and
  damage also raise their usual events so the HUD and effects follow without changes.
- **R8. It is saved.** Trade levels and experience are in the save, the version becomes 4, and a version 3
  save loads with starting trades through the upgrade step. A find in progress is not saved: a loaded game
  arrives at rest as today.
- **R9. The game is still the game.** A sprung trap can never wipe the party. With `stable_seconds` 120 over
  one hour on five seeds, runs still become stable below depth 2 and still beat the first guardian in at
  least three of five. Existing tests keep their statements; one that pins a state hash, or assumes every
  populated plain chamber holds monsters, may be updated (say which).

## Interfaces

```gdscript
# sim/defs/find_def.gd
class_name FindDef
extends Resource
enum Reward { GOLD, XP, HEAL }
@export var id: StringName
@export var display_name: String
@export var trade: StringName
@export var work_seconds: float
@export var reward: Reward
@export var reward_factor: float      # in kills of that depth (GOLD, XP) or share of max health (HEAL)
@export var fail_reward_factor: float
@export var fail_damage: float        # share of max health lost by every living hero on failure
func validate() -> PackedStringArray

# sim/party/trades.gd
class_name Trades
const IDS: Array[StringName] = [&"digging", &"trapwork", &"lore", &"herbalism"]

# sim/defs/hero_class_def.gd gains
@export var trade: StringName

# sim/party/hero.gd gains
func trade_level(trade: StringName) -> int
func trade_experience(trade: StringName) -> int

# sim/defs/content.gd gains
static func find(id: StringName) -> FindDef
static func find_ids() -> Array[StringName]

# sim/expedition/expedition.gd gains
const FIND_SHARE: float = 0.3
# State gains WORKING
## The id of the find that chamber holds on its current visit, or &"" (monsters, empty or cleared).
func find_in(level_depth: int, chamber_index: int) -> StringName
## While WORKING: the find, the worker's hero id, and progress from 0 to 1. Otherwise &"", -1, 0.0.
func working_find() -> StringName
func worker_id() -> int
func work_progress() -> float

# sim/sim_event.gd: Kind.FIND_STARTED, FIND_ENDED, TRADE_LEVEL_UP, placed before ENCOUNTER_STARTED
```

## Acceptance

In `tests/acceptance/test_025_finds_and_trades.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_trades` | Each class's trade; starting levels 1 and 0 |
| R2 | `test_r2_four_finds_are_valid` | Each loads and validates; each outcome in the table, success and failure, against kills of that depth |
| R3 | `test_r3_some_chambers_hold_finds` | The share and the kinds over 2,000 visits; other chamber kinds never hold one; reading in any order changes neither the answer nor the state hash |
| R4 | `test_r4_working_a_find` | The state, the chosen worker and the tie rule, the duration and its shortening, cleared afterwards and refilled after the respawn time |
| R5 | `test_r5_skill_against_depth` | The three success-rate statements and the 10% and 95% bounds |
| R6 | `test_r6_trades_grow` | Experience per attempt, level thresholds, and the one-hour statements |
| R7 | `test_r7_events` | Each event with its fields, and the usual gold, XP, heal and hit events beside them |
| R8 | `test_r8_saved` | Round trip; a version 3 dictionary loads with starting trades; bad values refused by name |
| R9 | `test_r9_still_the_game` | A trap never takes a hero below 1 health; the five-seed statements |

## Out of scope

- Anything on screen (spec 026): this spec may add no sprite and change nothing under `game/` except what
  must compile.
- Choosing who is in the party, new classes, new trades, pets.
- Finds that change the route (shortcuts, sealed doors), items or loot.
- The away report mentioning finds.

## Paths

- `sim/defs/find_def.gd`, `sim/defs/hero_class_def.gd`, `sim/defs/content.gd`, `sim/party/trades.gd`,
  `sim/party/hero.gd`, `sim/party/party.gd`
- `sim/expedition/expedition.gd`, `sim/expedition/chamber_state.gd`, `sim/sim_event.gd`, `sim/simulation.gd`
- `data/finds/` (new), `data/heroes/` (the trade field)
- `tools/` only if the `data` check step must learn the new folder
- `tests/acceptance/test_025_finds_and_trades.gd`, `tests/unit/test_expedition*.gd`, `tests/unit/test_hero*.gd`
- Existing tests only where they pin a state hash, the save version or the saved dictionary, or assume every
  populated plain chamber holds monsters (say which)
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

1. Is "find" the right word for these, or would you call them something else?
2. Are the four trades and their pairing with the classes right (knight digging, rogue trapwork, mage lore,
   cleric herbalism)?
3. Is 30% of plain chambers the right share to start from?
