class_name Palette
extends RefCounted
## The master palette (docs/style-bible.md), read from assets/style/palette.txt, the single source
## of truth. Each line of the file is `<symbol> <hex> <name>`.

const PATH: String = "res://assets/style/palette.txt"
## What an unknown name returns: loud, so a mistake shows on screen.
const MISSING: Color = Color.MAGENTA

static var _colors: PackedColorArray = []
static var _by_name: Dictionary[StringName, Color] = {}


## The palette colour called [param color_name] (for example [code]&"ink"[/code]).
## An unknown name is an error that names it, and returns magenta.
static func color(color_name: StringName) -> Color:
	_load()
	if not _by_name.has(color_name):
		push_error("Palette: no colour is named '%s' in %s" % [color_name, PATH])
		return MISSING
	return _by_name[color_name]


## The palette's colours, in file order.
static func all() -> PackedColorArray:
	_load()
	return _colors.duplicate()


static func _load() -> void:
	if not _colors.is_empty():
		return
	var text: String = FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error(
			"Palette: cannot read %s (%s)" % [PATH, error_string(FileAccess.get_open_error())]
		)
		return
	for raw: String in text.split("\n", false):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var fields: PackedStringArray = line.split(" ", false)
		if fields.size() != 3 or not fields[1].is_valid_html_color():
			push_error("Palette: malformed line in %s: '%s'" % [PATH, line])
			continue
		var value: Color = Color.html(fields[1])
		_colors.append(value)
		_by_name[StringName(fields[2])] = value
