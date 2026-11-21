extends ColonyTest
## Acceptance tests for specs/023-steady-monster-ids/spec.md, one per requirement.
##
## R4 is the existing suite. The others step seeded simulations directly; R5 drives a World as
## the game's frame loop would (a tick every six frames, then sync).

const SEEDS: Array[int] = [1, 2, 3]
const TICKS_PER_MINUTE: int = 60 * Simulation.TICKS_PER_SECOND
const FRAME: float = 1.0 / 60.0
const FRAMES_PER_TICK: int = 6
## Short enough that the party pushes deeper, wipes and comes back within the runs below.
const STABLE_SECONDS: float = 120.0

var _seen_events: Array[SimEvent] = []


func _sim(seed_value: int) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.expedition.stable_seconds = STABLE_SECONDS
	return sim


## The depths the world builds around the party: its level and both neighbours.
func _nearby(sim: Simulation) -> Array[int]:
	var depths: Array[int] = []
	for depth: int in range(sim.expedition.depth - 1, sim.expedition.depth + 2):
		if depth >= 1:
			depths.append(depth)
	return depths


## Asks for the monsters and the side quest of every chamber of the nearby levels, and for the
## work under way, as the world does.
func _watch(sim: Simulation) -> void:
	var e: Expedition = sim.expedition
	for depth: int in _nearby(sim):
		for index: int in sim.labyrinth.level(depth).chambers.size():
			e.side_quest_in(depth, index)
			if e.is_populated(depth, index):
				e.monsters_in(depth, index)
	e.working_quest()
	e.worker_id()
	e.work_progress()


## Every read the expedition offers, many times over, in no particular order.
func _storm(sim: Simulation) -> void:
	var e: Expedition = sim.expedition
	for pass_number: int in 3:
		for depth: int in range(e.depth + 3, -1, -1):
			e.guardian_of(depth)
			var count: int = sim.labyrinth.level(maxi(depth, 1)).chambers.size()
			for index: int in range(-1, count + 1):
				e.is_populated(depth, index)
				e.side_quest_in(depth, index)
				e.monsters_in(depth, index)
				e.monsters_in(depth, index)
		e.chamber()
		e.working_quest()
		e.worker_id()
		e.work_progress()
		for id: int in [1, 2, 3, 4, 999, Expedition.FIRST_MONSTER_ID]:
			e.hero_position(id)
		e.hash_parts()


func _event_parts(events: Array[SimEvent]) -> Array:
	var parts: Array = []
	for event: SimEvent in events:
		parts.append(
			[event.kind, event.tick, event.source_id, event.target_id, event.amount, event.flag]
		)
	return parts


# --- R1 ------------------------------------------------------------------------


func test_r1_reading_changes_nothing() -> void:
	var sim := _sim(SEEDS[0])
	var storms: int = 0
	for minute: int in 10:
		for i: int in TICKS_PER_MINUTE:
			sim.step()
			sim.drain_events()
			# Storm at odd moments too, not only on minute boundaries.
			if i % 211 != 0:
				continue
			var before: int = sim.state_hash()
			_storm(sim)
			assert_eq(sim.state_hash(), before, "reads changed the hash at tick %d" % sim.tick)
			storms += 1
	assert_gt(storms, 20)
	assert_gt(sim.expedition.deepest_depth, 1, "the run went somewhere")


# --- R2 ------------------------------------------------------------------------


func test_r2_watched_equals_unwatched() -> void:
	for seed_value: int in SEEDS:
		var watched := _sim(seed_value)
		var unwatched := _sim(seed_value)
		var mismatches: int = 0
		var events: int = 0
		for tick: int in 30 * TICKS_PER_MINUTE:
			watched.step()
			unwatched.step()
			_watch(watched)
			var seen: Array = _event_parts(watched.drain_events())
			var unseen: Array = _event_parts(unwatched.drain_events())
			events += seen.size()
			if seen != unseen:
				mismatches += 1
			if tick % 100 == 0 and watched.state_hash() != unwatched.state_hash():
				mismatches += 1
		assert_eq(mismatches, 0, "seed %d: watched and unwatched games agree" % seed_value)
		assert_eq(watched.state_hash(), unwatched.state_hash(), "seed %d: same end" % seed_value)
		assert_gt(events, 1000, "seed %d: the games did something" % seed_value)


# --- R3 ------------------------------------------------------------------------


## Every monster id waiting in the nearby levels, by "depth/chamber".
func _ids_by_chamber(sim: Simulation, reverse: bool) -> Dictionary[String, Array]:
	var found: Dictionary[String, Array] = {}
	var depths: Array[int] = _nearby(sim)
	if reverse:
		depths.reverse()
	for depth: int in depths:
		var indices: Array = range(sim.labyrinth.level(depth).chambers.size())
		if reverse:
			indices.reverse()
		for index: int in indices:
			var ids: Array = []
			for monster: Combatant in sim.expedition.monsters_in(depth, index):
				ids.append(monster.id)
			if not ids.is_empty():
				found["%d/%d" % [depth, index]] = ids
	return found


## The pairs of [param found] as [chamber, ids], in chamber order.
func _sorted(found: Dictionary[String, Array]) -> Array:
	var keys: Array = found.keys()
	keys.sort()
	var pairs: Array = []
	for key: String in keys:
		pairs.append([key, found[key]])
	return pairs


func test_r3_ids_come_from_place() -> void:
	var asked := _sim(SEEDS[1])
	var other := _sim(SEEDS[1])
	for minute: int in 12:
		for i: int in TICKS_PER_MINUTE:
			asked.step()
			other.step()
			asked.drain_events()
			other.drain_events()
		# One simulation is asked often and forwards, the other only now and backwards.
		_watch(asked)
		var forward: Dictionary[String, Array] = _ids_by_chamber(asked, false)
		var again: Dictionary[String, Array] = _ids_by_chamber(asked, false)
		var backward: Dictionary[String, Array] = _ids_by_chamber(other, true)
		assert_eq(_sorted(again), _sorted(forward), "asking twice gives the same ids")
		assert_eq(_sorted(backward), _sorted(forward), "the order of asking does not matter")

		var all: Dictionary[int, bool] = {}
		var total: int = 0
		for ids: Array in forward.values():
			for id: int in ids:
				assert_true(id >= Expedition.FIRST_MONSTER_ID, "monster id %d in range" % id)
				all[id] = true
				total += 1
		var battle: Battle = asked.expedition.battle
		if battle != null:
			for monster: Combatant in battle.monsters:
				assert_true(monster.id >= Expedition.FIRST_MONSTER_ID, "fighter in range")
				all[monster.id] = true
				total += 1
			for hero: Combatant in battle.heroes:
				all[hero.id] = true
				total += 1
		for hero: Hero in asked.party.heroes:
			assert_true(hero.id < Expedition.FIRST_MONSTER_ID, "hero ids stay below monsters")
			if battle == null:
				all[hero.id] = true
				total += 1
		assert_eq(all.size(), total, "every id at minute %d is unique" % minute)
		assert_gt(forward.size(), 1, "several chambers hold monsters")


# --- R5 ------------------------------------------------------------------------


func _world(sim: Simulation) -> World:
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.sim_event.connect(func(event: SimEvent) -> void: _seen_events.append(event))
	return world


## Problems with the sprites against the simulation after a sync: a sprite standing for a monster
## that is no longer alive, or (right after a scan) a living monster without a standing sprite.
func _mismatches(sim: Simulation, world: World, scanned: bool) -> Array[String]:
	var problems: Array[String] = []
	var living: Dictionary[int, bool] = {}
	for depth: int in world.labyrinth_view.built_depths():
		for index: int in sim.labyrinth.level(depth).chambers.size():
			for monster: Combatant in sim.expedition.monsters_in(depth, index):
				living[monster.id] = true
				var sprite: CharacterSprite = world.character(monster.id)
				var standing: bool = sprite != null and sprite.visible and not sprite.is_dead()
				if scanned and not standing:
					problems.append("waiting monster %d has no sprite" % monster.id)
	var battle: Battle = sim.expedition.battle
	if battle != null:
		for monster: Combatant in battle.monsters:
			if monster.is_alive():
				living[monster.id] = true
				var sprite: CharacterSprite = world.character(monster.id)
				if sprite == null or sprite.is_dead():
					problems.append("fighting monster %d has no sprite" % monster.id)
	for child: Node in world.get_node("Characters").get_children():
		var sprite: CharacterSprite = child as CharacterSprite
		if sprite == null or sprite.is_dead():
			continue
		var id: int = -1
		for candidate: int in living.keys():
			if world.character(candidate) == sprite:
				id = candidate
		var hero: bool = false
		for h: Hero in sim.party.heroes:
			hero = hero or world.character(h.id) == sprite
		if id < 0 and not hero:
			problems.append("a standing sprite shows no living monster")
	return problems


func _frame_mismatches(sim: Simulation, world: World, frame: int) -> Array[String]:
	if frame % FRAMES_PER_TICK == 0:
		sim.step()
	world.sync(FRAME)
	var scanned: bool = is_equal_approx(world._scan_in, World.SCAN_SECONDS)
	return _mismatches(sim, world, scanned)


func test_r5_world_follows_reused_ids() -> void:
	_seen_events = []
	var sim := _sim(SEEDS[0])
	sim.expedition.auto_push = false
	var world: World = _world(sim)
	var frame: int = 0
	var problems: Array[String] = []

	# Play until the party wins a fight, and remember the chamber and its monsters' ids.
	var cleared: Vector2i = Vector2i(0, -1)
	var old_ids: Array[int] = []
	var fighting: Array[int] = []
	while cleared.y < 0 and frame < 3000 * FRAMES_PER_TICK:
		var battle: Battle = sim.expedition.battle
		if battle != null:
			fighting = []
			for monster: Combatant in battle.monsters:
				fighting.append(monster.id)
		var count: int = _seen_events.size()
		problems.append_array(_frame_mismatches(sim, world, frame))
		frame += 1
		for i: int in range(count, _seen_events.size()):
			var event: SimEvent = _seen_events[i]
			if event.kind == SimEvent.Kind.ENCOUNTER_ENDED and event.flag:
				cleared = Vector2i(sim.expedition.depth, event.amount)
				old_ids = fighting
	assert_gt(cleared.y, -1, "the party won a fight")
	if cleared.y < 0:
		return

	# Make the chamber's next visit reuse the cleared visit's ids, if the scheme ever reuses ids
	# (spec R5): the record is the expedition's own, reached here only to force the case.
	var record: ChamberState = sim.expedition._chambers[cleared]
	record.visit += Expedition.VISIT_SPAN - 1

	# Play on, the party staying on this depth, until the chamber has refilled and been fought again.
	var refilled: bool = false
	var limit: int = frame + 1500 * FRAMES_PER_TICK
	while frame < limit:
		problems.append_array(_frame_mismatches(sim, world, frame))
		frame += 1
		if not refilled and sim.expedition.is_populated(cleared.x, cleared.y):
			var ids: Array[int] = []
			for monster: Combatant in sim.expedition.monsters_in(cleared.x, cleared.y):
				ids.append(monster.id)
			refilled = true
			var shared: int = 0
			for id: int in ids:
				if old_ids.has(id):
					shared += 1
			assert_gt(shared, 0, "the refilled chamber reuses ids of the monsters that died there")
	assert_true(refilled, "the chamber refilled")
	assert_eq(problems, [] as Array[String], "sprites follow the living monsters")
