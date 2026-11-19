class_name SideQuestDef
extends Resource
## A side quest: something a chamber can hold instead of monsters. A living hero with
## [member microskill] does it in [member work_seconds] for a reward worth
## [member reward_factor] kills of that depth; with nobody able, the party walks past, or a
## hazard ([member miss_damage] above 0) springs on it. One .tres file per side quest under
## res://data/sidequests.

enum Reward { GOLD, XP }

## The shortest and longest work a side quest may take, in seconds.
const _WORK_SECONDS_RANGE: Vector2 = Vector2(3.0, 6.0)

@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float
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


## One line per problem; empty when the side quest is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if description.is_empty():
		problems.append("description is empty")
	if String(microskill).is_empty():
		problems.append("microskill is empty")
	elif Content.microskill(microskill) == null:
		problems.append("microskill %s does not exist" % microskill)
	if work_seconds < _WORK_SECONDS_RANGE.x or work_seconds > _WORK_SECONDS_RANGE.y:
		problems.append(
			(
				"work_seconds %s is outside %s to %s"
				% [work_seconds, _WORK_SECONDS_RANGE.x, _WORK_SECONDS_RANGE.y]
			)
		)
	if reward_factor <= 0.0:
		problems.append("reward_factor %s is not above 0" % reward_factor)
	if miss_damage < 0.0 or miss_damage >= 1.0:
		problems.append("miss_damage %s is outside 0 to below 1" % miss_damage)
	return problems
