class_name HelpPanel
extends WindowContent
## Help: what the game is about in a few lines, and every key it answers to, with what each
## does, in two columns. It is the content of the Help window ([kbd]H[/kbd], its button on the
## button bar); it never pauses the game and can be open beside any other window.
##
## The keys list is built from [KeyBook], the one table of keys, so it can be checked against
## what the input code handles.

## What the game is about, one short line each.
const IDEA: Array[String] = [
	"Your party explores on its own; heroes' skills unlock quests.",
	"A stable (safe) stage leads on; a wipe goes back to the last safe stage.",
	"Gold buys upgrades in the Camp: every fifth rank is a milestone.",
	"It keeps going while the game is closed.",
	"A hero's talents are three paths of five: learn all fifteen in time.",
]
const TITLE: String = "Help"
const FOOTER: String = "Click a hero for details. Point at anything for a hint."
## The width of a key's column and of what it does, in UI pixels; the gap between the two halves.
## Every text in [method KeyBook.entries] fits [constant DOES_WIDTH] on one line (a test checks it).
const SHORTCUT_WIDTH: int = 50
const DOES_WIDTH: int = 196
const HALVES_GAP: int = 16

## Every line shown, top to bottom, as [method lines] gives them.
var _lines: Array[String] = []


func _init() -> void:
	name = "HelpPanel"
	closes_away = false
	add_theme_constant_override(&"separation", 2)
	_lines.append(TITLE)
	_heading("The idea")
	for line: String in IDEA:
		add_child(UiText.label(line, &"white"))
		_lines.append(line)
	_gap()
	_heading("Keys")
	var grid := GridContainer.new()
	grid.name = "Keys"
	grid.columns = 5
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 1)
	add_child(grid)
	var keys: Array[Array] = KeyBook.entries()
	var half: int = ceili(keys.size() / 2.0)
	for row: int in half:
		_key_cells(grid, keys[row])
		var gap := Control.new()
		gap.custom_minimum_size.x = HALVES_GAP
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(gap)
		if row + half < keys.size():
			_key_cells(grid, keys[row + half])
	for entry: Array in keys:
		_lines.append("%s  %s" % [entry[0], entry[1]])
	_gap()
	var footer: Label = UiText.label(FOOTER, &"steel")
	add_child(footer)
	_lines.append(FOOTER)


## Every line the panel shows, top to bottom: the title, "The idea" and its lines, "Keys" and one
## line per key as "<key>  <what it does>", then the footer.
func lines() -> Array[String]:
	return _lines.duplicate()


func _heading(text: String) -> void:
	var made: Label = UiText.label(text, &"steel", true)
	add_child(made)
	_lines.append(text)


func _gap() -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)


func _key_cells(grid: GridContainer, entry: Array) -> void:
	var key: Label = UiText.label(str(entry[0]), &"yellow", true)
	key.custom_minimum_size.x = SHORTCUT_WIDTH
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(key)
	var does: Label = UiText.label(str(entry[1]), &"silver")
	does.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	does.custom_minimum_size.x = DOES_WIDTH
	grid.add_child(does)
