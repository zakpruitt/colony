# 029 — Hero training: upgrade each hero from their sheet

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 014, 016, 022, 026
- **Pull request:** [#29](https://github.com/zakpruitt/colony/pull/29)

## Intent

Camp upgrades lift the whole party at once, so there is nothing to decide about any one hero. Zak asked for
a way to upgrade each character from their own UI. This spec adds **training**: gold spent on one hero, from
that hero's sheet, to make them hit harder, last longer or strike faster. It gives the player a real choice
(a tougher knight or a deadlier rogue?) and makes the hero sheet the place heroes are managed.

## Requirements

- **R1. Three trainings exist as data,** each a valid `TrainingDef` under `data/training/`:

  | Id | Name | Per rank | Ranks |
  |---|---|---|---|
  | `power` | Power | +5% damage and healing | 20 |
  | `toughness` | Toughness | +5% maximum health | 20 |
  | `quickness` | Quickness | +3% attack speed | 10 |

  Each has a base cost and a growth factor; the price of a hero's next rank depends only on that hero's
  current rank in it.
- **R2. Training is per hero.** `Simulation.train_hero(hero_id, training_id)` takes effect at the next
  step: if the party has the gold and the hero is below the maximum rank, the gold is taken, that hero's
  rank rises by one, and a `HERO_TRAINED` event is raised (source: the hero, target: the training's position
  in `Content.training_ids()`, amount: the new rank). Otherwise nothing happens. No other hero changes.
- **R3. It stacks with camp upgrades.** A hero's damage, healing, health and attack speed are their base
  values times the camp upgrade's multiplier times their training's multiplier. Raising toughness raises
  maximum health at once and leaves current health as it is (a living hero is not healed or hurt by it).
- **R4. It is saved.** Each hero's ranks are in the save; the version rises by one, and a save of the
  previous version loads with all ranks at zero through the upgrade step. Bad values are refused by name.
- **R5. Untrained changes nothing.** With no training bought, a simulation's state hash is the same, tick
  for tick, as before this spec, and every existing test passes (apart from assertions about the save
  version or the exact saved dictionary, which may be updated).
- **R6. The sheet has a Training section.** Under the stats, one row per training: its name, the hero's
  rank (`3/20`), the bonus so far (`+15%`), and a price button, yellow when affordable, dim red when not,
  `MAX` at the top rank, in the shop rows' style. Clicking the button, or pressing `1`, `2` or `3` while
  the sheet is open, trains the shown hero. The row flashes on a purchase, the gold count drops at once,
  and the stat block above shows the new value and its bonus on the next frame.
- **R7. The bonus is visible in the stats.** A stat raised by training shows the combined bonus of camp
  upgrade and training in green beside it, as spec 026 does for upgrades alone.
- **R8. The sheet still fits.** With the Training section, the sheet stays inside the screen, below the top
  band and at least 12 px above the party frames, for all four heroes, with every label legible and none
  overlapping. If the hero sheet has gained a Microskills section (spec 028) by the time you merge, both
  sections must fit.
- **R9. Number keys do not fight.** `1` to `5` buy camp upgrades only while the shop is open; `1` to `3`
  train only while the sheet is open; the two are never open together.
- **R10. Auto-buy leaves training alone.** With auto-buy on, no hero is ever trained by the game itself.
- **R11. It is sensible.** Each training's first rank costs between one and two times the cheapest camp
  upgrade's first rank. A one-hour run with `stable_seconds` 120 that spends all its gold on one hero's
  power ends with that hero dealing visibly more damage per hit than an untrained twin (at least 25%).

## Interfaces

```gdscript
# sim/defs/training_def.gd
class_name TrainingDef
extends Resource
enum Stat { POWER, TOUGHNESS, QUICKNESS }
@export var id: StringName
@export var display_name: String
@export var description: String
@export var order: int
@export var stat: Stat
@export var per_rank: float
@export var base_cost: int
@export var cost_growth: float
@export var max_rank: int
func validate() -> PackedStringArray

# sim/defs/content.gd gains
static func training(id: StringName) -> TrainingDef
static func training_ids() -> Array[StringName]      # in `order`

# sim/party/hero.gd gains
func training_rank(id: StringName) -> int
func training_cost(id: StringName) -> int            # price of the next rank; 0 at the maximum
func training_multiplier(stat: TrainingDef.Stat) -> float

# sim/simulation.gd gains
func train_hero(hero_id: int, training_id: StringName) -> void

# sim/sim_event.gd: Kind.HERO_TRAINED, placed before ENCOUNTER_STARTED

# game/hud/hero_sheet.gd gains
func train_row(index: int) -> void                   # what the button and the number key do
## `line` gains &"training_power", &"training_toughness", &"training_quickness":
## "<name> <rank>/<max> <bonus> <price or MAX>".
```

## Acceptance

In `tests/acceptance/test_029_hero_training.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_trainings_are_valid` | The three load and validate; prices by rank |
| R2 | `test_r2_training_is_per_hero` | Gold, rank and the event after the step; nothing without gold or at the maximum; other heroes unchanged |
| R3 | `test_r3_stacks_with_upgrades` | Each stat against base times both multipliers, in and out of a fight; current health untouched by toughness |
| R4 | `test_r4_saved` | Round trip; the previous version loads at zero; bad values refused by name |
| R5 | `test_r5_untrained_changes_nothing` | Hashes at sampled ticks over 20 minutes on two seeds equal values recorded before the change |
| R6 | `test_r6_training_section` | Each row's text and colours for affordable, unaffordable and maximum; the button and the keys train; the flash; gold and stats follow |
| R7 | `test_r7_bonus_is_visible` | The combined green bonus with an upgrade and a training |
| R8 | `test_r8_sheet_still_fits` | The sheet's rectangle and its labels for each hero |
| R9 | `test_r9_number_keys` | `1` with the shop open buys and trains nobody; `1` with the sheet open trains and buys nothing; `1` with neither does nothing |
| R10 | `test_r10_auto_buy_leaves_training` | Ten minutes of auto-buy with plenty of gold trains nobody |
| R11 | `test_r11_it_is_sensible` | The price statement and the 25% statement |

For R5, record the hashes of an untouched simulation before changing any `sim/` code.

**To look at, and for Zak:** in a throwaway scene you do not commit, open a hero's sheet with some gold,
take a shot, train twice, and take another. Crop and enlarge. Is it obvious what each training does, what
it costs and what changed? Describe the shots.

## Out of scope

- Equipment, talents, respec or refunds.
- Auto-training, or any change to auto-buy beyond R10.
- New sprites or sounds (a purchase may play the existing `ui_buy`).

## Paths

- `sim/defs/training_def.gd`, `sim/defs/content.gd`, `sim/party/hero.gd`, `sim/party/party.gd`,
  `sim/simulation.gd`, `sim/sim_event.gd`
- `data/training/` (new); `tools/` only if the `data` check step must learn the new folder
- `game/hud/hero_sheet.gd`, `game/hud/hud.gd` (the number keys only), `game/audio/sound_player.gd`
  (playing `ui_buy` for `HERO_TRAINED` only)
- `tests/acceptance/test_029_hero_training.gd`, `tests/unit/test_hero*.gd`
- Existing tests only where they assert the save version, the exact saved dictionary, the sheet's size or
  its list of lines, or list every event kind (say which)
- `docs/architecture.md` (the "Saving" section), `docs/wiki/index.html`

## Open questions

None.
