extends ColonyTest
## Spec 072: one content table, and less work per tick.

const DATA: String = "res://data"

# --- Helpers -------------------------------------------------------------------


## Every definition saved under data/[param folder], loaded from its file.
func _on_disk(folder: String) -> Array[Resource]:
	var found: Array[Resource] = []
	var dir: String = DATA.path_join(folder)
	for file: String in ResourceLoader.list_directory(dir):
		if file.get_extension() == "tres":
			found.append(load(dir.path_join(file)))
	return found


## The ids of the files under data/[param folder], each ranked by [param rank_of] (an id to an
## int), then by id.
func _ids_on_disk(folder: String, rank_of: Callable) -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: Resource in _on_disk(folder):
		ids.append(def.get(&"id") as StringName)
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var first: int = rank_of.call(a)
			var second: int = rank_of.call(b)
			if first != second:
				return first < second
			return String(a) < String(b)
	)
	return ids


func _by_id(_id: StringName) -> int:
	return 0


func _by_order(folder: String) -> Callable:
	return func(id: StringName) -> int:
		for def: Resource in _on_disk(folder):
			if def.get(&"id") == id:
				return def.get(&"order")
		return 0


## The order of the first area that gives resource [param id]; a large number when none does.
func _by_area(id: StringName) -> int:
	var best: int = 1 << 30
	for def: Resource in _on_disk("areas"):
		var area: AreaDef = def
		if area.resource == id:
			best = mini(best, area.order)
	return best


## Every id list Content keeps, by its folder.
func _lists() -> Dictionary[String, Array]:
	return {
		"heroes": Content.hero_class_ids(),
		"monsters": Content.monster_ids(),
		"upgrades": Content.upgrade_ids(),
		"training": Content.training_ids(),
		"microskills": Content.microskill_ids(),
		"sidequests": Content.side_quest_ids(),
		"areas": Content.area_ids(),
		"abilities": Content.ability_ids(),
		"resources": Content.resource_ids(),
	}


## The definition Content gives for [param id] of the kind kept under data/[param folder].
func _getter(folder: String, id: StringName) -> Resource:
	var found: Resource = null
	match folder:
		"heroes":
			found = Content.hero_class(id)
		"monsters":
			found = Content.monster(id)
		"upgrades":
			found = Content.upgrade(id)
		"training":
			found = Content.training(id)
		"microskills":
			found = Content.microskill(id)
		"sidequests":
			found = Content.side_quest(id)
		"areas":
			found = Content.area(id)
		"abilities":
			found = Content.ability(id)
		"resources":
			found = Content.resource_def(id)
		"talents":
			found = Content.talent_tree(id)
	return found


## The problems of [param data], a fresh save with [param change] made to it.
func _problems_after(change: Callable) -> PackedStringArray:
	var data: Dictionary = Simulation.new(7).to_save()
	change.call(data)
	return Simulation.save_problems(data)


func _hero(data: Dictionary) -> Dictionary:
	return (data["heroes"] as Array)[0]


# --- Requirements --------------------------------------------------------------


func test_r2_every_kind_of_content_is_one_row() -> void:
	var named: Dictionary[String, int] = {}
	for row: Dictionary in Content.KINDS:
		var folder: String = row["folder"]
		named[folder] = named.get(folder, 0) + 1
	var folders: PackedStringArray = DirAccess.get_directories_at(DATA)
	assert_gt(folders.size(), 0, "data has folders")
	for folder: String in folders:
		var rows: int = named.get(folder, 0)
		assert_eq(rows, 1, "data/%s is named by exactly one row" % folder)
	assert_eq(named.size(), folders.size(), "no row names a folder that is not there")

	var expected: Dictionary[String, Array] = {
		"heroes": _ids_on_disk("heroes", _by_id),
		"monsters": _ids_on_disk("monsters", _by_id),
		"upgrades": _ids_on_disk("upgrades", _by_order("upgrades")),
		"training": _ids_on_disk("training", _by_order("training")),
		"microskills": _ids_on_disk("microskills", _by_id),
		"sidequests": _ids_on_disk("sidequests", _by_id),
		"areas": _ids_on_disk("areas", _by_order("areas")),
		"abilities": _ids_on_disk("abilities", _by_id),
		"resources": _ids_on_disk("resources", _by_area),
	}
	var lists: Dictionary[String, Array] = _lists()
	for folder: String in expected:
		assert_eq(lists[folder], expected[folder], "the %s ids, in their order" % folder)
		for def: Resource in _on_disk(folder):
			var id: StringName = def.get(&"id")
			assert_true(is_same(_getter(folder, id), def), "%s %s is its file" % [folder, id])
		assert_null(_getter(folder, &"no_such_thing"), "an unknown %s id gives null" % folder)
	# Talent trees go by their class, one tree a class.
	var trees: Array[Resource] = _on_disk("talents")
	assert_eq(trees.size(), Content.hero_class_ids().size(), "a tree a class")
	for tree: Resource in trees:
		var class_id: StringName = (tree as TalentTreeDef).class_id
		assert_true(is_same(Content.talent_tree(class_id), tree), "the %s tree" % class_id)
	assert_null(Content.talent_tree(&"no_such_class"), "a class with no tree")
	assert_eq(Content.area_of_resource(&"clay"), &"claypits", "clay comes from the Claypits")


func test_r3_an_id_list_is_the_same_list_each_time() -> void:
	var first: Dictionary[String, Array] = _lists()
	var second: Dictionary[String, Array] = _lists()
	for folder: String in first:
		assert_true(is_same(first[folder], second[folder]), "the %s ids are one list" % folder)
		assert_true(first[folder].is_read_only(), "the %s ids are read-only" % folder)
		assert_false(first[folder].is_empty(), "there are %s" % folder)


func test_r4_a_shaft_is_found_once_per_level() -> void:
	var levels: int = 200
	var asked: Labyrinth = Labyrinth.new(42)
	var forward: Array[int] = []
	for depth: int in range(1, levels + 1):
		forward.append(asked.shaft_column(depth))
	# Asked again, and in the other order, of a labyrinth that has made levels in between.
	var fresh: Labyrinth = Labyrinth.new(42)
	for depth: int in range(levels, 0, -1):
		if depth % 7 == 0:
			fresh.level(depth)
		assert_eq(fresh.shaft_column(depth), forward[depth - 1], "depth %d's shaft" % depth)
		assert_eq(asked.shaft_column(depth), forward[depth - 1], "depth %d asked again" % depth)
	# Each level's column is worked out once and kept.
	assert_eq(asked._shaft_columns.size(), levels, "one column kept per level asked")
	# Another area's labyrinth has columns of its own.
	var other: Labyrinth = Labyrinth.new(42, "area/claypits/")
	var differs: bool = false
	for depth: int in range(1, levels + 1):
		differs = differs or other.shaft_column(depth) != forward[depth - 1]
	assert_true(differs, "another area's shafts are its own")


func test_r5_a_multiplier_follows_a_new_rank() -> void:
	var sim := Simulation.new(5)
	sim.party.gold = 1_000_000
	for id: StringName in Content.resource_ids():
		sim.party.set_resource(id, 1_000_000)
	var stats: Array = UpgradeDef.Stat.values()
	for round_number: int in 6:
		for id: StringName in Content.upgrade_ids():
			# Asked before the purchase, so a kept value must follow the new rank.
			for stat: int in stats:
				sim.upgrades.multiplier(stat as UpgradeDef.Stat)
			sim.buy_upgrade(id)
			sim.step()
			for stat: int in stats:
				var bonus: float = 0.0
				for other: StringName in Content.upgrade_ids():
					var def: UpgradeDef = Content.upgrade(other)
					if def.stat == stat:
						bonus += sim.upgrades.rank(other) * def.per_rank
				assert_eq(
					sim.upgrades.multiplier(stat as UpgradeDef.Stat),
					1.0 + bonus,
					"stat %d after %s rank %d" % [stat, id, sim.upgrades.rank(id)]
				)
	assert_true(sim.upgrades.any(), "ranks were bought")

	raise_party(sim, 20)
	var hero: Hero = sim.party.heroes[0]
	for stat: TrainingDef.Stat in TrainingDef.Stat.values():
		hero.paragon_multiplier(stat)
		var before: float = hero.max_health()
		sim.spend_paragon(hero.id, stat)
		sim.step()
		var def_of_stat: TrainingDef = TalentRules.stat_def(stat)
		var rank: int = hero.paragon_rank(stat)
		assert_gt(rank, 0, "a point went into stat %d" % stat)
		assert_eq(
			hero.paragon_multiplier(stat),
			1.0 + rank * def_of_stat.per_rank,
			"stat %d after a paragon point" % stat
		)
		if stat == TrainingDef.Stat.TOUGHNESS:
			assert_gt(hero.max_health(), before, "toughness raises health at once")
	# A loaded save brings its points with it.
	var loaded: Simulation = Simulation.from_save(sim.to_save())
	var again: Hero = loaded.party.heroes[0]
	for stat: TrainingDef.Stat in TrainingDef.Stat.values():
		assert_eq(again.paragon_multiplier(stat), hero.paragon_multiplier(stat), "stat %d" % stat)
	assert_eq(again.max_health(), hero.max_health(), "the loaded hero is as healthy")


func test_r7_save_problems_read_as_before() -> void:
	var cases: Array = [
		[
			func(d: Dictionary) -> void: d["version"] = "8",
			["version: missing or not a whole number"]
		],
		[func(d: Dictionary) -> void: d["seed"] = 2.5, ["seed: missing or not a whole number"]],
		[func(d: Dictionary) -> void: d["tick"] = 1.5, ["tick: missing or not a whole number"]],
		[func(d: Dictionary) -> void: d["gold"] = -1, ["gold: below 0"]],
		[
			func(d: Dictionary) -> void: d.erase("target_depth"),
			["target_depth: missing or not a whole number"]
		],
		[
			func(d: Dictionary) -> void:
				d.merge({"last_stable_depth": 3, "deepest_depth": 2}, true),
			["last_stable_depth: deeper than deepest_depth"]
		],
		[func(d: Dictionary) -> void: _hero(d)["level"] = 0, ["heroes[0].level: below 1"]],
		[
			func(d: Dictionary) -> void: _hero(d)["xp"] = "a",
			["heroes[0].xp: missing or not a whole number"]
		],
		[
			func(d: Dictionary) -> void: d["upgrades"] = {"stout_armor": 1.5},
			["upgrades.stout_armor: rank missing or not a whole number"]
		],
		[
			func(d: Dictionary) -> void: d["upgrades"] = {"stout_armor": -2},
			["upgrades.stout_armor: rank -2 is below 0"]
		],
		[
			func(d: Dictionary) -> void: d["upgrades"] = {"nope": 1},
			["upgrades.nope: unknown upgrade 'nope'"]
		],
		[
			func(d: Dictionary) -> void: d["areas"] = {"claypits": {"safe": 0, "furthest": 2.5}},
			[
				"areas.claypits.safe: below 1",
				"areas.claypits.furthest: missing or not a whole number"
			]
		],
		[
			func(d: Dictionary) -> void: d["areas"] = {"claypits": {"safe": 3, "furthest": 2}},
			["areas.claypits.safe: beyond furthest"]
		],
		[
			func(d: Dictionary) -> void: d["areas"] = {"nowhere": {"safe": 1, "furthest": 1}},
			["areas.nowhere: unknown area"]
		],
		[func(d: Dictionary) -> void: d["resources"] = {"clay": -1}, ["resources.clay: below 0"]],
		[
			func(d: Dictionary) -> void: d["resources"] = {"clay": 1.5},
			["resources.clay: missing or not a whole number"]
		],
		[
			func(d: Dictionary) -> void: d["resources"] = {"gold_dust": 1},
			["resources.gold_dust: unknown resource"]
		],
		[func(d: Dictionary) -> void: d["resources"] = {7: 1}, ["resources.7: unknown resource"]],
		[
			func(d: Dictionary) -> void: d["resources"] = 5,
			["resources: missing or not a dictionary of counts"]
		],
		[
			func(d: Dictionary) -> void: d["guardians_beaten"] = ["nowhere"],
			["guardians_beaten[0]: unknown area 'nowhere'"]
		],
		[
			func(d: Dictionary) -> void: _hero(d)["paragon"] = {"power": 1.5},
			["heroes[0].paragon.power: points missing or not a whole number"]
		],
		[
			func(d: Dictionary) -> void: _hero(d)["paragon"] = {"power": -1},
			["heroes[0].paragon.power: points -1 are below 0"]
		],
		[
			func(d: Dictionary) -> void: _hero(d)["paragon"] = {"speed": 1},
			["heroes[0].paragon.speed: unknown stat 'speed'"]
		],
		[
			func(d: Dictionary) -> void: _hero(d)["paragon"] = {"power": 2},
			["heroes[0].paragon: 2 points spent, but level 1 earns 0 paragon points"]
		],
	]
	assert_eq(
		_problems_after(func(_d: Dictionary) -> void: pass), PackedStringArray(), "a fresh save"
	)
	for i: int in cases.size():
		var change: Callable = cases[i][0]
		var expected: Array = cases[i][1]
		assert_eq(_problems_after(change), PackedStringArray(expected), "case %d" % i)
	# The checks themselves, from their own class.
	assert_true(SaveChecks.is_whole(3.0), "3.0 is whole")
	assert_false(SaveChecks.is_whole(3.5), "3.5 is not")
	assert_false(SaveChecks.is_whole("3"), "text is not")
	assert_eq(SaveChecks.whole(4.0), 4, "4.0 reads as 4")
	assert_eq(SaveChecks.whole("x", 9), 9, "the fallback for what is not whole")
	var problems := PackedStringArray()
	SaveChecks.check_counts(
		problems, {"clay": 2, "glowcaps": -1}, "resources", Content.resource_ids(), 0
	)
	assert_eq(problems, PackedStringArray(["resources.glowcaps: below 0"]), "a count below 0")
