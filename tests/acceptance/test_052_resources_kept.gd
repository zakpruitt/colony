extends "res://tests/acceptance/resources_052_test_base.gd"
## Acceptance tests for specs/052-resources/spec.md, R9 to R12: what the save keeps, the
## headless comparison and determinism (R1 to R8 are in test_052_resources.gd).

# --- R9 ------------------------------------------------------------------------


func test_r9_saves_carry_it() -> void:
	var sim := Simulation.new(SEED)
	sim.party.set_resource(GLOWCAPS, 12)
	sim.party.set_resource(EMBERS, 3)
	var saved: Dictionary = sim.to_save()
	var held: Dictionary = saved["resources"]
	assert_eq(held, {"glowcaps": 12, "embers": 3}, "each resource's count")
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var loaded: Simulation = Simulation.from_save(through_json)
	assert_not_null(loaded, "it loads through JSON")
	if loaded != null:
		for id: StringName in Content.resource_ids():
			assert_eq(loaded.party.resource(id), sim.party.resource(id), "%s kept" % id)
	# A version 7 save loads with none, its upgrade ranks kept.
	var old: Dictionary = saved.duplicate(true)
	old["version"] = 7
	old.erase("resources")
	old.erase("guardians_beaten")
	old["upgrades"] = {"sharp_blades": 6, "field_medicine": 4}
	assert_eq(Simulation.save_problems(old), PackedStringArray(), "an old save is fine")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "and loads")
	if from_old != null:
		assert_false(from_old.party.has_resources(), "with no resources")
		assert_eq(from_old.upgrades.rank(&"sharp_blades"), 6, "ranks it held stay")
		assert_eq(from_old.upgrades.rank(&"field_medicine"), 4, "every one")
	# Refused by name.
	var bad: Dictionary = saved.duplicate(true)
	bad["resources"] = {"glowcaps": -1, "gold_dust": 4, "clay": 1.5}
	var problems: PackedStringArray = Simulation.save_problems(bad)
	assert_true(problems.has("resources.glowcaps: below 0"), "a negative count")
	assert_true(problems.has("resources.gold_dust: unknown resource"), "an unknown resource")
	assert_true(problems.has("resources.clay: missing or not a whole number"), "not whole")
	assert_null(Simulation.from_save(bad), "and not loaded")
	var lost: Dictionary = saved.duplicate(true)
	lost["guardians_beaten"] = ["mossy_hollow", "atlantis"]
	assert_eq(
		Simulation.save_problems(lost),
		PackedStringArray(["guardians_beaten[1]: unknown area 'atlantis'"]),
		"an unknown area among the beaten guardians, by name"
	)
	assert_null(Simulation.from_save(lost), "and not loaded")
	var none: Dictionary = saved.duplicate(true)
	none.erase("resources")
	assert_true(
		Simulation.save_problems(none).has("resources: missing or not a dictionary of counts"),
		"a version 8 save without resources is refused"
	)


# --- R10 -----------------------------------------------------------------------


func test_r10_worth_the_trip() -> void:
	for seed_value: int in [1, 2, 3]:
		var sim := Simulation.new(seed_value)
		sim.set_auto_buy(true)
		var held_back: bool = false
		for i: int in roundi(MOSSY_MINUTES * 60.0 * Simulation.TICKS_PER_SECOND):
			sim.step()
			sim.drain_events()
			var blades: int = sim.upgrades.rank(&"sharp_blades")
			if blades == 3 and sim.party.gold >= sim.upgrades.cost(&"sharp_blades"):
				held_back = true
		assert_eq(sim.expedition.place, MOSSY, "seed %d: (only ever in Mossy Hollow)" % seed_value)
		for id: StringName in [&"stout_armor", &"sharp_blades", &"fat_purse"]:
			assert_eq(sim.upgrades.rank(id), 3, "seed %d: %s stops at rank 3" % [seed_value, id])
		assert_true(held_back, "seed %d: held back by the resource, not the gold" % seed_value)
		for id: StringName in [CLAY, BONES, EMBERS]:
			assert_eq(
				sim.party.resource(id), 0, "seed %d: no %s in Mossy Hollow" % [seed_value, id]
			)
		var medicine: int = sim.upgrades.rank(&"field_medicine")
		var march: int = sim.upgrades.rank(&"quick_march")
		assert_gt(medicine + march, 6, "seed %d: glowcaps buy past rank 3" % seed_value)
		assert_true(sim.is_area_open(CLAYPITS), "seed %d: the Claypits open" % seed_value)
		if not sim.is_area_open(CLAYPITS):
			continue
		sim.set_destination(CLAYPITS, 1)
		var arrived: int = -1
		var limit: int = roundi((CLAY_MINUTES * 60.0 + 30.0) * Simulation.TICKS_PER_SECOND)
		for i: int in limit:
			sim.step()
			for event: SimEvent in sim.drain_events():
				if event.kind == SimEvent.Kind.AREA_CHANGED and arrived < 0:
					arrived = sim.tick
			if (
				arrived >= 0
				and sim.tick - arrived >= CLAY_MINUTES * 60 * Simulation.TICKS_PER_SECOND
			):
				break
		assert_gt(arrived, 0, "seed %d: the party arrives" % seed_value)
		assert_gt(sim.party.resource(CLAY), 0, "seed %d: clay within five minutes" % seed_value)


# --- R11 -----------------------------------------------------------------------


func test_r11_still_deterministic() -> void:
	var a := Simulation.new(5)
	var b := Simulation.new(5)
	for sim: Simulation in [a, b]:
		set_party_level(sim, STRONG_LEVEL)
		sim.set_auto_buy(true)
	for i: int in 9000:
		a.step()
		b.step()
		a.drain_events()
		b.drain_events()
	assert_true(a.party.has_resources(), "(resources gathered)")
	assert_eq(a.state_hash(), b.state_hash(), "the same seed, the same game")
	for id: StringName in Content.resource_ids():
		assert_eq(a.party.resource(id), b.party.resource(id), "the same %s" % id)
	var c := Simulation.new(5)
	c.party.set_resource(CLAY, 1)
	assert_ne(c.state_hash(), Simulation.new(5).state_hash(), "the hash includes resources")
	# Leave the resources out and the recorded game is unchanged: the hash changes only where it
	# now includes them.
	for seed_value: int in HASHES_BEFORE:
		var sim := Simulation.new(seed_value)
		var samples: int = 0
		var changed: int = 0
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 != 0:
				continue
			var before: int = HASHES_BEFORE[seed_value][samples]
			assert_eq(
				_hash_before_resources(sim), before, "seed %d sample %d" % [seed_value, samples]
			)
			var includes: bool = sim.party.has_resources() or sim.is_guardian_beaten(MOSSY)
			assert_eq(sim.state_hash() != before, includes, "changed only with resources in it")
			if includes:
				changed += 1
			samples += 1
		assert_eq(samples, 8, "every sample")
		assert_gt(changed, 0, "(seed %d gathered within 20 minutes)" % seed_value)


# --- R12 -----------------------------------------------------------------------


func test_r12_beaten_guardians_are_remembered() -> void:
	var sim := Simulation.new(SEED)
	set_party_level(sim, STRONG_LEVEL)
	sim.expedition.stable_seconds = 2.0
	sim.set_target_depth(5)
	sim.set_auto_push(false)
	assert_false(sim.is_guardian_beaten(MOSSY), "not beaten at the start")
	var slain: bool = false
	for i: int in 30_000:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.GUARDIAN_SLAIN:
				slain = true
		if slain:
			break
	assert_true(slain, "(the Slime King falls)")
	assert_true(sim.is_guardian_beaten(MOSSY), "beaten, and kept")
	assert_false(sim.is_guardian_beaten(CLAYPITS), "only that one")
	var saved: Dictionary = sim.to_save()
	var beaten: Array = saved["guardians_beaten"]
	assert_eq(beaten, ["mossy_hollow"], "the save holds it")
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var loaded: Simulation = Simulation.from_save(through_json)
	assert_true(loaded != null and loaded.is_guardian_beaten(MOSSY), "and a load keeps it")
	# The last area's guardian, beaten, after a reload: the map reads the simulation.
	var last: Dictionary = Simulation.new(SEED).to_save()
	last["open_areas"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	last["area"] = "ember_deep"
	last["guardians_beaten"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	_sim = Simulation.from_save(last)
	assert_not_null(_sim, "(an Ember Deep save loads)")
	if _sim == null:
		return
	_build_hud()
	_hud.area_map.open()
	_hud.advance(0.0)
	for row: AreaMapRow in _hud.area_map.rows:
		assert_true(row.guardian_thumb.beaten, "%s's guardian shows beaten" % row.area_id)
	# Older saves: beaten when the area it opens is open or the furthest stage is past it.
	var old: Dictionary = Simulation.new(SEED).to_save()
	old["version"] = 7
	old.erase("resources")
	old.erase("guardians_beaten")
	old["open_areas"] = ["mossy_hollow", "claypits", "old_crypt", "ember_deep"]
	old["area"] = "ember_deep"
	old["last_stable_depth"] = 6
	old["deepest_depth"] = 6
	old["target_depth"] = 6
	old["areas"] = {"claypits": {"safe": 4, "furthest": 4}, "old_crypt": {"safe": 5, "furthest": 5}}
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "(a version 7 save loads)")
	if from_old == null:
		return
	assert_true(from_old.is_guardian_beaten(MOSSY), "the Claypits are open: the Slime King")
	assert_true(from_old.is_guardian_beaten(CLAYPITS), "the Old Crypt is open: the Colossus")
	assert_true(from_old.is_guardian_beaten(CRYPT), "Ember Deep is open: the Bone Lord")
	assert_true(from_old.is_guardian_beaten(EMBER), "furthest 6, past stage 5: the Deep Maw")
	# Beyond the guardian's stage in an area the party is not in, its next area not open.
	var elsewhere: Dictionary = old.duplicate(true)
	elsewhere["open_areas"] = ["mossy_hollow", "claypits"]
	elsewhere["area"] = "mossy_hollow"
	elsewhere["deepest_depth"] = 3
	elsewhere["last_stable_depth"] = 3
	elsewhere["target_depth"] = 3
	elsewhere["areas"] = {"claypits": {"safe": 5, "furthest": 6}}
	var from_elsewhere: Simulation = Simulation.from_save(elsewhere)
	assert_not_null(from_elsewhere, "(a version 7 save with the Claypits at 6 loads)")
	if from_elsewhere != null:
		assert_true(from_elsewhere.is_guardian_beaten(CLAYPITS), "furthest 6 there: the Colossus")
		assert_false(from_elsewhere.is_guardian_beaten(CRYPT), "and not the Bone Lord")
	elsewhere["areas"] = {"claypits": {"safe": 5, "furthest": 5}}
	var at_the_guardian: Simulation = Simulation.from_save(elsewhere)
	assert_true(
		at_the_guardian != null and not at_the_guardian.is_guardian_beaten(CLAYPITS),
		"furthest 5, the guardian's own stage: not beaten"
	)
	var shallow: Dictionary = old.duplicate(true)
	shallow["open_areas"] = ["mossy_hollow"]
	shallow["area"] = "mossy_hollow"
	shallow["deepest_depth"] = 5
	shallow["last_stable_depth"] = 5
	shallow["target_depth"] = 5
	shallow["areas"] = {}
	var from_shallow: Simulation = Simulation.from_save(shallow)
	assert_not_null(from_shallow, "(a version 7 save at stage 5 loads)")
	if from_shallow != null:
		for id: StringName in Content.area_ids():
			assert_false(from_shallow.is_guardian_beaten(id), "%s not beaten at stage 5" % id)
