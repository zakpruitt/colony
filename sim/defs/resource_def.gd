class_name ResourceDef
extends Resource
## A resource (spec 052): what an area gives the party for fighting there, which the later ranks of
## the camp upgrades cost. Its icon is its part of [code]assets/sprites/ui/resource_icons.px[/code],
## named by its id. One .tres file per resource under res://data/resources.

@export var id: StringName
@export var display_name: String  # one of it, capitalised: "Glowcap"
@export var plural: String  # more than one, in a sentence: "glowcaps"


## One line per problem; empty when the resource is usable.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if plural.is_empty():
		problems.append("plural is empty")
	return problems
