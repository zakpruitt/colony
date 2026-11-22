class_name ColonyTest
extends GutTest
## What every Colony test shares: keys and the mouse pushed into the viewport as the
## window would send them, heroes raised to a level, a simulation stepped until something holds,
## the main scene, and files of this process's own under user://, deleted after each test and
## after the last one.
##
## A test script extends this, directly, through a fixture under tests/support/ ([HudFixture]
## for a HUD over a simulation of its own, [MainFixture] for the main scene) or through a
## per-spec base (`*_test_base.gd`) built on one. When a second test needs a helper, it moves here
## or into a fixture rather than being copied: the harness check refuses a helper defined in
## more than two test scripts. A script that overrides after_each or after_all calls super() in
## it, or its files are left behind.
##
## The helpers named with a leading underscore are for the scripts that extend this, which call
## them by those names.

const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")

## The most ticks a test steps while it waits for something, by how long a wait it allows: fifty
## minutes of play, ten, five, three, and a minute and a half.
const LIMIT_TICKS: int = 30_000
const LIMIT_TICKS_10_MIN: int = 6000
const LIMIT_TICKS_5_MIN: int = 3000
const LIMIT_TICKS_3_MIN: int = 1800
const LIMIT_TICKS_90_S: int = 900

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


## Puts [param sim]'s party on stage [param depth], [param back] tiles of course short of its
## guardian's chamber (the one the way on leaves from) and walking in, auto-push off: the next
## steps start the guardian's fight. With
## [param reached] the stage counts as reached (the deepest at least [param depth]); with
## [param held], the stage above it is the last one held. Returns the guardian's chamber.
static func before_guardian(
	sim: Simulation, depth: int, back: float = 0.0, reached: bool = false, held: bool = false
) -> LabyrinthChamber:
	var e: Expedition = sim.expedition
	var level: LabyrinthLevel = sim.labyrinth.level(depth)
	var line: StageCourse = level.course
	var shaft: LabyrinthChamber = level.chambers[ChamberRules.way_on_room(line)]
	var stretch: Vector2 = line.stretch_of(shaft.index)
	sim.set_auto_push(false)
	e.depth = depth
	if reached:
		e.deepest_depth = maxi(e.deepest_depth, depth)
	if held:
		e.last_stable_depth = depth - 1
	e.target_depth = depth + 1
	# A distance along the stage's course: a tile outside the chamber's stretch, on the side the
	# course comes from (a flat stage's first chamber is come to from beyond it).
	if shaft.index > 0:
		e.x = stretch.x - 1.0 - back
		e.facing = 1
	else:
		e.x = stretch.y + 1.0 + back
		e.facing = -1
	return shaft


## Spends [param hero]'s talent points down its tree's trunk and then its first path.
static func _spend_talents(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.trunk.duplicate()
	order.append_array(tree.path_a)
	hero.set_talents(order.slice(0, TalentRules.talent_points_at(hero.level)))


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


## The ticks in [param seconds] of play.
static func ticks_in(seconds: float) -> int:
	return roundi(seconds * Simulation.TICKS_PER_SECOND)


## The events of [param events] of [param kind] (and from [param source], unless it is -2), in
## order.
static func _of_kind(
	events: Array[SimEvent], kind: SimEvent.Kind, source: int = -2
) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.kind == kind and (source == -2 or e.source_id == source):
			found.append(e)
	return found


## [param data] written as JSON and read back, as a save file holds it.
func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary, "the save survives JSON")
	if parsed is Dictionary:
		return parsed
	return {}


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


## A new game whose every stage is winding: rooms on three floors, joined by tunnels and ladders.
static func winding_simulation(seed_value: int = 1) -> Simulation:
	return Simulation.new(seed_value, Labyrinth.Shape.WINDING)


## The winding labyrinth of [param seed_value]: the first area's, as [method winding_simulation]
## has it, or with an [param area_label] another area's.
static func winding_labyrinth(seed_value: int = 1, area_label: String = "") -> Labyrinth:
	return Labyrinth.new(seed_value, area_label, Labyrinth.Shape.WINDING)


## A view of [param labyrinth] in the tree as the world makes it (each stage its own place, in
## the look of [param area]), with [param stage] built.
func zoned_view(labyrinth: Labyrinth, stage: int, area: StringName = &"") -> LabyrinthView:
	var view := LabyrinthView.new()
	view.labyrinth = labyrinth
	view.zoned = true
	view.area = area
	add_child_autofree(view)
	view.set_focus(Vector2(0.0, labyrinth.level(stage).floor_y))
	return view


## Every script under [param folder] and the folders in it, its text by its path, into
## [param into].
func scripts_in(folder: String, into: Dictionary[String, String]) -> void:
	for child: String in DirAccess.get_directories_at(folder):
		scripts_in(folder.path_join(child), into)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			into[folder.path_join(file)] = FileAccess.get_file_as_string(folder.path_join(file))


## Every Label under [param node], at any depth, into [param into], in tree order.
static func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func _delete_saved_files() -> void:
	for path: String in _saved_paths:
		for suffix: String in ["", SaveStore.BACKUP_SUFFIX, SaveStore.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## Steps [param sim] [param ticks] times and returns every event those ticks produced.
static func run_ticks(sim: Simulation, ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## The talent tree of [param class_id].
static func _tree(class_id: StringName) -> TalentTreeDef:
	return Content.talent_tree(class_id)


## Sets [param hero] to [param level] by hand, its xp at that level's start and its health full.
func _set_level(hero: Hero, level: int) -> void:
	hero.level = level
	hero.xp = Hero.xp_for_level(level)
	hero.health = hero.max_health()


## The colour [param label] writes in.
static func _colour(label: Label) -> Color:
	return label.get_theme_color(&"font_color")


## Every hero of [param sim] at 0 health.
static func _wipe(sim: Simulation) -> void:
	for hero: Hero in sim.party.heroes:
		hero.health = 0


## A monster to fight in a test: small, level 1, 100 health, 5 damage a second, slow; each of
## [param overrides] (a field's name to its value) set over that.
static func make_monster_def(overrides: Dictionary = {}) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = &"test_monster"
	def.display_name = "Test monster"
	def.size = MonsterDef.Size.SMALL
	def.base_level = 1
	def.max_health = 100
	def.damage = 5
	def.armor = 0
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 1.0
	def.crit_chance = 0.0
	def.xp = 1
	def.gold_min = 1
	def.gold_max = 2
	for key: String in overrides:
		def.set(key, overrides[key])
	return def
