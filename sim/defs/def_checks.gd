class_name DefChecks
extends RefCounted
## The validation rules definitions share: naming, and the fighting numbers of hero classes and
## monsters.


## Problems with a definition's id, display name and, when [param text_field] is not empty, the
## text in that field, one line each and in that order.
static func naming_problems(
	id: StringName, display_name: String, text: String = "", text_field: String = ""
) -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if not text_field.is_empty() and text.is_empty():
		problems.append("%s is empty" % text_field)
	return problems


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
