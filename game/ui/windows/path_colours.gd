class_name PathColours
extends RefCounted
## The colour of each talent path, a view table keyed by class and path: the path's
## banner, the lines lit along it, its nodes' frame tint and its name wherever a hero window names
## it are drawn in it. No colour is one a state uses (the gold, yellow, white and greys of the
## frames, the green of what is learned, the sand of the lit trunk), so a path's colour never reads
## as a state.

## Each class's two path colours, in the order of its tree's paths, as palette names.
const COLOURS: Dictionary[StringName, Array] = {
	&"knight": [&"blue", &"red"],
	&"rogue": [&"red", &"orchid"],
	&"mage": [&"orange", &"cyan"],
	&"cleric": [&"pink", &"tan"],
}
## A path's colour when nothing names it: an unknown class or path.
const PLAIN: StringName = &"steel"
## The colour of a closed path's lines and frame tint: dark, plainly not in play.
const DIM: StringName = &"dusk"


## The palette name of path [param path] (0 or 1) of [param class_id]'s tree.
static func of(class_id: StringName, path: int) -> StringName:
	var pair: Array = COLOURS.get(class_id, [])
	if path < 0 or path >= pair.size():
		return PLAIN
	return pair[path]


## The colour a closed path's lines and tint are drawn in.
static func dim() -> StringName:
	return DIM
