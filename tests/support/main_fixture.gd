class_name MainFixture
extends ColonyTest
## A test of the played game: the main scene laid out for a chosen room, its own processing off,
## and played by hand a frame at a time ([method _frame]); the mouse and keys pushed into the
## viewport as the window would send them.
##
## Mouse events are at the world's 640x360 coordinates ([method UiRoot.ui_to_world] turns a UI
## point into one). Nothing here touches the real settings or save file: each test that needs one
## has a file of its own under user://, named for this process, deleted after.

const ROOM_SMALL: Vector2i = Vector2i(960, 540)
const ROOM_LARGE: Vector2i = Vector2i(1280, 720)
## A frame at 60 frames a second.
const STEP: float = 1.0 / 60.0

## Files for a test's settings and save (used by the tests that extend this).
@warning_ignore("unused_private_class_variable")
var _settings_path: String = save_path("", "settings")
@warning_ignore("unused_private_class_variable")
var _save_path: String = save_path()
## What [method _frame] moves on after the world, in order, unless a call names others: any of
## &"effects", &"sound", &"hud", &"milestones" and &"moment" (the UI layer's).
var _frame_parts: Array[StringName] = [&"hud"]

# --- Helpers -------------------------------------------------------------------


## A main scene, its own processing off, laid out for [param room]; [param settings] keeps its
## windows' places.
func _main(room: Vector2i = ROOM_SMALL, settings: SoundSettings = null) -> Main:
	var main: Main = make_main()
	main.settings = settings
	add_child_autofree(main)
	main.driver.set_process(false)
	main.world.set_process(false)
	main.effects.set_process(false)
	main.hud.set_process(false)
	main.ui.set_room_for_test(room)
	# Above GUT's runner (canvas layer 128), whose window would otherwise take the mouse; the two
	# keep their order.
	main.hud_layer.layer = 129
	main.ui.layer = 130
	return main


## One frame of [param main]: [param ticks] ticks stepped, the world synced, then each of
## [param parts] (none named: [member _frame_parts]) moved on, all by [param delta] seconds.
func _frame(main: Main, ticks: int = 1, delta: float = STEP, parts: Array[StringName] = []) -> void:
	for i: int in ticks:
		main.simulation.step()
	main.world.sync(delta)
	for part: StringName in _frame_parts if parts.is_empty() else parts:
		match part:
			&"effects":
				main.effects.advance(delta)
			&"sound":
				main.sound._process(delta)  # its clock: a voice is free again once its sound ends
			&"hud":
				main.hud.advance(delta)
			&"milestones":
				main.milestones.advance(delta)
			&"moment":
				main.ui.moment.advance(delta)
			_:
				fail_test("no part of a frame is called %s" % part)


## A left click at [param at], a point in UI pixels on [param ui].
func _click_ui(ui: UiRoot, at: Vector2) -> void:
	click(ui.ui_to_world(at))


## A real click in the middle of [param control], a control on [param main]'s UI layer.
func _click_on(main: Main, control: Control) -> void:
	_click_ui(main.ui, control.get_global_rect().get_center())


## A real click on [param control], a control on the UI layer, then a frame of the HUD.
func _click(main: Main, control: Control) -> void:
	_click_on(main, control)
	main.hud.advance(STEP)


## [method ColonyTest.press], then a frame of the HUD.
func _press(main: Main, keycode: Key, shift: bool = false) -> void:
	press(keycode, shift)
	main.hud.advance(STEP)


## Drags [param window] by its title bar by [param by] UI pixels, in [param steps] moves, calling
## [param between] after each move (a frame of the game).
func _drag(
	ui: UiRoot, window: UiWindow, by: Vector2, steps: int = 8, between: Callable = Callable()
) -> void:
	var grip: Vector2 = window.title_bar.get_global_rect().position + Vector2(12, 6)
	mouse_move(ui.ui_to_world(grip))
	mouse_button(ui.ui_to_world(grip), true)
	for step: int in range(1, steps + 1):
		mouse_move(ui.ui_to_world(grip + by * float(step) / steps), true)
		if between.is_valid():
			between.call()
	mouse_button(ui.ui_to_world(grip + by), false)


## Every control on [param node]'s branch.
func _controls(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			into.append(child as Control)
		_controls(child, into)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Appends to [param into] every Label under [param node] that is on show.
func _labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label and (child as Label).is_visible_in_tree():
			into.append(child as Label)
		_labels(child, into)
