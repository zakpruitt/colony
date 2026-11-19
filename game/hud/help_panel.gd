class_name HelpPanel
extends VBoxContainer
## Help (spec 030 R2, moved onto the UI layer by spec 058 R8): what the game is about in a few
## lines, and every key it answers to, with what each does, in two columns. It is the content of
## the Help window ([kbd]H[/kbd], its button on the button bar); it never pauses the game and can be
## open beside any other window.
##
## The keys list is the one table [constant KEYS]; [method keycodes] turns each key label into
## the key codes it stands for, so the list can be checked against what the input code handles.

## The keys the game responds to, in the order shown: each entry is [key label, what it does].
## A label is one or more keys split by spaces; [code]1-5[/code] is a run of number keys.
const KEYS: Array[Array] = [
	["H", "Open or close Help"],
	["Esc", "Close the front window"],
	["- +", "Target a stage back or further"],
	["A", "Auto on or off: go on when it is safe"],
	["U", "Open or close the Camp"],
	["B", "Camp in front: auto-buy on or off"],
	["1-5", "Camp in front: buy that upgrade"],
	["1-3", "Talents tab: a paragon point to a stat"],
	["Q E", "Hero window or Tally: change tab"],
	["Tab", "Open the next hero's window"],
	["Shift+Tab", "Close the front hero window"],
	["J", "Open or close the Journal"],
	["O", "Open or close the Orders"],
	["T", "Open or close the Tally"],
	["L", "Show or hide the stage list"],
	["W", "Open or close the Map"],
	["G", "Show or hide the goals"],
	["Z", "Zoom in or out"],
	["F", "Game speed: 1x, 2x or 4x"],
	["M", "Sound on or off"],
	["F3", "Show the clock (for testing)"],
]
## What the game is about, one short line each.
const IDEA: Array[String] = [
	"Your party explores on its own; heroes' skills unlock side quests.",
	"A stable (safe) stage leads on; a wipe goes back to the last safe stage.",
	"Gold buys upgrades in the Camp: every fifth rank is a milestone.",
	"It keeps going while the game is closed.",
	"A hero's talent tree forks into two paths: choose one.",
]
const TITLE: String = "Help"
const FOOTER: String = "Click a hero for details. Point at anything for a hint."
## Key labels that are not a key's own name, and the keys each stands for: [code]+[/code] is
## also the [kbd]=[/kbd] key it shares, and both have a twin on the keypad.
const ALIASES: Dictionary[String, Array] = {
	"Esc": [KEY_ESCAPE],
	"Shift+Tab": [KEY_TAB],
	"-": [KEY_MINUS, KEY_KP_SUBTRACT],
	"+": [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD],
}
## The width of a key's column and of what it does, in UI pixels; the gap between the two halves.
## Every text in [constant KEYS] fits [constant DOES_WIDTH] on one line (a test checks it).
const SHORTCUT_WIDTH: int = 50
const DOES_WIDTH: int = 196
const HALVES_GAP: int = 16

## Every line shown, top to bottom, as [method lines] gives them.
var _lines: Array[String] = []


func _init() -> void:
	name = "HelpPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var half: int = ceili(KEYS.size() / 2.0)
	for row: int in half:
		_key_cells(grid, KEYS[row])
		var gap := Control.new()
		gap.custom_minimum_size.x = HALVES_GAP
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(gap)
		if row + half < KEYS.size():
			_key_cells(grid, KEYS[row + half])
	for entry: Array in KEYS:
		_lines.append("%s  %s" % [entry[0], entry[1]])
	_gap()
	var footer: Label = UiText.label(FOOTER, &"steel")
	add_child(footer)
	_lines.append(FOOTER)


## Every line the panel shows, top to bottom: the title, "The idea" and its lines, "Keys" and one
## line per key as "<key>  <what it does>", then the footer.
func lines() -> Array[String]:
	return _lines.duplicate()


## The key codes a key label from [constant KEYS] stands for: [code]"- +"[/code] is minus and plus
## (and their keypad twins and [kbd]=[/kbd]), [code]"1-5"[/code] the number keys 1 to 5,
## [code]"Tab"[/code] the Tab key, [code]"Shift+Tab"[/code] the Tab key too (held with Shift). Empty
## for a label that names no key.
static func keycodes(label: String) -> Array[int]:
	var codes: Array[int] = []
	for part: String in label.split(" ", false):
		if ALIASES.has(part):
			for code: int in ALIASES[part]:
				codes.append(code)
		elif part.length() == 3 and part[1] == "-" and part[0].is_valid_int():
			for digit: int in range(part[0].to_int(), part[2].to_int() + 1):
				codes.append(OS.find_keycode_from_string(str(digit)))
		else:
			var code: int = OS.find_keycode_from_string(part)
			if code > 0:  # 0 is no key
				codes.append(code)
	return codes


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
