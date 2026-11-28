class_name PathColours
extends RefCounted
## The colour of each talent path, a view table keyed by class and path: the path's
## banner, the lines lit along it, its nodes' frame tint and its name wherever a hero window names
## it are drawn in it. No colour is one a state uses (the gold, yellow, white and greys of the
## frames, the green of what is learned), so a path's colour never reads as a state.

## Each class's three path colours, in the order of its tree's paths, as palette names.
const COLOURS: Dictionary[StringName, Array] = {
	&"knight": [&"blue", &"red", &"copper"],
	&"rogue": [&"red", &"forest", &"orchid"],
	&"mage": [&"orange", &"cyan", &"orchid"],
	&"cleric": [&"pink", &"tan", &"cyan"],
}
## A path's colour when nothing names it: an unknown class or path.
const PLAIN: StringName = &"steel"


## The palette name of path [param path] (0 to 2) of [param class_id]'s tree.
static func of(class_id: StringName, path: int) -> StringName:
	var colours: Array = COLOURS.get(class_id, [])
	if path < 0 or path >= colours.size():
		return PLAIN
	return colours[path]
