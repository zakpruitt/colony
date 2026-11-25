class_name QuestDef
extends JobDef
## A quest: a job ([JobDef]) a chamber can hold instead of monsters. Every living hero with
## [member microskill] works on it, one alone in [member work_seconds] and quicker with help
## ([method QuestWork.work_ticks]), for a reward worth [member reward_factor] kills of that
## depth; with nobody able, the party walks past, or a hazard ([member miss_damage] above 0)
## springs on it. One .tres file per quest under res://data/quests.
##
## Its story on screen is data too: the pose its workers work in ([member work_move], a view hint
## no rule reads) and the lines said at its beats ([member lines], [QuestLine]).

enum Reward { GOLD, XP }

const _WORK_SECONDS_RANGE: Vector2 = Vector2(8.0, 18.0)
## The quests whose prop is a person who speaks (its subject), and the fewest lines it has for
## each beat it speaks at.
const SUBJECT_QUESTS: Array[StringName] = [&"hurt_wanderer"]
const SUBJECT_LEAST: Dictionary[StringName, int] = {&"plea": 3, &"thanks": 2}
## The beats every quest has at least LEAST_LINES lines for that any worker may say, and the
## fewest watch lines.
const WORKER_BEATS: Array[StringName] = [&"arrive", &"work", &"done"]
const LEAST_LINES: int = 2

@export var reward: Reward
@export var reward_factor: float  # in kills of that depth
## Share of max health every living hero loses if nobody has the microskill; 0 for no hazard.
@export var miss_damage: float
## The looping pose its workers play at the prop, a [CharacterMoves] work pose.
@export var work_move: StringName
@export var lines: Array[QuestLine]


## The lines that fit (class-tagged first, then any), for the view to pick from.
func lines_for(beat: StringName, speaker: StringName, class_id: StringName) -> Array[QuestLine]:
	var tagged: Array[QuestLine] = []
	var any: Array[QuestLine] = []
	for line: QuestLine in lines:
		if line == null or line.beat != beat or line.speaker != speaker:
			continue
		if line.class_id == &"":
			any.append(line)
		elif line.class_id == class_id:
			tagged.append(line)
	tagged.append_array(any)
	return tagged


## The gold or XP (by [member reward]) the quest gives at [param level_depth]:
## [member reward_factor] times what one kill there is worth on average, at least 1.
func reward_at(level_depth: int) -> int:
	var value: Vector2 = kill_value(level_depth)
	var per_kill: float = value.y if reward == Reward.XP else value.x
	return maxi(roundi(reward_factor * per_kill), 1)


## What one kill at [param level_depth] is worth on average, as Vector2(gold, XP): each monster
## (not a guardian) whose [member MonsterDef.base_level] is at most that depth, weighted by that
## level. It reads every monster, not an area's, so a reward depends on the depth alone.
static func kill_value(level_depth: int) -> Vector2:
	var gold: float = 0.0
	var xp: float = 0.0
	var weight: int = 0
	for monster_id: StringName in Content.monster_ids():
		var def: MonsterDef = Content.monster(monster_id)
		if def.guardian or def.base_level > level_depth:
			continue
		gold += def.base_level * (def.gold_min + def.gold_max) / 2.0
		xp += def.base_level * def.xp
		weight += def.base_level
	if weight == 0:
		return Vector2.ZERO
	return Vector2(gold, xp) / weight


## The shortest and longest work a quest may take, in seconds.
func work_range() -> Vector2:
	return _WORK_SECONDS_RANGE


## One line per problem; empty when the quest is usable: the job's, then the reward and hazard.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if reward_factor <= 0.0:
		problems.append("reward_factor %s is not above 0" % reward_factor)
	if miss_damage < 0.0 or miss_damage >= 1.0:
		problems.append("miss_damage %s is outside 0 to below 1" % miss_damage)
	problems.append_array(_line_problems())
	return problems


## The problems of [member lines]: each line's, then too few for a beat.
func _line_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	for line: QuestLine in lines:
		if line == null:
			problems.append("a line is empty")
			continue
		if not QuestLine.BEATS.has(line.beat):
			problems.append(
				"line '%s': beat %s is not one of %s" % [line.text, line.beat, QuestLine.BEATS]
			)
		if not QuestLine.SPEAKERS.has(line.speaker):
			problems.append(
				(
					"line '%s': speaker %s is not one of %s"
					% [line.text, line.speaker, QuestLine.SPEAKERS]
				)
			)
		if line.class_id != &"" and Content.hero_class(line.class_id) == null:
			problems.append("line '%s': class %s is not a hero class" % [line.text, line.class_id])
		if line.text.strip_edges().is_empty():
			problems.append("a %s line has no text" % line.beat)
		elif line.text.length() > QuestLine.MOST_CHARACTERS:
			problems.append(
				"line '%s' is over %d characters" % [line.text, QuestLine.MOST_CHARACTERS]
			)
	for beat: StringName in WORKER_BEATS:
		if _any_count(beat, &"worker") < LEAST_LINES:
			problems.append("fewer than %d %s lines any worker can say" % [LEAST_LINES, beat])
	if _any_count(&"watch", &"watcher") < LEAST_LINES:
		problems.append("fewer than %d watch lines" % LEAST_LINES)
	if SUBJECT_QUESTS.has(id):
		for beat: StringName in SUBJECT_LEAST:
			if _any_count(beat, &"subject") < SUBJECT_LEAST[beat]:
				problems.append(
					"fewer than %d %s lines for its subject" % [SUBJECT_LEAST[beat], beat]
				)
	return problems


## How many lines for [param beat] by [param speaker] fit any class.
func _any_count(beat: StringName, speaker: StringName) -> int:
	var found: int = 0
	for line: QuestLine in lines:
		if line != null and line.beat == beat and line.speaker == speaker and line.class_id == &"":
			found += 1
	return found
