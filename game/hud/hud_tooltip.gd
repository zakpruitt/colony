class_name HudTooltip
extends Control
## The HUD's tooltips (spec 030 R4): resting the mouse on a HUD element for [constant DELAY]
## seconds shows a small box with one plain sentence about it; moving off hides it at once.
##
## [method setup] gives each element its sentence. The box drops just below the top band for an
## element in the top half of the screen and sits just above an element in the bottom half, so it
## never covers what it explains, and it is pushed sideways to stay on the screen. The mouse is
## followed through [method _input] (or [method point_at]), and the delay runs only in
## [method advance], so a test can step it exactly. Nothing here takes a click.

## Seconds the mouse must rest on an element before its sentence shows.
const DELAY: float = 0.4
## Pixels between the box and the element it explains, or the top band.
const GAP: float = 2.0
## Space between the text and the box's border.
const PADDING: Vector2 = Vector2(4, 2)
## The box's height: one line of text.
const HEIGHT: float = 13.0
## Where the mouse is when it is nowhere over the screen.
const NOWHERE: Vector2 = Vector2(-1000, -1000)

## The box shown, with the sentence in it; hidden while no sentence shows.
var box: HudPanel

var _label: Label
## Each element's controls (the first is the element itself; the others widen where the mouse can
## rest) and its sentence, as a Callable returning a String.
var _targets: Array[Array] = []
var _sentences: Array[Callable] = []
var _mouse: Vector2 = NOWHERE
var _hovered: int = -1
var _rested: float = 0.0
## The HUD, whose UI-layer windows hide what is under them from the mouse.
var _hud: Hud


func _init() -> void:
	name = "HudTooltip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO
	box = HudPanel.new()
	box.name = "Box"
	box.visible = false
	box.bevel = Palette.color(&"dusk")
	box.border = Palette.color(&"slate")
	add_child(box)
	_label = PixelText.label("", &"white")
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = PADDING
	box.add_child(_label)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		# Under a window or the button bar of the UI layer (spec 058) is nowhere for the HUD.
		var covered: bool = (
			_hud != null and _hud.windows != null and _hud.windows.covers(motion.position)
		)
		point_at(NOWHERE if covered else motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		point_at(NOWHERE)


## Gives each of [param hud]'s elements its sentence. Call once, after the HUD has built them.
## (The frame of the screen has its own, [member Hud.frame_tip]: spec 061.)
func setup(hud: Hud) -> void:
	_hud = hud
	_tip([hud.shop_button], "Spend gold on upgrades for the whole party.")
	if hud.tally != null:
		# Spec 045 R6: the tally's tabs, its span switch and its button.
		for i: int in hud.tally.tab_buttons.size():
			_tip([hud.tally.tab_buttons[i]], TallyPanel.TAB_TIPS[i])
		for i: int in hud.tally.span_buttons.size():
			_tip([hud.tally.span_buttons[i]], TallyPanel.SPAN_TIPS[i])
		_tip([hud.tally_button], "The party tally: who deals, heals and takes the damage (T).")
	if hud.goals != null:
		# Spec 037 R5: each goal line says how to get there; spec 042 R3: then what a click does.
		for i: int in hud.goals.rows.size():
			tip([hud.goals.rows[i]], HudTooltip._goal_tip.bind(hud.goals, i))


## Moves the mouse to [param at], in screen pixels. A move onto another element starts its delay
## again; a move off every element hides the box at once.
func point_at(at: Vector2) -> void:
	_mouse = at
	_follow()


## Runs the delay on by [param delta] seconds and shows or hides the box. Called every frame by the
## HUD; tests call it.
func advance(delta: float) -> void:
	if _follow():
		_rested += delta
	if _hovered < 0 or _rested < DELAY:
		box.visible = false
		return
	_show(_hovered)


## The sentence showing, or "" when hidden.
func shown_text() -> String:
	return _label.text if box.visible else ""


## Notes which element is under the mouse; true if it is the one already noted.
func _follow() -> bool:
	var index: int = _target_at(_mouse)
	if index == _hovered:
		return index >= 0
	_hovered = index
	_rested = 0.0
	box.visible = false
	return false


## Gives an element its sentence after [method setup]: [param controls] are its controls (the first
## is the element itself), and [param sentence] is a String or a Callable returning one.
func tip(controls: Array, sentence: Variant) -> void:
	_tip(controls, sentence)


## As [method tip], but this element is found before every other under the mouse: for a control
## lying over another element (spec 053: the area's name, a button over the depth's caption).
func tip_first(controls: Array, sentence: Variant) -> void:
	_tip(controls, sentence)
	_targets.push_front(_targets.pop_back())
	_sentences.push_front(_sentences.pop_back())
	_hovered = -1


## The tooltip of goal line [param index]: how to get there, then what a click does (none for a
## finished goal).
static func _goal_tip(goals: Goals, index: int) -> String:
	var click: String = goals.action(index)
	return goals.hint(index) if click.is_empty() else goals.hint(index) + " " + click


func _tip(controls: Array, sentence: Variant) -> void:
	var targets: Array[Control] = []
	for control: Variant in controls:
		if control is Control:
			targets.append(control)
	if targets.is_empty():
		return
	_targets.append(targets)
	if sentence is Callable:
		_sentences.append(sentence)
	else:
		var text: String = sentence
		_sentences.append(func() -> String: return text)


## The index of the element under [param at], or -1.
func _target_at(at: Vector2) -> int:
	for i: int in _targets.size():
		var first: Control = _targets[i][0]
		if not first.is_visible_in_tree():
			continue
		if _rect(i).has_point(at):
			return i
	return -1


## The screen rectangle of element [param index]: its shown controls together.
func _rect(index: int) -> Rect2:
	var rect := Rect2()
	var started: bool = false
	for control: Control in _targets[index]:
		if not control.is_visible_in_tree():
			continue
		var each: Rect2 = control.get_global_rect()
		rect = each if not started else rect.merge(each)
		started = true
	return rect


func _show(index: int) -> void:
	var sentence: Callable = _sentences[index]
	var text: String = sentence.call()
	if _label.text != text:
		_label.text = text
		_label.reset_size()
	var width: float = PixelText.width(text) + PADDING.x * 2.0
	box.size = Vector2(width, HEIGHT)
	var element: Rect2 = _rect(index)
	var y: float = element.end.y + GAP
	if element.get_center().y < Hud.SCREEN.y / 2.0:
		y = maxf(element.end.y, Hud.TOP_BAND) + GAP
	else:
		y = element.position.y - GAP - HEIGHT
	var x: float = element.get_center().x - width / 2.0
	x = clampf(x, 1.0, Hud.SCREEN.x - 1.0 - width)
	box.global_position = Vector2(floorf(x), floorf(y))
	box.queue_redraw()
	box.visible = true
