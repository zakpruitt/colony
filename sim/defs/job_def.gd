class_name JobDef
extends ContentDef
## A job a microskill does in a number of seconds: a quest in a room ([QuestDef]), or a gate on a
## side path ([GateDef]). A living hero with [member microskill] does it in
## [member work_seconds]. Each kind extends this with its own fields and checks, and gives its own
## [method work_range].

@export var id: StringName
@export var display_name: String
@export var description: String
@export var microskill: StringName
@export var work_seconds: float


## The shortest and longest work this kind of job may take, in seconds.
func work_range() -> Vector2:
	return Vector2.ZERO


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the job is usable. Naming, then the microskill, then the work.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(
		id, display_name, description, "description"
	)
	if String(microskill).is_empty():
		problems.append("microskill is empty")
	elif Content.microskill(microskill) == null:
		problems.append("microskill %s does not exist" % microskill)
	var work: Vector2 = work_range()
	if work_seconds < work.x or work_seconds > work.y:
		problems.append("work_seconds %s is outside %s to %s" % [work_seconds, work.x, work.y])
	return problems
