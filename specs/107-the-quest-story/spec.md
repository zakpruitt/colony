# 107 — The quest's story

- **Status:** in-progress
- **Milestone:** M0
- **Depends on:** 057, 104, 105, 106
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

Every quest plays out as a short story each time. Examples:

- **The wanderer.** A hurt wanderer cries for help. The cleric kneels, says something kind, tends them, then lifts a prayer; light settles on the wanderer, who thanks them and walks off.
- **The chest.** The rogue kneels at a chest and fiddles with it, mutters, and the lid pops open in a spill of coins.
- **The door.** The knight shoulders a stuck door until it gives.
- **The stone.** The mage reads a rune stone aloud as it lights up.

Each kind of job has its own pose. The lines live in data, several for each moment, so a story reads differently each time and more lines can be added without code. Spec 106 built the stage; this spec is the performance on it.

## Requirements

- **R1. Each job has its own pose.**
  - A quest's `work_move` names a looping `CharacterMoves` pose. A worker who has arrived plays it in place of today's swing.

    | Quest | `work_move` |
    |---|---|
    | `locked_chest` | `kneel_work` |
    | `tripwire` | `kneel_work` |
    | `stuck_door` | `push` |
    | `rune_stone` | `read` |
    | `hurt_wanderer` | `tend` |

  - The four new poses are drawn in code like the moves of spec 057:
    - `kneel_work`: down on one knee, hands working at the prop.
    - `push`: a shoulder into the prop, with a lean and recoil on each shove.
    - `read`: upright, one hand raised toward the prop, a slow sway.
    - `tend`: kneeling, leaning in, hands moving.
  - Each pose keeps the hero's feet on the floor line. Each pose calls `QuestProps.worked` once per cycle, so the sound of the work is kept.
- **R2. The wanderer is healed, not hit.**
  - From `work_progress() >= 0.75` until DONE, a cleric worker plays the existing `prayer` move once.
  - The heal light that spec 057 shows on a healed hero then stands on the wanderer.
  - Small rising heal sparkles show over the wanderer while it is tended, through `World.fx`.
- **R3. Each job ends visibly.** On `QUEST_DONE` there is a payoff for each quest, through `World.fx` and the effects the game already has. These go beside `QuestEffects`' words and burst, which stay.

  | Quest | Payoff |
  |---|---|
  | `locked_chest` | 5 to 8 coins (`FxCoin`) arc out of the open chest |
  | `stuck_door` | each `push` cycle puffs dust at the door's foot |
  | `rune_stone` | the runes flare once, and XP motes (`FxMote`) drift from the stone to each living hero |
  | `tripwire` | a small white snip spark where the wire was |
  | `hurt_wanderer` | the heal light of R2 |

- **R4. The lines are data.**
  - `QuestDef` gains `lines: Array[QuestLine]`.
  - Each line has:
    - a `beat`, one of `plea`, `arrive`, `work`, `watch`, `done`, `thanks`;
    - a `speaker`: `subject` (the wanderer), `worker` or `watcher` (a sitting hero);
    - a `class_id` (`&""` for any class);
    - its `text`, at most 48 characters.
  - `QuestDef.validate()` reports any of these:
    - a beat or speaker that is not one of the above;
    - a `class_id` that is not a hero class;
    - text over 48 characters;
    - a quest with fewer than 2 lines any worker can say for each of `arrive`, `work` and `done`;
    - `hurt_wanderer` with fewer than 3 `plea` and 2 `thanks` lines for its `subject`.
  - Every quest also has at least 2 `watch` lines.
  - The lane writes all of these lines, about 60 in total. They are light high fantasy, warm, a little funny, never modern slang. For example: "Help… please, over here!", "Easy now, I've got you.", "Bless you, friend!", "Hold the torch steady…", "Come on, you stubborn thing!", "Take your time, we'll wait."
- **R5. The lines are said at the story's beats.** All are said through `World.say_for` (spec 105):

  | Beat | Who says it | When |
  |---|---|---|
  | `plea` | the wanderer | at `QUEST_STARTED`, and once on `QUEST_MISSED` for it while the party walks past |
  | `arrive` | the lead | when they first reach their spot |
  | `work` | the workers in turn | as `work_progress()` passes 1/3 and 2/3 |
  | `watch` | one sitting hero, if any sit | as it passes 1/2 |
  | `done` | the lead | at `QUEST_DONE` |
  | `thanks` | the wanderer | 0.4 s after `done`, while it stands |

  - A line tagged with the speaker's class is chosen before an untagged one. Among the lines that fit, one is chosen at random.
  - A speaker that is not a character (the wanderer) is one `Callable` kept for the quest's whole story. Spec 105 matches a `Callable` speaker by identity, so only a kept `Callable` has its line replaced rather than stacked.
  - The choice uses a `RandomNumberGenerator` seeded from the chamber's key and the event's tick, so the same moment always says the same line. The simulation's random stream is never touched.
  - The beats follow `work_progress()`, not the wall clock, so at a higher speed the lines still come in order. At speed 4 or above, only `plea`, `done` and `thanks` are said.
- **R6. The microskill's name moves into the story.** The name over the bar (spec 106, R7) goes. The bar stays.
  - The `arrive` line's bubble is the first place the player sees who is working.
  - The journal's sentence for the quest is unchanged.
- **R7. Late events stay quiet.**
  - Nothing in R1 to R5 starts for an event `World.may_animate` refuses.
  - A catch-up stops the poses and clears the bubbles (spec 105 does the latter).
  - A worker who is not yet at their spot plays no pose.

## Interfaces

```gdscript
# sim/defs/quest_line.gd (new)
class_name QuestLine
extends Resource
@export var beat: StringName      # plea, arrive, work, watch, done, thanks
@export var speaker: StringName   # subject, worker, watcher
@export var class_id: StringName  # &"" for any class
@export var text: String

# sim/defs/quest_def.gd
@export var work_move: StringName
@export var lines: Array[QuestLine]
## The lines that fit (class-tagged first, then any), for the view to pick from.
func lines_for(beat: StringName, speaker: StringName, class_id: StringName) -> Array[QuestLine]

# game/world/quest_story.gd (new): says the beats and plays the poses; a World child or held by QuestProps
class_name QuestStory
extends Node
```

## Acceptance

One test per requirement, in `tests/acceptance/test_107_the_quest_story.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_each_job_has_its_pose` | Each quest's `work_move` is one of the four new poses. A worker on `stuck_door` plays `push`, not an attack. Each pose keeps the feet on the floor line over a cycle. `worked` fires once a cycle |
| R2 | `test_r2_the_wanderer_is_healed` | Past 0.75 progress the cleric plays `prayer` once, and the heal light shows on the wanderer's spot |
| R3 | `test_r3_each_job_ends_visibly` | DONE on the chest adds 5 to 8 coins. On the stone it adds one mote for each living hero. On the wire it adds a spark. A refused (stale) DONE adds none |
| R4 | `test_r4_the_lines_are_data` | Every quest validates. A copy with a bad beat, a bad class, a 49-character line or too few `arrive` lines is reported |
| R5 | `test_r5_the_lines_come_at_the_beats` | On a stepped wanderer quest the bubbles' lines appear in the order plea, arrive, work, watch, work, done, thanks, from the right speakers. A cleric gets a cleric-tagged line when one exists. Two runs of the same moment say the same lines. At speed 4 only plea, done and thanks show |
| R6 | `test_r6_the_name_moves_into_the_story` | No microskill name is drawn over the bar. The `arrive` line shows over the lead |
| R7 | `test_r7_late_events_stay_quiet` | During a catch-up no bubble or pose starts. A worker still walking plays no pose |

For Zak's playtest, with a `--count` shot sequence across one wanderer scene and one chest scene, at both UI rooms:

- the story reads at a glance;
- the poses look like work, not fighting;
- the lines are charming rather than noisy.

## Out of scope

- Microskill upgrades or ranks.
- Lines anywhere but quests: fights, camp, gates.
- New prop art (spec 106 has it).
- Voices or new sounds.
- Changing the journal.
- Lines in other languages.

## Paths

- `sim/defs/quest_line.gd` (new) and its `.uid`, `sim/defs/quest_def.gd`
- `data/quests/*.tres`
- `game/world/quest_story.gd` (new) and its `.uid`, `game/world/quest_props.gd`, `game/world/world.gd` (making the story)
- `game/entities/character_moves.gd`
- `game/effects/quest_effects.gd`
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd` (the watchers of spec 106's rows, if a row needs the story)
- `tests/acceptance/test_107_the_quest_story.gd` and its `.uid`
- `tests/acceptance/test_106_the_quest_stage.gd` (its R2 swing check becomes "plays its `work_move`", and its R7 name check follows R6; those two only)
- `tests/acceptance/test_028_seeing_side_quests.gd` (any swing or name check, to follow R1 and R6)
- Added on 2026-11-25 after the lane's questions:
  - `tests/acceptance/test_091_the_party_on_a_winding_stage.gd`: in `test_r5_props_and_the_fallen_are_in_their_room`, only the quest's microskill-name checks (about lines 443-445). They follow R6: no name for a quest, and the name-over-bar check is dropped. The bar checks stay.
  - `game/effects/spell_effects.gd`: spec 057's heal light becomes one public function that takes a point, for example `light_column_at(feet: Vector2)`. The hero path calls it with the sprite's position, and the quest story calls it with the wanderer's spot. No second copy of it.
  - `tests/acceptance/test_105_chat_bubbles.gd`, `test_r5_stale_time_starts_nothing` (about lines 228-236): the per-frame `shown_count() == 1` becomes "the test's own bubble is still up" (`line_of(...) == LINE`), because quests on the way now speak. The check that a stage change clears every bubble stays.
- R6 is about quests only. A gate keeps its microskill name over its bar, and its swing.
- `docs/architecture.md`, `docs/standards.md` (a row: a quest's lines are `QuestLine`s on its def), `docs/wiki/index.html`

## Open questions

None.
