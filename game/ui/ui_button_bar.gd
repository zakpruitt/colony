class_name UiButtonBar
extends HBoxContainer
## The row of window buttons (spec 058 R7), at the bottom right of the UI layer just above the
## line of the hero frames: one button per window on the layer, in the order the windows were
## made, each its window's icon. A click opens or closes the window; a button is lit while its
## window is open; resting on one names its window and key in a tooltip ([code]Journal (J)[/code]).
## The last button, [member reset_button], puts every window back in its default place (R6).

## UI pixels between the bar and the room's right edge, and above the hero frames' line.
const MARGIN: float = 8.0
const ABOVE_FRAMES: float = 4.0
## A button's size, around its 16x16 icon.
const BUTTON_SIZE: Vector2 = Vector2(28, 28)
## The reset button's tooltip.
const RESET_TIP: String = "Put every window back in its place"

## A button per window id.
var buttons: Dictionary[StringName, UiButton] = {}
## Puts every window back where a new game has it.
var reset_button: UiButton
## The tooltip the buttons share.
var tip: UiTip

var _ui: UiRoot
var _windows: UiWindows


func _init() -> void:
	name = "ButtonBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)


func _process(_delta: float) -> void:
	refresh()


## Call once, after the windows are registered with [param windows].
func setup(ui: UiRoot, windows: UiWindows) -> void:
	_ui = ui
	_windows = windows
	tip = UiTip.new()
	ui.frame.add_child(tip)
	windows.changed.connect(refresh)
	reset_button = UiButton.new()
	reset_button.name = "Reset"
	reset_button.icon = _icon(&"reset")
	reset_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_button.custom_minimum_size = BUTTON_SIZE
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
		var button := UiButton.new()
		button.name = "Button_%s" % id
		button.icon = shown.icon
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = BUTTON_SIZE
		button.key_hint = shown.key_hint  # R4: the window's key, after its icon
		button.pressed.connect(_windows.toggle.bind(id))
		add_child(button)
		move_child(button, reset_button.get_index())
		buttons[id] = button
		tip.attach(button, "%s (%s)" % [shown.title, shown.key_hint])
	refresh()
	fit_room(_ui.room())


## Lights each button whose window is open.
func refresh() -> void:
	for id: StringName in buttons:
		buttons[id].lit = _windows.is_open(id)


## Puts the bar at the bottom right of a room of [param room] UI pixels, above the frames' line.
func fit_room(room: Vector2i) -> void:
	if _ui == null:
		return
	reset_size()
	size = get_combined_minimum_size()
	var frames_top: float = Hud.SCREEN.y - Hud.MARGIN - HeroFrame.SIZE.y
	var line: float = floorf(_ui.world_to_ui(Vector2(0, frames_top)).y)
	position = Vector2(room.x - MARGIN - size.x, line - ABOVE_FRAMES - size.y).round()


func _icon(part: StringName) -> Texture2D:
	var sheet: PixelSheet = PixelSheet.load_sheet(UiRoot.ICONS_PATH)
	return sheet.part(part) if sheet != null and sheet.has_part(part) else null
