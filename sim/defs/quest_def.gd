class_name QuestDef
extends JobDef
## A quest: a job ([JobDef]) a chamber can hold instead of monsters. Every living hero with
## [member microskill] works on it, one alone in [member work_seconds] and quicker with help
## ([method QuestWork.work_ticks]), for a reward worth [member reward_factor] kills of that
## depth; with nobody able, the party walks past, or a hazard ([member miss_damage] above 0)
## springs on it. One .tres file per quest under res://data/quests.

enum Reward { GOLD, XP }

const _WORK_SECONDS_RANGE: Vector2 = Vector2(8.0, 18.0)

@export var reward: Reward
@export var reward_factor: float  # in kills of that depth
## Share of max health every living hero loses if nobody has the microskill; 0 for no hazard.
@export var miss_damage: float


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
	return problems
