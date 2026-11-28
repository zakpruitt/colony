extends "res://tests/support/side_path_fixture.gd"
## Spec 112: a colony of more heroes than the four who go down. A new class's artifact is found in
## a cache, its hero waits at camp until its request is paid, and the player chooses the four.

const WINDING: Labyrinth.Shape = Labyrinth.Shape.WINDING
## The ids of a new game's heroes, and the one a first recruit takes.
const FIRST_RECRUIT: int = 5
## How long R2's seeded runs may look for the Test Whistle, in minutes of play.
const FIND_MINUTES: int = 150
## How long R2's and R7's runs compared tick for tick last.
const COMPARE_TICKS: int = 12_000
## The kinds a cache pays with, which come before an artifact it holds.
const CACHE_KINDS: Array[SimEvent.Kind] = [
	SimEvent.Kind.CACHE_OPENED,
	SimEvent.Kind.GOLD_GAINED,
	SimEvent.Kind.XP_GAINED,
	SimEvent.Kind.RESOURCE_GAINED,
]


## The place of [param class_id] in [method Content.hero_class_ids].
static func _place_of(class_id: StringName) -> int:
	return Content.hero_class_ids().find(class_id)


## The ids of [param heroes], in order.
static func _hero_ids(heroes: Array[Hero]) -> Array[int]:
	var ids: Array[int] = []
	for hero: Hero in heroes:
		ids.append(hero.id)
	return ids


## One step of [param sim] and its events.
static func _step(sim: Simulation) -> Array[SimEvent]:
	sim.step()
	return sim.drain_events()


## [param events] as plain values, to compare two runs by.
static func _plain(events: Array[SimEvent]) -> Array:
	var plain: Array = []
	for e: SimEvent in events:
		plain.append([e.kind, e.tick, e.source_id, e.target_id, e.amount, e.flag, e.ability_id])
	return plain


## A new game of [param seed_value] with the test class's artifact found, the party rich enough
## to pay its request.
func _with_artifact(seed_value: int = 1, shape: Labyrinth.Shape = WINDING) -> Simulation:
	var class_id: StringName = add_recruit_class()
	var sim := Simulation.new(seed_value, shape)
	sim.party.artifacts.append(class_id)
	sim.party.gold = 1000
	sim.party.set_resource(&"glowcaps", 50)
	return sim


## [method _with_artifact] with the test class's hero recruited onto the bench.
func _with_recruit(seed_value: int = 1, shape: Labyrinth.Shape = WINDING) -> Simulation:
	var sim: Simulation = _with_artifact(seed_value, shape)
	sim.roster.recruit(RECRUIT_CLASS)
	_step(sim)
	return sim


## True if some line of [param problems] begins with [param field] and a colon.
static func _names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.begins_with(field + ":"):
			return true
	return false


# --- R1 ------------------------------------------------------------------------


## R1: a new class names its artifact, its chance and its request, and the data check refuses each
## bad one by name; a class's looks must be a class that has its own.
func test_r1_artifact_and_request_as_data() -> void:
	for class_id: StringName in Party.STARTING_CLASSES:
		var def: HeroClassDef = Content.hero_class(class_id)
		assert_eq(def.validate(), PackedStringArray(), "%s passes" % class_id)
		assert_eq(def.artifact_name, "", "%s has no artifact" % class_id)
		assert_eq(def.artifact_chance, 0.0, "%s is never found" % class_id)
		assert_eq(def.recruit_gold, 0, "%s has no price" % class_id)
		assert_eq(def.recruit_resource, &"", "%s asks for no resource" % class_id)
		assert_eq(def.looks_like, &"", "%s has its own pictures" % class_id)
		assert_eq(def.look(), class_id, "%s is drawn as itself" % class_id)
	add_recruit_class()
	var good: HeroClassDef = Content.hero_class(RECRUIT_CLASS)
	assert_eq(good.validate(), PackedStringArray(), "the test class passes")
	assert_eq(good.look(), &"knight", "the test class is drawn as the Knight")
	var cases: Array[Array] = [
		["artifact_name", "", "artifact_name"],
		["artifact_chance", 0.0, "artifact_chance"],
		["artifact_chance", -0.1, "artifact_chance"],
		["artifact_chance", 1.01, "artifact_chance"],
		["recruit_gold", 0, "recruit_gold"],
		["recruit_resource", &"moonstone", "recruit_resource"],
		["recruit_resource_count", -1, "recruit_resource_count"],
		["recruit_resource_count", 0, "recruit_resource_count"],
		["looks_like", &"bard", "looks_like"],
	]
	for case: Array in cases:
		var bad: HeroClassDef = good.duplicate() as HeroClassDef
		bad.set(case[0] as String, case[1])
		var problems: PackedStringArray = bad.validate()
		assert_true(
			_names(problems, case[2] as String),
			"%s = %s is refused by name: %s" % [case[0], case[1], problems]
		)
	var no_resource: HeroClassDef = good.duplicate() as HeroClassDef
	no_resource.recruit_resource = &""
	assert_true(
		_names(no_resource.validate(), "recruit_resource_count"), "a count with no resource"
	)
	no_resource.recruit_resource_count = 0
	assert_eq(no_resource.validate(), PackedStringArray(), "gold alone is a request")
	var at_one: HeroClassDef = good.duplicate() as HeroClassDef
	at_one.artifact_chance = 1.0
	assert_eq(at_one.validate(), PackedStringArray(), "a chance of 1 is allowed")
	# A look must be a class with looks of its own, for a starting class too.
	var knight: HeroClassDef = Content.hero_class(&"knight").duplicate() as HeroClassDef
	knight.looks_like = &"nobody"
	assert_true(_names(knight.validate(), "looks_like"), "a look that is not a class")
	knight.looks_like = RECRUIT_CLASS
	assert_true(_names(knight.validate(), "looks_like"), "a look that looks like another")
	knight.looks_like = &"mage"
	assert_eq(knight.validate(), PackedStringArray(), "a look that is a class of its own")


# --- R2 ------------------------------------------------------------------------


## The label of the fork that rolls for the cache opened by [param opened] in [param sim].
static func _fork_label(sim: Simulation, opened: SimEvent) -> String:
	var e: Expedition = sim.expedition
	return "artifact/%s/%d/%d/%d" % [e.place, e.depth, opened.amount, opened.tick]


## R2: each cache opened may hold one artifact, rolled from a fork of its own; its event comes
## after the cache's; a found class is never rolled again; with nothing to find, nothing changes.
func test_r2_found_in_caches() -> void:
	# At chance 1 the first cache opened finds it.
	var class_id: StringName = add_recruit_class()
	Content.hero_class(class_id).artifact_chance = 1.0
	var sim: Simulation = winding_simulation(1)
	raise_party(sim, 10)
	var path: SidePath = _stand_before(sim, 1, 0, 1)
	path.gate = &"rubble"
	var events: Array[SimEvent] = _events_until(
		sim, func() -> bool: return not sim.party.artifacts.is_empty(), LIMIT_TICKS_3_MIN
	)
	var opened: Array[SimEvent] = _of_kind(events, SimEvent.Kind.CACHE_OPENED)
	var found: Array[SimEvent] = _of_kind(events, SimEvent.Kind.ARTIFACT_FOUND)
	assert_eq(opened.size(), 1, "one cache opened")
	assert_eq(found.size(), 1, "one artifact found")
	if opened.size() != 1 or found.size() != 1:
		return
	assert_eq(found[0].tick, opened[0].tick, "found as the cache opens")
	assert_eq(found[0].source_id, opened[0].source_id, "by the hero who opened the gate")
	assert_eq(found[0].target_id, _place_of(class_id), "the class's place")
	var at: int = events.find(found[0])
	for e: SimEvent in events:
		if e.tick == found[0].tick and CACHE_KINDS.has(e.kind):
			assert_lt(events.find(e), at, "after the cache's %s" % SimEvent.Kind.keys()[e.kind])
	assert_eq(sim.party.artifacts, [class_id] as Array[StringName], "the artifact is found")
	assert_true(sim.roster.is_waiting(class_id), "its hero waits at camp")
	# A found class is never drawn again.
	var rng_before: Dictionary[String, int] = sim.expedition._rng.save_state()
	for i: int in 5:
		ArtifactFinds.on_cache(sim.expedition, 1)
	assert_eq(sim.expedition.drain_events().size(), 0, "nothing more is found")
	assert_eq(sim.party.artifacts.size(), 1, "the one artifact")
	assert_eq(sim.expedition._rng.save_state(), rng_before, "the stream draws nothing")

	# At 0.12 a seeded run finds it on the cache its fork says.
	Content.hero_class(class_id).artifact_chance = 0.12
	var report: PackedStringArray = []
	for seed_value: int in range(1, 4):
		report.append(_seeded_find(seed_value, class_id))
	gut.p("\n".join(report))

	_remove_recruit_class()
	_check_nothing_to_find()


## Plays a winding run of [param seed_value], buying upgrades, until [param class_id]'s artifact
## is found, checking each cache it opens against its fork. Returns a line for the report.
func _seeded_find(seed_value: int, class_id: StringName) -> String:
	var sim: Simulation = winding_simulation(seed_value)
	sim.set_auto_buy(true)
	var caches: int = 0
	var expected: int = -1
	for i: int in ticks_in(FIND_MINUTES * 60.0):
		var events: Array[SimEvent] = _step(sim)
		for e: SimEvent in _of_kind(events, SimEvent.Kind.CACHE_OPENED):
			caches += 1
			var roll: float = sim.expedition._rng.fork(_fork_label(sim, e)).next_float()
			if expected < 0 and roll < 0.12:
				expected = caches
		var found: Array[SimEvent] = _of_kind(events, SimEvent.Kind.ARTIFACT_FOUND)
		if not found.is_empty():
			assert_eq(caches, expected, "seed %d: found on the cache its fork says" % seed_value)
			assert_eq(found[0].target_id, _place_of(class_id), "seed %d: the class" % seed_value)
			return (
				"seed %d: found on cache %d, at minute %.1f"
				% [seed_value, caches, sim.seconds() / 60.0]
			)
		if expected > 0 and caches >= expected:
			fail_test("seed %d: cache %d should have found it" % [seed_value, expected])
			return "seed %d: missed" % seed_value
	fail_test("seed %d: not found in %d minutes, %d caches" % [seed_value, FIND_MINUTES, caches])
	return "seed %d: not found" % seed_value


## With no class to find, a run whose caches each call the roll again equals a plain one, event
## for event and hash for hash, and the roll draws nothing from the expedition's stream.
func _check_nothing_to_find() -> void:
	var plain: Simulation = winding_simulation(2)
	var called: Simulation = winding_simulation(2)
	plain.set_auto_buy(true)
	called.set_auto_buy(true)
	var caches: int = 0
	var differ: int = -1
	for i: int in COMPARE_TICKS:
		var plain_events: Array[SimEvent] = _step(plain)
		var called_events: Array[SimEvent] = _step(called)
		if (
			_plain(plain_events) != _plain(called_events)
			or (plain.state_hash() != called.state_hash())
		):
			differ = called.tick
			break
		for e: SimEvent in _of_kind(called_events, SimEvent.Kind.CACHE_OPENED):
			caches += 1
			var before: Dictionary[String, int] = called.expedition._rng.save_state()
			ArtifactFinds.on_cache(called.expedition, e.source_id)
			assert_eq(called.expedition._rng.save_state(), before, "nothing drawn")
	assert_eq(differ, -1, "the runs are the same, tick for tick")
	assert_gt(caches, 0, "caches were opened")


# --- R3 ------------------------------------------------------------------------


## R3: a class whose artifact is found waits at camp, and paying its request recruits its hero to
## the bench at the level of the lowest going down; every other recruit does nothing.
func test_r3_recruiting() -> void:
	var class_id: StringName = add_recruit_class()
	var sim := Simulation.new(1)
	sim.party.gold = 1000
	sim.party.set_resource(&"glowcaps", 50)
	assert_false(sim.roster.is_waiting(class_id), "not waiting before the find")
	assert_eq(sim.roster.still_hidden(), 1, "one class still hidden")
	assert_eq(sim.roster.waiting_at_camp(), [] as Array[StringName], "nobody at camp")
	sim.roster.recruit(class_id)
	_check_refused(sim, "not found")

	sim.party.artifacts.append(class_id)
	assert_true(sim.roster.is_waiting(class_id), "waiting after the find")
	assert_true(sim.roster.can_recruit(class_id), "payable")
	assert_eq(sim.roster.waiting_at_camp(), [class_id] as Array[StringName], "at camp")
	assert_eq(sim.roster.still_hidden(), 0, "none hidden")

	for refused: Array in [[&"wizard", 1000, 50], [class_id, 299, 50], [class_id, 1000, 39]]:
		sim.party.gold = refused[1] as int
		sim.party.set_resource(&"glowcaps", refused[2] as int)
		sim.roster.recruit(refused[0] as StringName)
		_check_refused(sim, "%s with %d gold and %d glowcaps" % refused)
	assert_false(sim.roster.can_recruit(class_id), "short of glowcaps")

	var levels: Array[int] = [7, 5, 9, 6]
	for i: int in levels.size():
		raise(sim.party.heroes[i], levels[i])
	assert_eq(sim.roster.recruit_level(), 5, "the lowest going down")
	sim.party.gold = 1000
	sim.party.set_resource(&"glowcaps", 50)
	sim.roster.recruit(class_id)
	var events: Array[SimEvent] = _step(sim)
	var recruited: Array[SimEvent] = _of_kind(events, SimEvent.Kind.HERO_RECRUITED)
	assert_eq(recruited.size(), 1, "recruited")
	if recruited.size() != 1:
		return
	assert_eq(recruited[0].source_id, FIRST_RECRUIT, "the new hero's id")
	assert_eq(recruited[0].target_id, _place_of(class_id), "the class's place")
	assert_eq(recruited[0].amount, 300, "the gold paid")
	assert_eq(sim.party.gold, 700, "300 gold paid")
	assert_eq(sim.party.resource(&"glowcaps"), 10, "40 glowcaps paid")
	assert_eq(_hero_ids(sim.party.heroes), [1, 2, 3, 4] as Array[int], "the four are the same")
	assert_eq(sim.party.bench.size(), 1, "one on the bench")
	var hero: Hero = sim.party.hero(FIRST_RECRUIT)
	assert_not_null(hero, "found by id")
	if hero == null:
		return
	assert_eq(sim.party.bench[0], hero, "on the bench")
	assert_eq(hero.class_id, class_id, "of the class")
	assert_eq(hero.level, 5, "at the lowest level going down")
	assert_eq(hero.xp, Hero.xp_for_level(5), "with exactly that level's XP")
	assert_eq(hero.talent_points(), TalentRules.talent_points_at(5), "every talent point")
	assert_eq(hero.paragon_points(), TalentRules.paragon_points_at(5), "every paragon point")
	assert_true(hero.talents().is_empty(), "no node taken")
	assert_false(hero.ranks.any(), "every path at 0")
	assert_eq(hero.health, hero.max_health(), "full health")
	assert_eq(hero.upgrades, sim.upgrades, "the camp's upgrades")
	assert_eq(sim.party.roster().size(), 5, "five in the colony")
	assert_true(sim.party.has_class(class_id), "the colony has the class")
	assert_false(sim.roster.is_waiting(class_id), "no longer waiting")
	assert_eq(sim.party.artifacts, [class_id] as Array[StringName], "the artifact stays found")

	sim.party.gold = 1000
	sim.party.set_resource(&"glowcaps", 50)
	sim.roster.recruit(class_id)
	_check_refused(sim, "already in")


## Steps [param sim] once and checks the recruit asked for did nothing: no event, nothing paid,
## nobody new.
func _check_refused(sim: Simulation, what: String) -> void:
	var gold: int = sim.party.gold
	var glowcaps: int = sim.party.resource(&"glowcaps")
	var size: int = sim.party.roster().size()
	var events: Array[SimEvent] = _step(sim)
	assert_eq(_of_kind(events, SimEvent.Kind.HERO_RECRUITED).size(), 0, "%s: no event" % what)
	assert_eq(sim.party.gold, gold, "%s: no gold taken" % what)
	assert_eq(sim.party.resource(&"glowcaps"), glowcaps, "%s: no glowcaps taken" % what)
	assert_eq(sim.party.roster().size(), size, "%s: nobody new" % what)


# --- R4 ------------------------------------------------------------------------


## R4: a swap is made on the first step the party travels or rests, the four by role; one asked
## in a fight waits for its end; a stale one is dropped, and bad ids do nothing.
func test_r4_choosing_the_four() -> void:
	var sim: Simulation = _with_recruit(1, Labyrinth.Shape.FLAT)
	var recruit: Hero = sim.party.hero(FIRST_RECRUIT)
	var rogue: Hero = sim.party.hero(2)
	raise(rogue, 32)
	rogue.take_talent(_tree(&"rogue").path(0).nodes[0])
	rogue.spend_paragon(TrainingDef.Stat.POWER)
	rogue.ranks.set_xp(0, 7)
	var kept: Array = [rogue.level, rogue.xp, rogue.talents(), rogue.ranks.xp(0)]
	recruit.health = 1
	assert_eq(sim.expedition.state, Expedition.State.TRAVELLING, "travelling")
	sim.roster.swap(FIRST_RECRUIT, 2)
	assert_eq(sim.roster.waiting(), [Vector2i(FIRST_RECRUIT, 2)] as Array[Vector2i], "listed")
	var events: Array[SimEvent] = _step(sim)
	var fielded: Array[SimEvent] = _of_kind(events, SimEvent.Kind.HERO_FIELDED)
	assert_eq(fielded.size(), 1, "made on the next step")
	if fielded.size() == 1:
		assert_eq(fielded[0].source_id, FIRST_RECRUIT, "the hero who came in")
		assert_eq(fielded[0].target_id, 2, "the hero who left")
	# The recruit is a tank, as the Knight is: tanks first, then by id.
	assert_eq(
		_hero_ids(sim.party.heroes), [1, FIRST_RECRUIT, 3, 4] as Array[int], "by role, then id"
	)
	assert_eq(_hero_ids(sim.party.bench), [2] as Array[int], "the rogue is benched")
	assert_eq(recruit.health, recruit.max_health(), "comes in at full health")
	assert_eq(
		[rogue.level, rogue.xp, rogue.talents(), rogue.ranks.xp(0)], kept, "the rogue keeps all"
	)
	assert_eq(rogue.paragon_rank(TrainingDef.Stat.POWER), 1, "and its paragon")
	assert_true(sim.roster.waiting().is_empty(), "nothing waits")

	# Asked during a fight, it waits, and a second one for the same bench hero goes stale.
	assert_true(
		step_until(
			sim,
			func() -> bool: return sim.expedition.state == Expedition.State.FIGHTING,
			LIMIT_TICKS_3_MIN
		),
		"a fight"
	)
	sim.roster.swap(2, FIRST_RECRUIT)
	sim.roster.swap(2, 3)
	var asked: Array[Vector2i] = [Vector2i(2, FIRST_RECRUIT), Vector2i(2, 3)]
	assert_eq(sim.roster.waiting(), asked, "both listed, in order")
	var made: Array[SimEvent] = []
	var states: Array[Expedition.State] = []
	for i: int in LIMIT_TICKS_3_MIN:
		states.append(sim.expedition.state)
		var heard: Array[SimEvent] = _of_kind(_step(sim), SimEvent.Kind.HERO_FIELDED)
		if not heard.is_empty():
			made = heard
			break
		assert_eq(sim.roster.waiting(), asked, "still waiting")
		if sim.roster.waiting() != asked:
			break
	assert_eq(made.size(), 1, "one swap made, the stale one dropped")
	if made.size() != 1:
		return
	assert_true(states.has(Expedition.State.FIGHTING), "it waited through the fight")
	var at: Expedition.State = states[states.size() - 1]
	assert_true(
		at == Expedition.State.TRAVELLING or at == Expedition.State.RESTING,
		"made on a step that began travelling or resting"
	)
	for state: Expedition.State in states.slice(0, states.size() - 1):
		assert_true(
			state != Expedition.State.TRAVELLING and state != Expedition.State.RESTING,
			"on the first such step"
		)
	assert_eq(made[0].source_id, 2, "the rogue came in")
	assert_eq(made[0].target_id, FIRST_RECRUIT, "the recruit left")
	assert_eq(_hero_ids(sim.party.heroes), [1, 2, 3, 4] as Array[int], "the four of a new game")
	assert_eq(_hero_ids(sim.party.bench), [FIRST_RECRUIT] as Array[int], "the recruit benched")
	assert_true(sim.roster.waiting().is_empty(), "the stale one is gone")
	assert_eq(_of_kind(_step(sim), SimEvent.Kind.HERO_FIELDED).size(), 0, "and never made")

	# Bad ids do nothing.
	for bad: Vector2i in [Vector2i(1, 2), Vector2i(FIRST_RECRUIT, FIRST_RECRUIT), Vector2i(99, 1)]:
		sim.roster.swap(bad.x, bad.y)
	sim.roster.swap(FIRST_RECRUIT, 99)
	assert_true(sim.roster.waiting().is_empty(), "no bad swap waits")
	assert_eq(_of_kind(_step(sim), SimEvent.Kind.HERO_FIELDED).size(), 0, "and none is made")
	assert_eq(_hero_ids(sim.party.heroes), [1, 2, 3, 4] as Array[int], "the four unchanged")


# --- R5 ------------------------------------------------------------------------


## R5: a benched hero earns nothing and does nothing, and its tree is planned by command.
func test_r5_a_benched_hero() -> void:
	var sim: Simulation = _with_recruit(1, Labyrinth.Shape.FLAT)
	sim.roster.swap(FIRST_RECRUIT, 2)
	_step(sim)
	var rogue: Hero = sim.party.hero(2)
	assert_eq(sim.party.bench, [rogue] as Array[Hero], "the rogue is benched")
	raise(rogue, 4)
	var before: Array = [rogue.level, rogue.xp, rogue.ranks.xp(0), rogue.ranks.xp(1)]
	var won: int = 0
	var events: Array[SimEvent] = []
	for i: int in LIMIT_TICKS:
		var heard: Array[SimEvent] = _step(sim)
		events.append_array(heard)
		for e: SimEvent in _of_kind(heard, SimEvent.Kind.ENCOUNTER_ENDED):
			if e.flag:
				won += 1
		if won >= 10:
			break
	assert_gte(won, 10, "ten fights won")
	assert_eq(
		[rogue.level, rogue.xp, rogue.ranks.xp(0), rogue.ranks.xp(1)], before, "nothing earned"
	)
	assert_eq(rogue.ranks.xp(2), 0, "no path XP")
	for e: SimEvent in events:
		var by: bool = (
			(e.kind == SimEvent.Kind.XP_GAINED and e.target_id == 2)
			or (
				(
					[
						SimEvent.Kind.QUEST_STARTED,
						SimEvent.Kind.QUEST_DONE,
						SimEvent.Kind.GATE_STARTED,
						SimEvent.Kind.ATTACK_STARTED
					]
					. has(e.kind)
				)
				and e.source_id == 2
			)
		)
		assert_false(by, "the benched rogue in %s" % SimEvent.Kind.keys()[e.kind])
		if by:
			break
	var gained: int = 0
	for hero: Hero in sim.party.heroes:
		gained += hero.xp
	assert_gt(gained, 0, "the four earned XP")

	# Its tree, by command.
	var benched := Simulation.new(1)
	add_recruit_class()
	benched.party.artifacts.append(RECRUIT_CLASS)
	benched.party.gold = 5000
	benched.party.set_resource(&"glowcaps", 50)
	benched.roster.recruit(RECRUIT_CLASS)
	_step(benched)
	var hero: Hero = benched.party.hero(FIRST_RECRUIT)
	raise(hero, 32)
	var node: StringName = _tree(RECRUIT_CLASS).path(0).nodes[0]
	benched.take_talent(FIRST_RECRUIT, node)
	benched.spend_paragon(FIRST_RECRUIT, TrainingDef.Stat.POWER)
	var taken: Array[SimEvent] = _step(benched)
	assert_eq(_of_kind(taken, SimEvent.Kind.TALENT_TAKEN, FIRST_RECRUIT).size(), 1, "a node")
	assert_eq(_of_kind(taken, SimEvent.Kind.PARAGON_SPENT, FIRST_RECRUIT).size(), 1, "paragon")
	assert_eq(hero.talents(), [node] as Array[StringName], "the node taken")
	assert_eq(hero.paragon_rank(TrainingDef.Stat.POWER), 1, "the point spent")
	# A node it cannot take yet is refused as it would be for a hero going down.
	benched.take_talent(FIRST_RECRUIT, _tree(RECRUIT_CLASS).path(0).nodes[4])
	assert_eq(_of_kind(_step(benched), SimEvent.Kind.TALENT_TAKEN).size(), 0, "rank refused")
	var gold: int = benched.party.gold
	benched.reset_talents(FIRST_RECRUIT)
	var reset: Array[SimEvent] = _of_kind(_step(benched), SimEvent.Kind.TALENTS_RESET)
	assert_eq(reset.size(), 1, "reset")
	assert_eq(benched.party.gold, gold - Simulation.reset_price(hero), "for its price")
	assert_true(hero.talents().is_empty(), "every node given back")


# --- R6 ------------------------------------------------------------------------


## R6: the save keeps the bench and the artifacts found, gives ids in order on loading, loads a
## version 11 save with neither, and refuses each bad value by name.
func test_r6_saves() -> void:
	var sim: Simulation = _with_recruit(1, Labyrinth.Shape.FLAT)
	sim.roster.swap(FIRST_RECRUIT, 2)
	_step(sim)
	var rogue: Hero = sim.party.hero(2)
	raise(rogue, 6)
	rogue.take_talent(_tree(&"rogue").path(0).nodes[0])
	rogue.ranks.set_xp(1, 11)
	var data: Dictionary = _through_json(sim.to_save())
	assert_eq(SaveChecks.whole(data["version"]), 12, "version 12")
	assert_eq(Simulation.SAVE_VERSION, 12)
	var artifacts: Array = data["artifacts"]
	assert_eq(artifacts, [String(RECRUIT_CLASS)], "the artifact found")
	var bench: Array = data["bench"]
	assert_eq(bench.size(), 1, "one benched")
	var loaded: Simulation = Simulation.from_save(data)
	assert_not_null(loaded, "it loads: %s" % Simulation.save_problems(data))
	if loaded == null:
		return
	var classes: Array[StringName] = []
	for hero: Hero in loaded.party.heroes:
		classes.append(hero.class_id)
	assert_eq(
		classes, [&"knight", RECRUIT_CLASS, &"mage", &"cleric"] as Array[StringName], "the four"
	)
	assert_eq(_hero_ids(loaded.party.heroes), [1, 2, 3, 4] as Array[int], "ids 1 to 4 going down")
	assert_eq(_hero_ids(loaded.party.bench), [5] as Array[int], "the next id on the bench")
	var benched: Hero = loaded.party.bench[0]
	assert_eq(benched.class_id, &"rogue", "the rogue benched")
	assert_eq(benched.level, rogue.level, "its level")
	assert_eq(benched.xp, rogue.xp, "its XP")
	assert_eq(benched.talents(), rogue.talents(), "its talents")
	assert_eq(benched.ranks.xp(1), 11, "its paths")
	assert_eq(benched.upgrades, loaded.upgrades, "the camp's upgrades")
	assert_eq(loaded.party.artifacts, [RECRUIT_CLASS] as Array[StringName], "the artifact")
	assert_eq(_through_json(loaded.to_save()), data, "a round trip keeps it all")

	# A version 11 save has no bench and no artifacts.
	var old: Dictionary = _through_json(Simulation.new(3).to_save())
	old["version"] = 11
	old.erase("bench")
	old.erase("artifacts")
	var upgraded: Dictionary = RosterSave.upgrade_11_to_12(old.duplicate(true))
	assert_eq(SaveChecks.whole(upgraded["version"]), 12, "brought to 12")
	var empty_bench: Array = upgraded["bench"]
	var none_found: Array = upgraded["artifacts"]
	assert_eq(empty_bench, [], "an empty bench")
	assert_eq(none_found, [], "no artifact")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "a version 11 save loads: %s" % Simulation.save_problems(old))
	if from_old != null:
		assert_true(from_old.party.bench.is_empty(), "with an empty bench")
		assert_true(from_old.party.artifacts.is_empty(), "and no artifact found")

	_check_refusals(data)


## Each bad value of a save [param good] that has a bench and an artifact is refused by name.
func _check_refusals(good: Dictionary) -> void:
	var knight: Dictionary = (good["heroes"] as Array)[0]
	var rogue: Dictionary = (good["bench"] as Array)[0]
	var five: Array = (good["heroes"] as Array).duplicate(true)
	five.append(rogue.duplicate(true))
	var bad_level: Dictionary = rogue.duplicate(true)
	bad_level["level"] = 0
	var cases: Array[Array] = [
		["bench", "bench", null],
		["bench", "bench", "rogue"],
		["bench[0].level", "bench", [bad_level]],
		["bench[1].class", "bench", [rogue, rogue]],
		["bench[1].class", "bench", [rogue, knight]],
		["heroes", "heroes", five],
		["artifacts", "artifacts", null],
		["artifacts", "artifacts", {}],
		["artifacts[0]", "artifacts", ["wizard"]],
		["artifacts[0]", "artifacts", ["knight"]],
		["artifacts[1]", "artifacts", [String(RECRUIT_CLASS), String(RECRUIT_CLASS)]],
		["heroes[1].class", "artifacts", []],
	]
	for case: Array in cases:
		var data: Dictionary = good.duplicate(true)
		if case[2] == null:
			data.erase(case[1] as String)
		else:
			data[case[1] as String] = case[2]
		var problems: PackedStringArray = Simulation.save_problems(data)
		assert_true(_names(problems, case[0] as String), "%s is refused: %s" % [case[0], problems])
		assert_null(Simulation.from_save(data), "%s: nothing loads" % case[0])
	assert_eq(Simulation.save_problems(good), PackedStringArray(), "the good save has none")


# --- R7 ------------------------------------------------------------------------


## R7: a new game is the four it was; the recorded hashes hold; a run that never recruits, its
## refused commands and all, plays as a plain one tick for tick.
func test_r7_nothing_changes() -> void:
	var sim := Simulation.new(1)
	var classes: Array[StringName] = []
	for hero: Hero in sim.party.heroes:
		classes.append(hero.class_id)
	assert_eq(classes, Party.STARTING_CLASSES, "the four starting classes")
	assert_eq(_hero_ids(sim.party.heroes), [1, 2, 3, 4] as Array[int], "ids 1 to 4")
	assert_true(sim.party.bench.is_empty(), "nobody benched")
	assert_true(sim.party.artifacts.is_empty(), "no artifact found")
	assert_eq(sim.party.roster(), sim.party.heroes, "the colony is the four")
	assert_eq(sim.roster.still_hidden(), 0, "no class to find in the data")

	var recorded: Dictionary = load("res://tests/acceptance/test_016_camp_upgrades.gd").get(
		"RECORDED_HASHES"
	)
	var seed_value: int = recorded.keys()[0]
	var run := Simulation.new(seed_value)
	var hashes: Array = []
	for i: int in 12_000:
		_step(run)
		if run.tick % 1500 == 0:
			hashes.append(run.state_hash())
	var expected: Array = recorded[seed_value]
	assert_eq(hashes, expected, "seed %d hashes as recorded" % seed_value)

	var plain: Simulation = winding_simulation(3)
	var asked: Simulation = winding_simulation(3)
	var differ: int = -1
	for i: int in COMPARE_TICKS:
		if i % 50 == 0:
			asked.roster.recruit(&"knight")
			asked.roster.recruit(&"wizard")
			asked.roster.swap(1, 2)
			asked.roster.swap(9, 1)
		if _plain(_step(plain)) != _plain(_step(asked)) or plain.state_hash() != asked.state_hash():
			differ = asked.tick
			break
	assert_eq(differ, -1, "a run that never recruits plays as before, tick for tick")
