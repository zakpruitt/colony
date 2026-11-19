class_name UiButtonBar
extends HBoxContainer
## The row of window buttons (spec 058 R7, spec 068), at the bottom right of the UI layer just
## above the line of the hero frames: one button per window on the layer, in the order the windows
## were made. Each says what it opens (spec 068 R1): its window's icon, the window's short name
## ([constant NAMES]) and its key in a small key cap. A click opens or closes the window; a button
## is lit while its window is open; resting on one gives the window's title, its key and what it
## is for in one sentence ([code]Journal (J): what has happened to the party, newest first.[/code]).
## The last button, [member reset_button], puts every window back in its default place (R6).
##
## The row has two forms (spec 068 R4, [method fit_room]). With room for it, each button is its
## icon, its name and its key side by side, [constant ROW_HEIGHT] tall. Where that would reach
## into the [constant LEFT_ROOM] the bar leaves at its left (960x540), the keys are dropped from
## the buttons ([member shows_keys] is false; the tooltips still name them) and each button is its
## icon over its name, so every name stays whole in one row. The buttons are [constant
## UiTheme.BAR_BUTTON]s, padded a little less than other buttons.

## UI pixels between the bar and the room's right edge, and above the hero frames' line.
const MARGIN: float = 8.0
const ABOVE_FRAMES: float = 4.0
## A button's height, around its 16x16 icon, when the icon, the name and the key stand side by
## side.
const ROW_HEIGHT: float = 28.0
## A button's height in the narrower form: its icon over a line of text, a pixel between them,
## and the padding.
const NARROW_HEIGHT: float = 16.0 + 1.0 + UiText.LINE_HEIGHT + 2.0 * (UiTheme.BAR_PAD_Y + 1)
## UI pixels between two buttons.
const GAP: int = 2
## UI pixels the bar leaves free at its left: what the fourth hero window, cascaded from the left,
## needs beside it at 1280x720 (spec 060). At 960x540 a hero window's
## default place and the ticker's longest line (spec 062 R10) need 635 of them.
const LEFT_ROOM: float = 754.0
## Spec 068 R2: the one word for each window, on its button, in the help's key list and in
## tooltips. [member UiWindow.short_name] is given from here.
const NAMES: Dictionary[StringName, String] = {
	UiRoot.HELP: "Help",
	UiRoot.JOURNAL: "Journal",
	UiRoot.ORDERS: "Orders",
	ShopWindow.ID: "Camp",
	AreaMapWindow.ID: "Map",
	TallyWindow.ID: "Tally",
}
## Spec 068 R3: what each window is for, the end of its button's tooltip after its title and key.
const ABOUT: Dictionary[StringName, String] = {
	UiRoot.HELP: "how Colony works, and every key it answers to.",
	UiRoot.JOURNAL: "what has happened to the party, newest first.",
	UiRoot.ORDERS: "how careful the party is, and whether it fights guardians.",
	ShopWindow.ID: "spend gold on upgrades for the whole party.",
	AreaMapWindow.ID: "the areas the party can go to, and what each holds.",
	TallyWindow.ID: "who deals, heals and takes the damage.",
}
## The reset button's word and tooltip.
const RESET_NAME: String = "Reset"
const RESET_TIP: String = "Put every window back in its place"

## Spec 068 R4: true while the buttons show their keys; false in a room too narrow for that.
var shows_keys: bool = true
## A button per window id.
var buttons: Dictionary[StringName, UiButton] = {}
## Spec 059 R6: each button's amber tag, shown while its window's [member UiWindow.badge] is
## above 0.
var badges: Dictionary[StringName, UiBadge] = {}
## The tags' own layer, just after the bar on the UI layer (spec 062 R12): drawn over every button,
## and under every window, which come later.
var tag_layer: Control
## Puts every window back where a new game has it.
var reset_button: UiButton
## The tooltip the buttons share.
var tip: UiTip

var _ui: UiRoot
## The room the bar was last laid out for.
var _fitted: Vector2i = Vector2i.ZERO
var _windows: UiWindows


func _init() -> void:
	name = "ButtonBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", GAP)


func _process(delta: float) -> void:
	advance(delta)


## Lights the buttons, shows the tags and runs their pulse on by [param delta] seconds. Called
## every frame; tests call it.
func advance(delta: float) -> void:
	refresh()
	for id: StringName in badges:
		badges[id].advance(delta)


## Call once, after the windows are registered with [param windows].
func setup(ui: UiRoot, windows: UiWindows) -> void:
	_ui = ui
	_windows = windows
	tip = UiTip.new()
	ui.frame.add_child(tip)
	tag_layer = Control.new()
	tag_layer.name = "Tags"
	tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.frame.add_child(tag_layer)
	ui.frame.move_child(tag_layer, get_index() + 1)
	windows.changed.connect(refresh)
	reset_button = UiButton.new(RESET_NAME)
	reset_button.name = "Reset"
	reset_button.icon = _icon(&"reset")
	reset_button.theme_type_variation = UiTheme.BAR_BUTTON
	reset_button.pressed.connect(windows.reset_places)
	add_child(reset_button)
	tip.attach(reset_button, RESET_TIP)
	rebuild()


## Makes a button for each window there is, then lays the bar out.
func rebuild() -> void:
	for id: StringName in _windows.ids():
		var shown: UiWindow = _windows.window(id)
		if buttons.has(id) or not shown.on_bar:
			continue
		if shown.short_name.is_empty():
			shown.short_name = NAMES.get(id, shown.title)
		var button := UiButton.new(shown.short_name)
		button.name = "Button_%s" % id
		button.icon = shown.icon
		button.theme_type_variation = UiTheme.BAR_BUTTON
		button.key_cap = true
		button.pressed.connect(_windows.toggle.bind(id))
		add_child(button)
		move_child(button, reset_button.get_index())
		buttons[id] = button
		tip.attach(button, _tip_for(shown))
		var tag := UiBadge.new()
		tag.name = "Badge_%s" % id
		tag_layer.add_child(tag)
		badges[id] = tag
	fit_room(_ui.room())
	refresh()


## Lights each button whose window is open, and shows each window's tag (spec 059 R6) over its
## button's top right corner: on the button's edge, never on its icon, name or key (spec 068 R3).
func refresh() -> void:
	for id: StringName in buttons:
		buttons[id].lit = _windows.is_open(id)
		var tag: UiBadge = badges.get(id, null)
		if tag == null:
			continue
		tag.count = _windows.window(id).badge
		tag.visible = tag.count > 0
		var button: UiButton = buttons[id]
		var edge: float = button.get_theme_stylebox(&"normal").get_margin(SIDE_TOP)
		tag.position = (
			position
			+ button.position
			+ Vector2(button.size.x - tag.size.x + 4.0, edge - tag.size.y)
		)


## Puts the bar at the bottom right of a room of [param room] UI pixels, above the frames' line:
## with the keys on the buttons where there is room, without them where there is not (spec 068
## R4).
func fit_room(room: Vector2i) -> void:
	if _ui == null:
		return
	_fitted = room
	_shape(true)
	if get_combined_minimum_size().x > room.x - MARGIN - LEFT_ROOM:
		_shape(false)
	reset_size()
	size = get_combined_minimum_size()
	position = rect_in(room).position


## Where the bar stands in a room of [param room] UI pixels: at the right, just above the hero
## frames' line (the hero windows keep clear of it). The bar's size goes by the room (spec 068
## R4), so a room it is not yet laid out for is fitted first: whoever asks before the layer has
## told the bar of a new room still gets that room's answer.
func rect_in(room: Vector2i) -> Rect2:
	if _ui == null:
		return Rect2()
	if room != _fitted:
		fit_room(room)
	var line: float = floorf(Hud.frames_line(room))
	return Rect2(Vector2(room.x - MARGIN - size.x, line - ABOVE_FRAMES - size.y).round(), size)


## Gives every button its form: [param wide], its icon, name and key side by side; else its icon
## over its name, the key left to the tooltip.
func _shape(wide: bool) -> void:
	shows_keys = wide
	var row: Array[UiButton] = [reset_button]
	row.append_array(buttons.values())
	for button: UiButton in row:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = (
			VERTICAL_ALIGNMENT_CENTER if wide else VERTICAL_ALIGNMENT_TOP
		)
		# Icon over name, a button's own layout counts the name's height twice: the icon is
		# left out of its sums (expand_icon; the theme holds it at its 16 pixels) and the
		# height given here.
		button.expand_icon = not wide
		button.custom_minimum_size.y = ROW_HEIGHT if wide else NARROW_HEIGHT
	for id: StringName in buttons:
		buttons[id].key_hint = _windows.window(id).key_hint if wide else ""


## The tooltip of [param shown]'s button: its title, its key and what it is for.
func _tip_for(shown: UiWindow) -> String:
	var named: String = "%s (%s)" % [shown.title, shown.key_hint]
	var about: String = ABOUT.get(shown.window_id, "")
	return named if about.is_empty() else "%s: %s" % [named, about]


func _icon(part: StringName) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(UiRoot.ICONS_PATH)
	return sheet.part(part) if sheet != null and sheet.has_part(part) else null
