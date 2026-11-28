extends ColonyTest
## Unit tests for loading saved progress (Simulation.from_save, save_problems).


func _valid() -> Dictionary:
	return {
		"version": 1,
		"seed": 5,
		"tick": 1200,
		"gold": 40,
		"heroes":
		[
			{"class": "cleric", "level": 3, "xp": 150},
			{"class": "knight", "level": 1, "xp": 10},
			{"class": "rogue", "level": 2, "xp": 50},
		],
		"last_stable_depth": 2,
		"deepest_depth": 3,
		"target_depth": 3,
		"auto_push": true,
	}


func test_whole_floats_load_as_ints() -> void:
	var data: Dictionary = _valid()
	for field: String in ["version", "seed", "tick", "gold", "last_stable_depth"]:
		var number: int = data[field]
		data[field] = float(number)
	var sim: Simulation = Simulation.from_save(data)
	assert_not_null(sim)
	if sim == null:
		return
	assert_eq(sim.tick, 1200)
	assert_eq(sim.party.gold, 40)
	assert_eq(sim.expedition.last_stable_depth, 2)
	var seed_value: int = sim.to_save()["seed"]
	assert_eq(seed_value, 5)


func test_fractional_and_unrepresentable_numbers_are_refused() -> void:
	for bad: float in [1.5, INF, -INF, NAN, 1e300]:
		var data: Dictionary = _valid()
		data["gold"] = bad
		var problems: PackedStringArray = Simulation.save_problems(data)
		assert_eq(problems.size(), 1, "gold %s: %s" % [bad, problems])
		assert_true(problems.size() == 1 and problems[0].begins_with("gold"))


func test_heroes_come_back_in_order_with_fresh_ids() -> void:
	var sim: Simulation = Simulation.from_save(_valid())
	assert_not_null(sim)
	if sim == null:
		return
	var seen: Array = []
	for hero: Hero in sim.party.heroes:
		seen.append([hero.id, String(hero.class_id), hero.level, hero.xp])
	assert_eq(seen, [[1, "cleric", 3, 150], [2, "knight", 1, 10], [3, "rogue", 2, 50]])


func test_problems_name_the_hero() -> void:
	var data: Dictionary = _valid()
	var heroes: Array = data["heroes"]
	heroes[2] = {"class": "rogue", "level": 0, "xp": 50}
	assert_eq(Simulation.save_problems(data), PackedStringArray(["heroes[2].level: below 1"]))


func test_saved_target_is_kept_without_a_change_event() -> void:
	var sim: Simulation = Simulation.from_save(_valid())
	assert_not_null(sim)
	if sim == null:
		return
	sim.step()
	assert_eq(sim.expedition.target_depth, 3)
	for event: SimEvent in sim.drain_events():
		assert_ne(event.kind, SimEvent.Kind.TARGET_DEPTH_CHANGED, "the target was not reset")
		assert_ne(event.kind, SimEvent.Kind.DEPTH_CHANGED, "the party did not move depth")


func test_saving_a_loaded_simulation_gives_the_same_data() -> void:
	var sim: Simulation = Simulation.from_save(_valid())
	assert_not_null(sim)
	if sim != null:
		# Spec 016: a version 1 save comes back as version 2, with every upgrade at rank 0.
		var expected: Dictionary = _valid()
		expected["version"] = Simulation.SAVE_VERSION
		expected["upgrades"] = sim.to_save()["upgrades"]
		expected["auto_buy"] = false  # spec 022: version 3 adds the switch, off
		# Spec 051: version 7 drops spec 029's training and gives each hero no talents and no
		# paragon points spent; version 10 gives each no order of use either, and version 11 its
		# three paths at 0 XP.
		var ranks: Dictionary = {}
		for training_id: StringName in Content.training_ids():
			ranks[String(training_id)] = 0
		for saved: Dictionary in expected["heroes"]:
			saved["talents"] = []
			saved["used"] = []
			saved["paths"] = [0, 0, 0]
			saved["paragon"] = ranks
		# Spec 035: version 5 adds the orders at their defaults.
		expected["pace"] = "steady"
		expected["guardian_order"] = "challenge"
		# Spec 049: version 6 puts the party in Mossy Hollow, with only it open at depth 3.
		expected["area"] = "mossy_hollow"
		expected["areas"] = {}
		expected["open_areas"] = ["mossy_hollow"]
		# Spec 052: version 8 adds no resources, and no guardian beaten at depth 3.
		expected["resources"] = {}
		expected["guardians_beaten"] = []
		# Spec 096: version 9 adds the side path order at its default.
		expected["side_paths"] = "explore"
		assert_eq(sim.to_save(), expected)
