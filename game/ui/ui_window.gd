class_name UiWindow
extends PanelContainer
## A window on the UI layer (spec 058 R5): a title bar with its name and a close button over its
## [member content]. It is dragged by the title bar and kept so the bar never leaves the room;
## [UiWindows] keeps the windows' order (a click anywhere brings one to the front), closes the
## front one on [kbd]Esc[/kbd] and remembers where each was. A window stops every click on it, so
## nothing under it (the world, the old HUD, another window) hears one. It never pauses the game.

## Emitted when the window opens or closes.
signal open_changed(window: UiWindow)
## Emitted when a drag of the title bar ends.
signal moved(window: UiWindow)

## UI pixels of the title bar that are always kept inside the room, left and right.
const KEEP_SHOWN: float = 48.0

## The window's name in the settings file and to [UiWindows].
var window_id: StringName
## The name in its title bar.
var title: String = "":
	set(value):
		title = value
		if title_label != null:
			title_label.text = value
## What the window shows, under the title bar.
var content: Control
## Where a new game puts the window, its top-left corner in UI pixels.
var default_place: Vector2 = Vector2.ZERO
## True once the player has put the window somewhere (or a saved place was put back): until then
## it follows [member default_place] when the room changes.
var placed: bool = false
## The key that opens and closes it, as the help list names it ([code]"H"[/code]); its code.
var key_hint: String = ""
var keycode: Key
## Its picture on the button bar.
var icon: Texture2D
## False for a window with no button on the bar (spec 060: a hero's window opens from its frame).
var on_bar: bool = true

var title_bar: PanelContainer
var title_label: Label
var close_button: UiButton

var _dragging: bool = false
## Where in the title bar the drag took hold, in its own UI pixels.
var _grab: Vector2 = Vector2.ZERO
## The room the window is kept in.
var _room: Vector2 = Vector2(UiRoot.MIN_ROOM)


func _init(
	id: StringName, window_title: String, body: Control, key_label: String = "", key: int = 0
) -> void:
	window_id = id
	name = "Window_%s" % id
	theme_type_variation = UiTheme.WINDOW
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	key_hint = key_label
	keycode = key as Key
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title_bar = PanelContainer.new()
	title_bar.name = "TitleBar"
	title_bar.theme_type_variation = UiTheme.TITLE_BAR
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_bar.gui_input.connect(_on_title_input)
	column.add_child(title_bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	title_bar.add_child(row)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = UiTheme.TITLE
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	if not key_label.is_empty():
		var hint: Label = UiText.label("%s or Esc to close" % key_label, &"slate")
		hint.name = "Hint"
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint)
	close_button = UiButton.new("x")  # padded as every button is (R4)
	close_button.name = "Close"
	close_button.pressed.connect(close)
	row.add_child(close_button)
	var margin := MarginContainer.new()
	margin.name = "Body"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTheme.WINDOW_PAD)
	column.add_child(margin)
	content = body
	margin.add_child(body)
	title = window_title


func _gui_input(event: InputEvent) -> void:
	# A click on the window's body that nothing in it took still stops here.
	if event is InputEventMouseButton:
		accept_event()


## Shows the window where it was last.
func open() -> void:
	if visible:
		return
	visible = true
	open_changed.emit(self)


## Hides the window.
func close() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	open_changed.emit(self)


## True while the window shows.
func is_open() -> bool:
	return visible


## True while its title bar is being dragged.
func is_dragging() -> bool:
	return _dragging


## The window's size as its content asks, in whole UI pixels.
func fit_size() -> void:
	reset_size()
	size = get_combined_minimum_size().ceil()


## Moves the window to [param place] (rounded to whole UI pixels), then back inside
## [param room] as [method keep_in] does.
func place_at(place: Vector2, room: Vector2) -> void:
	position = place.round()
	keep_in(room)


## Moves the window wholly inside [param room] (the window was resized), as far as it fits: a
## window wider or taller than the room keeps its top-left corner in it. The title bar is then
## inside too, as [method keep_in] asks.
func fit_in(room: Vector2) -> void:
	_room = room
	position = (
		Vector2(
			clampf(position.x, 0.0, maxf(room.x - size.x, 0.0)),
			clampf(position.y, 0.0, maxf(room.y - size.y, 0.0))
		)
		. round()
	)
	keep_in(room)


## Keeps the title bar inside [param room] while the window is dragged: all of it top to bottom,
## and at least [constant KEEP_SHOWN] pixels of it left to right.
func keep_in(room: Vector2) -> void:
	_room = room
	var column: Control = title_bar.get_parent() as Control
	var bar_bottom: float = column.position.y + title_bar.position.y + title_bar.size.y
	if title_bar.size.y <= 0.0:
		bar_bottom = 24.0
	var shown: float = minf(KEEP_SHOWN, size.x)
	position = (
		Vector2(
			clampf(position.x, shown - size.x, maxf(room.x - shown, shown - size.x)),
			clampf(position.y, 0.0, maxf(room.y - bar_bottom, 0.0))
		)
		. round()
	)


func _on_title_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_grab = button.position
		elif _dragging:
			_dragging = false
			placed = true
			moved.emit(self)
		title_bar.accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		position += motion.position - _grab
		keep_in(_room)
		title_bar.accept_event()
