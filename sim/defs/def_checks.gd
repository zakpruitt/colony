class_name DefChecks
extends RefCounted
## The validation rules hero classes and monsters share.


## Problems with the fighting numbers every combatant definition has, one line each.
static func combat_problems(
	id: StringName,
	display_name: String,
	max_health: int,
	damage: int,
	attack_interval: float,
	attack_range: float,
	move_speed: float,
	crit_chance: float
) -> PackedStringArray:
	var problems: PackedStringArray = []
	if id.is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if max_health < 1:
		problems.append("max_health %d is below 1" % max_health)
	if damage < 1:
		problems.append("damage %d is below 1" % damage)
	if attack_interval <= 0.0:
		problems.append("attack_interval %s is not positive" % attack_interval)
	if attack_range <= 0.0:
		problems.append("attack_range %s is not positive" % attack_range)
	if move_speed <= 0.0:
		problems.append("move_speed %s is not positive" % move_speed)
	if crit_chance < 0.0 or crit_chance > 1.0:
		problems.append("crit_chance %s is outside 0 to 1" % crit_chance)
	return problems
