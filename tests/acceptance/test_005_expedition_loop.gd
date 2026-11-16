extends GutTest
## Acceptance tests for specs/005-expedition-loop/spec.md, one per requirement.
##
## These run the real simulation with the shipped data. Where a test needs a
## situation quickly it sets the expedition's public fields (depth, x, facing,
## target, stable_seconds) and hero health directly, as the spec allows.

const SEED: int = 1234
const EPSILON: float = 0.001
const HOUR_TICKS: int = 36_000

# --- Helpers -------------------------------------------------------------------


func _ticks(seconds: float) -> int:
	return roundi(seconds * Simulation.TICKS_PER_SECOND)


## Steps [param count] ticks and returns every event they produced.
func _run(sim: Simulation, count: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in count:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## Steps until an event of [param kind] appears (that step included), at most [param limit] ticks.
func _run_until(sim: Simulation, kind: SimEvent.Kind, limit: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in limit:
		sim.step()
		var fresh: Array[SimEvent] = sim.drain_events()
		events.append_array(fresh)
		if not _of_kind(fresh, kind).is_empty():
			return events
	fail_test("no %s within %d ticks" % [SimEvent.Kind.keys()[kind], limit])
	return events


func _of_kind(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.kind == kind:
			found.append(e)
	return found


func _level(sim: Simulation, depth: int) -> LabyrinthLevel:
	return sim.labyrinth.level(depth)


## The chambers of a level that are never populated: START, the shaft chamber, the landing chamber.
func _always_empty(sim: Simulation, depth: int) -> Array[int]:
	var level: LabyrinthLevel = _level(sim, depth)
	var empty: Array[int] = [level.shaft_chamber().index]
	for room: LabyrinthChamber in level.chambers:
		if room.kind == LabyrinthChamber.Kind.START:
			empty.append(room.index)
	if depth > 1:
		empty.append(level.chamber_at(sim.labyrinth.shaft_column(depth - 1)).index)
	return empty


## The first populated chamber of a level, or -1.
func _populated(sim: Simulation, depth: int) -> int:
	for room: LabyrinthChamber in _level(sim, depth).chambers:
		if sim.expedition.is_populated(depth, room.index):
			return room.index
	return -1


## Puts the party on [param depth], one step outside chamber [param index], walking into it.
func _approach(sim: Simulation, depth: int, index: int, from_left: bool = true) -> void:
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth
	var room: LabyrinthChamber = _level(sim, depth).chambers[index]
	if from_left:
		e.x = room.rect.position.x - 0.1
		e.facing = 1
	else:
		e.x = room.rect.end.x + 0.05
		e.facing = -1


## The amounts of every event of [param kind], in order.
func _amounts(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[int]:
	var amounts: Array[int] = []
	for e: SimEvent in _of_kind(events, kind):
		amounts.append(e.amount)
	return amounts


func _ids(fighters: Array[Combatant]) -> Array[int]:
	var ids: Array[int] = []
	for c: Combatant in fighters:
		ids.append(c.id)
	return ids


func _def_ids(fighters: Array[Combatant]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for c: Combatant in fighters:
		ids.append(c.def_id)
	return ids


## Kills every hero: in the fight if there is one, otherwise where they stand.
func _force_wipe(sim: Simulation) -> void:
	if sim.expedition.battle != null:
		for c: Combatant in sim.expedition.battle.heroes:
			c.health = 0
	else:
		for hero: Hero in sim.party.heroes:
			hero.health = 0


# --- R1 ------------------------------------------------------------------------


func test_r1_new_simulation_starts_an_expedition() -> void:
	var sim := Simulation.new(SEED)
	var classes: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
	assert_eq(sim.party.heroes.size(), 4, "a party of four")
	for i: int in sim.party.heroes.size():
		var hero: Hero = sim.party.heroes[i]
		assert_eq(hero.id, i + 1, "hero ids 1 to 4 in order")
		assert_eq(hero.class_id, classes[i], "hero %d class" % hero.id)
		assert_eq(hero.level, 1)
		assert_eq(hero.xp, 0)
		assert_eq(hero.max_health(), Content.hero_class(classes[i]).max_health)
		assert_eq(hero.health, hero.max_health(), "full health")
		assert_eq(sim.party.hero(hero.id), hero)
	assert_eq(sim.party.gold, 0)

	var e: Expedition = sim.expedition
	assert_eq(e.depth, 1)
	assert_eq(e.state, Expedition.State.TRAVELLING)
	var start: LabyrinthChamber = e.chamber()
	assert_not_null(start)
	if start == null:
		return
	assert_eq(start.kind, LabyrinthChamber.Kind.START, "stands in the START chamber")
	assert_almost_eq(e.x, (start.rect.position.x + start.rect.end.x - 1) / 2.0, EPSILON, "middle")
	var shaft_x: float = _level(sim, 1).shaft_down.position.x
	assert_eq(e.facing, 1 if shaft_x > e.x else -1, "faces the shaft")

	var before: float = e.x
	sim.step()
	assert_eq(sim.tick, 1)
	assert_almost_eq(
		e.x - before, e.facing * Expedition.PARTY_SPEED / Simulation.TICKS_PER_SECOND, EPSILON
	)


# --- R2 ------------------------------------------------------------------------


func test_r2_party_walks_in_formation() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	var start_x: float = e.x
	_run(sim, 10)
	assert_eq(e.state, Expedition.State.TRAVELLING)
	assert_almost_eq(
		absf(e.x - start_x), Expedition.PARTY_SPEED, EPSILON, "PARTY_SPEED tiles in 1 s"
	)
	assert_eq(sim.party.heroes[0].class_id, &"knight", "the tank leads")
	var floor_y: float = _level(sim, 1).floor_y
	for rank: int in sim.party.heroes.size():
		var at: Vector2 = e.hero_position(sim.party.heroes[rank].id)
		assert_almost_eq(
			at.x, e.x - e.facing * rank, EPSILON, "rank %d is %d tiles behind" % [rank, rank]
		)
		assert_eq(at.y, floor_y, "on the floor row")


# --- R3 ------------------------------------------------------------------------


func test_r3_descends_ascends_and_patrols() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	var shaft: float = sim.labyrinth.shaft_column(1) + Labyrinth.SHAFT_WIDTH / 2.0  # spec 015

	sim.set_target_depth(2)
	var events: Array[SimEvent] = _run_until(sim, SimEvent.Kind.DEPTH_CHANGED, _ticks(1800))
	assert_eq(e.depth, 2, "climbed down")
	assert_eq(_of_kind(events, SimEvent.Kind.DEPTH_CHANGED)[0].amount, 2)
	assert_almost_eq(e.x, shaft, EPSILON, "lands at the shaft's middle")
	assert_eq(e.hero_position(1).y, float(_level(sim, 2).floor_y), "on the floor of depth 2")
	assert_eq(_of_kind(events, SimEvent.Kind.PARTY_WIPED).size(), 0)

	sim.set_target_depth(1)
	_run_until(sim, SimEvent.Kind.DEPTH_CHANGED, _ticks(1800))
	assert_eq(e.depth, 1, "climbed back up")
	assert_almost_eq(e.x, shaft, EPSILON, "arrives at the top of the shaft")

	# At the target it patrols: it turns at the far end of the last chamber and of the first.
	var level: LabyrinthLevel = _level(sim, 1)
	var right_end: float = level.chambers[level.chambers.size() - 1].rect.end.x - 1
	var left_end: float = level.chambers[0].rect.position.x
	var turned_right: int = 0
	var turned_left: int = 0
	var facing: int = e.facing
	for i: int in _ticks(600):
		sim.step()
		sim.drain_events()
		if e.facing != facing and e.state == Expedition.State.TRAVELLING:
			if e.facing < 0:
				assert_almost_eq(
					e.x, right_end, EPSILON, "turns at the far end of the last chamber"
				)
				turned_left += 1
			else:
				assert_almost_eq(
					e.x, left_end, EPSILON, "turns at the far end of the first chamber"
				)
				turned_right += 1
		facing = e.facing
	assert_gt(turned_left, 0, "turned round at the right end")
	assert_gt(turned_right, 0, "turned round at the left end")
	assert_eq(e.depth, 1, "stayed on its target depth")


# --- R4 ------------------------------------------------------------------------


func test_r4_battle_starts_on_entering_a_populated_chamber() -> void:
	for seed_value: int in range(1, 11):
		var sim := Simulation.new(seed_value)
		for depth: int in range(1, 6):
			for index: int in _always_empty(sim, depth):
				assert_false(
					sim.expedition.is_populated(depth, index),
					"seed %d depth %d chamber %d is always empty" % [seed_value, depth, index]
				)
				assert_eq(sim.expedition.monsters_in(depth, index).size(), 0)

	for from_left: bool in [true, false]:
		var sim := Simulation.new(SEED)
		var index: int = _populated(sim, 2)
		assert_gte(index, 0, "depth 2 has a populated chamber")
		var room: LabyrinthChamber = _level(sim, 2).chambers[index]
		_approach(sim, 2, index, from_left)
		sim.step()
		var started: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.ENCOUNTER_STARTED)
		var e: Expedition = sim.expedition
		assert_eq(e.state, Expedition.State.FIGHTING, "a battle starts on entering")
		assert_not_null(e.battle)
		if e.battle == null:
			return
		assert_eq(started.size(), 1)
		assert_eq(started[0].amount, index, "the event names the chamber")
		assert_eq(e.chamber(), room)
		var left: float = room.rect.position.x
		var right: float = room.rect.end.x - 1
		var hero_xs: Array[float] = []
		for c: Combatant in e.battle.heroes:
			hero_xs.append(c.x)
		for c: Combatant in e.battle.heroes + e.battle.monsters:
			assert_between(c.x, left, right, "everyone stands on the chamber floor")
		for m: Combatant in e.battle.monsters:
			for hx: float in hero_xs:
				if from_left:
					assert_lt(hx, m.x, "heroes came in from the left")
				else:
					assert_gt(hx, m.x, "heroes came in from the right")
		var rear: float = hero_xs.min() if from_left else hero_xs.max()
		var edge: float = left if from_left else right
		assert_almost_eq(rear, edge, EPSILON, "the rear hero stands at the entry edge")

	# Over a long walk, no fight ever starts in an always-empty chamber.
	var walker := Simulation.new(SEED)
	walker.expedition.stable_seconds = 120.0
	var fights: int = 0
	for i: int in _ticks(1200):
		walker.step()
		if not _of_kind(walker.drain_events(), SimEvent.Kind.ENCOUNTER_STARTED).is_empty():
			fights += 1
			var where: LabyrinthChamber = walker.expedition.chamber()
			assert_does_not_have(_always_empty(walker, walker.expedition.depth), where.index)
	assert_gt(fights, 5, "the walk had fights")


# --- R5 ------------------------------------------------------------------------


func test_r5_encounter_composition() -> void:
	var ranges: Dictionary = {
		LabyrinthChamber.Kind.PLAIN: Vector2i(2, 3),
		LabyrinthChamber.Kind.DEN: Vector2i(4, 5),
		LabyrinthChamber.Kind.VAULT: Vector2i(2, 3),
	}
	var picks: Dictionary[StringName, int] = {}
	for seed_value: int in range(1, 61):
		var sim := Simulation.new(seed_value)
		var other := Simulation.new(seed_value)
		for depth: int in [6, 5, 4, 3, 2, 1]:
			for index: int in range(_level(other, depth).chambers.size() - 1, -1, -1):
				other.expedition.monsters_in(depth, index)
		for depth: int in range(1, 7):
			var level: LabyrinthLevel = _level(sim, depth)
			for room: LabyrinthChamber in level.chambers:
				if not sim.expedition.is_populated(depth, room.index):
					continue
				var where: String = "seed %d depth %d chamber %d" % [seed_value, depth, room.index]
				var monsters: Array[Combatant] = sim.expedition.monsters_in(depth, room.index)
				var wanted: Vector2i = ranges[room.kind]
				assert_between(monsters.size(), wanted.x, wanted.y, "count for the kind, " + where)
				var width: float = room.rect.end.x - 1 - room.rect.position.x
				var low: float = room.rect.position.x + width / 4.0
				var high: float = room.rect.end.x - 1 - width / 4.0
				for m: Combatant in monsters:
					var def: MonsterDef = Content.monster(m.def_id)
					assert_lte(def.min_depth, depth, "no monster above its depth, " + where)
					assert_eq(m.level, depth, "made at the level's depth")
					assert_between(m.x, low - EPSILON, high + EPSILON, "middle half, " + where)
					if depth == 5:
						picks[m.def_id] = picks.get(m.def_id, 0) + 1
				var again: Array[Combatant] = other.expedition.monsters_in(depth, room.index)
				assert_eq(_def_ids(again), _def_ids(monsters), "same monsters, " + where)

	# Deeper dwellers are more likely than shallow ones once available: compared among the
	# monsters that live at depth 5 (spec 013 adds deeper ones, never met there).
	var ids: Array[StringName] = []
	for id: StringName in Content.monster_ids():
		if Content.monster(id).min_depth <= 5:
			ids.append(id)
	for deeper: StringName in ids:
		for shallower: StringName in ids:
			if Content.monster(deeper).min_depth > Content.monster(shallower).min_depth:
				var deeper_picks: int = picks.get(deeper, 0)
				var shallower_picks: int = picks.get(shallower, 0)
				assert_gt(
					deeper_picks,
					shallower_picks,
					"%s favoured over %s at depth 5: %s" % [deeper, shallower, picks]
				)

	# The waiting monsters are the combatants the battle uses.
	var walker := Simulation.new(SEED)
	var index: int = _populated(walker, 1)
	var waiting: Array[Combatant] = walker.expedition.monsters_in(1, index)
	assert_gt(waiting.size(), 0)
	_approach(walker, 1, index)
	walker.step()
	var fight: Battle = walker.expedition.battle
	assert_not_null(fight)
	if fight == null:
		return
	assert_eq(_ids(fight.monsters), _ids(waiting), "same ids in the battle")
	assert_same(fight.monsters[0], waiting[0], "the same combatants")


# --- R6 ------------------------------------------------------------------------


func test_r6_health_carries_into_and_out_of_battle() -> void:
	var sim := Simulation.new(SEED)
	var index: int = _populated(sim, 1)
	_approach(sim, 1, index)
	sim.party.hero(1).health = 10
	sim.party.hero(3).health = 30
	sim.step()
	var fight: Battle = sim.expedition.battle
	assert_not_null(fight)
	if fight == null:
		return
	assert_eq(fight.combatant(1).health, 10, "the knight enters with 10")
	assert_eq(fight.combatant(3).health, 30, "the mage enters with 30")
	assert_eq(fight.combatant(2).health, sim.party.hero(2).max_health(), "a full hero enters full")

	var events: Array[SimEvent] = _run_until(sim, SimEvent.Kind.ENCOUNTER_ENDED, 3000)
	assert_true(_of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)[0].flag, "the heroes won")
	for hero: Hero in sim.party.heroes:
		assert_eq(
			hero.health,
			fight.combatant(hero.id).health,
			"hero %d keeps its battle health" % hero.id
		)
	assert_lt(sim.party.hero(1).health, sim.party.hero(1).max_health(), "health was not reset")


# --- R7 ------------------------------------------------------------------------


func _check_rewards(fight: Battle, events: Array[SimEvent], gold_factor: int) -> int:
	var last_dead: MonsterDef = null
	var gold: int = 0
	for e: SimEvent in events:
		if e.kind == SimEvent.Kind.DIED and e.source_id >= Expedition.FIRST_MONSTER_ID:
			last_dead = Content.monster(fight.combatant(e.source_id).def_id)
		elif e.kind == SimEvent.Kind.XP_GAINED:
			assert_not_null(last_dead, "XP follows a death")
			if last_dead != null:
				assert_eq(e.amount, last_dead.xp, "the monster's xp")
		elif e.kind == SimEvent.Kind.GOLD_GAINED:
			var def: MonsterDef = Content.monster(fight.combatant(e.source_id).def_id)
			assert_eq(def, last_dead, "gold names the monster that just died")
			assert_between(e.amount, def.gold_min * gold_factor, def.gold_max * gold_factor)
			assert_eq(e.amount % gold_factor, 0, "a multiple of %d" % gold_factor)
			gold += e.amount
	return gold


func test_r7_kills_pay_xp_and_gold() -> void:
	var sim := Simulation.new(SEED)
	var index: int = _populated(sim, 1)
	_approach(sim, 1, index)
	sim.party.hero(4).health = 0  # the cleric is down before the fight
	sim.step()
	var fight: Battle = sim.expedition.battle
	var monsters: int = fight.monsters.size()
	var events: Array[SimEvent] = _run_until(sim, SimEvent.Kind.ENCOUNTER_ENDED, 3000)
	var gold: int = _check_rewards(fight, events, 1)
	assert_eq(_of_kind(events, SimEvent.Kind.GOLD_GAINED).size(), monsters, "gold for every kill")
	assert_eq(sim.party.gold, gold, "the party has all the gold")
	var xp_by_hero: Dictionary[int, int] = {}
	for e: SimEvent in _of_kind(events, SimEvent.Kind.XP_GAINED):
		xp_by_hero[e.target_id] = xp_by_hero.get(e.target_id, 0) + e.amount
	assert_false(xp_by_hero.has(4), "a dead hero gains no XP")
	assert_eq(sim.party.hero(4).xp, 0)
	for id: int in [1, 2, 3]:
		if fight.combatant(id).is_alive():
			var paid: int = xp_by_hero.get(id, -1)
			assert_eq(sim.party.hero(id).xp, paid, "hero %d has its XP" % id)
			assert_gt(sim.party.hero(id).xp, 0)

	# In a vault the gold is doubled.
	var vault_seen: bool = false
	for seed_value: int in range(1, 40):
		var vault_sim := Simulation.new(seed_value)
		for depth: int in [1, 2]:
			for room: LabyrinthChamber in _level(vault_sim, depth).chambers:
				if vault_seen or room.kind != LabyrinthChamber.Kind.VAULT:
					continue
				if not vault_sim.expedition.is_populated(depth, room.index):
					continue
				vault_seen = true
				_approach(vault_sim, depth, room.index)
				vault_sim.step()
				var vault_fight: Battle = vault_sim.expedition.battle
				var vault_events: Array[SimEvent] = _run_until(
					vault_sim, SimEvent.Kind.ENCOUNTER_ENDED, 3000
				)
				assert_gt(_of_kind(vault_events, SimEvent.Kind.GOLD_GAINED).size(), 0)
				assert_eq(_check_rewards(vault_fight, vault_events, 2), vault_sim.party.gold)
	assert_true(vault_seen, "found a populated vault")


# --- R8 ------------------------------------------------------------------------


func test_r8_levels() -> void:
	assert_eq(Hero.xp_for_level(1), 0)
	assert_eq(Hero.xp_for_level(2), 50)
	assert_eq(Hero.xp_for_level(3), 150)
	assert_eq(Hero.xp_for_level(4), 300)

	var def: HeroClassDef = Content.hero_class(&"knight")
	var hero := Hero.new(1, def)
	assert_eq(hero.gain_xp(49), 0)
	assert_eq(hero.level, 1, "49 XP is not enough")
	assert_eq(hero.gain_xp(1), 1)
	assert_eq(hero.level, 2, "50 XP is level 2")
	assert_eq(hero.max_health(), def.max_health + def.health_per_level)
	assert_eq(hero.health, hero.max_health(), "healed by the health gained")

	var hurt := Hero.new(2, def)
	hurt.health = 20
	assert_eq(hurt.gain_xp(300), 3, "300 XP jumps three levels at once")
	assert_eq(hurt.level, 4)
	assert_eq(hurt.health, 20 + 3 * def.health_per_level, "healed by the health gained, no more")
	var fighter: Combatant = hurt.combatant()
	assert_eq(fighter.max_health, def.max_health + 3 * def.health_per_level, "health grows")
	assert_eq(fighter.damage, def.damage + 3 * def.damage_per_level, "damage grows")
	assert_eq(fighter.health, hurt.health)

	# In play, the expedition levels heroes and reports each level.
	var sim := Simulation.new(SEED)
	var events: Array[SimEvent] = _run(sim, _ticks(900))
	var level_ups: Array[SimEvent] = _of_kind(events, SimEvent.Kind.LEVEL_UP)
	assert_gt(level_ups.size(), 0, "heroes levelled in 15 minutes")
	var reached: Dictionary[int, int] = {1: 1, 2: 1, 3: 1, 4: 1}
	for e: SimEvent in level_ups:
		assert_eq(e.amount, reached[e.target_id] + 1, "one event per level, in order")
		reached[e.target_id] = e.amount
	for h: Hero in sim.party.heroes:
		assert_eq(h.level, reached[h.id])
		assert_gte(h.xp, Hero.xp_for_level(h.level))
		assert_lt(h.xp, Hero.xp_for_level(h.level + 1))


# --- R9 ------------------------------------------------------------------------


func test_r9_rest_heals_then_moves_on() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	_approach(sim, 1, _populated(sim, 1))
	sim.party.hero(4).health = 0  # a dead hero forces a rest
	var events: Array[SimEvent] = _run_until(sim, SimEvent.Kind.ENCOUNTER_ENDED, 3000)
	assert_true(_of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)[0].flag, "the heroes won")
	assert_eq(_of_kind(events, SimEvent.Kind.REST_STARTED).size(), 1, "rest starts")
	assert_eq(e.state, Expedition.State.RESTING)
	var start: Dictionary[int, int] = {}
	for hero: Hero in sim.party.heroes:
		start[hero.id] = hero.health
	var x: float = e.x
	_run(sim, 10)
	assert_eq(e.x, x, "rests where it stands")
	for hero: Hero in sim.party.heroes:
		var expected: int = mini(
			hero.max_health(),
			start[hero.id] + floori(Expedition.REST_HEAL_PER_SECOND * hero.max_health() + EPSILON)
		)
		assert_eq(hero.health, expected, "hero %d heals at the rest rate" % hero.id)
	assert_gt(sim.party.hero(4).health, 0, "the dead hero is healed too")

	_run_until(sim, SimEvent.Kind.REST_ENDED, _ticks(60))
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.health, hero.max_health(), "hero %d full" % hero.id)
	assert_eq(e.state, Expedition.State.TRAVELLING, "travel resumes")

	# A healthy party does not rest.
	var healthy := Simulation.new(SEED)
	_approach(healthy, 1, _populated(healthy, 1))
	healthy.step()
	for m: Combatant in healthy.expedition.battle.monsters:
		m.health = 1
	var quick: Array[SimEvent] = _run_until(healthy, SimEvent.Kind.ENCOUNTER_ENDED, 3000)
	for hero: Hero in healthy.party.heroes:
		assert_gte(float(hero.health), Expedition.REST_BELOW * hero.max_health())
	assert_eq(_of_kind(quick, SimEvent.Kind.REST_STARTED).size(), 0, "no rest")
	assert_eq(healthy.expedition.state, Expedition.State.TRAVELLING, "travel resumes at once")


# --- R10 -----------------------------------------------------------------------


func test_r10_cleared_chamber_refills() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	var index: int = _populated(sim, 1)
	_approach(sim, 1, index)
	e.target_depth = 2  # walk on and away after the fight
	var events: Array[SimEvent] = _run_until(sim, SimEvent.Kind.ENCOUNTER_ENDED, 3000)
	assert_true(_of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)[0].flag, "the heroes won")
	var cleared: int = sim.tick
	assert_false(e.is_populated(1, index), "empty once cleared")
	assert_eq(e.monsters_in(1, index).size(), 0)
	var refill: int = cleared + _ticks(Expedition.RESPAWN_SECONDS)
	while sim.tick < refill - 1:
		sim.step()
		sim.drain_events()
		if e.is_populated(1, index):
			fail_test("refilled early, at tick %d" % sim.tick)
			return
	sim.step()
	assert_true(e.is_populated(1, index), "refilled RESPAWN_SECONDS after it was cleared")
	assert_gt(e.monsters_in(1, index).size(), 0, "with new monsters")


# --- R11 -----------------------------------------------------------------------


func test_r11_wipe_falls_back_and_keeps_progress() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	e.last_stable_depth = 2
	var index: int = _populated(sim, 3)
	_approach(sim, 3, index)
	sim.party.gold = 77
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(40)
		hero.health = 1
	sim.party.hero(4).health = 0  # no healer to save them
	sim.step()
	var fight: Battle = e.battle
	assert_not_null(fight)
	if fight == null:
		return
	_run_until(sim, SimEvent.Kind.PARTY_WIPED, 3000)
	var wiped_at: int = sim.tick
	var gold: int = sim.party.gold
	var progress: Array = []
	for hero: Hero in sim.party.heroes:
		progress.append([hero.level, hero.xp])
	var survivors: Array[int] = []
	for m: Combatant in fight.monsters:
		if m.is_alive():
			survivors.append(m.id)
	assert_eq(e.state, Expedition.State.REVIVING)
	assert_null(e.battle)

	_run(sim, _ticks(Expedition.REVIVE_SECONDS) - 1)
	assert_eq(e.state, Expedition.State.REVIVING, "still down before the delay")
	sim.step()
	var revived: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.PARTY_REVIVED)
	assert_eq(sim.tick - wiped_at, _ticks(Expedition.REVIVE_SECONDS), "revived after the delay")
	assert_eq(_amounts(revived, SimEvent.Kind.PARTY_REVIVED), [2], "revived on depth 2")
	assert_eq(e.depth, 2, "back on the last stable depth")
	assert_eq(e.target_depth, 2, "which is the new target")
	var landing: int = sim.labyrinth.shaft_column(1)
	assert_almost_eq(e.x, landing + Labyrinth.SHAFT_WIDTH / 2.0, EPSILON, "the shaft's middle")
	assert_eq(e.chamber(), _level(sim, 2).chamber_at(landing), "in the landing chamber")
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.health, hero.max_health(), "full health")
	assert_eq(sim.party.gold, gold, "gold kept")
	assert_gte(gold, 77)
	for i: int in sim.party.heroes.size():
		var hero: Hero = sim.party.heroes[i]
		var kept: Array = progress[i]
		assert_eq([hero.level, hero.xp], kept, "levels and XP kept")
		assert_gte(hero.xp, 40)

	var waiting: Array[Combatant] = e.monsters_in(3, index)
	assert_eq(_ids(waiting), survivors, "the chamber keeps its survivors")
	for m: Combatant in waiting:
		assert_eq(m.health, m.max_health, "healed to full")


# --- R12 -----------------------------------------------------------------------


## Puts a fresh party on depth 2 at the landing, with auto-push off.
func _on_depth_two(stable: float) -> Simulation:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	sim.expedition.stable_seconds = stable
	sim.expedition.depth = 2
	sim.expedition.target_depth = 2
	sim.expedition.x = sim.labyrinth.shaft_column(1)
	return sim


func test_r12_last_stable_depth() -> void:
	var sim := _on_depth_two(30.0)
	var e: Expedition = sim.expedition
	assert_eq(e.last_stable_depth, 1, "starts at 1")
	var events: Array[SimEvent] = _run(sim, _ticks(30) - 1)
	assert_eq(e.last_stable_depth, 1, "not yet")
	assert_eq(_of_kind(events, SimEvent.Kind.STABLE_DEPTH_REACHED).size(), 0)
	events = _run(sim, 1)
	assert_eq(e.last_stable_depth, 2, "stable after stable_seconds")
	assert_eq(_amounts(events, SimEvent.Kind.STABLE_DEPTH_REACHED), [2], "reported once")

	# Leaving the depth restarts the count.
	var leaver := _on_depth_two(60.0)
	_run(leaver, _ticks(20))
	leaver.set_target_depth(1)
	_run_until(leaver, SimEvent.Kind.DEPTH_CHANGED, _ticks(40))
	leaver.set_target_depth(2)
	_run_until(leaver, SimEvent.Kind.DEPTH_CHANGED, _ticks(300))
	var arrived: int = leaver.tick
	_run_until(leaver, SimEvent.Kind.STABLE_DEPTH_REACHED, _ticks(120))
	assert_eq(leaver.tick - arrived, _ticks(60), "the count started again on return")

	# A wipe restarts the count.
	var wiped := _on_depth_two(60.0)
	_run(wiped, _ticks(40))
	_force_wipe(wiped)
	_run_until(wiped, SimEvent.Kind.PARTY_REVIVED, _ticks(30))
	assert_eq(wiped.expedition.depth, 1, "fell back to depth 1")
	assert_eq(wiped.expedition.last_stable_depth, 1, "depth 2 never became stable")
	wiped.set_target_depth(2)
	_run_until(wiped, SimEvent.Kind.DEPTH_CHANGED, _ticks(600))
	var back: int = wiped.tick
	_run_until(wiped, SimEvent.Kind.STABLE_DEPTH_REACHED, _ticks(120))
	assert_eq(wiped.tick - back, _ticks(60), "the time before the wipe did not count")

	# It never moves shallower.
	var deep := Simulation.new(SEED)
	deep.expedition.last_stable_depth = 3
	deep.expedition.stable_seconds = 10.0
	deep.set_auto_push(false)
	var none: Array[SimEvent] = _run(deep, _ticks(60))
	assert_eq(deep.expedition.last_stable_depth, 3)
	assert_eq(_of_kind(none, SimEvent.Kind.STABLE_DEPTH_REACHED).size(), 0)


# --- R13 -----------------------------------------------------------------------


func test_r13_auto_push_and_commands() -> void:
	var sim := Simulation.new(SEED)
	assert_true(sim.expedition.auto_push, "auto-push is on by default")
	sim.expedition.stable_seconds = 30.0
	_run(sim, _ticks(30) - 1)
	assert_eq(sim.expedition.target_depth, 1, "not yet")
	var events: Array[SimEvent] = _run(sim, 1)
	assert_eq(sim.expedition.target_depth, 2, "pushed after stable_seconds at the target")
	assert_eq(_amounts(events, SimEvent.Kind.TARGET_DEPTH_CHANGED), [2], "reported once")

	var held := Simulation.new(SEED)
	held.expedition.stable_seconds = 30.0
	held.set_auto_push(false)
	assert_false(held.expedition.auto_push)
	var quiet: Array[SimEvent] = _run(held, _ticks(90))
	assert_eq(held.expedition.target_depth, 1, "no push with auto-push off")
	assert_eq(_of_kind(quiet, SimEvent.Kind.TARGET_DEPTH_CHANGED).size(), 0)

	held.set_target_depth(4)
	assert_eq(held.expedition.target_depth, 1, "a command waits for the next tick")
	held.step()
	assert_eq(held.expedition.target_depth, 4, "and applies on it")
	var told: Array[SimEvent] = held.drain_events()
	assert_eq(_amounts(told, SimEvent.Kind.TARGET_DEPTH_CHANGED), [4], "reported once")
	assert_eq(told[-1].tick, held.tick, "on the tick it applied")
	held.set_target_depth(0)
	held.step()
	assert_eq(held.expedition.target_depth, 1, "the target never goes above depth 1")

	# A wipe restarts the count toward the next push.
	var fallen := Simulation.new(SEED)
	fallen.expedition.stable_seconds = 30.0
	_run(fallen, _ticks(20))
	_force_wipe(fallen)
	_run_until(fallen, SimEvent.Kind.PARTY_REVIVED, _ticks(30))
	assert_eq(fallen.expedition.depth, 1, "revived on the target depth")
	var revived_at: int = fallen.tick
	_run_until(fallen, SimEvent.Kind.TARGET_DEPTH_CHANGED, _ticks(60))
	assert_eq(fallen.tick - revived_at, _ticks(30), "a full stable_seconds after the revival")


# --- R14 -----------------------------------------------------------------------


func test_r14_events_cover_the_loop() -> void:
	var sim := Simulation.new(SEED)
	var index: int = _populated(sim, 1)
	_approach(sim, 1, index)
	sim.party.hero(1).health = 20  # hurt enough to rest afterwards
	var events: Array[SimEvent] = []
	var fight: Battle = null
	for i: int in 3000:
		sim.step()
		if fight == null:
			fight = sim.expedition.battle
		var fresh: Array[SimEvent] = sim.drain_events()
		for e: SimEvent in fresh:
			assert_eq(e.tick, sim.tick, "stamped with the simulation tick")
		events.append_array(fresh)
		if not _of_kind(fresh, SimEvent.Kind.REST_ENDED).is_empty():
			break
	assert_eq(sim.drain_events().size(), 0, "drained once")
	assert_not_null(fight)
	if fight == null:
		return

	assert_eq(events[0].kind, SimEvent.Kind.ENCOUNTER_STARTED, "the encounter comes first")
	assert_eq(events[0].amount, index)
	for kind: SimEvent.Kind in [SimEvent.Kind.ATTACK_STARTED, SimEvent.Kind.HIT]:
		assert_gt(_of_kind(events, kind).size(), 0, "battle events passed on")
	var deaths: Array[int] = []
	for e: SimEvent in _of_kind(events, SimEvent.Kind.DIED):
		if e.source_id >= Expedition.FIRST_MONSTER_ID:
			deaths.append(e.source_id)
	assert_eq(deaths.size(), fight.monsters.size(), "every monster died")
	var gold_from: Array[int] = []
	for e: SimEvent in _of_kind(events, SimEvent.Kind.GOLD_GAINED):
		gold_from.append(e.source_id)
	assert_eq(gold_from, deaths, "gold names each dead monster, in order")
	var xp_events: Array[SimEvent] = _of_kind(events, SimEvent.Kind.XP_GAINED)
	assert_gt(xp_events.size(), 0)
	for e: SimEvent in xp_events:
		assert_between(e.target_id, 1, 4, "XP names a hero")
	assert_eq(_amounts(events, SimEvent.Kind.ENCOUNTER_ENDED), [index], "ended once")
	assert_true(_of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)[0].flag, "the heroes won")
	var loop: Array[SimEvent.Kind] = [
		SimEvent.Kind.ENCOUNTER_STARTED,
		SimEvent.Kind.ENCOUNTER_ENDED,
		SimEvent.Kind.REST_STARTED,
		SimEvent.Kind.REST_ENDED,
	]
	var order: Array[SimEvent.Kind] = []
	for e: SimEvent in events:
		if e.kind in loop:
			order.append(e.kind)
	assert_eq(order, loop, "encounter, then rest")

	# The target and the depth changing are reported too.
	sim.set_target_depth(2)
	sim.step()
	var target: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.TARGET_DEPTH_CHANGED)
	assert_eq(target.size(), 1)
	var down: Array[SimEvent] = _run_until(sim, SimEvent.Kind.DEPTH_CHANGED, 3000)
	assert_eq(_of_kind(down, SimEvent.Kind.DEPTH_CHANGED)[0].amount, 2)


# --- R15 -----------------------------------------------------------------------


func test_r15_ids() -> void:
	var sim := Simulation.new(SEED)
	sim.expedition.stable_seconds = 120.0
	var seen: Dictionary[int, String] = {}
	var lowest: int = 1 << 62
	var fight: Battle = null
	var battles: int = 0
	for i: int in _ticks(1800):
		sim.step()
		sim.drain_events()
		var now: Battle = sim.expedition.battle
		if now == null or now == fight:
			continue
		fight = now
		battles += 1
		assert_eq(_ids(fight.heroes), [1, 2, 3, 4], "hero combatant ids are hero ids")
		for hero: Hero in sim.party.heroes:
			assert_eq(fight.combatant(hero.id).def_id, hero.class_id)
		var where: String = "%d/%d" % [sim.expedition.depth, sim.expedition.chamber().index]
		for m: Combatant in fight.monsters:
			lowest = mini(lowest, m.id)
			var identity: String = "%s %s" % [where, m.def_id]
			# Only a survivor of a wipe, waiting in the same chamber, is met again.
			var known: String = seen.get(m.id, identity)
			assert_eq(known, identity, "monster id %d is not reused" % m.id)
			seen[m.id] = identity
	assert_gt(battles, 20)
	assert_eq(lowest, Expedition.FIRST_MONSTER_ID, "monster ids start at 100")


# --- R16 -----------------------------------------------------------------------


func test_r16_hero_positions() -> void:
	var sim := Simulation.new(SEED)
	var e: Expedition = sim.expedition
	_run(sim, 5)
	var floor_y: float = _level(sim, 1).floor_y
	for rank: int in 4:
		assert_eq(e.hero_position(rank + 1), Vector2(e.x - e.facing * rank, floor_y), "travelling")

	var fighting := Simulation.new(SEED)
	_approach(fighting, 1, _populated(fighting, 1))
	for i: int in 30:
		fighting.step()
		var fight: Battle = fighting.expedition.battle
		if fight == null:
			break
		for hero: Hero in fighting.party.heroes:
			var c: Combatant = fight.combatant(hero.id)
			assert_eq(fighting.expedition.hero_position(hero.id), Vector2(c.x, floor_y), "fighting")

	# Resting: in column on the floor row, exactly floor_y.
	var resting := Simulation.new(SEED)
	_approach(resting, 1, _populated(resting, 1))
	resting.party.hero(4).health = 0
	_run_until(resting, SimEvent.Kind.REST_STARTED, 3000)
	_run(resting, 3)
	var r: Expedition = resting.expedition
	assert_eq(r.state, Expedition.State.RESTING)
	for rank: int in 4:
		var at: Vector2 = r.hero_position(rank + 1)
		assert_eq(at.y, floor_y, "resting on the floor row")
		assert_almost_eq(at.x, r.x - r.facing * rank, EPSILON, "resting in column")

	var climber := Simulation.new(SEED)
	climber.set_auto_push(false)
	climber.set_target_depth(2)
	var shaft: float = climber.labyrinth.shaft_column(1) + Labyrinth.SHAFT_WIDTH / 2.0  # spec 015
	var top: float = _level(climber, 1).floor_y
	var bottom: float = _level(climber, 2).floor_y
	var climbing_ticks: int = 0
	var last_y: float = -INF
	for i: int in _ticks(1800):
		climber.step()
		climber.drain_events()
		if climber.expedition.state != Expedition.State.CLIMBING:
			if climbing_ticks > 0:
				break
			continue
		climbing_ticks += 1
		var lead: Vector2 = climber.expedition.hero_position(1)
		if climbing_ticks == 1:
			assert_eq(lead.y, top, "the climb starts on the floor row above")
		if climbing_ticks > 1:
			var stride: float = Expedition.CLIMB_SPEED / Simulation.TICKS_PER_SECOND
			assert_almost_eq(lead.y - last_y, stride, EPSILON, "moving down at CLIMB_SPEED")
		last_y = lead.y
		for hero: Hero in climber.party.heroes:
			var at: Vector2 = climber.expedition.hero_position(hero.id)
			assert_eq(at.x, shaft, "on the shaft's middle")
			assert_between(at.y, top, bottom, "inside the shaft")
			assert_lte(at.y, lead.y, "the leader goes first")
	assert_gt(climbing_ticks, 30, "the climb took a while")
	assert_eq(climber.expedition.depth, 2)
	for hero: Hero in climber.party.heroes:
		assert_eq(climber.expedition.hero_position(hero.id).y, bottom, "landed on floor_y below")


# --- R17 -----------------------------------------------------------------------


func test_r17_deterministic_and_endless() -> void:
	var a := Simulation.new(SEED)
	var b := Simulation.new(SEED)
	var c := Simulation.new(SEED)
	var mismatches: int = 0
	var diverged: bool = false
	for i: int in 3000:
		if i == 1000:
			a.set_target_depth(3)
			b.set_target_depth(3)
			c.set_target_depth(2)
		a.step()
		b.step()
		c.step()
		if a.state_hash() != b.state_hash():
			mismatches += 1
		if a.state_hash() != c.state_hash():
			diverged = true
	assert_eq(mismatches, 0, "same seed and commands: equal hashes at every tick")
	assert_true(diverged, "a different command gives a different hash")
	assert_eq(_describe_events(a.drain_events()), _describe_events(b.drain_events()))

	# The hash covers the party, the expedition and the battle.
	var one := Simulation.new(SEED)
	var two := Simulation.new(SEED)
	for sim: Simulation in [one, two]:
		_approach(sim, 1, _populated(sim, 1))
		sim.step()
	assert_eq(one.state_hash(), two.state_hash())
	two.expedition.battle.monsters[0].x += 0.5
	assert_ne(one.state_hash(), two.state_hash(), "battle state")
	two.expedition.battle.monsters[0].x -= 0.5
	two.party.gold += 1
	assert_ne(one.state_hash(), two.state_hash(), "party gold")
	two.party.gold -= 1
	two.party.hero(2).health -= 1
	assert_ne(one.state_hash(), two.state_hash(), "hero state")
	two.party.hero(2).health += 1
	two.expedition.last_stable_depth = 4
	assert_ne(one.state_hash(), two.state_hash(), "expedition state")

	# One hour runs without errors from any seed.
	for seed_value: int in [11, 12, 13]:
		var sim := Simulation.new(seed_value)
		for i: int in HOUR_TICKS:
			sim.step()
			sim.drain_events()
		assert_eq(sim.tick, HOUR_TICKS, "seed %d ran an hour" % seed_value)
		assert_gte(sim.expedition.deepest_depth, 1)


func _describe_events(events: Array[SimEvent]) -> Array:
	var described: Array = []
	for e: SimEvent in events:
		described.append([e.kind, e.tick, e.source_id, e.target_id, e.amount, e.flag])
	return described


# --- R18 -----------------------------------------------------------------------


func test_r18_plays_like_the_design() -> void:
	var kinds_seen: Dictionary[SimEvent.Kind, bool] = {}
	for seed_value: int in [1, 2, 3, 4, 5]:
		var sim := Simulation.new(seed_value)
		sim.expedition.stable_seconds = 120.0
		var battles: int = 0
		var wipes: int = 0
		var gold: int = 0
		var progress: Array[Vector2i] = []
		for hero: Hero in sim.party.heroes:
			progress.append(Vector2i(hero.level, hero.xp))
		var backwards: int = 0
		for i: int in HOUR_TICKS:
			sim.step()
			for e: SimEvent in sim.drain_events():
				kinds_seen[e.kind] = true
				if e.kind == SimEvent.Kind.ENCOUNTER_ENDED:
					battles += 1
				elif e.kind == SimEvent.Kind.PARTY_WIPED:
					wipes += 1
			if sim.party.gold < gold:
				backwards += 1
			gold = sim.party.gold
			for rank: int in sim.party.heroes.size():
				var hero: Hero = sim.party.heroes[rank]
				if hero.level < progress[rank].x or hero.xp < progress[rank].y:
					backwards += 1
				progress[rank] = Vector2i(hero.level, hero.xp)
		var where: String = "seed %d" % seed_value
		assert_gte(battles, 30, "at least 30 battles, " + where)
		assert_gt(sim.party.gold, 0, "gains gold, " + where)
		var levelled: bool = false
		for hero: Hero in sim.party.heroes:
			levelled = levelled or hero.level > 1
		assert_true(levelled, "gains levels, " + where)
		assert_gte(sim.expedition.last_stable_depth, 2, "stable on depth 2 or deeper, " + where)
		assert_gte(wipes, 1, "wipes at least once, " + where)
		assert_eq(backwards, 0, "gold, XP and levels never go down, " + where)
	for kind: int in range(SimEvent.Kind.ENCOUNTER_STARTED, SimEvent.Kind.size()):
		assert_true(kinds_seen.has(kind), "%s happened" % SimEvent.Kind.keys()[kind])
