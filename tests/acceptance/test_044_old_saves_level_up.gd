extends GutTest
## Acceptance tests for specs/044-old-saves-level-up/spec.md, one per requirement.

const SEED: int = 44
## The XP a hero saved before spec 036 might hold at level 4: more than level 5 costs now.
const OLD_XP: int = 450
## A depth from which every time is the deep game's (DepthTiming.DEEP_DEPTH).
const DEEP: int = 10
## A level at which the party wins its fights at DEEP.
const STRONG_LEVEL: int = 30


## A save of a new game with the hero of class [param class_text] at [param level] holding
## [param xp], as a game saved before spec 036 might hold it.
func _old_save(class_text: String, level: int, xp: int) -> Dictionary:
	var data: Dictionary = Simulation.new(SEED).to_save()
	for saved: Dictionary in data["heroes"] as Array:
		if saved["class"] == class_text:
			saved["level"] = level
			saved["xp"] = xp
	return data


func _hero_of(sim: Simulation, class_id: StringName) -> Hero:
	for hero: Hero in sim.party.heroes:
		if hero.class_id == class_id:
			return hero
	return null


## A hero of class [param class_id] made at [param level], to compare a loaded one with.
func _fresh(class_id: StringName, level: int) -> Hero:
	var hero := Hero.new(99, Content.hero_class(class_id))
	hero.level = level
	return hero


func _kinds(events: Array[SimEvent]) -> Array[SimEvent.Kind]:
	var kinds: Array[SimEvent.Kind] = []
	for event: SimEvent in events:
		kinds.append(event.kind)
	return kinds


# --- R1 ------------------------------------------------------------------------


func test_r1_loaded_hero_has_its_level() -> void:
	assert_lt(Hero.xp_for_level(5), OLD_XP, "450 XP pays for level 5")
	assert_gt(Hero.xp_for_level(6), OLD_XP, "but not level 6")
	var data: Dictionary = _old_save("knight", 4, OLD_XP)
	# The mage learns a microskill at level 4, so loading must give it one.
	for saved: Dictionary in data["heroes"] as Array:
		if saved["class"] == "mage":
			saved["level"] = 3
			saved["xp"] = OLD_XP
	var sim: Simulation = Simulation.from_save(data)
	assert_not_null(sim, "the save loads")
	if sim == null:
		return
	for class_id: StringName in [&"knight", &"mage"]:
		var hero: Hero = _hero_of(sim, class_id)
		var level_5: Hero = _fresh(class_id, 5)
		assert_eq(hero.level, 5, "%s: the level its XP earns" % class_id)
		assert_eq(hero.xp, OLD_XP, "%s: its XP kept" % class_id)
		assert_eq(hero.max_health(), level_5.max_health(), "%s: level 5's health" % class_id)
		assert_eq(hero.health, hero.max_health(), "%s: and full" % class_id)
		assert_eq(hero.microskills(), level_5.microskills(), "%s: its microskills" % class_id)
		assert_eq(hero.combatant().damage, level_5.combatant().damage, "%s: its damage" % class_id)
	assert_true(
		_hero_of(sim, &"mage").has_microskill(_fresh(&"mage", 5).microskills()[0]),
		"the mage learned its level 4 microskill"
	)
	for hero: Hero in sim.party.heroes:
		assert_lt(hero.xp, Hero.xp_for_level(hero.level + 1), "%s owes no level" % hero.class_id)

	assert_eq(sim.drain_events(), [] as Array[SimEvent], "loading raises no events")
	var replay := AwayReplay.new(sim, 1.0)
	while not replay.run(1_000_000):
		pass
	for hero: Hero in sim.party.heroes:
		assert_eq(replay.report.levels_gained[hero.id], 0, "the away report counts no levels")
	var kinds: Array[SimEvent.Kind] = _kinds(sim.drain_events())
	assert_false(kinds.has(SimEvent.Kind.LEVEL_UP), "no level-up flashes")
	assert_false(kinds.has(SimEvent.Kind.MICROSKILL_LEARNED), "no microskill flashes")

	# A save that was already consistent loads exactly as before.
	var played := Simulation.new(SEED)
	for i: int in 1200:
		played.step()
	_hero_of(played, &"rogue").gain_xp(Hero.xp_for_level(6) + 7)
	var consistent: Dictionary = played.to_save()
	var again: Simulation = Simulation.from_save(consistent)
	assert_not_null(again, "a consistent save loads")
	if again == null:
		return
	assert_eq(again.to_save(), consistent, "and saves the same data")
	assert_eq(again.drain_events(), [] as Array[SimEvent], "with no events")
	for i: int in played.party.heroes.size():
		var before: Hero = played.party.heroes[i]
		var after: Hero = again.party.heroes[i]
		assert_eq(
			[after.level, after.xp], [before.level, before.xp], "%s unchanged" % after.class_id
		)


# --- R2 ------------------------------------------------------------------------


func _make_hud(simulation: Simulation) -> Hud:
	var world := World.new()
	world.simulation = simulation
	add_child_autofree(world)
	world.set_process(false)
	var effects := CombatEffects.new()
	add_child_autofree(effects)
	effects.setup(world, simulation)
	effects.set_process(false)
	var made := Hud.new()
	add_child_autofree(made)
	made.set_process(false)
	made.setup(simulation, world, effects)
	made.advance(0.0)
	return made


func test_r2_sheet_is_right_at_once() -> void:
	var sim: Simulation = Simulation.from_save(_old_save("knight", 4, OLD_XP))
	assert_not_null(sim, "the save loads")
	if sim == null:
		return
	var hud: Hud = _make_hud(sim)
	var knight: Hero = _hero_of(sim, &"knight")
	var into: int = OLD_XP - Hero.xp_for_level(5)
	var span: int = Hero.xp_for_level(6) - Hero.xp_for_level(5)
	var fraction: float = float(into) / float(span)
	var frame: HeroFrame = null
	for each: HeroFrame in hud.frames:
		if each.hero_id == knight.id:
			frame = each
	assert_not_null(frame, "the knight has a frame")
	if frame == null:
		return
	assert_almost_eq(frame.shown_xp(), fraction, 0.001, "the frame's bar from the first frame")
	hud.hero_sheet.open(knight.id)
	hud.advance(0.016)
	var expected: String = "%d / %d XP, %d to level 6" % [into, span, Hero.xp_for_level(6) - OLD_XP]
	assert_eq(hud.hero_sheet.line(&"xp"), expected, "the sheet's XP line on the first frame")
	assert_eq(hud.hero_sheet.line(&"level"), "Level 5", "and its level")
	assert_almost_eq(hud.hero_sheet.bar_fraction(&"xp"), fraction, 0.001, "and its bar")
	assert_almost_eq(frame.shown_xp(), fraction, 0.001, "the frame's bar still")
	for hero: Hero in sim.party.heroes:
		hud.hero_sheet.open(hero.id)
		hud.advance(0.016)
		assert_false(hud.hero_sheet.line(&"xp").contains("-"), "%s: no negative" % hero.class_id)


# --- R3 ------------------------------------------------------------------------


func test_r3_chamber_needs_its_depth() -> void:
	var init_args: Array = []
	var init_defaults: Array = []
	for method: Dictionary in (ChamberState as Script).get_script_method_list():
		if method["name"] == "_init":
			init_args = method["args"]
			init_defaults = method["default_args"]
	assert_eq(init_args.size(), 1, "the constructor takes the depth")
	assert_eq(init_defaults, [], "and has no default for it")
	if init_args.size() != 1 or not init_defaults.is_empty():
		return
	for level_depth: int in [1, 7, DEEP]:
		assert_eq(
			ChamberState.new(level_depth).depth, level_depth, "made at depth %d" % level_depth
		)

	# In a running expedition every chamber record carries its own level's depth.
	var sim := Simulation.new(SEED)
	sim.set_auto_buy(true)
	for i: int in 20 * 60 * Simulation.TICKS_PER_SECOND:
		sim.step()
	var depths: Dictionary[int, bool] = {}
	for key: Vector2i in sim.expedition._chambers:
		var record: ChamberState = sim.expedition._chambers[key]
		assert_eq(record.depth, key.x, "chamber %s" % key)
		depths[key.x] = true
	assert_gt(depths.size(), 1, "chambers on more than one depth were made: %s" % [depths.keys()])


# --- R4 ------------------------------------------------------------------------


## A game saved at depth DEEP with every hero at STRONG_LEVEL, staying there.
func _deep_game() -> Simulation:
	var data: Dictionary = Simulation.new(SEED).to_save()
	for saved: Dictionary in data["heroes"] as Array:
		saved["level"] = STRONG_LEVEL
		saved["xp"] = Hero.xp_for_level(STRONG_LEVEL)
	data["last_stable_depth"] = DEEP
	data["deepest_depth"] = DEEP
	data["target_depth"] = DEEP
	data["auto_push"] = false
	return Simulation.from_save(data)


## True when the chamber has something in it again: monsters or a side quest.
func _refilled(sim: Simulation, chamber_index: int) -> bool:
	return (
		sim.expedition.is_populated(DEEP, chamber_index)
		or sim.expedition.side_quest_in(DEEP, chamber_index) != &""
	)


func test_r4_deep_refill() -> void:
	assert_eq(DepthTiming.DEEP_DEPTH, DEEP, "depth 10 keeps the deep game's pace")
	var sim: Simulation = _deep_game()
	assert_not_null(sim, "the deep game loads")
	if sim == null:
		return
	# Play until the party clears a plain chamber at depth 10.
	var chamber: int = -1
	var cleared_at: int = -1
	var limit: int = sim.tick + 30 * 60 * Simulation.TICKS_PER_SECOND
	while chamber < 0 and sim.tick < limit:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind != SimEvent.Kind.ENCOUNTER_ENDED or not event.flag:
				continue
			var won: ChamberState = sim.expedition._chambers[Vector2i(DEEP, event.amount)]
			if not won.guardian:
				chamber = event.amount
				cleared_at = event.tick
	assert_eq(sim.expedition.depth, DEEP, "the party stayed at depth 10")
	assert_gt(chamber, -1, "the party cleared a chamber at depth 10")
	if chamber < 0:
		return
	var record: ChamberState = sim.expedition._chambers[Vector2i(DEEP, chamber)]
	assert_eq(record.depth, DEEP, "its record knows its depth")
	assert_eq(record.cleared_tick, cleared_at, "and when it was cleared")

	var at_89: int = cleared_at + 89 * Simulation.TICKS_PER_SECOND
	var at_90: int = cleared_at + 90 * Simulation.TICKS_PER_SECOND
	while sim.tick < at_89:
		sim.step()
		assert_false(_refilled(sim, chamber), "empty at %.1f s" % sim.seconds())
		if _refilled(sim, chamber):
			return
	assert_eq(sim.tick, at_89, "89 seconds after the clear")
	assert_false(_refilled(sim, chamber), "still empty at 89 s")
	while sim.tick < at_90:
		sim.step()
	assert_true(_refilled(sim, chamber), "refilled at 90 s")
