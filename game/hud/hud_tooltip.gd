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
		point_at(motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		point_at(NOWHERE)


## Gives each of [param hud]'s elements its sentence. Call once, after the HUD has built them.
func setup(hud: Hud) -> void:
	_tip([hud.depth_label, hud.depth_caption], "How deep the party is now.")
	_tip([hud.state_label], "What the party is doing right now, and why.")
	_tip([hud.stable_label], "The last safe depth: a wipe sends the party back there.")
	_tip(
		[hud.stable_note, hud.stable_bar, hud.stable_next],
		func() -> String:
			if hud.stable_bar.visible:
				return "Time left until this depth is safe."
			return "This depth is safe: a wipe comes back here."
	)
	_tip([hud.target_label, hud.target_caption], "The depth the party is heading for.")
	_tip([hud.minus_button], "Set the target one depth up.")
	_tip([hud.plus_button], "Set the target one depth down.")
	_tip([hud.auto_button], "When on, the party goes deeper each time a depth is safe.")
	_tip([hud.shop_button], "Spend gold on upgrades for the whole party.")
	_tip([hud.speed_button], "How fast the game runs: click (or press F) for 1x, 2x or 4x.")
	_tip([hud.gold_panel], "Gold from fights, to spend in the Shop.")
	_tip([hud.boss_bar], "A guardian holds the way down: beat it to go deeper.")
	if hud.help_button != null:
		_tip([hud.help_button], "Help: what everything means, and the keys.")
	for frame: HeroFrame in hud.frames:
		_tip([frame], "Click for details")
	if hud.goals != null:
		# Spec 037 R5: each goal line says how to get there.
		for i: int in hud.goals.rows.size():
			tip([hud.goals.rows[i]], hud.goals.hint.bind(i))


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
