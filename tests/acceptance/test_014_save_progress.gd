extends GutTest
## Acceptance tests for specs/014-save-progress/spec.md, one per requirement.
##
## The progress tests play the real simulation with the shipped data. To reach
## past depth 1 in 20 minutes they shorten the time a depth needs to become
## stable (a tunable field, not saved). File tests use per-process names under
## user:// and delete everything they make.

const SEED: int = 1234
const TWENTY_MINUTES: int = 12_000
const HOUR_TICKS: int = 36_000
const SAVE_FIELDS: Array[String] = [
	"version",
	"seed",
	"tick",
	"gold",
	"heroes",
	"last_stable_depth",
	"deepest_depth",
	"target_depth",
	"auto_push",
]

var _paths: Array[String] = []

# --- Helpers -------------------------------------------------------------------


func after_each() -> void:
	for path: String in _paths:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	_paths.clear()


## A simulation after 20 minutes of play, quick to call a depth stable so it gets somewhere.
func _played() -> Simulation:
	var sim := Simulation.new(SEED)
	sim.expedition.stable_seconds = 60.0
	for i: int in TWENTY_MINUTES:
		sim.step()
	sim.drain_events()
	return sim


func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary, "the save parses back to a dictionary")
	if parsed is Dictionary:
		return parsed
	return {}


## Valid save data, written by hand: two heroes, last stable depth 3.
func _valid() -> Dictionary:
	return {
		"version": 1,
		"seed": 99,
		"tick": 5000,
		"gold": 321,
		"heroes":
		[
			{"class": "knight", "level": 4, "xp": 300},
			{"class": "mage", "level": 2, "xp": 60},
		],
		"last_stable_depth": 3,
		"deepest_depth": 4,
		"target_depth": 4,
		"auto_push": false,
	}


## True if [param value] holds only numbers, strings, booleans, arrays and dictionaries.
func _is_plain(value: Variant) -> bool:
	var plain: bool = typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]
	if value is Array:
		var items: Array = value
		plain = not items.is_typed()
		for item: Variant in items:
			plain = plain and _is_plain(item)
	elif value is Dictionary:
		var map: Dictionary = value
		plain = not map.is_typed()
		for key: Variant in map:
			plain = plain and typeof(key) == TYPE_STRING and _is_plain(map[key])
	return plain


## [param value] with every int made a float, so an int and the same whole float compare equal.
func _numbers_as_floats(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		var whole: int = value
		return float(whole)
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_numbers_as_floats(item))
		return items
	if value is Dictionary:
		var map: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			map[key] = _numbers_as_floats(source[key])
		return map
	return value


## True if [param a] and [param b] hold the same values, an int equal to a whole float.
func _same(a: Variant, b: Variant) -> bool:
	return _numbers_as_floats(a) == _numbers_as_floats(b)


func _any_names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.contains(field):
			return true
	return false


func _store_path(label: String) -> String:
	var path: String = "user://test_014_%s_%d.save" % [label, OS.get_process_id()]
	_paths.append(path)
	return path


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The dictionary a file holds as JSON, or an empty one.
func _file_data(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data


## The progress values a save promises to keep, read from a live simulation.
func _progress(sim: Simulation) -> Array:
	var heroes: Array = []
	for hero: Hero in sim.party.heroes:
		heroes.append([String(hero.class_id), hero.level, hero.xp])
	var trip: Expedition = sim.expedition
	return [
		sim.tick,
		sim.party.gold,
		heroes,
		trip.last_stable_depth,
		trip.deepest_depth,
		trip.target_depth,
		trip.auto_push,
	]


# --- Requirements --------------------------------------------------------------


func test_r1_progress_is_plain_data() -> void:
	var sim: Simulation = _played()
	var data: Dictionary = sim.to_save()
	for field: String in SAVE_FIELDS:
		assert_true(data.has(field), "the save holds %s" % field)
	assert_true(_is_plain(data), "only plain values: %s" % data)
	var heroes: Array = []
	for hero: Hero in sim.party.heroes:
		heroes.append({"class": String(hero.class_id), "level": hero.level, "xp": hero.xp})
	var expected: Dictionary = {
		"version": Simulation.SAVE_VERSION,
		"seed": SEED,
		"tick": sim.tick,
		"gold": sim.party.gold,
		"heroes": heroes,
		"last_stable_depth": sim.expedition.last_stable_depth,
		"deepest_depth": sim.expedition.deepest_depth,
		"target_depth": sim.expedition.target_depth,
		"auto_push": sim.expedition.auto_push,
	}
	assert_true(_same(data, expected), "the save holds\n%s\nnot\n%s" % [expected, data])
	assert_gt(sim.party.gold, 0, "20 minutes of play earns gold")
	assert_gt(sim.expedition.last_stable_depth, 1, "the play got past depth 1")
	# JSON makes every number a float; compared as values, nothing changes.
	var parsed: Dictionary = _through_json(data)
	assert_true(_same(parsed, data), "unchanged through JSON: %s" % parsed)


func test_r2_progress_comes_back() -> void:
	var played: Simulation = _played()
	var loaded: Simulation = Simulation.from_save(_through_json(played.to_save()))
	assert_not_null(loaded, "the save loads")
	if loaded == null:
		return
	assert_eq(loaded.to_save(), played.to_save(), "seed, tick and every progress value")
	assert_eq(_progress(loaded), _progress(played))
	for hero: Hero in loaded.party.heroes:
		assert_eq(hero.health, hero.max_health(), "hero %d alive and full" % hero.id)
	var trip: Expedition = loaded.expedition
	var stable: int = played.expedition.last_stable_depth
	assert_eq(trip.depth, stable, "at the last stable depth")
	assert_eq(trip.state, Expedition.State.TRAVELLING)
	assert_null(trip.battle, "no fight in progress")
	assert_eq(loaded.drain_events().size(), 0, "no events pending")
	# The arrival chamber, where revival stands the party: the landing of the shaft from above.
	var level: LabyrinthLevel = loaded.labyrinth.level(stable)
	var landing: LabyrinthChamber = level.chamber_at(loaded.labyrinth.shaft_column(stable - 1))
	assert_not_null(trip.chamber())
	if trip.chamber() != null:
		assert_eq(trip.chamber().index, landing.index, "in the arrival chamber")
	for hero: Hero in loaded.party.heroes:
		var feet: Vector2 = trip.hero_position(hero.id)
		assert_eq(feet.y, float(level.floor_y), "hero %d on the floor" % hero.id)
	# Every chamber starts out freshly populated.
	for room: LabyrinthChamber in level.chambers:
		if room.index == landing.index or room.index == level.shaft_chamber().index:
			continue
		assert_true(trip.is_populated(stable, room.index), "chamber %d populated" % room.index)
		var fresh: Array[Combatant] = trip.monsters_in(stable, room.index)
		for monster: Combatant in fresh:
			assert_eq(monster.health, monster.max_health)
	# Depth 1 arrives in the START chamber.
	var at_one: Dictionary = _valid()
	at_one["last_stable_depth"] = 1
	var first: Simulation = Simulation.from_save(at_one)
	assert_not_null(first)
	if first != null and first.expedition.chamber() != null:
		assert_eq(first.expedition.chamber().kind, LabyrinthChamber.Kind.START)


func test_r3_carries_on() -> void:
	var data: Dictionary = _through_json(_played().to_save())
	var a: Simulation = Simulation.from_save(data)
	var b: Simulation = Simulation.from_save(data)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	var gold: int = a.party.gold
	var levels: Array[int] = []
	var xps: Array[int] = []
	for hero: Hero in a.party.heroes:
		levels.append(hero.level)
		xps.append(hero.xp)
	var lowest_gold: int = gold
	var dropped: Array[String] = []
	for i: int in HOUR_TICKS:
		a.step()
		b.step()
		a.drain_events()
		b.drain_events()
		lowest_gold = mini(lowest_gold, a.party.gold)
		if i % 100 != 0:
			continue
		for h: int in a.party.heroes.size():
			var hero: Hero = a.party.heroes[h]
			if hero.level < levels[h] or hero.xp < xps[h]:
				dropped.append("hero %d at tick %d" % [hero.id, a.tick])
	assert_gte(lowest_gold, gold, "gold never below the loaded amount")
	assert_eq(dropped, [] as Array[String], "levels and XP never below the loaded values")
	assert_gt(a.party.gold, gold, "an hour of play earns more")
	assert_eq(a.state_hash(), b.state_hash(), "two loads stepped alike agree")
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r4_bad_data_is_refused() -> void:
	assert_eq(Simulation.save_problems(_valid()), PackedStringArray(), "valid data has no problems")
	assert_not_null(Simulation.from_save(_valid()))

	# [field to name in the problem, the broken data]
	var cases: Array = []
	for field: String in SAVE_FIELDS:
		var missing: Dictionary = _valid()
		missing.erase(field)
		cases.append([field, missing])
		var wrong: Dictionary = _valid()
		wrong[field] = "x"
		cases.append([field, wrong])
		var listed: Dictionary = _valid()
		listed[field] = [1]
		cases.append([field, listed])
	var cases_by_value: Array = [
		["version", "version", 7],
		["class", "heroes", [{"class": "bard", "level": 1, "xp": 0}]],
		["level", "heroes", [{"class": "knight", "level": 0, "xp": 0}]],
		["xp", "heroes", [{"class": "knight", "level": 1, "xp": -5}]],
		["level", "heroes", [{"class": "knight", "level": 1.5, "xp": 0}]],
		["class", "heroes", [{"level": 1, "xp": 0}]],
		["heroes", "heroes", ["knight"]],
		["gold", "gold", -1],
		["last_stable_depth", "last_stable_depth", 0],
		["deepest_depth", "deepest_depth", 0],
		["target_depth", "target_depth", -2],
		["last_stable_depth", "last_stable_depth", 5],
		["auto_push", "auto_push", 1],
	]
	for entry: Array in cases_by_value:
		var broken: Dictionary = _valid()
		broken[entry[1]] = entry[2]
		cases.append([entry[0], broken])
	var all_wrong: Dictionary = {}
	for field: String in SAVE_FIELDS:
		all_wrong[field] = Vector2(1, 2)
	cases.append(["version", all_wrong])
	cases.append(["version", {}])
	var weird: Dictionary = _valid()
	weird[3] = null
	weird["heroes"] = [null, 4, {"class": 5, "level": [], "xp": {}}]
	cases.append(["heroes", weird])

	for entry: Array in cases:
		var field: String = entry[0]
		var data: Dictionary = entry[1]
		var problems: PackedStringArray = Simulation.save_problems(data)
		assert_false(problems.is_empty(), "%s refused: %s" % [field, data])
		assert_true(_any_names(problems, field), "a problem names %s: %s" % [field, problems])
		assert_null(Simulation.from_save(data), "no simulation from %s" % [data])
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r5_upgrade_is_a_pass_through() -> void:
	assert_eq(Simulation.SAVE_VERSION, 1)
	var data: Dictionary = _valid()
	assert_eq(Simulation.upgrade_save(data), _valid(), "version 1 is unchanged by the upgrade")
	assert_eq(data, _valid(), "and the input is not touched")
	var parsed: Dictionary = _through_json(_valid())
	assert_eq(Simulation.upgrade_save(parsed), parsed, "the same after JSON")
	for version: int in [0, 2]:
		var other: Dictionary = _valid()
		other["version"] = version
		assert_null(Simulation.from_save(other), "version %d refused" % version)
		assert_true(_any_names(Simulation.save_problems(other), "version"))
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r6_write_is_atomic_with_a_backup() -> void:
	var path: String = _store_path("r6")
	var store := SaveStore.new(path)
	var first: Dictionary = _valid()
	assert_true(store.write(first), "first write succeeds")
	assert_eq(_file_data(path), _through_json(first), "the file holds the data")
	var leftovers: Array[String] = []
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(path.get_file()) and file_name != path.get_file():
			leftovers.append(file_name)
	assert_eq(leftovers, [] as Array[String], "no temporary file or backup after one write")

	var second: Dictionary = _valid()
	second["gold"] = 999
	assert_true(store.write(second), "second write succeeds")
	assert_eq(_file_data(path), _through_json(second))
	assert_eq(_file_data(store.backup_path()), _through_json(first))
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(path.get_file()):
			files.append(file_name)
	files.sort()
	var expected: Array[String] = [path.get_file(), store.backup_path().get_file()]
	expected.sort()
	assert_eq(files, expected, "only the save and its backup remain")
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r7_read_falls_back() -> void:
	var store := SaveStore.new(_store_path("r7"))
	assert_eq(store.read(), {}, "missing: empty")

	var first: Dictionary = _valid()
	var second: Dictionary = _valid()
	second["gold"] = 7
	store.write(first)
	store.write(second)
	assert_eq(store.read(), _through_json(second), "a good save is read")

	for damaged: String in ['{"version": 1, "gold', "not json at all", "[1, 2, 3]", "42", ""]:
		_write_text(_paths[0], damaged)
		assert_eq(store.read(), _through_json(first), "damaged %s: the backup" % damaged)
		DirAccess.remove_absolute(_paths[0])
		assert_eq(store.read(), _through_json(first), "save missing: the backup")
		_write_text(_paths[0], damaged)
		_write_text(store.backup_path(), "]]")
		assert_eq(store.read(), {}, "both damaged: empty")
		DirAccess.remove_absolute(store.backup_path())
		assert_eq(store.read(), {}, "damaged and no backup: empty")
		_write_text(store.backup_path(), JSON.stringify(first))
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r8_store_uses_its_path() -> void:
	var one := SaveStore.new(_store_path("r8a"))
	var two := SaveStore.new(_store_path("r8b"))
	var data_one: Dictionary = _valid()
	var data_two: Dictionary = _valid()
	data_two["gold"] = 5
	assert_true(one.write(data_one))
	assert_eq(two.read(), {}, "the second store sees nothing of the first")
	assert_true(two.write(data_two))
	assert_eq(one.read(), _through_json(data_one))
	assert_eq(two.read(), _through_json(data_two))
	assert_true(FileAccess.file_exists(_paths[0]))
	assert_true(FileAccess.file_exists(_paths[1]))
	assert_eq(SaveStore.DEFAULT_PATH, "user://colony.save")
	assert_ne(one.backup_path(), two.backup_path())
