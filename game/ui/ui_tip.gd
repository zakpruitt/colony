class_name UiTip
extends PanelContainer
## The UI layer's tooltip (spec 058 R4, R7): one plain sentence in a small dark box, shown once the
## mouse has rested [constant DELAY] seconds on a control it was attached to, above the control
## (below it if there is no room above), always inside the room. Drawn by the theme's
## [constant UiTheme.TIP] look and never in the way of a click.

## Seconds the mouse rests on a control before its tip shows.
const DELAY: float = 0.4
## UI pixels between the tip and its control.
const GAP: float = 4.0

var label: Label

var _texts: Dictionary[Control, String] = {}
var _hovered: Control
var _rested: float = 0.0


func _init() -> void:
	name = "Tip"
	theme_type_variation = UiTheme.TIP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", Palette.color(&"white"))
	add_child(label)


func _process(delta: float) -> void:
	advance(delta)


## Gives [param control] the tip [param text]; a second call changes the text.
func attach(control: Control, text: String) -> void:
	if not _texts.has(control):
		control.mouse_entered.connect(_on_entered.bind(control))
		control.mouse_exited.connect(_on_exited.bind(control))
	_texts[control] = text


## The tip [param control] was given, or "".
func text_for(control: Control) -> String:
	return _texts.get(control, "")


## The sentence showing now, or "" while hidden.
func shown_text() -> String:
	return label.text if visible else ""


## Counts the mouse's rest on by [param delta] seconds, and shows the tip once it is long enough.
## Called every frame; tests call it.
func advance(delta: float) -> void:
	if _hovered == null or not is_instance_valid(_hovered) or not _hovered.is_visible_in_tree():
		_hovered = null
		visible = false
		return
	_rested += delta
	if _rested >= DELAY and not visible:
		_show()


func _show() -> void:
	label.text = _texts.get(_hovered, "")
	reset_size()
	size = get_combined_minimum_size()
	var room: Vector2 = (get_parent() as Control).size if get_parent() is Control else size
	var over: Rect2 = _hovered.get_global_rect()
	var at := Vector2(over.get_center().x - size.x / 2.0, over.position.y - GAP - size.y)
	if at.y < 0.0:
		at.y = over.end.y + GAP
	at.x = clampf(at.x, 0.0, maxf(room.x - size.x, 0.0))
	position = at.round()
	visible = true


func _on_entered(control: Control) -> void:
	_hovered = control
	_rested = 0.0
	visible = false


func _on_exited(control: Control) -> void:
	if _hovered == control:
		_hovered = null
		visible = false
