class_name AwayPanel
extends HudPanel
## The panel in the middle of the screen after a replay of the time away (spec 019, R5): how
## long the party was away and what changed. Closes on a click or any key, or by itself after
## [constant SHOW_SECONDS]. The game runs behind it.

## Seconds the panel stays up if nobody closes it.
const SHOW_SECONDS: float = 12.0
## Space inside the panel's border, and between lines.
const PADDING: Vector2 = Vector2(8, 6)
const LINE_HEIGHT: float = 10.0

var _left: float = SHOW_SECONDS
var _lines: Array[Label] = []


## A panel telling of [param report]; [param party] names the heroes.
func _init(report: AwayReport, party: Party) -> void:
	super()
	name = "AwayPanel"
	_add_line("While you were away", &"yellow")
	_add_line("Away %s" % duration(report.seconds), &"white")
	_add_line("Gold +%s" % Hud.group_thousands(report.gold_gained), &"yellow")
	if report.depth_after == report.depth_before:
		_add_line("Depth %d" % report.depth_after, &"silver")
	else:
		_add_line("Depth %d to %d" % [report.depth_before, report.depth_after], &"silver")
	_add_line("Slain %s   Wipes %d" % [Hud.group_thousands(report.kills), report.wipes], &"silver")
	for hero: Hero in party.heroes:
		var gained: int = report.levels_gained.get(hero.id, 0)
		var word: String = "level" if gained == 1 else "levels"
		var colour: StringName = &"green" if gained > 0 else &"steel"
		_add_line("%s +%d %s" % [hero.def().display_name, gained, word], colour)
	_add_line("Click or press any key", &"steel")
	_layout()


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var button: InputEventMouseButton = event as InputEventMouseButton
	if (key != null and key.pressed and not key.echo) or (button != null and button.pressed):
		close()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## Counts down the time left; closes the panel when it runs out. Tests call it.
func advance(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		close()


## Hides the panel and frees it.
func close() -> void:
	if is_queued_for_deletion():
		return
	visible = false
	set_process(false)
	set_process_input(false)
	queue_free()


## Every line the panel shows, one per row.
func text() -> String:
	var rows: PackedStringArray = []
	for line: Label in _lines:
		rows.append(line.text)
	return "\n".join(rows)


## [param seconds] as hours and minutes: "8h 0m", "1h 5m", "30m".
static func duration(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %dm" % [minutes / 60, minutes % 60]


func _add_line(line: String, colour: StringName) -> void:
	var label: Label = PixelText.label(line, colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_lines.append(label)


func _layout() -> void:
	var width: float = 0.0
	for line: Label in _lines:
		width = maxf(width, PixelText.width(line.text))
	size = Vector2(width + PADDING.x * 2.0, _lines.size() * LINE_HEIGHT + PADDING.y * 2.0 - 2.0)
	for i: int in _lines.size():
		var line: Label = _lines[i]
		var line_width: float = PixelText.width(line.text)
		var x: float = (
			PADDING.x if i > 0 and i < _lines.size() - 1 else floorf((size.x - line_width) / 2.0)
		)
		line.position = Vector2(x, PADDING.y + i * LINE_HEIGHT - 1.0)
	position = ((Hud.SCREEN - size) / 2.0).floor()
