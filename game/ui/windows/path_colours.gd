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
## The darker shade of each path colour, for the bottom row of its rank bar.
const SHADES: Dictionary[StringName, StringName] = {
	&"blue": &"navy",
	&"red": &"crimson",
	&"copper": &"clay",
	&"forest": &"pine",
	&"orchid": &"plum",
	&"orange": &"brick",
	&"cyan": &"blue",
	&"pink": &"tawny",
	&"tan": &"clay",
}
## What is held shut by a path's rank is drawn in: darker than the plain lines, so a tier the
## rank has not opened reads as further off.
const DIM: StringName = &"dusk"


## The palette name of path [param path] (0 to 2) of [param class_id]'s tree.
static func of(class_id: StringName, path: int) -> StringName:
	var colours: Array = COLOURS.get(class_id, [])
	if path < 0 or path >= colours.size():
		return PLAIN
	return colours[path]


## The palette name of what a path's rank holds shut: the lines into its shut nodes.
static func dim() -> StringName:
	return DIM


## The darker shade of path colour [param colour] (itself when it has none).
static func shade(colour: StringName) -> StringName:
	return SHADES.get(colour, colour)
