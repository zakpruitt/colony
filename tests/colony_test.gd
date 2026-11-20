class_name ColonyTest
extends GutTest
## What every Colony test shares (spec 071): keys and the mouse pushed into the viewport as the
## window would send them, heroes raised to a level, a simulation stepped until something holds,
## the main scene, and files of this process's own under user://, deleted after each test and
## after the last one.
##
## A test script extends this, directly or through a per-spec base (`*_test_base.gd`). When a
## second test needs a helper, it moves here rather than being copied. A script that overrides
## after_each or after_all calls super() in it, or its files are left behind.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")

## The paths [method save_path] has handed out; each is deleted with its backup and temporary file.
var _saved_paths: Array[String] = []


func after_each() -> void:
	_delete_saved_files()


## Also after the last test: a Main with a save store saves again when GUT frees it, which is
## after after_each has run.
func after_all() -> void:
	_delete_saved_files()


# --- Input ---------------------------------------------------------------------


## Presses and releases [param keycode] (with Shift held if [param shift]), as the window would.
func press(keycode: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.shift_pressed = shift
		event.pressed = pressed
		get_viewport().push_input(event)


## Moves the mouse to [param at], in the world's screen pixels (640x360), with the left button
## down if [param held].
func mouse_move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event, true)


## Presses or releases [param button] at [param at], in the world's screen pixels.
func mouse_button(at: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	if button == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


## Moves the mouse to [param at] and clicks [param button] there, in the world's screen pixels.
## The mouse stays where it clicked.
func click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	mouse_move(at)
	mouse_button(at, true, button)
	mouse_button(at, false, button)


# --- The party -----------------------------------------------------------------


## Gives [param hero] the experience of [param level] (so it levels up as in play, gaining its
## points) and full health.
func raise(hero: Hero, level: int) -> void:
	hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
	hero.health = hero.max_health()


## [method raise]s every hero of [param simulation]'s party to [param level].
func raise_party(simulation: Simulation, level: int) -> void:
	for hero: Hero in simulation.party.heroes:
		raise(hero, level)


## Sets [param hero] at [param level] outright, its experience that level's. It does not level up
## through the levels between (no points gained) and does not touch its health.
func set_level_keeping_health(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)


## Sets every hero of [param simulation]'s party at [param level] outright (as
## [method set_level_keeping_health]), and its health full.
func set_party_level(simulation: Simulation, level: int) -> void:
	for hero: Hero in simulation.party.heroes:
		set_level_keeping_health(hero, level)
		hero.health = hero.max_health()


# --- The simulation ------------------------------------------------------------


## Steps [param simulation] a tick at a time until [param done] returns true, checking before each
## tick. After [param limit] ticks without it, fails the test and returns false.
func step_until(simulation: Simulation, done: Callable, limit: int) -> bool:
	for i: int in limit:
		if done.call():
			return true
		simulation.step()
	if done.call():
		return true
	fail_test("not done within %d ticks" % limit)
	return false


# --- The game ------------------------------------------------------------------


## The main scene, instantiated and not yet in the tree: no save store and no window settings
## (a Main outside a played game makes neither), no sound settings.
func make_main() -> Main:
	return MAIN_SCENE.instantiate() as Main


## A file of this process's own under user:// (every worktree on the machine shares user://),
## named for the test script and [param tag]. It is deleted, with its backup and temporary files,
## after each test and after the last one.
func save_path(tag: String = "", extension: String = "save") -> String:
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	var file_name: String = script_name if tag.is_empty() else "%s_%s" % [script_name, tag]
	var path: String = "user://%s_%d.%s" % [file_name, OS.get_process_id(), extension]
	if not _saved_paths.has(path):
		_saved_paths.append(path)
	return path


## Every script under [param folder] and the folders in it, its text by its path, into
## [param into].
func scripts_in(folder: String, into: Dictionary[String, String]) -> void:
	for child: String in DirAccess.get_directories_at(folder):
		scripts_in(folder.path_join(child), into)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			into[folder.path_join(file)] = FileAccess.get_file_as_string(folder.path_join(file))


func _delete_saved_files() -> void:
	for path: String in _saved_paths:
		for suffix: String in ["", SaveStore.BACKUP_SUFFIX, SaveStore.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
