class_name TrainingDef
extends Resource
## One stat a hero's paragon points go into. Each
## point adds [member per_rank] to one of that hero's multipliers, with no limit. One .tres file
## per stat under res://data/training.

## What a point raises: damage and healing, maximum health, or attack speed.
enum Stat { POWER, TOUGHNESS, QUICKNESS }

@export var id: StringName
@export var display_name: String
@export var description: String  # one short line, e.g. "+3% damage and healing"
@export var order: int  # position on the hero sheet, lowest first
@export var stat: Stat
@export var per_rank: float


## One line per problem; empty when the stat is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if description.is_empty():
		problems.append("description is empty")
	if per_rank <= 0.0:
		problems.append("per_rank %s is not above 0" % per_rank)
	return problems
