extends "res://tests/acceptance/ui_layer_test.gd"
## What the acceptance tests of spec 061 (the frame of the screen on the sharp layer) share: their
## constants and helpers, on top of ui_layer_test.gd's. Kept apart so the tests' own file stays
## under gdlint's length.

const STEP: float = 1.0 / 60.0
const LIMIT_TICKS: int = 30_000
const STRONG_LEVEL: int = 30
const ROOMS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720)]
## Window sizes giving each pairing of world and UI scale: 1 and 1, 3 and 2, 4 and 2.
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const WIKI: String = "res://docs/wiki/index.html"
const SHOWCASE: String = "res://game/dev/showcase.gd"

# --- Helpers -------------------------------------------------------------------


## One frame of one tick: the simulation, the world, the effects, the HUD.
func _tick(main: Main) -> void:
	main.simulation.step()
	main.world.sync(STEP)
	main.effects.advance(STEP)
	main.hud.advance(STEP)


## Steps [param main] a tick a frame until [param done] is true, at most [param ticks] ticks.
func _until(main: Main, done: Callable, ticks: int = LIMIT_TICKS) -> bool:
	for i: int in ticks:
		if done.call():
			return true
		_tick(main)
	return done.call()


func _raise(main: Main, level: int) -> void:
	for hero: Hero in main.simulation.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


## Sets the party up just before the guardian of stage [param depth].
func _before_guardian(main: Main, depth: int) -> void:
	var sim: Simulation = main.simulation
	var e: Expedition = sim.expedition
	var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


## A guardian fight under way in [param main], strong enough heroes to last.
func _guardian_fight(main: Main) -> bool:
	_before_guardian(main, Expedition.GUARDIAN_EVERY)
	_raise(main, STRONG_LEVEL)
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


## A real click on [param control], a control on the UI layer, then a frame of the HUD.
func _click(main: Main, control: Control) -> void:
	_click_ui(main.ui, control.get_global_rect().get_center())
	main.hud.advance(STEP)


func _press(main: Main, keycode: Key) -> void:
	_key(keycode)
	main.hud.advance(STEP)


## Where [param node], a node of the world's viewport, is on the UI layer, in UI pixels.
func _on_ui(main: Main, node: CanvasItem) -> Vector2:
	return main.ui.world_to_ui(node.get_global_transform_with_canvas().origin)


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
	_move(Vector2(-50, -50))
	main.hud.advance(STEP)
	_move(main.ui.ui_to_world(control.get_global_rect().get_center()))
	main.hud.advance(0.2)
	assert_eq(tip.shown_text(), "", "%s: nothing before 0.4 s" % control.name)
	main.hud.advance(0.25)
	return tip.shown_text()
