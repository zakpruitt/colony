# 103 — Quests

- **Status:** approved (2026-11-24)
- **Milestone:** M0
- **Depends on:** 025, 093
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

"Side quests" become **quests**: in what the player reads, in the code and in the data. Zak's word is quest.

A quest and a gate are both a job a microskill does, in a number of seconds. They become two kinds of one base definition, `JobDef`, so the work that specs 104 to 107 add has one shape to extend.

This spec changes nothing the game does. Every recorded hash stays as it is, and a save made before it loads after it.

## Requirements

- **R1. Nothing the game does changes.**
  - Every existing recorded hash and baseline passes unedited.
  - In particular, the random fork label in `ChamberRules` keeps its text `"sidequest/"`, because the roll of which room holds a quest is seeded from it. A comment there says why it keeps the old word.
  - A save written by `dev` before this spec loads, and plays on, the same.
- **R2. The player reads "quest".**
  - Every player-facing string that says "side quest" or "side quests" says "quest" or "quests" instead, with "Side quests" becoming "Quests". The places include:
    - the help panel's line;
    - the hero window's Skills tab tip;
    - the away story's "Side quests done" and "Side quests missed" rows;
    - the tally window's "N side quests";
    - the journal's sentences;
    - the showcase's labels ("A SIDE QUEST: …").
  - The wiki and `docs/design/world.md` say quest too.
- **R3. The code and data say "quest".** These renames are made everywhere, with no alias kept:

  | From | To |
  |---|---|
  | `SideQuestDef` (`sim/defs/side_quest_def.gd`) | `QuestDef` (`sim/defs/quest_def.gd`) |
  | `data/sidequests/` | `data/quests/` |
  | `Content.Kind.SIDE_QUESTS`, `side_quest()`, `side_quest_ids()` | `Content.Kind.QUESTS`, `quest()`, `quest_ids()` |
  | `SimEvent.Kind.SIDE_QUEST_STARTED`, `_DONE`, `_MISSED` | `QUEST_STARTED`, `QUEST_DONE`, `QUEST_MISSED` |
  | `Expedition.side_quest_in()` | `Expedition.quest_in()` |
  | `ChamberRules.SIDE_QUEST_SHARE` | `ChamberRules.QUEST_SHARE` |
  | `AwayReport.side_quests_done`, `side_quests_missed` | `quests_done`, `quests_missed` |

  - Any other identifier or comment that says `side_quest`, `sidequest` or "side quest" is renamed the same way.
  - Test file names that carry a spec's title (such as `test_025_microskills_and_side_quests.gd`) keep their names.
  - `SimEvent.Kind` keeps its order. Only the names change.
- **R4. Quests and gates share one base definition.**
  - `JobDef extends ContentDef` holds what both have, and checks it once:
    - `id`, `display_name`, `description`, `microskill` and `work_seconds`;
    - its `validate()` checks naming (`DefChecks.naming_problems`), that the microskill exists, and that `work_seconds` is inside `work_range()`.
  - `QuestDef` and `GateDef` extend `JobDef`. Each keeps only its own fields and checks:
    - a quest keeps its reward and hazard;
    - each gives its own `work_range()`: 3 to 6 seconds for both, as today.
  - The problems each reports are word for word what it reports today, so `test_078`'s expected messages pass unedited.
  - Each `.tres` loads with its fields unchanged.
- **R5. The standards say so.** `docs/standards.md`'s content row names quest and gate as kinds of `JobDef`: a new kind of microskill job extends it.

## Interfaces

```gdscript
# sim/defs/job_def.gd (new)
class_name JobDef
extends ContentDef
## A job a microskill does in a number of seconds: a quest in a room, or a gate on a side path.
@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float
## The shortest and longest work this kind of job may take, in seconds.
func work_range() -> Vector2
func key() -> StringName
func validate() -> PackedStringArray

# sim/defs/quest_def.gd: class_name QuestDef extends JobDef (reward, reward_factor, miss_damage, reward_at, kill_value)
# sim/defs/gate_def.gd:  class_name GateDef extends JobDef
```

## Acceptance

`tests/acceptance/test_103_quests.gd`:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | (the existing suite) | Every recorded hash test passes with its recorded values unedited (`git diff` shows no change to any `RECORDED_HASHES`/`HASHES_BEFORE` value) |
| R1 | `test_r1_an_old_save_plays_the_same` | A save written before the rename (kept as a fixture string or file in the test) loads, and 600 steps give the same hash as the same save stepped before. Record the hash on the unchanged code first |
| R2 | `test_r2_the_player_reads_quest` | No string shown by the help panel, hero window, away story, tally window or journal for a quest contains "side quest" (case-insensitive), and the away story shows "Quests done" |
| R3 | `test_r3_nothing_says_side_quest` | No `.gd` or `.tres` under `sim/`, `game/` or `data/` contains `side_quest`, `sidequest`, `SideQuest` or "side quest", apart from the one fork label of R1 |
| R4 | `test_r4_quests_and_gates_are_jobs` | Every quest and gate is a `JobDef`. A quest and a gate with an unknown microskill, or `work_seconds` out of range, report the same messages as before |
| R5 | (review) | The standards row is there |

R3's text check belongs in the `harness` step if the lane prefers. CLAUDE.md says a rule about source text is a harness check: then it is a row in `rule_problems` with a test in `tools/tests/`, and R3's GUT test is dropped.

## Out of scope

- Any change to how quests or gates work, their times or rewards. That is spec 104.
- Merging the expedition's work machine (`QuestWork`, `SidePathWalk`). Spec 104 works in it.
- Renaming side paths, caches or gates.
- Renaming test files.

## Paths

- Every tracked file outside `specs/` that `git grep -il "side_quest\|sidequest\|SideQuest\|side quest\|side-quest"` lists (79 today, across `sim/`, `game/`, `data/`, `tests/`, `docs/`, `tools/` and `.claude/skills/godot-headless-test/SKILL.md`), for the rename only. The `.tres` files move with `git mv`.
- `sim/defs/job_def.gd` (new) and its `.uid`, `sim/defs/gate_def.gd`, `sim/defs/quest_def.gd` (moved) and its `.uid`
- `tests/acceptance/test_103_quests.gd` and its `.uid`
- `tools/dev.py` and `tools/tests/` (only if R3 becomes a harness rule)
- `docs/standards.md`, `docs/architecture.md`, `docs/design/world.md`, `docs/wiki/index.html`
- `specs/README.md` is the lead's, not the lane's. Older specs keep their words.

## Open questions

None.
