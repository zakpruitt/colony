class_name UiTip
extends PanelContainer
## The UI layer's tooltip (spec 058 R4, R7): a title in bold where there is one, then one or two
## plain sentences wrapped to [constant WIDTH], in a small dark box, shown once the mouse has
## rested [constant DELAY] seconds on a control it was attached to, above the control (below it if
## there is no room above), always inside the room and never over the control. Drawn by the theme's
## [constant UiTheme.TIP] look and never in the way of a click.
##
## A tip hears the mouse through each control's own entering and leaving, or, with
## [member follows_mouse] (spec 061: the frame of the screen, whose labels take no mouse), by
## finding which of its controls is under each move of the mouse, as [method point_at] does for
## tests. [member covered] says where the mouse is on something in front (a window), which is
## nowhere for a tip that follows the mouse.

## Seconds the mouse rests on a control before its tip shows.
const DELAY: float = 0.4
## UI pixels between the tip and its control.
const GAP: float = 4.0
## The widest a tip's text runs before it wraps, in UI pixels.
const WIDTH: float = 240.0
## Where the mouse is when it is nowhere.
const NOWHERE: Vector2 = Vector2(-10000, -10000)

## The sentences, and the bold title over them (hidden when there is none).
var label: Label
var title_label: Label
## True for a tip that finds its control under the mouse itself (see the class description).
var follows_mouse: bool = false
## Given a point in the viewport's coordinates (where input events are), true while something in
## front covers it; unset, nothing does.
var covered: Callable
## The room the tip stays inside, in its parent's pixels from the parent's top left; zero for the
## parent's own size.
var room: Vector2 = Vector2.ZERO

## Each control's text and title: a String, or a Callable that returns one.
var _texts: Dictionary[Control, Variant] = {}
var _titles: Dictionary[Control, Variant] = {}
## The order controls were attached in: the first under a point wins.
var _order: Array[Control] = []
var _hovered: Control
var _rested: float = 0.0
var _box: VBoxContainer


func _init() -> void:
	name = "Tip"
	theme_type_variation = UiTheme.TIP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 1)
	add_child(_box)
	title_label = UiText.label("", &"yellow", true)
	title_label.name = "Title"
	title_label.visible = false
	_box.add_child(title_label)
	label = Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", Palette.color(&"white"))
	_box.add_child(label)


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not follows_mouse:
		return
	if covered.is_valid() and covered.call(motion.position):
		point_at(NOWHERE)
		return
	# Through the layer's transform, never a camera's (as the old HUD's tooltip reads the mouse).
	var layer: CanvasLayer = get_canvas_layer_node()
	var to_canvas: Transform2D = (
		layer.get_final_transform() if layer != null else Transform2D.IDENTITY
	)
	point_at(to_canvas.affine_inverse() * motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and follows_mouse:
		point_at(NOWHERE)


## Gives [param control] the tip [param text] (a String, or a Callable returning one, read as the
## tip shows) under the bold [param title] ("" for none); a second call changes them.
func attach(control: Control, text: Variant, title: Variant = "") -> void:
	if not _texts.has(control):
		_order.append(control)
		if not follows_mouse:
			control.mouse_entered.connect(_on_entered.bind(control))
			control.mouse_exited.connect(_on_exited.bind(control))
	_texts[control] = text
	_titles[control] = title


## The tip [param control] was given, or "".
func text_for(control: Control) -> String:
	return _read(_texts.get(control, ""))


## The title [param control] was given, or "".
func title_for(control: Control) -> String:
	return _read(_titles.get(control, ""))


## The sentences showing now, or "" while hidden.
func shown_text() -> String:
	return label.text if visible else ""


## The title showing now, or "" while hidden or untitled.
func shown_title() -> String:
	return title_label.text if visible and title_label.visible else ""


## The control whose tip is showing or waiting to, or null.
func hovered() -> Control:
	return _hovered


## Puts the mouse at [param at] (global coordinates of this tip's canvas, [constant NOWHERE] for
## none): the first visible control attached under it is hovered. A move onto another control
## starts the delay again; a move off every control hides the tip at once.
func point_at(at: Vector2) -> void:
	var found: Control = null
	for control: Control in _order:
		if (
			is_instance_valid(control)
			and control.is_visible_in_tree()
			and control.get_global_rect().has_point(at)
		):
			found = control
			break
	if found == _hovered:
		return
	if found == null:
		_on_exited(_hovered)
	else:
		_on_entered(found)


## Counts the mouse's rest on by [param delta] seconds, and shows the tip once it is long enough.
## Called every frame; tests call it.
func advance(delta: float) -> void:
	if _hovered == null or not is_instance_valid(_hovered) or not _hovered.is_visible_in_tree():
		_hovered = null
		visible = false
		return
	_rested += delta
	if _rested >= DELAY:
		_show()


func _show() -> void:
	var text: String = _read(_texts.get(_hovered, ""))
	var title: String = _read(_titles.get(_hovered, ""))
	if visible and text == label.text and title == title_label.text:
		_place()
		return
	title_label.text = title
	title_label.visible = not title.is_empty()
	label.text = text
	# Wrapped at WIDTH: a short tip is as wide as its text, a long one runs onto more lines.
	var widest: float = UiText.width(title, true) - UiText.SPACING
	for line: String in text.split("\n"):
		widest = maxf(widest, UiText.width(line) - UiText.SPACING)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(widest + 1.0, WIDTH)
	reset_size()
	size = get_combined_minimum_size()
	_place()
	visible = true


## Puts the box above its control, or below it with no room above, inside the room.
func _place() -> void:
	var parent: Control = get_parent() as Control
	var inside: Vector2 = room
	if inside == Vector2.ZERO:
		inside = parent.size if parent != null else size
	var to_local: Transform2D = (
		parent.get_global_transform().affine_inverse() if parent != null else Transform2D.IDENTITY
	)
	var over: Rect2 = to_local * _hovered.get_global_rect()
	var at := Vector2(over.get_center().x - size.x / 2.0, over.position.y - GAP - size.y)
	if at.y < 0.0:
		at.y = over.end.y + GAP
	at.x = clampf(at.x, 0.0, maxf(inside.x - size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(inside.y - size.y, 0.0))
	position = at.round()


func _on_entered(control: Control) -> void:
	_hovered = control
	_rested = 0.0
	visible = false


func _on_exited(control: Control) -> void:
	if _hovered == control:
		_hovered = null
		visible = false


static func _read(source: Variant) -> String:
	if source is Callable:
		return str((source as Callable).call())
	return str(source)
