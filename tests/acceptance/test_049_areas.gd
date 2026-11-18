extends GutTest
## Acceptance tests for specs/049-areas/spec.md, one per requirement: the labyrinth is a set of
## areas, each with its own monsters, guardian and stages, and the party can be sent between them.

const AREAS: Array[StringName] = [&"mossy_hollow", &"claypits", &"old_crypt", &"ember_deep"]
## R1's table: name, base level, monsters with their first stage, guardian, opened by.
const TABLE: Dictionary[StringName, Array] = {
	&"mossy_hollow":
	[
		"Mossy Hollow",
		1,
		{&"slime": 1, &"cave_bat": 1, &"spider": 2, &"goblin": 3},
		&"slime_king",
		&"",
	],
	&"claypits":
	[
		"The Claypits",
		6,
		{&"mud_golem": 1, &"clay_hound": 1, &"ogre": 3},
		&"clay_colossus",
		&"mossy_hollow",
	],
	&"old_crypt":
	[
		"The Old Crypt",
		11,
		{&"skeleton": 1, &"ghoul": 1, &"wraith": 3},
		&"bone_lord",
		&"claypits",
	],
	&"ember_deep":
	[
		"Ember Deep",
		16,
		{&"fire_imp": 1, &"crystal_beetle": 1, &"deep_horror": 3},
		&"deep_maw",
		&"old_crypt",
	],
}
## The shallowest depth each Mossy Hollow monster appeared on before this spec (its old
## min_depth), which fixed how strong it was at each depth: R10 checks against these numbers.
const OLD_MIN_DEPTH: Dictionary[StringName, int] = {
	&"slime": 1,
	&"cave_bat": 1,
	&"spider": 3,
	&"goblin": 4,
	&"slime_king": 5,
}
## How much a monster grew per depth below its old min_depth, before this spec.
const OLD_GROWTH: float = 1.12
const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const JOURNEY_TICKS: int = 100
const STRONG_LEVEL: int = 60

# --- Helpers -------------------------------------------------------------------


func _raise(sim: Simulation, level: int) -> void:
	for hero: Hero in sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(level) - hero.xp)
		hero.health = hero.max_health()


## Opens [param area] (as a beaten guardian would), sends the party there at [param stage] and
## steps until it arrives. Returns the events seen.
func _send(sim: Simulation, area: StringName, stage: int) -> Array[SimEvent]:
	sim.expedition.travel.open[area] = true
	sim.set_destination(area, stage)
	var events: Array[SimEvent] = []
	for i: int in JOURNEY_TICKS + 400:
		sim.step()
		var drained: Array[SimEvent] = sim.drain_events()
		events.append_array(drained)
		for event: SimEvent in drained:
			if event.kind == SimEvent.Kind.AREA_CHANGED:
				return events
	fail_test("the party never arrived in %s" % area)
	return events


## Health [param hero] gains in ten seconds of rest (the journey, as amended).
func _rested(hero: Hero) -> int:
	return floori(Expedition.REST_HEAL_PER_SECOND * hero.max_health() * 10.0 + 0.0001)


## Steps [param sim] until [param state] (true) or [param ticks] pass (false); the events go to
## [param seen].
func _until_state(
	sim: Simulation, state: Expedition.State, ticks: int, seen: Array[SimEvent]
) -> bool:
	for i: int in ticks:
		if sim.expedition.state == state:
			return true
		sim.step()
		seen.append_array(sim.drain_events())
	return sim.expedition.state == state


func _kinds(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


## Puts the party on [param depth] just outside its shaft chamber, walking in, no auto-push.
func _before_guardian(sim: Simulation, depth: int) -> void:
	var e: Expedition = sim.expedition
	var shaft: LabyrinthChamber = sim.labyrinth.level(depth).shaft_chamber()
	sim.set_auto_push(false)
	e.depth = depth
	e.target_depth = depth + 1
	if shaft.index > 0:
		e.x = shaft.rect.position.x - 1.0
		e.facing = 1
	else:
		e.x = shaft.rect.end.x
		e.facing = -1


func _run(sim: Simulation, ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## A monster's numbers met at [param level] as the old rule made them at that depth.
func _old_strength(def: MonsterDef, old_min: int, level: int) -> Vector2i:
	var scale: float = pow(OLD_GROWTH, maxi(level - old_min, 0))
	return Vector2i(roundi(def.max_health * scale), roundi(def.damage * scale))


func _rects(labyrinth: Labyrinth, depth: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for chamber: LabyrinthChamber in labyrinth.level(depth).chambers:
		rects.append(chamber.rect)
	rects.append(labyrinth.level(depth).shaft_down)
	return rects


func _has_problem(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.begins_with(field):
			return true
	return false


# --- R1 ------------------------------------------------------------------------


func test_r1_areas_are_content() -> void:
	assert_eq(Content.area_ids(), AREAS, "four areas, in order")
	for id: StringName in AREAS:
		var def: AreaDef = Content.area(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate().size(), 0, "%s is valid: %s" % [id, def.validate()])
		var row: Array = TABLE[id]
		var shown: String = row[0]
		var base_level: int = row[1]
		var guardian: StringName = row[3]
		var opener: StringName = row[4]
		assert_eq(def.display_name, shown, "%s's name" % id)
		assert_eq(def.base_level, base_level, "%s's base level" % id)
		var monsters: Dictionary = row[2]
		assert_eq(def.monsters.size(), monsters.size(), "%s's monsters" % id)
		for i: int in def.monsters.size():
			assert_true(monsters.has(def.monsters[i]), "%s lives in %s" % [def.monsters[i], id])
			if monsters.has(def.monsters[i]):
				var first: int = monsters[def.monsters[i]]
				assert_eq(def.monster_stages[i], first, "%s's stage" % id)
		assert_eq(def.guardian, guardian, "%s's guardian" % id)
		assert_eq(def.guardian_stage, 5, "%s's guardian stands at stage 5" % id)
		assert_eq(def.opened_by, opener, "what opens %s" % id)
	var base: AreaDef = Content.area(&"mossy_hollow")
	var unknown: AreaDef = base.duplicate()
	unknown.monsters = [&"slime", &"cave_bat", &"spider", &"dragon"]
	assert_true(_has_problem(unknown.validate(), "monsters[3]"), "an unknown monster is refused")
	var uneven: AreaDef = base.duplicate()
	uneven.monster_stages = [1, 1]
	assert_true(_has_problem(uneven.validate(), "monsters (4)"), "lists of different length")
	var weak: AreaDef = base.duplicate()
	weak.guardian = &"slime"
	assert_true(_has_problem(weak.validate(), "guardian"), "a guardian that is not a boss")


# --- R2 ------------------------------------------------------------------------


func test_r2_a_stage_is_a_depth() -> void:
	var sim := Simulation.new(7)
	for area: StringName in AREAS:
		if area != &"mossy_hollow":
			_send(sim, area, 1)
		var e: Expedition = sim.expedition
		var def: AreaDef = Content.area(area)
		assert_eq(e.area, area, "in %s" % area)
		for stage: int in range(1, 8):
			var level: int = def.base_level + stage - 1
			assert_eq(e.level_at(stage), level, "%s %d is level %d" % [area, stage, level])
			e.depth = stage
			# Amended by the lead: the timers go by the stage number, not the level.
			assert_almost_eq(
				e.stable_seconds,
				DepthTiming.stable_seconds_at(stage),
				0.001,
				"%s %d's safe timer is depth %d's" % [area, stage, stage]
			)
			var level_map: LabyrinthLevel = sim.labyrinth.level(stage)
			for room: LabyrinthChamber in level_map.chambers:
				var fill: ChamberState = e._record(stage, room.index)
				if not fill.guardian:
					assert_almost_eq(
						DepthTiming.refill_seconds(fill),
						DepthTiming.respawn_seconds_at(stage),
						0.001,
						"%s %d refills as depth %d did" % [area, stage, stage]
					)
				for monster: Combatant in e.monsters_in(stage, room.index):
					var monster_def: MonsterDef = Content.monster(monster.def_id)
					var expected := Combatant.from_monster(monster_def, level, monster.id)
					assert_eq(monster.max_health, expected.max_health, "%s health" % monster.def_id)
					assert_eq(monster.damage, expected.damage, "%s damage" % monster.def_id)
		e.depth = 1
	# A wipe goes back to the area's own safe stage.
	var e2: Expedition = sim.expedition
	e2.last_stable_depth = 2
	e2.deepest_depth = 4
	e2.depth = 4
	for hero: Hero in sim.party.heroes:
		hero.health = 0
	_run(sim, 80)
	assert_eq(e2.area, &"ember_deep", "still in the area after a wipe")
	assert_eq(e2.depth, 2, "back to the area's safe stage")


# --- R3 ------------------------------------------------------------------------


func test_r3_only_the_areas_monsters() -> void:
	for seed_value: int in SEEDS:
		var sim := Simulation.new(seed_value)
		for area: StringName in AREAS:
			if area != &"mossy_hollow":
				_send(sim, area, 1)
			var def: AreaDef = Content.area(area)
			var e: Expedition = sim.expedition
			for stage: int in range(1, 13):
				var guardian_here: bool = stage == 5 or stage == 10
				assert_eq(
					e.guardian_of(stage),
					def.guardian if guardian_here else &"",
					"%s %d's guardian, seed %d" % [area, stage, seed_value]
				)
				for room: LabyrinthChamber in sim.labyrinth.level(stage).chambers:
					for monster: Combatant in e.monsters_in(stage, room.index):
						var where: String = "%s %d, seed %d" % [area, stage, seed_value]
						if monster.def_id == def.guardian:
							assert_true(guardian_here, "the guardian only at 5 and 10, " + where)
							continue
						var at: int = def.monsters.find(monster.def_id)
						assert_true(at >= 0, "%s is %s's, %s" % [monster.def_id, area, where])
						if at >= 0:
							assert_lte(def.monster_stages[at], stage, "not before its stage")
			var shaft5: LabyrinthChamber = sim.labyrinth.level(5).shaft_chamber()
			var shaft10: LabyrinthChamber = sim.labyrinth.level(10).shaft_chamber()
			var at5: Array[Combatant] = e.monsters_in(5, shaft5.index)
			var at10: Array[Combatant] = e.monsters_in(10, shaft10.index)
			assert_eq(at5.size(), 1, "the guardian alone at 5 in %s" % area)
			assert_eq(at10.size(), 1, "the guardian alone at 10 in %s" % area)
			if at5.size() == 1 and at10.size() == 1:
				assert_eq(at5[0].def_id, def.guardian, "%s's guardian at 5" % area)
				assert_eq(at10[0].def_id, def.guardian, "%s's guardian at 10" % area)
				assert_gt(at10[0].max_health, at5[0].max_health, "stronger at 10")


# --- R4 ------------------------------------------------------------------------


func test_r4_sent_elsewhere() -> void:
	# A closed area: nothing happens, and it is judged when the command is given (amended): opening
	# the area afterwards does not send the party.
	var closed := Simulation.new(3)
	closed.set_destination(&"claypits", 1)
	closed.expedition.travel.open[&"claypits"] = true
	for i: int in 300:
		closed.step()
		assert_ne(closed.expedition.state, Expedition.State.JOURNEYING, "never leaves")
	assert_eq(closed.expedition.area, &"mossy_hollow", "a closed area is ignored")
	assert_false(Simulation.new(3).is_area_open(&"claypits"), "the Claypits are closed at first")

	# While travelling: the party leaves on the next tick and spends 10 seconds on the way.
	var sim := Simulation.new(3)
	sim.expedition.travel.open[&"claypits"] = true
	var before: Labyrinth = sim.labyrinth
	sim.party.hero(2).health = 17
	sim.set_destination(&"claypits", 3)
	sim.step()
	var left_on: int = sim.tick
	assert_eq(sim.expedition.state, Expedition.State.JOURNEYING, "on its way at once")
	assert_eq(sim.expedition.area, &"claypits", "heading to the Claypits")
	var arrived_on: int = -1
	for i: int in 200:
		sim.step()
		for event: SimEvent in sim.drain_events():
			if event.kind == SimEvent.Kind.AREA_CHANGED and arrived_on < 0:
				arrived_on = sim.tick
		if arrived_on >= 0:
			break
	assert_eq(arrived_on - left_on, JOURNEY_TICKS, "10 seconds on the way")
	var e: Expedition = sim.expedition
	assert_eq(e.state, Expedition.State.TRAVELLING, "arrived")
	assert_eq(e.depth, 1, "at the area's safe stage, as stage 3 is beyond it")
	assert_eq(e.target_depth, 3, "the stage asked for is the target")
	assert_eq(e.x, Arrival.column(sim.labyrinth, 1), "at the start of the stage")
	assert_ne(sim.labyrinth, before, "in the Claypits' own labyrinth")
	var mage: Hero = sim.party.hero(2)
	var rested: int = mini(mage.max_health(), 17 + _rested(mage))
	assert_eq(mage.health, rested, "healed as ten seconds of rest would (amended)")
	assert_true(sim.party.any_alive(), "alive")

	# Asked for a stage at or above the safe stage: arrives there.
	e.last_stable_depth = 4
	e.deepest_depth = 4
	_send(sim, &"mossy_hollow", 1)
	_send(sim, &"claypits", 2)
	assert_eq(sim.expedition.depth, 2, "at the stage asked for")
	assert_eq(sim.expedition.target_depth, 2, "with it as the target")

	# During a fight: the party finishes it, then leaves.
	var fighter := Simulation.new(5)
	_raise(fighter, STRONG_LEVEL)
	fighter.set_auto_push(false)
	fighter.expedition.travel.open[&"claypits"] = true
	var guard: int = 0
	while fighter.expedition.state != Expedition.State.FIGHTING and guard < 3000:
		fighter.step()
		guard += 1
	assert_eq(fighter.expedition.state, Expedition.State.FIGHTING, "in a fight")
	fighter.set_destination(&"claypits", 1)
	var ended: bool = false
	for i: int in 2000:
		fighter.step()
		for event: SimEvent in fighter.drain_events():
			if event.kind == SimEvent.Kind.ENCOUNTER_ENDED:
				ended = true
		if fighter.expedition.state == Expedition.State.JOURNEYING:
			break
		if fighter.expedition.battle != null:
			assert_eq(fighter.expedition.state, Expedition.State.FIGHTING, "fights on")
	assert_true(ended, "the fight ran to its end before the party left")
	assert_eq(fighter.expedition.state, Expedition.State.JOURNEYING, "then it left")


func test_r4_on_the_way() -> void:
	# A hero down when the party leaves stands up on the way; a new destination turns the party
	# and restarts the ten seconds; a target chosen on the way is the target on arrival.
	var sim := Simulation.new(3)
	sim.expedition.travel.open[&"claypits"] = true
	sim.expedition.travel.open[&"old_crypt"] = true
	var knight: Hero = sim.party.hero(1)
	knight.health = 0
	sim.set_destination(&"claypits", 1)
	sim.step()
	assert_eq(sim.expedition.state, Expedition.State.JOURNEYING, "on its way")
	for i: int in 40:
		sim.step()
	sim.set_destination(&"old_crypt", 2)
	sim.step()
	var turned_on: int = sim.tick
	assert_eq(sim.expedition.area, &"old_crypt", "turned to the Old Crypt")
	assert_eq(sim.expedition.state, Expedition.State.JOURNEYING, "still on its way")
	sim.set_target_depth(4)
	var seen: Array[SimEvent] = []
	var arrived_on: int = -1
	for i: int in 300:
		sim.step()
		for event: SimEvent in sim.drain_events():
			seen.append(event)
			if event.kind == SimEvent.Kind.AREA_CHANGED and arrived_on < 0:
				arrived_on = sim.tick
		if arrived_on >= 0:
			break
	assert_eq(arrived_on - turned_on, JOURNEY_TICKS, "ten seconds from the turn")
	assert_eq(_kinds(seen, SimEvent.Kind.AREA_CHANGED).size(), 1, "one arrival")
	var e: Expedition = sim.expedition
	assert_eq(e.place, &"old_crypt", "in the Old Crypt")
	assert_eq(e.depth, 1, "at its safe stage")
	assert_eq(e.target_depth, 4, "the target chosen on the way")
	assert_true(knight.is_alive(), "the fallen knight stood up on the way")
	assert_eq(knight.health, mini(knight.max_health(), _rested(knight)), "ten seconds' rest, once")


func test_r4_leaves_rest_work_and_revival() -> void:
	# Resting: the rest ends with REST_ENDED when the party leaves.
	var rester := Simulation.new(5)
	rester.expedition.travel.open[&"claypits"] = true
	var seen: Array[SimEvent] = []
	for hero: Hero in rester.party.heroes:
		hero.health = 1
	rester.expedition._start_rest()
	rester.step()
	rester.drain_events()
	assert_eq(rester.expedition.state, Expedition.State.RESTING, "setup: the party rests")
	rester.set_destination(&"claypits", 1)
	rester.step()
	seen.append_array(rester.drain_events())
	assert_eq(rester.expedition.state, Expedition.State.JOURNEYING, "it leaves the rest")
	assert_eq(_kinds(seen, SimEvent.Kind.REST_ENDED).size(), 1, "and the rest ends")

	# Working a side quest: the party finishes it (SIDE_QUEST_DONE), then leaves.
	var worker: Simulation = null
	for seed_value: int in range(1, 40):
		var candidate := Simulation.new(seed_value)
		_raise(candidate, STRONG_LEVEL)
		candidate.set_auto_push(false)
		var none: Array[SimEvent] = []
		if _until_state(candidate, Expedition.State.WORKING, 3000, none):
			worker = candidate
			break
	assert_not_null(worker, "setup: some seed's party works a side quest")
	if worker == null:
		return
	worker.drain_events()
	worker.expedition.travel.open[&"claypits"] = true
	worker.set_destination(&"claypits", 1)
	var done: Array[SimEvent] = []
	assert_true(_until_state(worker, Expedition.State.JOURNEYING, 600, done), "then it leaves")
	assert_eq(_kinds(done, SimEvent.Kind.SIDE_QUEST_DONE).size(), 1, "after the work is done")

	# Down after a wipe: the party stands up first, then leaves.
	var beaten := Simulation.new(5)
	beaten.expedition.travel.open[&"claypits"] = true
	for hero: Hero in beaten.party.heroes:
		hero.health = 0
	beaten.step()
	assert_eq(beaten.expedition.state, Expedition.State.REVIVING, "setup: down")
	beaten.set_destination(&"claypits", 1)
	var waited: Array[SimEvent] = []
	assert_true(_until_state(beaten, Expedition.State.JOURNEYING, 200, waited), "it leaves")
	assert_eq(_kinds(waited, SimEvent.Kind.PARTY_REVIVED).size(), 1, "once it has stood up")


# --- R5 ------------------------------------------------------------------------


func test_r5_each_area_remembers() -> void:
	var sim := Simulation.new(11)
	var e: Expedition = sim.expedition
	e.last_stable_depth = 3
	e.deepest_depth = 4
	e.depth = 3
	assert_eq(sim.area_progress(&"mossy_hollow"), Vector2i(3, 4), "Mossy Hollow's progress")
	assert_eq(sim.area_progress(&"claypits"), Vector2i(1, 0), "never been to the Claypits")
	_send(sim, &"claypits", 1)
	assert_eq(sim.area_progress(&"mossy_hollow"), Vector2i(3, 4), "kept while away")
	assert_eq(e.last_stable_depth, 1, "the Claypits start from their own stages")
	e.last_stable_depth = 2
	e.deepest_depth = 2
	_send(sim, &"mossy_hollow", 9)
	assert_eq(e.area, &"mossy_hollow", "back in Mossy Hollow")
	assert_eq(e.depth, 3, "starting from its safe stage, not stage 1")
	assert_eq(e.last_stable_depth, 3, "its safe stage")
	assert_eq(e.deepest_depth, 4, "its furthest stage")
	assert_eq(e.target_depth, 9, "heading for the stage asked for")
	assert_eq(sim.area_progress(&"claypits"), Vector2i(2, 2), "the Claypits' progress kept")


# --- R6 ------------------------------------------------------------------------


func test_r6_guardians_open_areas() -> void:
	var sim := Simulation.new(2)
	_raise(sim, STRONG_LEVEL)
	assert_false(sim.is_area_open(&"claypits"), "closed before")
	assert_true(sim.is_area_open(&"mossy_hollow"), "the first area is open")
	_before_guardian(sim, 5)
	var events: Array[SimEvent] = _run(sim, 3000)
	var slain: Array[SimEvent] = _kinds(events, SimEvent.Kind.GUARDIAN_SLAIN)
	assert_eq(slain.size(), 1, "the Slime King is beaten")
	var opened: Array[SimEvent] = _kinds(events, SimEvent.Kind.AREA_OPENED)
	assert_eq(opened.size(), 1, "one event says an area opened")
	if opened.size() == 1:
		assert_eq(opened[0].amount, Content.area_ids().find(&"claypits"), "the Claypits")
	assert_true(sim.is_area_open(&"claypits"), "open after")
	assert_false(sim.is_area_open(&"old_crypt"), "the Old Crypt is still closed")
	# Beaten again (a new visit refills the chamber): no second event.
	_send(sim, &"claypits", 1)
	_send(sim, &"mossy_hollow", 5)
	_raise(sim, STRONG_LEVEL)
	_before_guardian(sim, 5)
	var again: Array[SimEvent] = _run(sim, 3000)
	assert_eq(_kinds(again, SimEvent.Kind.GUARDIAN_SLAIN).size(), 1, "beaten again")
	assert_eq(_kinds(again, SimEvent.Kind.AREA_OPENED).size(), 0, "no second event")
	# A later loss changes nothing.
	var waited: int = 0
	while sim.expedition.state == Expedition.State.FIGHTING and waited < 2000:
		sim.step()
		waited += 1
	for hero: Hero in sim.party.heroes:
		hero.health = 0
	var lost: Array[SimEvent] = _run(sim, 100)
	assert_eq(_kinds(lost, SimEvent.Kind.PARTY_WIPED).size(), 1, "the party is wiped")
	assert_true(sim.is_area_open(&"claypits"), "still open after a loss")


# --- R7 ------------------------------------------------------------------------


func test_r7_its_own_place() -> void:
	for seed_value: int in SEEDS:
		var sim := Simulation.new(seed_value)
		var again := Simulation.new(seed_value)
		var layouts: Dictionary[StringName, Array] = {}
		for area: StringName in AREAS:
			var mine: Labyrinth = sim.expedition.travel.labyrinth(area)
			var theirs: Labyrinth = again.expedition.travel.labyrinth(area)
			var layout: Array = []
			for depth: int in range(1, 4):
				assert_eq(
					_rects(mine, depth),
					_rects(theirs, depth),
					"%s %d repeats for seed %d" % [area, depth, seed_value]
				)
				layout.append(_rects(mine, depth))
			layouts[area] = layout
		for i: int in AREAS.size():
			for j: int in range(i + 1, AREAS.size()):
				assert_ne(
					layouts[AREAS[i]],
					layouts[AREAS[j]],
					"%s and %s differ, seed %d" % [AREAS[i], AREAS[j], seed_value]
				)
	# The labyrinth the party walks in is its area's.
	var walker := Simulation.new(4)
	_send(walker, &"old_crypt", 1)
	assert_eq(
		_rects(walker.labyrinth, 1), _rects(Labyrinth.new(4, "area/old_crypt/"), 1), "its own"
	)


# --- R8 ------------------------------------------------------------------------


func test_r8_saves() -> void:
	var sim := Simulation.new(21)
	sim.expedition.last_stable_depth = 4
	sim.expedition.deepest_depth = 6
	_send(sim, &"claypits", 2)
	sim.expedition.last_stable_depth = 2
	sim.expedition.deepest_depth = 3
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	var area_saved: String = data["area"]
	assert_eq(version, 8, "version 8 since spec 052 (6 when spec 049 landed)")
	assert_eq(area_saved, "claypits", "the area the party is in")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var back: Simulation = Simulation.from_save(parsed)
	assert_not_null(back, "loads: %s" % Simulation.save_problems(data))
	if back == null:
		return
	assert_eq(back.expedition.area, &"claypits", "in the Claypits")
	assert_eq(back.area_progress(&"claypits"), Vector2i(2, 3), "the Claypits' stages")
	assert_eq(back.area_progress(&"mossy_hollow"), Vector2i(4, 6), "Mossy Hollow's stages")
	assert_true(back.is_area_open(&"claypits"), "the Claypits open")
	assert_false(back.is_area_open(&"old_crypt"), "the Old Crypt closed")
	assert_eq(back.expedition.depth, 2, "standing at the Claypits' safe stage")
	assert_eq(back.labyrinth.level(1).chambers.size(), sim.labyrinth.level(1).chambers.size())
	assert_eq(back.to_save(), data, "the same save again")

	# A save made on the way loads in the destination, with the target it will have there.
	var going := Simulation.new(21)
	going.expedition.travel.open[&"claypits"] = true
	going.set_destination(&"claypits", 3)
	for i: int in 20:
		going.step()
	going.set_target_depth(2)
	going.step()
	assert_eq(going.expedition.state, Expedition.State.JOURNEYING, "setup: on its way")
	var on_way: Dictionary = JSON.parse_string(JSON.stringify(going.to_save()))
	assert_eq(Simulation.save_problems(on_way), PackedStringArray(), "a good save")
	var landed: Simulation = Simulation.from_save(on_way)
	assert_not_null(landed, "it loads")
	if landed != null:
		assert_eq(landed.expedition.place, &"claypits", "in the Claypits")
		assert_eq(landed.expedition.depth, 1, "at its safe stage")
		assert_eq(landed.expedition.target_depth, 2, "the target chosen on the way")
		assert_eq(landed.area_progress(&"mossy_hollow").y, 1, "Mossy Hollow kept as it was")
		assert_eq(landed.labyrinth, landed.expedition.travel.labyrinth(&"claypits"))

	# Version 5 saves.
	var opened_by_depth: Dictionary[int, Array] = {
		3: [&"mossy_hollow"],
		7: [&"mossy_hollow", &"claypits"],
		16: [&"mossy_hollow", &"claypits", &"old_crypt", &"ember_deep"],
	}
	for furthest: int in opened_by_depth:
		var old: Dictionary = Simulation.new(5).to_save()
		for key: String in ["area", "areas", "open_areas"]:
			old.erase(key)
		old["version"] = 5
		old["last_stable_depth"] = furthest - 1
		old["deepest_depth"] = furthest
		old["target_depth"] = furthest
		var loaded: Simulation = Simulation.from_save(old)
		assert_not_null(loaded, "a version 5 save at %d loads" % furthest)
		if loaded == null:
			continue
		assert_eq(loaded.expedition.area, &"mossy_hollow", "in Mossy Hollow")
		assert_eq(
			loaded.area_progress(&"mossy_hollow"), Vector2i(furthest - 1, furthest), "its depths"
		)
		for area: StringName in AREAS:
			assert_eq(
				loaded.is_area_open(area),
				(opened_by_depth[furthest] as Array).has(area),
				"%s open at furthest depth %d" % [area, furthest]
			)

	# Bad values, refused by name.
	var cases: Array = [
		["area", "nowhere"],
		["area", 3],
		["open_areas", "claypits"],
		["areas", []],
	]
	for case: Array in cases:
		var field: String = case[0]
		var bad: Dictionary = data.duplicate(true)
		bad[field] = case[1]
		assert_true(_has_problem(Simulation.save_problems(bad), field), "%s = %s" % case)
	var closed: Dictionary = data.duplicate(true)
	closed["open_areas"] = ["mossy_hollow"]
	assert_true(_has_problem(Simulation.save_problems(closed), "area:"), "the area is not open")
	var unknown_open: Dictionary = data.duplicate(true)
	unknown_open["open_areas"] = ["mossy_hollow", "claypits", "atlantis"]
	assert_true(_has_problem(Simulation.save_problems(unknown_open), "open_areas[2]"), "unknown")
	var low: Dictionary = data.duplicate(true)
	low["areas"]["mossy_hollow"]["safe"] = 0
	assert_true(_has_problem(Simulation.save_problems(low), "areas.mossy_hollow.safe"), "safe 0")
	var past: Dictionary = data.duplicate(true)
	past["areas"]["mossy_hollow"]["safe"] = 9
	assert_true(_has_problem(Simulation.save_problems(past), "areas.mossy_hollow.safe"), "beyond")
	var stranger: Dictionary = data.duplicate(true)
	stranger["areas"]["atlantis"] = {"safe": 1, "furthest": 1}
	assert_true(_has_problem(Simulation.save_problems(stranger), "areas.atlantis"), "unknown area")


# --- R9 ------------------------------------------------------------------------


func test_r9_screen_names_the_area() -> void:
	# A new party, level 1, sent to the Claypits: on its way, then there, then beaten there.
	var sim := Simulation.new(SEEDS[0])
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.setup(world, sim)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(sim, world, fx)
	var frame: Callable = func() -> void:
		sim.step()
		world.sync(0.1)
		hud.advance(0.1)
	for i: int in 20:
		frame.call()

	# In Mossy Hollow.
	var mossy: Labyrinth = sim.labyrinth
	assert_eq(hud.place_panel.area_button.text, "Mossy Hollow", "the depth panel names the area")
	assert_eq(hud.ladder.hover_text(2).get_slice("\n", 0).get_slice(":", 0), "Mossy Hollow 2")
	assert_eq(world.labyrinth_view.labyrinth, mossy, "the world shows Mossy Hollow")
	assert_false(hud.status_text().contains("depth"), "no depths: %s" % hud.status_text())
	assert_true(
		"\n".join(hud.goals.lines()).contains("Mossy Hollow"),
		"a goal names the place: %s" % [hud.goals.lines()]
	)

	# On the way.
	sim.expedition.travel.open[&"claypits"] = true
	sim.set_destination(&"claypits", 3)
	var journeying: bool = false
	for i: int in 400:
		frame.call()
		if sim.expedition.state == Expedition.State.JOURNEYING:
			journeying = true
			break
	assert_true(journeying, "the party set off")
	assert_eq(hud.status_text(), "On the way to The Claypits 1", "the status says where to")

	# There.
	for i: int in JOURNEY_TICKS + 10:
		frame.call()
	assert_eq(sim.expedition.place, &"claypits", "arrived")
	assert_ne(sim.labyrinth, mossy, "another labyrinth")
	assert_eq(world.labyrinth_view.labyrinth, sim.labyrinth, "the world redrew the Claypits")
	assert_eq(hud.place_panel.area_button.text, "The Claypits")
	assert_eq(hud.ladder.hover_text(1).get_slice("\n", 0).get_slice(":", 0), "The Claypits 1")
	# Scrolled away from the party, the ladder's arrow points back up to it, and the heading still
	# names the area: the arrow finds another place than over it.
	var deepest_was: int = sim.expedition.deepest_depth
	sim.expedition.deepest_depth = 20
	hud.ladder.scroll_by(6)
	for i: int in 60:
		hud.advance(1.0 / 60.0)
	assert_true(hud.ladder.arrow_points_up(), "setup: the arrow points up to the party")
	var caption: Label = hud.ladder.get_node("Caption")
	assert_true(caption.visible, "the heading shows")
	assert_eq(caption.text, "The Claypits", "and names the area")
	var heading := Rect2(caption.position, Vector2(PixelText.width(caption.text), 8))
	var arrow: Rect2 = hud.ladder.arrow_rect()
	assert_false(arrow.intersects(heading), "the arrow %s clear of it %s" % [arrow, heading])
	assert_true(Rect2(Vector2.ZERO, hud.ladder.size).encloses(arrow), "on the ladder")
	hud.ladder.follow()
	sim.expedition.deepest_depth = deepest_was
	assert_true(
		"\n".join(hud.journal.lines()).contains("Arrived in The Claypits"),
		"the journal says so: %s" % [hud.journal.lines()]
	)
	assert_true(
		"\n".join(hud.goals.lines()).contains("The Claypits"),
		"the goals name the new area: %s" % [hud.goals.lines()]
	)

	# Beaten there: level-1 heroes against level-6 monsters.
	var beaten: bool = false
	for i: int in 6000:
		frame.call()
		if hud.defeat_note.is_shown():
			beaten = true
			break
	assert_true(beaten, "the party lost in the Claypits")
	var note: String = "\n".join(hud.defeat_note.lines())
	assert_true(note.contains("The Claypits"), "the defeat note names the area: %s" % note)
	assert_false(note.contains("depth"), "and no depth: %s" % note)
	var told: bool = false
	for line: String in hud.journal.lines():
		told = told or (line.contains("Beaten") and line.contains("The Claypits"))
	assert_true(told, "the journal names where: %s" % [hud.journal.lines()])

	# The away report.
	var report := AwayReport.new()
	report.area_before = &"mossy_hollow"
	report.depth_before = 3
	report.area_after = &"mossy_hollow"
	report.depth_after = 5
	assert_eq(AwayStory.where(report), "Mossy Hollow 3 to 5")
	report.area_after = &"claypits"
	report.depth_after = 1
	assert_eq(AwayStory.where(report), "Mossy Hollow 3 to The Claypits 1")
	report.area_before = &"claypits"
	report.depth_before = 1
	assert_eq(AwayStory.where(report), "The Claypits 1")


## A world, its effects and the HUD on [param sim], every _process off: index 0 the World, 1 the
## CombatEffects, 2 the Hud.
func _view(sim: Simulation) -> Array[Node]:
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var fx := CombatEffects.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.setup(world, sim)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(sim, world, fx)
	# Spec 059: the tally is a window on the UI layer, so the HUD needs one for it to open.
	var ui := UiRoot.new()
	add_child_autofree(ui)
	ui.setup(sim, hud, null)
	ui.bar.set_process(false)
	return [world, fx, hud]


## The z's floating over resting heroes.
func _zs(fx: CombatEffects) -> int:
	var count: int = 0
	for text: FxText in fx._texts:
		if text.kind == &"z":
			count += 1
	return count


func test_r9_no_rest_on_the_road() -> void:
	# A party resting when it is sent away stops resting: no z's over it on the road or after.
	var sim := Simulation.new(SEEDS[0])
	var view: Array[Node] = _view(sim)
	var world: World = view[0]
	var fx: CombatEffects = view[1]
	for hero: Hero in sim.party.heroes:
		hero.health = 1
	sim.expedition._start_rest()
	for i: int in 20:
		sim.step()
		world.sync(0.1)
		fx.advance(0.1)
	assert_gt(_zs(fx), 0, "setup: z's over the resting party")
	sim.expedition.travel.open[&"claypits"] = true
	sim.set_destination(&"claypits", 1)
	for i: int in JOURNEY_TICKS + 30:
		sim.step()
		world.sync(0.1)
		fx.advance(0.1)
	assert_eq(sim.expedition.place, &"claypits", "setup: arrived")
	assert_eq(_zs(fx), 0, "no z's once the party has left its rest")


func test_r9_old_deaths_spare_new_monsters() -> void:
	# Monster ids name the stage and chamber, not the area: the first fight's monsters in Mossy
	# Hollow 1 share ids with the Claypits 1 monsters waiting in the same chamber. Their deaths,
	# heard in the frame that also holds the arrival, must not take those monsters off the screen.
	var sim := Simulation.new(SEEDS[0])
	var view: Array[Node] = _view(sim)
	var world: World = view[0]
	_raise(sim, STRONG_LEVEL)
	sim.expedition.travel.open[&"claypits"] = true
	world.sync(0.1)
	var guard: int = 0
	while sim.expedition.state != Expedition.State.FIGHTING and guard < 600:
		sim.step()
		guard += 1
	assert_eq(sim.expedition.state, Expedition.State.FIGHTING, "setup: the first fight")
	var fought: Array[int] = []
	for monster: Combatant in sim.expedition.battle.monsters:
		fought.append(monster.id)
	sim.set_destination(&"claypits", 1)
	guard = 0
	while sim.expedition.place != &"claypits" and guard < 2000:
		sim.step()
		guard += 1
	assert_eq(sim.expedition.place, &"claypits", "setup: arrived, with no frame between")
	world.sync(0.1)
	var shared: int = 0
	for depth: int in world.labyrinth_view.built_depths():
		for index: int in sim.labyrinth.level(depth).chambers.size():
			if not sim.expedition.is_populated(depth, index):
				continue
			for monster: Combatant in sim.expedition.monsters_in(depth, index):
				if fought.has(monster.id):
					shared += 1
				assert_not_null(world.character(monster.id), "%s drawn" % monster.def_id)
	assert_gt(shared, 0, "setup: a waiting monster shares an id with one that died")


func test_r9_one_frame_holds_the_journey() -> void:
	# The ticks of a fight, the journey and the arrival all stepped before one frame (as at 4x, or
	# after time away): the new area's waiting monsters all have sprites, and the journal and the
	# tally name where the fight was.
	var sim := Simulation.new(SEEDS[0])
	var view: Array[Node] = _view(sim)
	var world: World = view[0]
	var hud: Hud = view[2]
	world.sync(0.1)
	hud.advance(0.1)
	_raise(sim, STRONG_LEVEL)
	_before_guardian(sim, 5)
	world.sync(0.1)
	hud.advance(0.1)
	sim.expedition.travel.open[&"claypits"] = true
	var guard: int = 0
	while sim.expedition.state != Expedition.State.FIGHTING and guard < 600:
		sim.step()
		guard += 1
	assert_eq(sim.expedition.state, Expedition.State.FIGHTING, "setup: the Slime King's fight")
	sim.set_destination(&"claypits", 1)
	guard = 0
	while sim.expedition.place != &"claypits" and guard < 2000:
		sim.step()
		guard += 1
	assert_eq(sim.expedition.place, &"claypits", "setup: arrived, with no frame between")
	world.sync(0.1)
	hud.advance(0.1)

	assert_eq(world.labyrinth_view.labyrinth, sim.labyrinth, "the world shows the Claypits")
	var waiting: int = 0
	for depth: int in world.labyrinth_view.built_depths():
		for index: int in sim.labyrinth.level(depth).chambers.size():
			if not sim.expedition.is_populated(depth, index):
				continue
			for monster: Combatant in sim.expedition.monsters_in(depth, index):
				waiting += 1
				assert_not_null(world.character(monster.id), "%s drawn" % monster.def_id)
	assert_gt(waiting, 0, "setup: monsters wait in the Claypits")
	var slew: String = "Slew the Slime King on Mossy Hollow 5"
	var lines: Array[String] = hud.journal.lines()
	var found: bool = false
	for line: String in lines:
		found = found or line.ends_with(slew)
	assert_true(found, "the journal names where it was: %s" % [lines])
	hud.tally.open()
	hud.advance(0.1)
	var row: String = hud.tally.rows()[0] if not hud.tally.rows().is_empty() else ""
	assert_true(row.contains(", Mossy Hollow 5, "), "and the tally: " + row)


# --- R10 -----------------------------------------------------------------------


func test_r10_same_fights() -> void:
	var def: AreaDef = Content.area(&"mossy_hollow")
	var met: Dictionary[StringName, bool] = {}
	for seed_value: int in SEEDS:
		var sim := Simulation.new(seed_value)
		for stage: int in range(1, 11):
			for room: LabyrinthChamber in sim.labyrinth.level(stage).chambers:
				for monster: Combatant in sim.expedition.monsters_in(stage, room.index):
					var monster_def: MonsterDef = Content.monster(monster.def_id)
					var old: Vector2i = _old_strength(
						monster_def, OLD_MIN_DEPTH[monster.def_id], stage
					)
					var where: String = "%s at %d, seed %d" % [monster.def_id, stage, seed_value]
					assert_eq(
						monster.max_health, old.x, "health as depth %d gave, " % stage + where
					)
					assert_eq(monster.damage, old.y, "damage as depth %d gave, " % stage + where)
					met[monster.def_id] = true
	for id: StringName in def.monsters:
		assert_true(met.has(id), "%s was met" % id)
	assert_true(met.has(def.guardian), "the guardian was met")

	# The same seed and commands, with a journey, give the same run.
	var hashes: Array[int] = []
	for run: int in 2:
		var sim := Simulation.new(9)
		var trail: Array[int] = []
		var arrivals: Array[StringName] = []
		for tick: int in 6000:
			if tick == 1200:
				sim.expedition.travel.open[&"claypits"] = true
				sim.set_destination(&"claypits", 2)
			if tick == 3000:
				sim.set_destination(&"mossy_hollow", 1)
			sim.step()
			for event: SimEvent in sim.drain_events():
				if event.kind == SimEvent.Kind.AREA_CHANGED:
					arrivals.append(Content.area_ids()[event.amount])
			if tick % 600 == 0:
				trail.append(sim.state_hash())
		assert_eq(arrivals, [&"claypits", &"mossy_hollow"] as Array[StringName], "there and back")
		hashes.append(hash(trail))
	assert_eq(hashes[0], hashes[1], "two runs of one seed agree")
