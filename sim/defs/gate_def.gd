class_name GateDef
extends ContentDef
## A gate: what closes a side path ([SidePath]). A living hero with [member microskill] opens it
## in [member work_seconds]; with nobody able, the party walks past. One .tres file per gate
## under res://data/gates.

## The shortest and longest a gate may take to open, in seconds.
const _WORK_SECONDS_RANGE: Vector2 = Vector2(3.0, 6.0)

@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the gate is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(
		id, display_name, description, "description"
	)
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
	return problems
