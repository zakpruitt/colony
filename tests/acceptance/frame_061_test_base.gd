extends "res://tests/support/main_fixture.gd"
## What the acceptance tests of spec 061 (the frame of the screen on the sharp layer) share: their
## constants and helpers, on top of MainFixture's. Kept apart so the tests' own file stays
## under gdlint's length.

const STRONG_LEVEL: int = 30
const ROOMS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720)]
## Window sizes giving each pairing of world and UI scale: 1 and 1, 3 and 2, 4 and 2.
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const WIKI: String = "res://docs/wiki/index.html"

# --- Helpers -------------------------------------------------------------------


## One frame of one tick: the simulation, the world, the effects, the HUD.
func _tick(main: Main) -> void:
	_frame(main, 1, STEP, [&"effects", &"hud"])


## Steps [param main] a tick a frame until [param done] is true, at most [param ticks] ticks.
func _until(main: Main, done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		if done.call():
			return true
		_tick(main)
	return done.call()


## A guardian fight under way in [param main], strong enough heroes to last.
func _guardian_fight(main: Main) -> bool:
	before_guardian(main.simulation, Expedition.GUARDIAN_EVERY)
	raise_party(main.simulation, STRONG_LEVEL)
	return _until(main, func() -> bool: return main.hud.boss_bar.is_showing())


func _fight(main: Main) -> bool:
	return _until(
		main,
		func() -> bool:
			return (
				main.simulation.expedition.battle != null
				and main.simulation.expedition.state == Expedition.State.FIGHTING
			)
	)


## The pieces of the frame, by name.
func _pieces(main: Main) -> Dictionary[String, Control]:
	var hud: Hud = main.hud
	var pieces: Dictionary[String, Control] = {
		"place panel": hud.place_panel,
		"countdown": hud.countdown,
		"purse": hud.purse,
	}
	if hud.boss_bar.visible:
		pieces["boss bar"] = hud.boss_bar
	for frame: HeroFrameView in hud.frames:
		pieces[String(frame.name)] = frame
	return pieces


## Where [param node], a node of the world's viewport, is on the UI layer, in UI pixels.
func _on_ui(main: Main, node: CanvasItem) -> Vector2:
	return main.ui.world_to_ui(node.get_global_transform_with_canvas().origin)


## Where [param node], a thing flying to the frame, is going, on the UI layer in UI pixels:
## [param target] is its own goal, in the world pixels its place is in. It is put exactly there
## the frame it arrives, and is gone with it.
func _goal_on_ui(main: Main, node: Node2D, target: Callable) -> Vector2:
	var goal: Vector2 = target.call()
	var parent: CanvasItem = node.get_parent() as CanvasItem
	return main.ui.world_to_ui(parent.get_global_transform_with_canvas() * goal)


## The names of what on [param layer] draws over [param item]: anything later in the draw order
## (the tree's, or a higher z) whose rectangle meets [param item]'s.
func _drawn_over(layer: CanvasLayer, item: Control) -> Array[String]:
	var order: Array[CanvasItem] = []
	_in_draw_order(layer, order)
	var box: Rect2 = item.get_global_rect()
	var over: Array[String] = []
	var after: bool = false
	for other: CanvasItem in order:
		if other == item:
			after = true
			continue
		if item.is_ancestor_of(other) or other.is_ancestor_of(item):
			continue
		if not other.is_visible_in_tree():
			continue
		var later: bool = _z_of(other) > _z_of(item) or (after and _z_of(other) == _z_of(item))
		var control: Control = other as Control
		var rect: Rect2 = control.get_global_rect() if control != null else box
		if later and rect.intersects(box) and rect.has_area():
			over.append(String(other.get_path()))
	return over


func _in_draw_order(node: Node, order: Array[CanvasItem]) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem:
			order.append(child as CanvasItem)
		_in_draw_order(child, order)


func _z_of(item: CanvasItem) -> int:
	var z: int = 0
	var at: Node = item
	while at is CanvasItem:
		var canvas_item: CanvasItem = at as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		at = at.get_parent()
	return z


## The emitted events go to the world's listeners stamped with the current tick, so they are recent.
func _emit(main: Main, kind: SimEvent.Kind, source: int, target: int, amount: int) -> void:
	main.world.sim_event.emit(SimEvent.new(kind, main.simulation.tick, source, target, amount))


## The rectangle [param label]'s text inks, in UI pixels.
func _ink(label: Label) -> Rect2:
	var bold: bool = label.get_theme_font(&"font") == UiText.font(true)
	var scale: float = float(label.get_theme_font_size(&"font_size")) / float(UiText.SIZE)
	var width: float = (UiText.width(label.text, bold) - UiText.SPACING) * scale
	var at: Vector2 = label.get_global_rect().position
	return Rect2(at, Vector2(width, UiText.LINE_HEIGHT * scale))


## Every label of [param node]'s branch that shows text.
func _shown_labels(node: Node) -> Array[Label]:
	var all: Array[Control] = []
	_controls(node, all)
	var labels: Array[Label] = []
	for control: Control in all:
		var label: Label = control as Label
		if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			labels.append(label)
	return labels


## Rests the real mouse on [param control] (on the UI layer) until its tip shows, and returns the
## tip's sentences ("" if none came).
func _rest_on(main: Main, control: Control) -> String:
	var tip: UiTip = main.hud.frame_tip
	mouse_move(Vector2(-50, -50))
	main.hud.advance(STEP)
	mouse_move(main.ui.ui_to_world(control.get_global_rect().get_center()))
	main.hud.advance(0.2)
	assert_eq(tip.shown_text(), "", "%s: nothing before 0.4 s" % control.name)
	main.hud.advance(0.25)
	return tip.shown_text()
