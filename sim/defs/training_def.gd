class_name TrainingDef
extends ContentDef
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


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the stat is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(
		id, display_name, description, "description"
	)
	if per_rank <= 0.0:
		problems.append("per_rank %s is not above 0" % per_rank)
	return problems
