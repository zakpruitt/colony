# 110 — Skill paths: ranks earned by use

- **Status:** in progress (approved 2026-11-27)
- **Milestone:** M8
- **Depends on:** 109
- **Pull request:** —

## Intent

After spec 109, a hero can learn any path's capstone as soon as it has the points. Zak wants paths to
rank up through use, as skills do in Skyrim. A path a hero fights with grows, and its deeper tiers
open only when it has grown enough. This spec adds that rule, the data that tunes it, and its save.
The tab gains only what it needs to say why a node is shut. Spec 111 draws it properly.

## Requirements

- **R1. Path XP from won fights.**
  - When the party wins a fight, every hero in the party gains path XP in each of its class's three
    paths. That includes a hero who fell during the fight.
  - The amount for a path is (nodes the hero holds in that path) + (times that path's abilities
    acted or fired for that hero in that fight). "Acted or fired" means an `ABILITY_USED` event with
    the hero as source, strike boosts included.
  - Each ability counts at most `uses_counted` times a fight (tunable data, starting at 3). Without
    the cap, a passive that fires on every strike, such as Poisoned Blades, would rank its path many
    times faster than a path of actions.
  - A lost fight, or one the expedition ends at its 90-second limit, gives no path XP.
  - A hero with no nodes gains nothing. A run that takes no talents keeps every path at 0.
- **R2. Ranks.**
  - A path's rank is the number of thresholds in its class tree's `rank_xp` that its XP has reached.
    `rank_xp` is a rising list of totals, one per rank (tunable data).
  - Every path starts at rank 0, and a rank never goes down.
  - When a won fight raises a path's rank, `PATH_RANKED` reports it, once for each rank passed, in
    rank order. Its source is the hero, its target the path's index (0 to 2), and its amount the new
    rank.
  - XP past the top rank still counts but raises nothing.
- **R3. Deeper tiers need a rank.**
  - A node can be taken only if its path's rank is at least `tier_ranks[tier - 1]` (tunable data,
    starting at `[0, 2, 5, 9]`), as well as everything spec 109 R3 asks.
  - A command for a node its path's rank still holds shut does nothing and sends no event.
  - A node already held stays held, whatever happens.
- **R4. The data check.**
  - `rank_xp` is not empty and every total in it is above the one before; the first is above 0.
  - `tier_ranks` has four entries. The first is 0, none is below the one before, and the last is no
    higher than the number of ranks.
  - `uses_counted` is 0 or more.
  - Each fault is refused by name.
  - The starting values are the same in all four trees:
    `rank_xp = [10, 25, 50, 90, 150, 240, 350, 490, 650, 850]` (ten ranks),
    `tier_ranks = [0, 2, 5, 9]`, `uses_counted = 3`. The lane tunes them under R7.
- **R5. A fresh start keeps the ranks.** `reset_talents` gives back every talent point as spec 109
  R5 says. Every path keeps its XP and rank, and paragon stays.
- **R6. Saves (version 11).**
  - Each hero's save carries `paths`: its XP in each of its three paths, in path order. A round trip
    keeps it.
  - A version 10 save loads with every hero's talents given back and every path at 0. This is Zak's
    rule for saves from before path ranks: a free re-pick, ranks from 0. Version 9 and earlier reach
    the same through 9 to 10 and then 10 to 11.
  - The check refuses each of these by name (`heroes[2].paths`, `heroes[0].talents[3]`):
    - `paths` missing, not a list of three, or holding anything but whole numbers of 0 or more;
    - a node held whose tier needs a higher rank than its path's saved XP gives.
- **R7. A capstone in a fair stretch of play.**
  - The runs: `python tools/dev.py sim --seed=N --minutes=180 --spend-talents --buy-upgrades
    --winding`, for N = 1, 2 and 3.
  - Every hero learns its first capstone between 25 and 50 minutes of game time. Today's run reaches
    level 10, the earliest a fifth point allows a capstone, at about 15 to 17 minutes. Level 14 comes
    at about 30 and level 18 at about 45.
  - Every hero holds all fifteen nodes by the end of the 180 minutes. Today's run reaches level 30,
    the fifteenth point, at about 120 minutes.
  - The lane tunes `rank_xp` (and, if it must, `uses_counted`) until both hold, and reports the
    numbers it settled on with each hero's times.
- **R8. Still deterministic, and the hash of a run that spends nothing is unchanged.**
  - The state hash includes a hero's path XP only while some of it is above 0, as it includes talents
    only once a hero has grown. Spec 016's recorded hashes, and the others recorded for runs that
    spend nothing, pass unchanged.
  - Two runs with spending agree.
- **R9. The tab says why a node is shut.** This is the least the tab needs. Spec 111 is the real
  window.
  - Each path's banner shows `Rank N`.
  - A node its path's rank still holds shut is drawn locked. Its card and the strip say
    `Rank 5 in Guardian opens this` (the rank needed and the path's name).
  - A click on such a node takes nothing.
- **R10. The headless run.**
  - `TalentSpender` keeps its order (spec 109 R12) but passes over nodes the rank still holds shut.
    So a point goes to another path's open node rather than wait.
  - Each hero in `run_sim.gd`'s summary gains `"ranks"` (its three path ranks at the end),
    `"capstone_at"` (the game seconds when it learned its first tier-4 node, or null) and
    `"full_at"` (when it held all fifteen, or null).

## How the numbers were chosen

These are measured on `dev` before spec 109:
`python tools/dev.py sim --spend-talents --buy-upgrades --winding`, on seeds 1 to 3.

| Game minutes | 5 | 10 | 15 | 20 | 30 | 45 | 60 | 90 | 120 | 240 |
|---|---|---|---|---|---|---|---|---|---|---|
| Party level | 4–5 | 6 | 9–10 | 11 | 14–15 | 17–18 | 20–21 | 25 | 29–30 | 42 |
| Fights won | 14–18 | 30 | 34–49 | 44–65 | 94–99 | 135–142 | 172–184 | 264–270 | 337–352 | 625–647 |

That is about three won fights a minute. Under the spender, the first path's tier 1 comes at level 2
(about 2 minutes), and later points come at about 5, 10, 13 and 16 minutes.

If a path earns about 2.5 XP a fight with one node, rising to about 10 with four, its XP is about 20
by level 4. With rank 2 at 25, that opens tier 2 about one point late. Its XP is about 150 to 250 by
levels 8 to 10, when rank 5 opens tier 3, and about 650 by 30 minutes, when rank 9 opens the
capstone.

Uses per fight are a guess until the rule runs. That is why R7 is a measured requirement and the
table is tunable.

## Interfaces

```gdscript
# sim/defs/talent_tree_def.gd: three new fields, read by the rules
@export var rank_xp: Array[int] = []      # total path XP for ranks 1, 2 … in order
@export var tier_ranks: Array[int] = []   # the rank each tier needs: four entries
@export var uses_counted: int = 3         # most uses of one ability counted in one fight
func rank_at(xp: int) -> int
func rank_needed(ability_id: StringName) -> int   # 0 for a node not in the tree

# sim/party/path_ranks.gd: one hero's XP in its class's three paths
class_name PathRanks
extends RefCounted
func xp(path: int) -> int
func rank(path: int, tree: TalentTreeDef) -> int
## Adds amount (0 or more) to path's XP; returns the rank before.
func add(path: int, amount: int, tree: TalentTreeDef) -> int
func set_xp(path: int, value: int) -> void      # loading a save, tests
func any() -> bool                              # some XP above 0

# sim/party/hero.gd: a field, not a method (Hero stays at 19 public methods after spec 109)
var ranks: PathRanks = PathRanks.new()
# can_take adds the rank rule; the save, the spender and the tab ask hero.ranks.

# sim/combat/combatant.gd: every ABILITY_USED it is the source of, by ability, this fight;
# cleared by reset_abilities.
var uses: Dictionary[StringName, int] = {}

# sim/expedition/path_training.gd: the path XP for a won fight, kept out of Expedition (882 of 900
# lines). Expedition._end_battle calls it once when the heroes win; it emits as ResourceDrops does.
class_name PathTraining
extends RefCounted
static func after_win(run: Expedition, fought: Battle) -> void

# sim/sim_event.gd: after TALENTS_RESET, among the rarer kinds
PATH_RANKED
```

`Simulation.SAVE_VERSION` becomes 11, with `TalentSave.upgrade_10_to_11`. The ranks need no new
command, so `Simulation`'s method count does not change. `Party.hash_parts` adds a hero's path XP
only while `ranks.any()`. `Expedition` grows by the call only.

## Acceptance

In `tests/acceptance/test_110_ranks_by_use.gd`, one test per requirement named `test_rN_…`, each
written before its code and seen to fail.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_path_xp_from_won_fights` | A built battle with known uses. Each path gains its nodes plus its uses, capped at `uses_counted`; a fallen hero gains too. A lost fight and a limit-ended fight give nothing. A bare hero gains nothing |
| R2 | `test_r2_ranks` | Rank by the thresholds, with one `PATH_RANKED` per rank passed in order. No rank above the top, and none ever lower |
| R3 | `test_r3_deeper_tiers_need_a_rank` | Tier 2 refused at rank 1 and taken at rank 2, and the same for tiers 3 and 4. A refusal sends no event |
| R4 | `test_r4_the_data_check` | Each bad table is refused by name. The four trees pass |
| R5 | `test_r5_reset_keeps_ranks` | XP and ranks the same after a reset; points back |
| R6 | `test_r6_saves` | A round trip. A version 10 save with deep nodes loads bare at rank 0. Each bad `paths`, and a node above its path's saved rank, refused by name |
| R7 | `tools/tests/godot/test_110_capstone_in_fair_time.py` | The three 180-minute runs: every `capstone_at` between 1500 and 3000 seconds, and every `full_at` not null |
| R8 | `test_r8_deterministic_and_hash_kept` | Two spending runs agree; a hero with no XP hashes as before |
| R9 | `test_r9_the_tab_says_why` | Real mouse motion and clicks. The banner's rank, the locked node, the card's and the strip's words, and a click that takes nothing |
| R10 | `test_r10_spender_and_summary` (in the R7 script) | Points are not left waiting when another path's node is open. The summary's three new fields |

**To report for Zak:** the settled `rank_xp`, `tier_ranks` and `uses_counted`, and for each seed and
class the minute of its first capstone and of its fifteenth node. Say which paths rank fastest and
slowest and why.

## Tests that change

- `tests/colony_test.gd`: `_spend_talents` sets nodes directly. It must also give each path the XP
  its deepest held tier needs. Otherwise a hero it raised breaks R6's check when a test saves and
  loads it (tests 037, 041, 042, 046 and 092 call it).
- `tests/acceptance/test_109_three_paths_of_five.gd`, `test_109_every_ability_is_seen.gd` and
  `talent_tree_test_base.gd`: where they take a deep node by command, they first give the path the
  XP it needs (`hero.ranks.set_xp`). R8's play needs no change, since the spender respects ranks.
- `tests/acceptance/test_051_talent_trees_and_paragon.gd`, `test_014_save_progress.gd`,
  `test_093_side_paths_and_caches.gd` and `test_096_the_order_to_press_on.gd`: their save version
  asserts (10 becomes 11).
- `tests/acceptance/test_055_the_tree_on_the_sheet.gd`, `test_060_hero_windows.gd` and
  `test_064_the_talent_tree_as_a_tree.gd`: only where they click a deep node to take it.
- `tools/tests/godot/test_051_sim_talents.py`: only if the rank rule changes what it sees.

## Out of scope

- The rank bars, the rank-up and capstone moments, journal lines for ranks, the showcase and the
  wiki (spec 111). This spec changes only the wiki lines that would be false.
- XP from anything but won fights. Ranks that make abilities stronger. Different tables per path.
  Spending gold or resources for rank.

## Paths

- `sim/defs/talent_tree_def.gd`, `sim/party/path_ranks.gd` (new), `sim/party/hero.gd`,
  `sim/party/party.gd` (the hash), `sim/combat/combatant.gd`, `sim/combat/battle.gd` and
  `sim/combat/battle_abilities.gd` (counting uses only), `sim/expedition/path_training.gd` (new),
  `sim/expedition/expedition.gd` (the one call), `sim/sim_event.gd`, `sim/talent_save.gd`,
  `sim/simulation.gd` (the version and the upgrade step only), each new script's `.uid`
- `data/talents/`
- `game/ui/windows/path_banner.gd`, `hero_talents_tab.gd`, `talent_tree_view.gd`, `talent_node.gd`
  and `next_strip.gd` (R9 only)
- `tools/godot/talent_spender.gd`, `tools/godot/run_sim.gd`, `tools/dev.py` (its usage line, if a
  flag changes)
- `tests/acceptance/test_110_ranks_by_use.gd` and its `.uid`,
  `tools/tests/godot/test_110_capstone_in_fair_time.py`, and the files in "Tests that change"
- `docs/architecture.md` (the save version and the path ranks), `docs/wiki/index.html` (lines this
  makes false)
- `tests/acceptance/test_092_the_game_plays_winding_stages.gd` (the save version it asserts as a literal, 9, becomes the new version; nothing else)

## Open questions

None.
