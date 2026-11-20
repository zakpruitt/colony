class_name KeyBook
extends RefCounted
## Every key the game answers to, in one table: its label, what it does, and when it applies.
## The help's list of keys is built from it ([method entries]), text that names a key asks it for
## the key's letter ([method label]), and every piece of input code asks [method pressed] whether
## an event is a fresh press of its key.
##
## A window on the bar has its key in its [WindowEntry]; the table names the window where its
## line stands in the help, and a window entry the table does not name has its line at the end.

## The table, in the help's order. A key's row is [action, label, what it does, when it applies]
## ("" for always); a window's row is [window id] alone. A label is one or more keys split by
## spaces; [code]1-5[/code] is a run of number keys.
const ROWS: Array[Array] = [
	[&"help"],
	[&"close", "Esc", "Close the front window", ""],
	[&"target", "- +", "Target a stage back or further", ""],
	[&"auto", "A", "Auto on or off: go on when it is safe", ""],
	[&"shop"],
	[&"auto_buy", "B", "auto-buy on or off", "Camp in front"],
	[&"buy", "1-5", "buy that upgrade", "Camp in front"],
	[&"paragon", "1-3", "a paragon point to a stat", "Talents tab"],
	[&"tabs", "Q E", "change tab", "Hero window or Tally"],
	[&"next_hero", "Tab", "Open the next hero's window", ""],
	[&"close_hero", "Shift+Tab", "Close the front hero window", ""],
	[&"journal"],
	[&"orders"],
	[&"tally"],
	[&"stage_list", "L", "Show or hide the stage list", ""],
	[&"map"],
	[&"goals", "G", "Show or hide the goals", ""],
	[&"zoom", "Z", "Zoom in or out", ""],
	[&"speed", "F", "Game speed: 1x, 2x or 4x", ""],
	[&"sound", "M", "Sound on or off", ""],
	[&"full_screen", "F11", "Full screen on or off", ""],
	[&"clock", "F3", "Show the clock (for testing)", ""],
]
## Key labels that are not a key's own name, and the keys each stands for: [code]+[/code] is
## also the [kbd]=[/kbd] key it shares, and both have a twin on the keypad.
const ALIASES: Dictionary[String, Array] = {
	"Esc": [KEY_ESCAPE],
	"Shift+Tab": [KEY_TAB],
	"-": [KEY_MINUS, KEY_KP_SUBTRACT],
	"+": [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD],
}
## Each key row's label by its action, read from [constant ROWS] once.
## How many times a key's label has been asked for ([method label]), ever.
static var asked: int = 0
static var _labels: Dictionary[StringName, String] = {}


## Every key in the help's order, each as [label, what it does], what it does led by when it
## applies ([code]Camp in front: buy that upgrade[/code]).
static func entries() -> Array[Array]:
	var windows: Array[WindowEntry] = WindowBook.listed()
	var named: Dictionary[StringName, bool] = {}
	var made: Array[Array] = []
	for row: Array in ROWS:
		if row.size() == 1:
			var id: StringName = row[0]
			var entry: WindowEntry = _window(windows, id)
			if entry != null:
				named[entry.id] = true
				made.append([key_name(entry.key), entry.help_text()])
			continue
		var does: String = row[2]
		var when: String = row[3]
		made.append([row[1], does if when.is_empty() else "%s: %s" % [when, does]])
	for entry: WindowEntry in windows:
		if not named.has(entry.id):
			made.append([key_name(entry.key), entry.help_text()])
	return made


## True when [param event] is a fresh press of [param key]: pressed, not held down and repeating.
static func pressed(event: InputEvent, key: Key) -> bool:
	var fresh: InputEventKey = fresh_key(event)
	return fresh != null and fresh.keycode == key


## [param event] as a key event when it is a fresh press of any key, else null.
static func fresh_key(event: InputEvent) -> InputEventKey:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return null
	return key


## The label of [param action]'s key, as the help shows it ("O", "U", "F"): an action of
## [constant ROWS] or a window's id. "" for one there is not.
static func label(action: StringName) -> String:
	asked += 1
	var key: int = WindowBook.key_of(action)
	if key != 0:
		return key_name(key as Key)
	if _labels.is_empty():
		for row: Array in ROWS:
			if row.size() > 1:
				_labels[row[0] as StringName] = row[1] as String
	return _labels.get(action, "")


## True when [param key] is one of the keys [param key_label] stands for ([method keycodes]).
static func stands_for(key: InputEventKey, key_label: String) -> bool:
	return key != null and keycodes(key_label).has(key.keycode)


## The name a key is shown by ([code]H[/code], [code]F11[/code]).
static func key_name(key: Key) -> String:
	return OS.get_keycode_string(key)


## The key codes a key label stands for: [code]"- +"[/code] is minus and plus (and their keypad
## twins and [kbd]=[/kbd]), [code]"1-5"[/code] the number keys 1 to 5, [code]"Tab"[/code] the Tab
## key, [code]"Shift+Tab"[/code] the Tab key too (held with Shift). Empty for a label that names
## no key.
static func keycodes(key_label: String) -> Array[int]:
	var codes: Array[int] = []
	for part: String in key_label.split(" ", false):
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


static func _window(windows: Array[WindowEntry], id: StringName) -> WindowEntry:
	for entry: WindowEntry in windows:
		if entry.id == id:
			return entry
	return null
