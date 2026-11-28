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
## How long a headless run may take to beat the Slime King.
const KING_LIMIT_MINUTES: float = 60.0
## The fight each path must win and the bare party loses: Old Crypt's guardian at its own
## level, against a party of [constant PATH_PARTY_LEVEL], on [constant PATH_SEEDS] battle seeds.
const PATH_FIGHT: StringName = &"bone_lord"
const PATH_FIGHT_LEVEL: int = 15
const PATH_PARTY_LEVEL: int = 14
const PATH_SEEDS: int = 5

## The class [method add_recruit_class] adds, a copy of the Knight that can be recruited.
const RECRUIT_CLASS: StringName = &"test_recruit"

## The paths [method save_path] has handed out; each is deleted with its backup and temporary file.
var _saved_paths: Array[String] = []
## True while [constant RECRUIT_CLASS] is among the classes the data has.
var _recruit_added: bool = false


func after_each() -> void:
	_delete_saved_files()
	_remove_recruit_class()


## Also after the last test: a Main with a save store saves again when GUT frees it, which is
## after after_each has run.
func after_all() -> void:
	_delete_saved_files()
	_remove_recruit_class()


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


## Spends [param hero]'s talent points on its tree's first path, then its second, then its third, in
## order, giving each path the XP its deepest node held needs.
static func _spend_talents(hero: Hero) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var order: Array[StringName] = tree.path(0).nodes.duplicate()
	order.append_array(tree.path(1).nodes)
	order.append_array(tree.path(2).nodes)
	var taken: Array[StringName] = order.slice(0, TalentRules.talent_points_at(hero.level))
	hero.set_talents(taken)
	for node: StringName in taken:
		give_rank(hero, node)


## Gives [param hero]'s path of [param node] the XP the node's tier needs, if it has less.
static func give_rank(hero: Hero, node: StringName) -> void:
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
	var needed: int = tree.rank_needed(node)
	var path: int = tree.path_of(node)
	if needed > 0 and hero.ranks.rank(path, tree) < needed:
		hero.ranks.set_xp(path, tree.rank_xp[needed - 1])


# --- Talents worth having (specs 051 and 109) ---------------------------------


## The game time of the first win over the Slime King from seed [param seed_value], or -1, and
## the wipes before it; spending as `dev.py sim --spend-talents` does if [param spending].
func _until_king(seed_value: int, spending: bool) -> Array[float]:
	var sim := Simulation.new(seed_value)
	var wipes: int = 0
	for i: int in roundi(KING_LIMIT_MINUTES * 60.0 * Simulation.TICKS_PER_SECOND):
		if spending:
			TalentSpender.spend(sim)
		var fight: Battle = sim.expedition.battle
		sim.step()
		for e: SimEvent in sim.drain_events():
			if e.kind == SimEvent.Kind.PARTY_WIPED:
				wipes += 1
			elif e.kind == SimEvent.Kind.GUARDIAN_SLAIN and fight != null:
				if fight.combatant(e.source_id).def_id == &"slime_king":
					return [sim.seconds(), float(wipes)] as Array[float]
	return [-1.0, float(wipes)] as Array[float]


## Checks that spending reaches the first Slime King win sooner, with fewer wipes, on seeds 1 to 5.
func _check_king_sooner() -> void:
	var report: PackedStringArray = []
	for seed_value: int in range(1, 6):
		var plain: Array[float] = _until_king(seed_value, false)
		var spent: Array[float] = _until_king(seed_value, true)
		var line: String = (
			"seed %d: without %.0f s, %d wipes; with %.0f s, %d wipes"
			% [seed_value, plain[0], plain[1], spent[0], spent[1]]
		)
		report.append(line)
		assert_gt(spent[0], 0.0, "with talents the King falls, " + line)
		assert_true(plain[0] < 0.0 or spent[0] < plain[0], "sooner, " + line)
		assert_lt(spent[1], plain[1], "with fewer wipes, " + line)
	gut.p("\n".join(report))


## Wins out of [constant PATH_SEEDS] against [constant PATH_FIGHT], with [param class_id]'s hero
## holding the five nodes of path [param path] and nothing else (no one, if [param class_id] is
## empty).
func _path_wins(class_id: StringName, path: int) -> int:
	var wins: int = 0
	for seed_value: int in PATH_SEEDS:
		var party := Party.new()
		var heroes: Array[Combatant] = []
		for hero: Hero in party.heroes:
			raise(hero, PATH_PARTY_LEVEL)
			if hero.class_id == class_id:
				hero.set_talents(Content.talent_tree(class_id).path(path).nodes)
			heroes.append(hero.combatant())
		var def: MonsterDef = Content.monster(PATH_FIGHT)
		var monsters: Array[Combatant] = [Combatant.from_monster(def, PATH_FIGHT_LEVEL, 100)]
		var battle := Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(seed_value * 7 + 1))
		while battle.result() == Battle.Result.ONGOING and battle.tick < LIMIT_TICKS_90_S:
			battle.step()
		if battle.result() == Battle.Result.HEROES_WON:
			wins += 1
	return wins


## Checks that each path of [param class_id] wins most of a fight its bare party never wins.
func _check_paths_win(class_id: StringName) -> void:
	assert_eq(_path_wins(&"", -1), 0, "the bare party never beats the %s in 90 s" % PATH_FIGHT)
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	for path: int in tree.paths.size():
		var name_text: String = tree.path(path).display_name
		var wins: int = _path_wins(class_id, path)
		gut.p("%s %s: %d of %d" % [class_id, name_text, wins, PATH_SEEDS])
		assert_gte(wins, 3, "%s wins it %d times of %d" % [name_text, wins, PATH_SEEDS])


# --- The roster ----------------------------------------------------------------


## Puts a class that can be recruited among the classes the data has, until the test ends: a copy
## of the Knight under the id [constant RECRUIT_CLASS], its artifact the Test Whistle at chance
## 0.12, priced 300 gold and 40 glowcaps, looking like the Knight, with a copy of the Knight's
## talent tree. Returns its id.
func add_recruit_class() -> StringName:
	if _recruit_added:
		return RECRUIT_CLASS
	var def: HeroClassDef = Content.hero_class(&"knight").duplicate() as HeroClassDef
	def.id = RECRUIT_CLASS
	def.display_name = "Test Recruit"
	def.artifact_name = "Test Whistle"
	def.artifact_chance = 0.12
	def.recruit_gold = 300
	def.recruit_resource = &"glowcaps"
	def.recruit_resource_count = 40
	def.looks_like = &"knight"
	var tree: TalentTreeDef = Content.talent_tree(&"knight").duplicate() as TalentTreeDef
	tree.class_id = RECRUIT_CLASS
	_put_content(Content.Kind.HEROES, RECRUIT_CLASS, def)
	_put_content(Content.Kind.TALENTS, RECRUIT_CLASS, tree)
	_recruit_added = true
	return RECRUIT_CLASS


## Takes [constant RECRUIT_CLASS] and its tree out of the data again, if a test put them in.
func _remove_recruit_class() -> void:
	if not _recruit_added:
		return
	_recruit_added = false
	_put_content(Content.Kind.HEROES, RECRUIT_CLASS, null)
	_put_content(Content.Kind.TALENTS, RECRUIT_CLASS, null)


## Adds [param def] to [param kind] under [param key], or with null takes the key out; the kind's
## ids stay sorted and read-only, as [Content] keeps them.
static func _put_content(kind: Content.Kind, key: StringName, def: Resource) -> void:
	var ids: Array[StringName] = []
	ids.assign(Content._ids_of(kind))
	ids.erase(key)
	if def == null:
		Content._defs[kind].erase(key)
	else:
		Content._defs[kind][key] = def
		ids.append(key)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	ids.make_read_only()
	Content._ids[kind] = ids


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
