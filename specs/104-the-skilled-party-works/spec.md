# 104 — The skilled party works, and it takes time

- **Status:** in-progress
- **Milestone:** M0
- **Depends on:** 025, 093, 103
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

Today a quest takes 3 to 6 seconds and only one hero does it: the living hero with the microskill and the lowest id. This spec changes two things:

- **Longer work.** A quest now takes 10 to 15 seconds.
- **Every able hero works.** Every living hero with the quest's microskill works on it, and each extra worker shortens the job.

This is the simulation half of making a quest a little scene. Spec 105 (chat bubbles) and spec 106 (the scene on screen) build on it. The time comes from one function, so later microskill upgrades have one place to shorten it.

## Requirements

- **R1. Quests take longer.**
  - The quests' `work_seconds` become:

    | Quest | `work_seconds` |
    |---|---|
    | `tripwire` | 10 |
    | `locked_chest` | 12 |
    | `hurt_wanderer` | 12 |
    | `stuck_door` | 14 |
    | `rune_stone` | 14 |

  - `QuestDef.work_range()` (spec 103's `JobDef`) becomes 8 to 18 seconds (both ends included), so `validate()` reports a value outside it.
  - Gates (`GateDef`, 3 to 6 seconds) are unchanged.
- **R2. Every living hero with the microskill works.**
  - When the party meets a quest, the workers are every living hero who has its microskill, in ascending id order.
  - The first worker is the *lead*:
    - `Expedition.worker_id()` returns the lead.
    - `QUEST_STARTED.source_id`, `QUEST_DONE.source_id`, the `GOLD_GAINED` it pays and `ResourceDrops.on_quest` all use the lead, as the single worker does today.
  - A dead hero, or one without the skill, does not work.
  - With nobody able, the party does what it does today (it walks past, or the hazard springs).
- **R3. Helpers shorten the work.**
  - With `n` workers the job takes `maxi(roundi(base_ticks / (1.0 + QuestWork.HELPER_SHARE * (n - 1))), 1)` ticks.
    - `base_ticks` is `Combatant.seconds_to_ticks(def.work_seconds)`.
    - `HELPER_SHARE` is 0.35 (tunable).
  - At 10 ticks a second, a 12-second quest takes:

    | Workers | Ticks |
    |---|---|
    | 1 | 120 |
    | 2 | 89 |
    | 3 | 71 |

  - `QUEST_STARTED.amount` is that shortened count. `work_progress()` runs from 0 to 1 over it.
- **R4. Everyone working can be read.**
  - `QuestWork.workers(run)` returns the ids of everyone working, lead first:
    - all of the workers while a quest is worked;
    - only the opener while a gate is worked;
    - an empty array otherwise.
  - The workers are part of `Expedition.hash_parts()`.
- **R5. Nothing else changes.**
  - A quest's reward does not depend on how many worked.
  - Gates are opened by one hero in their own 3 to 6 seconds, as today.
  - Saves are unchanged. Work in progress is not saved today (a loaded run arrives `TRAVELLING`, `Arrival`), and this spec does not start saving it.

## Interfaces

```gdscript
# sim/expedition/quest_work.gd
## Each worker past the first shortens a quest's work by this share of one worker's pace.
const HELPER_SHARE: float = 0.35
## The ticks a quest takes with [param worker_count] workers (at least 1 each way).
static func work_ticks(def: QuestDef, worker_count: int) -> int
## Everyone working now, lead first; empty when the party is not WORKING.
static func workers(run: Expedition) -> Array[int]

# sim/party/party.gd
## Every living hero with this microskill, in ascending id order.
func heroes_with_microskill(id: StringName) -> Array[Hero]

# sim/expedition/expedition.gd: a private field beside _worker, set by QuestWork and SidePathWalk
var _workers: Array[int] = []
```

Notes on these:

- `Party.hero_with_microskill` stays as it is. Gates and other callers use it.
- `Expedition` gains no public method. It is at gdlint's cap of 20 public methods, and its file is held to 900 lines.

## Acceptance

One test per requirement, in `tests/acceptance/test_104_the_skilled_party_works.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_quests_take_ten_to_fifteen_seconds` | Each quest's `work_seconds` matches the table. A def at 7.9 or 18.1 is reported and one at 8 or 18 is not. Every gate is still from 3 to 6 |
| R2 | `test_r2_every_able_hero_works` | Two level-3 clerics and a knight meet `hurt_wanderer`: both clerics work, the lower id is the lead and is the source of STARTED, DONE and GOLD_GAINED. With one cleric dead, only the other works. With no cleric, the party walks past |
| R3 | `test_r3_helpers_shorten_the_work` | One worker takes 120 ticks on a 12 s quest, two take 89, three take 71 (`work_ticks`, and a stepped run whose STARTED amount and time to DONE match) |
| R4 | `test_r4_the_workers_can_be_read` | `workers()` lists every worker lead first while working on a quest, only the opener at a gate, and is empty while travelling. Two runs that differ only in a second cleric's level hash differently while working |
| R5 | `test_r5_the_reward_does_not_depend_on_workers` | The same quest at the same depth pays the same gold with one worker and with two. A gate's work time and opener are as before |

Existing tests:

- **`test_025_microskills_and_side_quests.gd`.** It asserts 3 to 6 seconds and "the work takes `work_seconds`" with two lockpickers, so it follows R1 and R3. The assertions change to the new range, and to `QuestWork.work_ticks` with the workers it set up. The lowest-id check stays, read as the lead.
- **Tests that record a run's hashes.** Longer quests change the timeline of any run that meets one. Re-record each recorded value that changes, the way specs 025, 036 and 052 did. Add a line to the recording's comment ("Re-recorded by spec 104, whose quests take longer and are worked by every able hero"). Change no assertion.

For Zak's playtest: quests feel long enough to notice, but not so long they stall the run. Compare `python tools/dev.py sim --seed=7 --minutes=30 --winding` gold and XP per hour before and after (put both in the pull request).

## Out of scope

- Anything on screen: other workers walking to the prop, sitting heroes, poses, chat bubbles, new props. Those are specs 105 and 106. Until 106 lands, the view still moves and swings only the lead (`worker_id()`). Leave it so.
- Microskill upgrades or ranks. Only the one `work_ticks` function exists, for them to change later.
- Changing rewards, `QUEST_SHARE`, which quests exist, or gates.
- Saving work in progress.
- A worker dying mid-job. Nothing can hurt the party while it is `WORKING`.

## Paths

- `sim/expedition/quest_work.gd`
- `sim/expedition/expedition.gd` (the `_workers` field and its place in `hash_parts` only)
- `sim/expedition/side_path_walk.gd` (set and clear `_workers` beside `_worker`)
- `sim/party/party.gd`
- `sim/defs/quest_def.gd`
- `data/quests/*.tres`
- `tests/acceptance/test_104_the_skilled_party_works.gd` and its `.uid`
- `tests/acceptance/test_025_microskills_and_side_quests.gd` (the work-time and range assertions)
- The recorded hash values, and their comments, in any of these that change:
  - `tests/acceptance/resources_052_test_base.gd`
  - `test_016_camp_upgrades.gd`
  - `test_024_guardian_fights.gd`
  - `test_035_party_orders.gd`
  - `test_038_rough_edges.gd`
  - `test_039_the_countdown.gd`
  - `test_040_orders_that_hold.gd`
  - `test_050_abilities_in_combat.gd`
  - `test_052_resources_kept.gd`
  - `test_093_side_paths_and_caches.gd`
  - `test_096_the_order_to_press_on.gd`
  - `test_100_rooms_shaped_like_caves.gd`
  - `test_101_what_stands_in_a_cave.gd`
  - `test_079_effect_nodes.gd`
  - `test_080_frame_pieces.gd`

  If a test outside this list breaks only because a run's timing moved, stop and report it.
- `docs/architecture.md` (the "Quests and microskills" section)
- `docs/wiki/index.html`

## Open questions

None.
