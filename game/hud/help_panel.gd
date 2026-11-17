class_name HelpPanel
extends Control
## The help panel (spec 030 R2): what the game is about in a few lines, and every key it answers
## to, with what each does. The HUD's [code]?[/code] button and the [kbd]H[/kbd] key open and close
## it; [kbd]Esc[/kbd] closes it. It sits in the middle of the screen, between the top band and the
## party frames, and never pauses the game.
##
## It never shares the screen with the shop, the hero sheet or the journal: opening it closes them,
## and each of them closes it when it opens ([method advance] also closes it should one be open).
## The keys list is the one table [constant KEYS]; [method keycodes] turns each key label into
## the key codes it stands for, so the list can be checked against what the input code handles.
## Drawn as a [HudPanel] is.

## The keys the game responds to, in the order shown: each entry is [key label, what it does].
## A label is one or more keys split by spaces; [code]1-5[/code] is a run of number keys.
const KEYS: Array[Array] = [
	["H", "Show or hide this help"],
	["Esc", "Close any open panel"],
	["- +", "Lower or raise the target depth"],
	["A", "Auto on or off: go deeper when a depth is safe"],
	["U", "Open or close the Shop"],
	["B", "In the Shop: auto-buy on or off"],
	["1-5", "In the Shop: buy that upgrade"],
	["1-3", "On a hero's Training tab: train that row"],
	["Q E", "On a hero sheet: previous or next tab"],
	["Tab", "Show the next hero's sheet"],
	["J", "Open or close the journal"],
	["Z", "Zoom in or out"],
	["F", "Game speed: 1x, 2x or 4x"],
	["M", "Sound on or off"],
	["F3", "Show the clock (for testing)"],
]
## What the game is about, one short line each.
const IDEA: Array[String] = [
	"Your party explores on its own; heroes' skills unlock side quests.",
	"When a depth turns stable (safe), it heads one deeper.",
	"A wipe sends it back to the last safe depth.",
	"Gold buys upgrades in the Shop, and training on hero sheets.",
	"It keeps going while the game is closed.",
]
const TITLE: String = "How Colony works"
const HINT: String = "H or Esc close"
const FOOTER: String = "Click a hero for details. Point at anything for a hint."
## Key labels that are not a key's own name, and the keys each stands for: [code]+[/code] is
## also the [kbd]=[/kbd] key it shares, and both have a twin on the keypad.
const ALIASES: Dictionary[String, Array] = {
	"Esc": [KEY_ESCAPE],
	"-": [KEY_MINUS, KEY_KP_SUBTRACT],
	"+": [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD],
}

## Space inside the border; a line's height; the title row's height; space above a section.
const PADDING: float = 4.0
const LINE_HEIGHT: float = 9.0
const TITLE_HEIGHT: float = 13.0
const SECTION_GAP: float = 5.0
## The column where a key's description starts, after its label.
const DOES_X: float = 30.0
## Pixels between the panel and the top band above it.
const DROP: float = 2.0

## The close button at the top right.
var close_button: HudButton

var _simulation: Simulation
var _world: World
## Every line shown, top to bottom, as [method lines] gives them.
var _lines: Array[String] = []


func _init() -> void:
	name = "HelpPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _draw() -> void:
	HudPanel.draw_panel(
		self,
		Rect2(Vector2.ZERO, size),
		Palette.color(&"night"),
		Palette.color(&"dusk"),
		Palette.color(&"ink")
	)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_H:
			toggle()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			# Not marked handled, so the HUD and the journal close what they have open too.
			close()


## Call once, before the first advance. Neither the simulation nor the world is changed.
func setup(simulation: Simulation, world: World) -> void:
	_simulation = simulation
	_world = world
	var width: float = 0.0
	var y: float = PADDING
	var title: Label = _add(TITLE, &"yellow", Vector2(PADDING + 2.0, y))
	width = maxf(width, title.position.x + PixelText.width(TITLE) + 60.0)
	_lines.append(TITLE)
	y += TITLE_HEIGHT
	var dividers: Array[float] = [y - 1.0]
	y += 2.0
	_add("The idea", &"steel", Vector2(PADDING + 2.0, y))
	_lines.append("The idea")
	y += LINE_HEIGHT + 1.0
	for line: String in IDEA:
		var label: Label = _add(line, &"white", Vector2(PADDING + 2.0, y))
		width = maxf(width, label.position.x + PixelText.width(line))
		_lines.append(line)
		y += LINE_HEIGHT
	y += SECTION_GAP
	_add("Keys", &"steel", Vector2(PADDING + 2.0, y))
	_lines.append("Keys")
	y += LINE_HEIGHT + 1.0
	for entry: Array in KEYS:
		var key_label: String = entry[0]
		var does: String = entry[1]
		_add(key_label, &"yellow", Vector2(PADDING + 2.0, y))
		var label: Label = _add(does, &"silver", Vector2(PADDING + DOES_X, y))
		width = maxf(width, label.position.x + PixelText.width(does))
		_lines.append("%s  %s" % [key_label, does])
		y += LINE_HEIGHT
	y += SECTION_GAP - 2.0
	dividers.append(y)
	y += 3.0
	var footer: Label = _add(FOOTER, &"steel", Vector2(PADDING + 2.0, y))
	width = maxf(width, footer.position.x + PixelText.width(FOOTER))
	_lines.append(FOOTER)
	y += LINE_HEIGHT
	size = Vector2(ceilf(width + PADDING + 4.0), y + PADDING)
	position = Vector2(floorf((Hud.SCREEN.x - size.x) / 2.0), Hud.TOP_BAND + DROP)
	for at: float in dividers:
		var divider := ColorRect.new()
		divider.color = Palette.color(&"dusk")
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.position = Vector2(PADDING, at)
		divider.size = Vector2(size.x - PADDING * 2.0, 1.0)
		add_child(divider)
	close_button = HudButton.new("x")
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(HudButton.HEIGHT, HudButton.HEIGHT)
	close_button.size = close_button.get_combined_minimum_size()
	close_button.position = Vector2(size.x - PADDING - close_button.size.x, PADDING - 1.0)
	close_button.pressed.connect(close)
	add_child(close_button)
	var hint: Label = _add(HINT, &"slate", Vector2.ZERO)
	hint.position = Vector2(close_button.position.x - 6.0 - PixelText.width(HINT), PADDING)


## Closes the panel if the shop, the hero sheet or the journal has opened. Called every frame by
## the HUD; tests call it.
func advance(_delta: float) -> void:
	if not is_open():
		return
	var hud: Hud = get_parent() as Hud
	if hud == null:
		return
	var shop: bool = hud.shop != null and hud.shop.is_open()
	var sheet: bool = hud.hero_sheet != null and hud.hero_sheet.is_open()
	var journal: bool = hud.journal != null and hud.journal.is_open()
	if shop or sheet or journal:
		close()


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Shows the panel, closing the shop, the hero sheet, the journal and the "While you were away"
## panel if any is up.
func open() -> void:
	var hud: Hud = get_parent() as Hud
	if hud != null:
		if hud.shop != null:
			hud.shop.close()
		if hud.hero_sheet != null:
			hud.hero_sheet.close()
		if hud.journal != null:
			hud.journal.close()
		var layer: Node = hud.get_parent()
		if layer != null:
			for child: Node in layer.get_children():
				if child is AwayPanel:
					(child as AwayPanel).close()
	visible = true


## Hides the panel.
func close() -> void:
	visible = false


## Opens the panel if it is closed, closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Every line the panel shows, top to bottom: the title, "The idea" and its lines, "Keys" and one
## line per key as "<key>  <what it does>", then the footer.
func lines() -> Array[String]:
	return _lines.duplicate()


## The key codes a key label from [constant KEYS] stands for: [code]"- +"[/code] is minus and plus
## (and their keypad twins and [kbd]=[/kbd]), [code]"1-5"[/code] the number keys 1 to 5,
## [code]"Tab"[/code] the Tab key. Empty for a label that names no key.
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


func _add(text: String, colour: StringName, at: Vector2) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made
