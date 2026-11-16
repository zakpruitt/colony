# 016 — Camp upgrades: something to spend gold on

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M3
- **Depends on:** 005, 014
- **Pull request:** [#18](https://github.com/zakpruitt/colony/pull/18)

## Intent

The party earns gold and nothing uses it: after an hour there are 1,500 coins and no decision to make. This
spec closes the loop. Gold buys permanent, party-wide upgrades in ranks, each rank dearer than the last, so
the player always has a next thing to save for and a reason to push deeper where monsters pay more. This is
the simulation half: the rules, the data, the command and the save. The shop on screen is spec 017.

## Requirements

- **R1. Upgrades are data.** Five upgrades exist as `UpgradeDef` resources under `data/upgrades/`, each valid:

  | Id | Name | Each rank gives | Max rank |
  |---|---|---|---|
  | `sharp_blades` | Sharp Blades | +5% hero damage and healing power | 20 |
  | `stout_armor` | Stout Armor | +5% hero maximum health | 20 |
  | `field_medicine` | Field Medicine | +10% healing speed while resting | 10 |
  | `quick_march` | Quick March | +4% travel and climb speed | 10 |
  | `fat_purse` | Fat Purse | +5% gold from kills | 20 |

  Bonuses of one upgrade add up by rank (rank 3 of Sharp Blades is +15%, not compounded).
- **R2. Each rank costs more.** The price of the next rank is `base_cost * cost_growth ^ rank`, rounded to a
  whole number, from the upgrade's data. First ranks cost between 20 and 60 gold; growth is between 1.3 and
  1.6. At the maximum rank there is no price.
- **R3. Buying is a command.** `Simulation.buy_upgrade(id)` takes effect at the next step: if the id is known,
  the rank is below the maximum and the party has the gold, the gold is taken, the rank rises by one, and an
  `UPGRADE_BOUGHT` event is recorded. Otherwise nothing happens: no gold lost, no event, no error. Several
  commands before one step are applied in order while gold lasts.
- **R4. Upgrades change the game.** Hero damage, healing power and maximum health, rest healing, travel and
  climb speed and gold from kills are each multiplied by `1 + rank * per_rank` of their upgrade. A health
  upgrade raises current health by the health gained. Every bonus applies by the start of the next fight at
  the latest; rest, travel and gold bonuses apply at once.
- **R5. With no upgrades, nothing changes.** Every existing test passes unchanged, and a simulation that buys
  nothing has the same state hash, tick for tick, as before this spec.
- **R6. Upgrades are worth buying.** Over one hour on five seeds with `stable_seconds` 120, a party that
  buys the cheapest affordable upgrade whenever it can ends with a deeper last stable depth, or fewer wipes
  at the same depth, than a party that buys nothing, on at least four of the five seeds.
- **R7. Upgrades are saved.** `to_save()` holds each upgrade's rank; the save version becomes 2. Loading
  brings the ranks back and their effects with them. A version 1 save still loads, with every rank 0, through
  the upgrade step spec 014 left for this. A rank that is negative, above the maximum or for an unknown
  upgrade makes the save refused with a problem naming it.
- **R8. The headless summary shows them.** `python tools/dev.py sim` prints each upgrade's rank in its JSON,
  and accepts `--buy-upgrades` to make the run buy the cheapest affordable upgrade whenever it can.

## Interfaces

```gdscript
# sim/defs/upgrade_def.gd
class_name UpgradeDef
extends Resource
enum Stat { DAMAGE, HEALTH, REST_HEALING, TRAVEL_SPEED, GOLD }
@export var id: StringName
@export var display_name: String
@export var description: String     # one short line, e.g. "+5% damage and healing"
@export var order: int              # position in the shop, lowest first
@export var stat: Stat
@export var per_rank: float
@export var base_cost: int
@export var cost_growth: float
@export var max_rank: int
func validate() -> PackedStringArray

# sim/defs/content.gd
static func upgrade(id: StringName) -> UpgradeDef          # null if unknown
static func upgrade_ids() -> Array[StringName]             # in shop order

# sim/party/upgrades.gd
class_name Upgrades
extends RefCounted
func rank(id: StringName) -> int
func cost(id: StringName) -> int                           # price of the next rank; -1 at the maximum or unknown
func multiplier(stat: UpgradeDef.Stat) -> float            # 1.0 with no ranks

# sim/simulation.gd
var upgrades: Upgrades
func buy_upgrade(id: StringName) -> void

# sim/sim_event.gd: Kind.UPGRADE_BOUGHT
#   source_id = the upgrade's position in Content.upgrade_ids(), amount = its new rank
```

## Acceptance

In `tests/acceptance/test_016_camp_upgrades.gd`, plus a Python test for R8 in `tools/tests/`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_five_upgrades_are_valid` | Each id loads and validates with the stat, per-rank bonus and maximum above; `upgrade_ids()` is in `order` |
| R2 | `test_r2_each_rank_costs_more` | Costs follow the formula for ranks 0 to 5; first-rank cost and growth within range; -1 at the maximum |
| R3 | `test_r3_buying_is_a_command` | Bought at the next step with gold taken and one event; unaffordable, unknown and maxed do nothing; three commands with gold for two buy two |
| R4 | `test_r4_upgrades_change_the_game` | For each stat, a simulation with ranks set differs from one without by the stated factor: combatant damage, heal power and max health; rest healing per second; distance travelled and climbed per second; gold from the same kill. A health upgrade heals by the gain |
| R5 | `test_r5_no_upgrades_changes_nothing` | A simulation that buys nothing matches a recorded hash sequence taken before the change, over 20 minutes; and the existing suite passes |
| R6 | `test_r6_upgrades_are_worth_buying` | The five-seed comparison |
| R7 | `test_r7_upgrades_are_saved` | Ranks round-trip through JSON with their effects; a version 1 dictionary loads with rank 0; each bad rank is refused by name |
| R8 | `test_r8_sim_command_upgrades` (py) | Ranks in the JSON; `--buy-upgrades` gives ranks above 0 |

## Out of scope

- Any screen, button or key for buying (spec 017).
- Per-hero upgrades, equipment, items, talents, anything that is not party-wide.
- Buying automatically in the real game. `--buy-upgrades` is for the headless tool and the R6 test only.
- Refunds, respec, upgrades that cost anything but gold.

## Paths

- `sim/defs/upgrade_def.gd`, `sim/defs/content.gd`, `data/upgrades/`
- `sim/party/`, `sim/simulation.gd`, `sim/sim_event.gd`, `sim/expedition/expedition.gd`
- `tools/dev.py`, `tools/godot/run_sim.gd`, `tools/godot/validate_data.gd`, `tools/tests/`
- `tests/acceptance/test_016_camp_upgrades.gd`, `tests/unit/test_upgrades*.gd`
- `tests/acceptance/test_014_save_progress.gd`, `tests/unit/test_save_progress.gd` (only where they assert the
  version is 1 or that version 2 is refused)
- `docs/architecture.md` (the "Saving" section), `docs/wiki/index.html`

## Open questions

None.
