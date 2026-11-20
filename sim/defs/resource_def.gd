class_name ResourceDef
extends ContentDef
## A resource: what an area gives the party for fighting there, which the later ranks of
## the camp upgrades cost. Its icon is its part of [code]assets/sprites/ui/resource_icons.px[/code],
## named by its id. One .tres file per resource under res://data/resources.

@export var id: StringName
@export var display_name: String  # one of it, capitalised: "Glowcap"
@export var plural: String  # more than one, in a sentence: "glowcaps"


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the resource is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(id, display_name, plural, "plural")
	return problems
