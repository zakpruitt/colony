class_name MicroskillDef
extends ContentDef
## A microskill: a minor passive a hero picks up at a level of their class (see
## [member HeroClassDef.microskills]), which lets the party do quests that ask for it.
## One .tres file per microskill under res://data/microskills.

@export var id: StringName
@export var display_name: String
@export var description: String  # one short line, e.g. "Opens locks"


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the microskill is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(
		id, display_name, description, "description"
	)
	return problems
