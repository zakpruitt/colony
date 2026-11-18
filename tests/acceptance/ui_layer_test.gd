extends GutTest
## What spec 058's acceptance tests share: a main scene laid out for a chosen room, and the mouse
## and keys pushed into the viewport as the window would send them. Not a test file itself (GUT
## runs only test_*.gd); the spec's tests extend it.
##
## Mouse events are at the world's 640x360 coordinates ([method UiRoot.ui_to_world] turns a UI
## point into one). Nothing here touches the real settings or save file: each test that needs one
## has a file of its own under user://, named for this process, deleted after.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const ROOM_SMALL: Vector2i = Vector2i(960, 540)
const ROOM_LARGE: Vector2i = Vector2i(1280, 720)

var _settings_path: String = "user://test_058_windows_%d.settings" % OS.get_process_id()
var _save_path: String = "user://test_058_windows_%d.save" % OS.get_process_id()


func after_each() -> void:
	_delete_files()


func after_all() -> void:
	_delete_files()


func _delete_files() -> void:
	for path: String in [_settings_path, _save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- Helpers -------------------------------------------------------------------


## A main scene, its own processing off, laid out for [param room]; [param settings] keeps its
## windows' places.
func _main(room: Vector2i = ROOM_SMALL, settings: SoundSettings = null) -> Main:
	var main: Main = MAIN_SCENE.instantiate()
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


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## Moves the mouse to [param at], in the world's screen pixels, as the window would.
func _move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event, true)


func _button(at: Vector2, pressed: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	if index == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


## A left click at [param at], a point in UI pixels on [param ui].
func _click_ui(ui: UiRoot, at: Vector2) -> void:
	var world: Vector2 = ui.ui_to_world(at)
	_move(world)
	_button(world, true)
	_button(world, false)


## A left click at [param at], in the world's screen pixels.
func _click_world(at: Vector2) -> void:
	_move(at)
	_button(at, true)
	_button(at, false)


## Drags [param window] by its title bar by [param by] UI pixels, in [param steps] moves, calling
## [param between] after each move (a frame of the game).
func _drag(
	ui: UiRoot, window: UiWindow, by: Vector2, steps: int = 8, between: Callable = Callable()
) -> void:
	var grip: Vector2 = window.title_bar.get_global_rect().position + Vector2(12, 6)
	_move(ui.ui_to_world(grip))
	_button(ui.ui_to_world(grip), true)
	for step: int in range(1, steps + 1):
		_move(ui.ui_to_world(grip + by * float(step) / steps), true)
		if between.is_valid():
			between.call()
	_button(ui.ui_to_world(grip + by), false)


## Every control on [param node]'s branch.
func _controls(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			into.append(child as Control)
		_controls(child, into)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
