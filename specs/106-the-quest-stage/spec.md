# 106 — The quest's stage

- **Status:** approved (2026-11-24)
- **Milestone:** M0
- **Depends on:** 028, 100, 102, 103, 104, 105
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

A quest stops being a prop in the middle of a room with one hero swinging at it. It becomes a stage:

- The prop stands toward the far side of the room.
- Every hero who works it (spec 104) walks over and works.
- Everyone else sits down where they stopped and watches.
- The prop changes as the job goes: a chest's lid opens, a door swings open, runes light up, a wire goes slack. The wanderer gets to their feet and walks out.

The props are redrawn simply, with the states this needs. They are placeholders; Zak will replace them. Each prop also has three looks, a tint and a little dressing, so no two rooms show quite the same quest.

Spec 107 then gives each worker their own way of doing the job, and gives the scene its lines.

## Requirements

- **R1. The prop stands toward the far side of its room.**
  - A quest's prop stands on the room's floor (`WorldPlaces.floor_line`), at two-thirds of the way across the room's floor. "Across" is in the direction the stage's course runs through that room (`StageCourse.heading_at` at the room's middle), so the party walks in at the near end.
  - Its x is clamped so it stands at least 2 tiles from the room's walls. The walls are taken from the room's shape (`LabyrinthView.shapes(depth).shape_of(room)`), not its rectangle.
  - A room whose open floor is under 6 tiles keeps the prop at its middle.
- **R2. Every worker works at the prop.**
  - While the party is `WORKING` a quest, each id in `QuestWork.workers(run)` walks to a work spot and faces the prop:
    - the lead stands `WORK_GAP` short of it, on the side the party came from;
    - the second stands `WORK_GAP` past it, on the far side;
    - a third or fourth stands 7 pixels behind the lead or the second.
  - Each worker swings on the slow repeat it has today (`QuestProps.SWING_SECONDS`), and only once it has arrived. The swings are offset by 0.27 s a worker, so they do not strike together.
  - A gate is worked as today: one opener, beside it.
- **R3. Everyone else sits and watches.**
  - While the party works a quest, every living hero who is not a worker stays where the simulation has them. Once they have stopped, they sit (`CharacterSprite.sitting`, the camp's pose from spec 102) facing the prop.
  - When the work ends they stand and walk on.
  - The dead are unchanged (`FallenParty`).
  - No campfire or bedrolls appear. If the party rests after a fight, the camp (`CampView`) is unchanged.
- **R4. The props have states.** Each prop's sheet is redrawn in the master palette (it passes `art.py lint`) with these parts:

  | Quest | Before | While worked | When done |
  |---|---|---|---|
  | `locked_chest` (`chest.px`) | `locked` | `locked` | `open`, lid up |
  | `stuck_door` (`door.px`) | `stuck` | `stuck` | `open`, swung back |
  | `rune_stone` (`stone.px`) | `dim` | `dim` + a `rune_1`..`rune_4` overlay, one more lit for each quarter of `work_progress()` | `lit` |
  | `tripwire` (`wire.px`) | `taut` | `taut` | `slack` |
  | `hurt_wanderer` (`wanderer.px`, 16x24) | `hurt`, slumped on the floor | `hurt` | `stand`, then `walk_0`/`walk_1` |

  - Each sheet's parts share one pivot, at the bottom centre, so a change of state does not jump.
  - The wanderer is drawn as a small hooded traveller, the height of a hero's body, with a bandage. It must not be mistaken for a hero.
- **R5. A done prop stays done, and the wanderer leaves.**
  - On `QUEST_DONE` the prop switches to its done part. A done chest, door, stone or wire stays in that state until its room holds something again (a quest or monsters on a later visit) or the party leaves the stage. Then it is removed as a prop is today.
  - The wanderer stands for 0.6 s. Then it walks, alternating `walk_0` and `walk_1`, at a hero's walking pace, back the way the party came, and is removed once it is out of its room.
  - A game loaded from a save shows no done props.
- **R6. Late or skipped events snap.**
  - On a `QUEST_DONE` that `World.may_animate` refuses, or during a catch-up, the prop takes its done part at once. A wanderer is removed at once and does not walk.
  - The sitting and the work spots follow the simulation's state every frame, so a catch-up needs nothing more for them.
- **R7. The bar stays readable.**
  - The progress bar and the microskill's name are drawn over the prop's middle, `BAR_RAISE` above the floor, and no longer between the worker and the prop.
  - With two or more workers the name is followed by `×N` (for example `Mender ×2`).
- **R8. The showcase shows each quest.**
  - The `quest_done` row is replaced by one row for each of the five quests ("A QUEST: …"), each seen at its `QUEST_DONE`.
  - One more row, "TWO CLERICS MEND A WANDERER", sets up two clerics and is seen while both work.

- **R9. Each room's quest looks a little different.** Two chests in two rooms should not look like copies.
  - Each prop sheet has **3 looks**, each with every part R4 lists for that quest:

    | Quest | Looks |
    |---|---|
    | chest | a plain wooden chest, an iron-banded one, a small round-lidded coffer |
    | door | planks, iron-studded, round-topped |
    | stone | tall, squat, cracked and leaning |
    | wire | a plain wire, a wire hung with little bells, a wire to a dart box on the wall |
    | wanderer | a hooded traveller, a miner with a pick on their back, a robed pilgrim |

  - Look parts are named `<look>_<state>`, for example `iron_open`.
  - On top of its look, each prop takes:
    - a tint from a short list of palette swaps (3 for each quest, for example cloak or wood colours);
    - a facing: mirrored or not, except the door, which hangs on the wall side.
  - **Dressing.** Each prop has 1 to 3 small dressing pieces on the floor within 2 tiles of it, chosen from its quest's own list, for example:
    - wanderer: a dropped pack, a spilled lantern;
    - chest: a few loose coins, an old bone;
    - door: broken planks;
    - stone: stubby candles;
    - wire: a skull, a spent dart.

    These are new small sprites in `assets/sprites/props/quest_dressing.px`, or existing ambience sprites where one fits. Dressing never stands on a work spot (R2), and it goes with its prop.
  - The look, tint, facing and dressing are chosen from a `RandomNumberGenerator` seeded from the area, the depth and the chamber index, never the simulation's stream. So a room shows the same quest the same way every time it is seen, and different rooms differ.
  - The quest's states (R4 and R5) play the same in every look.

## Interfaces

```gdscript
# game/world/quest_props.gd
## Where a quest's prop stands in that chamber (R1).
func spot(depth: int, chamber_index: int) -> Vector2
## The part a chamber's prop shows now (&"locked", &"open", &"hurt", ...), or &"" with none.
func part_of(depth: int, chamber_index: int) -> StringName
## True while that chamber shows a done prop (R5); the wanderer while it walks off.
func is_done(depth: int, chamber_index: int) -> bool

# game/world/quest_stage.gd (new): who stands where while the party works a quest
class_name QuestStage
extends RefCounted
func goal_for(id: int, goal: Vector2) -> Vector2   # chained in World._follow like CampView's
func sits(id: int) -> bool
func facing_of(id: int, otherwise: int) -> int
```

## Acceptance

One test per requirement, in `tests/acceptance/test_106_the_quest_stage.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_prop_stands_on_the_far_side` | In a wide room the prop is past the room's middle in the course's direction, at least 2 tiles from the shaped wall, and on the floor line. In a room narrower than 6 tiles it is at the middle. Tried on rooms whose course runs each way |
| R2 | `test_r2_every_worker_works_at_the_prop` | With two clerics on `hurt_wanderer`, both reach their spots, one on each side, and both face the prop. Each swings (the `worked` signal fires for both ids), not on the same frame. A gate still has one opener |
| R3 | `test_r3_everyone_else_sits` | While working, the knight and the rogue are `sitting` and face the prop. The clerics are not sitting. After DONE, nobody is sitting. No campfire shows |
| R4 | `test_r4_the_props_have_states` | Each sheet has its parts with one shared pivot. The stone shows 0, 1, 2, 3, then 4 runes as the progress passes each quarter. `art.py lint` passes (the `art` step) |
| R5 | `test_r5_a_done_prop_stays_and_the_wanderer_leaves` | After DONE the chest's part is `open`, and it is still shown 10 s later. It goes when the stage changes. The wanderer stands, walks the way the party came, and is gone once out of its room |
| R6 | `test_r6_late_events_snap` | A DONE seen during a catch-up leaves the chest `open` at once and no wanderer at all |
| R7 | `test_r7_the_bar_over_the_prop` | The bar's middle is over the prop's x. The name reads "Mender ×2" with two workers and "Mender" with one |
| R8 | `test_r8_the_showcase_shows_each_quest` | Each new row exists, and a run of each is marked seen |
| R9 | `test_r9_each_room_looks_its_own` | Over 40 chambers holding each quest, at least 3 different (look, tint, facing) combinations show. The same chamber built twice shows the same look and dressing. No dressing stands on a work spot. Every look has every state's part |

Existing tests:

- `test_028_seeing_side_quests.gd` checks the prop at the room's middle, a single worker's spot and the bar between the worker and the prop. Change those checks to R1, R2 and R7. Leave everything else in it.
- `test_092_the_game_plays_winding_stages.gd` names the `quest_done` row; it follows R8.

For Zak's playtest, and for the lane's shots of every new showcase row at 1280x720 and `--ui-room=960x540`, with the props cropped and enlarged 3x:

- each prop reads as what it is, in both states;
- the wanderer reads as a person, not a hero;
- the three looks of each prop read as the same kind of thing, but clearly not copies;
- the sitting party reads as "waiting while their friend works".

## Out of scope

- New poses (kneeling, pushing, reading, tending), chat-bubble lines, heal glows, coins or motes. That is spec 107. Workers keep today's swing.
- Changing `QuestEffects`' words and burst on DONE, or the missed and sprung moments.
- Changing gates, caches or `SideProps`.
- Saving done props.

## Paths

- `game/world/quest_props.gd`
- `game/world/quest_stage.gd` (new) and its `.uid`
- `game/world/world.gd` (the goal chain in `_follow`, sitting and facing in `_act`, making the stage)
- `assets/sprites/props/chest.px`, `door.px`, `stone.px`, `wire.px`, `wanderer.px`, `quest_dressing.px` (new) and their baked `.png`/`.json`
- `game/world/quest_looks.gd` (new, if the lane wants the look, tint and dressing choice in its own class) and its `.uid`
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_106_the_quest_stage.gd` and its `.uid`
- `tests/acceptance/test_028_seeing_side_quests.gd` (the spot, worker and bar checks)
- `tests/acceptance/test_092_the_game_plays_winding_stages.gd` (the `quest_done` row's name only)
- `tests/support/play_fixture.gd` (only if a helper is shared)
- `docs/architecture.md` (World's children), `docs/wiki/index.html`

## Open questions

None.
