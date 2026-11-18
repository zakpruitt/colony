class_name AwayWindow
extends UiWindow
## The report after time away (spec 062 R5, specs 019 and 031): a window that opens by itself in
## the middle of the room, in front of every other, telling [AwayStory]'s rows as a short list with
## the values right-aligned, over a button that closes it. [kbd]Esc[/kbd] closes it as it closes
## any front window; it also goes by itself after [constant SHOW_SECONDS], but never while the
## mouse is on it. It is not one of the windows kept in the settings and has no button on the bar.

## The window's id.
const ID: StringName = &"away"
## Seconds the report stays up if nobody closes it, counted only while the mouse is off it.
const SHOW_SECONDS: float = 12.0
## The closing button's text.
const CLOSE_TEXT: String = "Back to the game"
## UI pixels between the label column and the value column.
const COLUMN_GAP: int = 24

## The list's labels and values, a pair per row.
var labels: Array[Label] = []
var values: Array[Label] = []
## Closes the report.
var close_button_bottom: UiButton

var _left: float = SHOW_SECONDS
## Where the mouse is, in the viewport's coordinates (where input events are).
var _mouse: Vector2 = UiTip.NOWHERE


## A report telling of [param report]; [param party] names the heroes.
func _init(report: AwayReport, party: Party) -> void:
	var body := VBoxContainer.new()
	body.name = "Report"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 8)
	var grid := GridContainer.new()
	grid.name = "Rows"
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", COLUMN_GAP)
	grid.add_theme_constant_override(&"v_separation", 1)
	body.add_child(grid)
	for row: AwayStory.Row in AwayStory.rows(report, party):
		var label: Label = UiText.label(row.label, row.colour)
		grid.add_child(label)
		labels.append(label)
		var value: Label = UiText.label(row.value, row.colour, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
		values.append(value)
	close_button_bottom = UiButton.new(CLOSE_TEXT)
	close_button_bottom.name = "Done"
	close_button_bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(close_button_bottom)
	super(ID, AwayStory.TITLE, body)
	name = "AwayWindow"
	on_bar = false
	close_button_bottom.pressed.connect(close)
	open_changed.connect(_on_open_changed)


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_mouse = motion.position


## Counts down the time left while the mouse is off the report; closes it when it runs out.
## Tests call it.
func advance(delta: float) -> void:
	if not is_open() or is_queued_for_deletion():
		return
	if is_under(_mouse):
		return
	_left -= delta
	if _left <= 0.0:
		close()


## True when [param at], a point in the viewport's coordinates, is on the report.
func is_under(at: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * at
	return Rect2(Vector2.ZERO, size).has_point(local)


## Every line the report shows, one per row: the title, each row's label and value, and the
## closing button.
func text() -> String:
	var lines: PackedStringArray = [AwayStory.TITLE]
	for i: int in labels.size():
		var value: String = values[i].text
		lines.append(labels[i].text if value.is_empty() else "%s %s" % [labels[i].text, value])
	lines.append(CLOSE_TEXT)
	return "\n".join(lines)


## Puts the report in the middle of a room of [param room] UI pixels.
func centre_in(room: Vector2) -> void:
	fit_size()
	position = ((room - size) / 2.0).floor()


## Closes every report among [param windows]' windows (a window opened by the player closes it, as
## the old panels did: spec 059), unless the windows are opening those left open last session,
## which open under it (spec 062 R5).
static func close_in(windows: UiWindows) -> void:
	if windows == null or windows.is_opening_waiting():
		return
	for child: Node in windows.get_children():
		if child is AwayWindow:
			(child as AwayWindow).close()


## Once closed, the report is gone for good.
func _on_open_changed(_window: UiWindow) -> void:
	if not is_open() and not is_queued_for_deletion():
		set_process(false)
		set_process_input(false)
		queue_free()
