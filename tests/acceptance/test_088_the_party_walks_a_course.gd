extends ColonyTest
## Spec 088: every level has a course, the line the party walks, and the expedition takes every
## place from it. Today's levels are checked as `Labyrinth` makes them; a course that bends is
## `BentLabyrinth`'s: a room, a ladder down, and a second room walked from right to left.

const SEED: int = 7
const STRONG_LEVEL: int = 40
## Mossy Hollow's guardian holds this stage.
const GUARDIAN_STAGE: int = 5
const HOLD: Expedition.GuardianOrder = Expedition.GuardianOrder.HOLD
const TICKS: int = Simulation.TICKS_PER_SECOND


## A simulation whose party walks a `BentLabyrinth`, auto-push off.
func _bent(exit_room: int, entry_room: int = 0) -> Simulation:
	var sim := Simulation.new(SEED)
	var maze := BentLabyrinth.new(exit_room, entry_room)
	sim.expedition = Expedition.new(maze, sim.party, SimRng.new(SEED).fork("expedition"))
	sim.set_auto_push(false)
	return sim


## The course of the stage [param sim]'s party is on.
func _course(sim: Simulation) -> StageCourse:
	return sim.labyrinth.level(sim.expedition.depth).course


## Puts [param sim]'s party on [param stage] with [param target] as its target, where it stands.
func _on_stage(sim: Simulation, stage: int, target: int) -> void:
	sim.expedition.depth = stage
	sim.expedition.target_depth = target


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


# --- R2 ------------------------------------------------------------------------


## R2: on the levels `Labyrinth` makes, the distance is the world column.
func test_r2_todays_course_is_the_floor_row() -> void:
	var wrong: Array[String] = []
	var checked: int = 0
	for seed_value: int in range(1, 41):
		var maze := Labyrinth.new(seed_value)
		for depth: int in range(1, 13):
			var level: LabyrinthLevel = maze.level(depth)
			var course: StageCourse = level.course
			var where: String = "seed %d depth %d" % [seed_value, depth]
			var first: LabyrinthChamber = level.chambers[0]
			var last: LabyrinthChamber = level.chambers[level.chambers.size() - 1]
			if course.start != first.floor_columns().x or course.end != last.floor_columns().y:
				wrong.append("%s: ends %s to %s" % [where, course.start, course.end])
			var shaft: float = level.shaft_down.position.x + Labyrinth.SHAFT_WIDTH / 2.0
			if course.exit != shaft:
				wrong.append("%s: exit %s, the shaft's middle is %s" % [where, course.exit, shaft])
			var entry: float = maze.shaft_column(maxi(depth - 1, 1)) + Labyrinth.SHAFT_WIDTH / 2.0
			if depth == 1:
				assert_eq(first.kind, LabyrinthChamber.Kind.START, where + ": the START chamber")
				entry = (first.floor_columns().x + first.floor_columns().y) / 2.0
			if course.entry != entry:
				wrong.append("%s: entry %s, not %s" % [where, course.entry, entry])
			for half: int in range(roundi(course.start * 2.0), roundi(course.end * 2.0) + 1):
				var d: float = half / 2.0
				var room: LabyrinthChamber = level.chamber_at(floori(d))
				var index: int = room.index if room != null else -1
				checked += 1
				if course.point_at(d) != Vector2(d, level.floor_y):
					wrong.append("%s: point_at(%s) is %s" % [where, d, course.point_at(d)])
				if course.heading_at(d) != 1 or course.on_ladder(d):
					wrong.append("%s: heading_at(%s) is not 1" % [where, d])
				if course.chamber_at(d) != index:
					wrong.append("%s: chamber_at(%s) is not %d" % [where, d, index])
			for room: LabyrinthChamber in level.chambers:
				var columns := Vector2(room.floor_columns())
				if course.stretch_of(room.index) != columns:
					wrong.append("%s: stretch of %d is not its floor" % [where, room.index])
				if course.distance_in(room.index, columns.x + 2.25) != columns.x + 2.25:
					wrong.append("%s: distance_in(%d) is not the column" % [where, room.index])
	assert_gt(checked, 40 * 12 * 100, "every half column of every level was read")
	assert_eq(wrong.size(), 0, "the course is the floor row: " + "; ".join(wrong.slice(0, 5)))


## R2: a course that bends knows its places.
func test_r2_a_bent_course_knows_its_places() -> void:
	var maze := BentLabyrinth.new(1)
	var course: StageCourse = maze.level(1).course
	var top: int = BentLabyrinth.floor_row(1, 0)
	var foot: int = BentLabyrinth.floor_row(1, 1)
	var column: float = BentLabyrinth.LADDER_COLUMN
	assert_eq(course.start, 0.0, "it starts where it was begun")
	assert_eq(course.end, BentLabyrinth.END, "and ends after both rooms and the ladder")
	assert_eq(course.entry, BentLabyrinth.ENTRIES[0], "the entry given")
	assert_eq(course.exit, BentLabyrinth.EXITS[1], "the exit given")

	assert_eq(course.point_at(0.0), Vector2(BentLabyrinth.UPPER.position.x, top), "the first point")
	assert_eq(course.point_at(BentLabyrinth.LADDER_TOP), Vector2(column, top), "the ladder's top")
	assert_eq(course.point_at(24.0), Vector2(column, top + 5.0), "down the ladder: the column kept")
	assert_eq(course.point_at(BentLabyrinth.LADDER_FOOT), Vector2(column, foot), "its foot")
	assert_eq(course.point_at(34.0), Vector2(column - 5.0, foot), "then left along the floor below")
	assert_eq(course.point_at(BentLabyrinth.END), Vector2(BentLabyrinth.LOWER.position.x, foot))
	assert_eq(course.point_at(-5.0), course.point_at(0.0), "clamped to the line at its start")
	assert_eq(course.point_at(99.0), course.point_at(BentLabyrinth.END), "and at its end")

	assert_eq(course.heading_at(10.0), 1, "right through the first room")
	assert_eq(course.heading_at(24.0), 0, "neither on the ladder")
	assert_eq(course.heading_at(35.0), -1, "left through the second")
	assert_true(course.on_ladder(24.0), "on the ladder between the floors")
	assert_false(course.on_ladder(10.0), "not on a floor")
	assert_false(course.on_ladder(BentLabyrinth.LADDER_TOP), "the ladder's top is the floor above")
	assert_false(course.on_ladder(BentLabyrinth.LADDER_FOOT), "its foot the floor below")
	assert_eq(
		course.heading_at(BentLabyrinth.LADDER_FOOT), -1, "where the party already heads left"
	)

	assert_eq(course.stretch_of(0), Vector2(0.0, BentLabyrinth.LADDER_TOP), "the first room")
	assert_eq(course.stretch_of(1), Vector2(BentLabyrinth.LADDER_FOOT, BentLabyrinth.END))
	var disagree: Array[float] = []
	for quarter: int in roundi(BentLabyrinth.END * 4.0) + 1:
		var d: float = quarter / 4.0
		for room: int in 2:
			var stretch: Vector2 = course.stretch_of(room)
			if (course.chamber_at(d) == room) != (d >= stretch.x and d <= stretch.y):
				disagree.append(d)
		if course.chamber_at(d) == -1 and not course.on_ladder(d):
			disagree.append(d)
	assert_eq(disagree.size(), 0, "chamber_at and stretch_of agree: not at %s" % [disagree])

	assert_gt(
		course.distance_in(1, 10.0), course.distance_in(1, 20.0), "further as the column falls"
	)
	for at: float in [9.0, 12.5, 20.0, 23.0]:
		var d: float = course.distance_in(1, at)
		assert_eq(course.point_at(d), Vector2(at, foot), "distance_in is point_at backwards")
	assert_eq(course.distance_in(0, 10.0), 6.0, "in the first room it grows with the column")
	assert_eq(course.distance_in(1, 2.0), BentLabyrinth.END, "clamped to the room's stretch")
	assert_eq(course.distance_in(0, 99.0), BentLabyrinth.LADDER_TOP, "at either end")

	var short := StageCourse.new()
	short.begin(Vector2(2.0, 5.0), 0.0)
	short.line_to(Vector2(2.4, 5.0), 0)
	assert_eq(short.heading_at(0.2), 1, "a run under half a tile long is level")
	assert_false(short.on_ladder(0.2), "not a ladder")
	assert_almost_eq(short.point_at(0.2).x, 2.2, 0.001, "and is walked along the floor")


## R2 (a chamber is half-open): feet at column c stand on the tile from c to c + 1, whichever way
## the course walks a floor, so the column of a chamber's far wall is the tunnel's.
func test_r2_a_chamber_is_half_open_walked_either_way() -> void:
	# One floor row: a room on columns 10 to 25, a tunnel on 26 to 29, a room on 30 to 39.
	var rects: Array[Rect2i] = [Rect2i(10, 0, 16, 6), Rect2i(30, 0, 10, 6)]
	var row: float = 5.0
	var rightward := StageCourse.new()
	rightward.begin(Vector2(rects[0].position.x, row), 0.0)
	rightward.line_to(Vector2(rects[0].end.x, row), 0)
	rightward.line_to(Vector2(rects[1].position.x, row))
	rightward.line_to(Vector2(rects[1].end.x - 1, row), 1)
	var leftward := StageCourse.new()
	leftward.begin(Vector2(rects[1].end.x - 1, row), 0.0)
	leftward.line_to(Vector2(rects[1].position.x, row), 1)
	leftward.line_to(Vector2(rects[0].end.x, row))
	leftward.line_to(Vector2(rects[0].position.x, row), 0)
	var courses: Array[StageCourse] = [rightward, leftward]
	for way: int in courses.size():
		var course: StageCourse = courses[way]
		var label: String = "walked rightward: " if way == 0 else "walked leftward: "
		assert_eq(course.end, 29.0, label + "as long as the floor")
		assert_eq(course.heading_at(5.0), 1 if way == 0 else -1, label + "its heading")
		var wrong: Array[float] = []
		for quarter: int in roundi(course.end * 4.0) + 1:
			var d: float = quarter / 4.0
			var column: int = floori(course.point_at(d).x)
			var room: int = -1
			for index: int in rects.size():
				if column >= rects[index].position.x and column < rects[index].end.x:
					room = index
			if course.chamber_at(d) != room:
				wrong.append(d)
		assert_eq(wrong.size(), 0, label + "chamber_at is the tile's room: not at %s" % [wrong])
		for index: int in rects.size():
			var stretch: Vector2 = course.stretch_of(index)
			assert_lt(stretch.x, stretch.y, label + "a stretch runs the way the distance does")
			var columns: Array[float] = [course.point_at(stretch.x).x, course.point_at(stretch.y).x]
			columns.sort()
			assert_eq(columns[0], float(rects[index].position.x), label + "from its first column")
			assert_eq(columns[1], float(rects[index].end.x - 1), label + "to its last")
			var inside: float = rects[index].position.x + 3.5
			assert_eq(
				course.point_at(course.distance_in(index, inside)).x, inside, label + "a column"
			)


# --- R3 ------------------------------------------------------------------------


## R3: a party sent across walks the bend in order, its heroes behind it on the same line, at one
## speed.
func test_r3_the_party_walks_the_bend() -> void:
	var sim: Simulation = _bent(1)
	var e: Expedition = sim.expedition
	var course: StageCourse = _course(sim)
	var spacing: float = PartyPlaces.HERO_SPACING
	var distances: Array[float] = [e.x]
	var facings: Array[int] = [e.facing]
	var anchor_off: int = 0
	var hero_off: int = 0
	var out_of_line: int = 0
	var lined_up: int = 0
	var on_ladder: bool = false
	var left_after: bool = false
	var walked: float = 0.0
	var was: Vector2 = PartyPlaces.anchor(e)
	for tick: int in ticks_in(45.0):
		sim.step()
		assert_eq(e.state, Expedition.State.TRAVELLING, "nothing stops it on this stage")
		var anchor: Vector2 = PartyPlaces.anchor(e)
		if not _near(anchor, course.point_at(e.x)):
			anchor_off += 1
		walked = walked + absf(e.x - distances[-1]) if e.facing == facings[-1] else 0.0
		if course.on_ladder(e.x):
			on_ladder = true
			if anchor.x != BentLabyrinth.LADDER_COLUMN or anchor.y <= was.y:
				anchor_off += 1
		elif on_ladder and e.facing == 1 and anchor.x < was.x and anchor.y == was.y:
			left_after = true
		for rank: int in sim.party.heroes.size():
			var feet: Vector2 = e.hero_position(sim.party.heroes[rank].id)
			if not BentLabyrinth.on_course(1, feet):
				hero_off += 1
			if walked < rank * spacing:
				continue
			lined_up += 1
			var behind: float = e.x - e.facing * rank * spacing
			if behind >= course.start and not _near(feet, course.point_at(behind)):
				out_of_line += 1
		if e.facing == -1:
			break
		distances.append(e.x)
		facings.append(e.facing)
		was = anchor
	assert_eq(anchor_off, 0, "the anchor is at point_at(x) on every tick, straight down the ladder")
	assert_true(on_ladder, "it was seen on the ladder")
	assert_true(left_after, "and then travelling left along the floor below")
	assert_eq(e.x, BentLabyrinth.END, "to the far end of the course")
	assert_eq(hero_off, 0, "no hero is ever off the course")
	assert_gt(lined_up, 100, "heroes were seen in line")
	assert_eq(out_of_line, 0, "each hero HERO_SPACING behind the last along the line")

	var floor_seconds: int = 0
	var ladder_seconds: int = 0
	for i: int in distances.size() - TICKS:
		var a: float = distances[i]
		var b: float = distances[i + TICKS]
		if b >= BentLabyrinth.END:
			continue
		var both_ladder: bool = course.on_ladder(a) and course.on_ladder(b)
		var both_floor: bool = course.chamber_at(a) == 1 and course.chamber_at(b) == 1
		if both_ladder or both_floor:
			assert_almost_eq(b - a, Expedition.PARTY_SPEED, 0.001, "a second's course at %s" % a)
			ladder_seconds += int(both_ladder)
			floor_seconds += int(both_floor)
	assert_gt(ladder_seconds, 0, "measured on the ladder")
	assert_gt(floor_seconds, 0, "and on the floor")


# --- R4 ------------------------------------------------------------------------


## The party of [param sim] walked into the guardian's room, the second, where the fight has just
## begun.
func _into_the_fight(sim: Simulation) -> void:
	_on_stage(sim, GUARDIAN_STAGE, GUARDIAN_STAGE)
	var e: Expedition = sim.expedition
	step_until(sim, func() -> bool: return e.battle != null, LIMIT_TICKS_90_S)


## R4: in a room the course walks from right to left the heroes enter from the right, on that
## room's floor, and travel on from where the front hero stood.
func test_r4_a_fight_is_entered_the_way_the_party_came() -> void:
	var sim: Simulation = _bent(1)
	var e: Expedition = sim.expedition
	raise_party(sim, STRONG_LEVEL)
	_into_the_fight(sim)
	var course: StageCourse = _course(sim)
	var row: float = BentLabyrinth.floor_row(GUARDIAN_STAGE, 1)
	assert_eq(e.chamber().index, 1, "the fight is in the second room")
	assert_false(e.battle.monsters.is_empty(), "against its monsters")
	assert_eq(PartyPlaces.world_facing(e), -1, "the party faces left")
	for hero: Hero in sim.party.heroes:
		var feet: Vector2 = e.hero_position(hero.id)
		assert_eq(feet.y, row, "hero %d stands on that room's floor row" % hero.id)
		assert_eq(feet.x, e.battle.combatant(hero.id).x, "at its fighter's column")
		for monster: Combatant in e.battle.monsters:
			assert_gt(
				feet.x, monster.x, "hero %d starts right of monster %d" % [hero.id, monster.id]
			)

	var front: Combatant = e.battle.combatant(sim.party.heroes[0].id)
	var ended: Array[SimEvent] = []
	step_until(
		sim,
		func() -> bool:
			ended.append_array(_of_kind(sim.drain_events(), SimEvent.Kind.ENCOUNTER_ENDED))
			return e.battle == null,
		LIMIT_TICKS_90_S
	)
	assert_true(ended.size() == 1 and ended[0].flag, "the party won")
	var stretch: Vector2 = course.stretch_of(1)
	assert_true(e.x >= stretch.x and e.x <= stretch.y, "x is in that room's stretch: %s" % e.x)
	assert_true(
		_near(PartyPlaces.anchor(e), Vector2(front.x, row)), "gathered at its front hero's place"
	)
	step_until(sim, func() -> bool: return e.state == Expedition.State.TRAVELLING, LIMIT_TICKS)
	var from: Vector2 = PartyPlaces.anchor(e)
	var at: float = e.x
	run_ticks(sim, TICKS)
	assert_eq(e.facing, 1, "it travels on along the course")
	assert_almost_eq(e.x - at, Expedition.PARTY_SPEED, 0.001, "at its speed")
	assert_almost_eq(PartyPlaces.anchor(e).x - from.x, -Expedition.PARTY_SPEED, 0.001, "left")
	assert_eq(PartyPlaces.anchor(e).y, row, "along that floor")


## R4: a party wiped there lies where each hero fell, on that room's floor row.
func test_r4_a_lost_fight_falls_where_it_stood() -> void:
	var sim: Simulation = _bent(1)
	var e: Expedition = sim.expedition
	_into_the_fight(sim)
	var fighters: Array[Combatant] = e.battle.heroes.duplicate()
	step_until(sim, func() -> bool: return e.battle == null, LIMIT_TICKS_3_MIN)
	assert_eq(e.state, Expedition.State.REVIVING, "the party was wiped")
	var row: float = BentLabyrinth.floor_row(GUARDIAN_STAGE, 1)
	for fighter: Combatant in fighters:
		var feet: Vector2 = e.hero_position(fighter.id)
		assert_eq(feet.y, row, "hero %d lies on that room's floor row" % fighter.id)
		assert_almost_eq(feet.x, fighter.x, 0.001, "at the column it fell")
		assert_true(BentLabyrinth.on_course(GUARDIAN_STAGE, feet), "which is in the room")


# --- R5 ------------------------------------------------------------------------


## R5: revived or loaded, a party stands at `entry` facing `exit`; at its target it turns at both
## ends; the entry's and the exit's rooms are always empty.
func test_r5_arrival_is_the_entry_facing_the_exit() -> void:
	# (exit room, entry room, the way from entry to exit along the course)
	for rooms: Vector3i in [Vector3i(1, 0, 1), Vector3i(0, 1, -1)]:
		var label: String = "exit in room %d: " % rooms.x
		var sim: Simulation = _bent(rooms.x, rooms.y)
		var e: Expedition = sim.expedition
		var entry: float = _course(sim).entry
		assert_eq(e.x, entry, label + "a new party stands at the entry")
		assert_eq(e.facing, rooms.z, label + "facing the exit")
		run_ticks(sim, 3 * TICKS)
		assert_ne(e.x, entry, label + "it walks off")
		_wipe(sim)
		sim.step()
		assert_eq(e.state, Expedition.State.REVIVING, label + "wiped")
		assert_eq(e.revival_place(), Vector3(entry, 1.0, rooms.z), label + "where it will stand")
		step_until(sim, func() -> bool: return e.state != Expedition.State.REVIVING, LIMIT_TICKS)
		assert_eq(e.x, entry, label + "revived at the entry")
		assert_eq(e.facing, rooms.z, label + "facing the exit")

		var loaded: Simulation = _bent(rooms.x, rooms.y)
		Arrival.from_save(loaded.expedition, 100, 2, 2, 2, false)
		assert_eq(loaded.expedition.depth, 2, label + "loaded on its stage")
		assert_eq(loaded.expedition.x, _course(loaded).entry, label + "at the entry")
		assert_eq(loaded.expedition.facing, rooms.z, label + "facing the exit")

	var roaming: Simulation = _bent(1)
	var run: Expedition = roaming.expedition
	var course: StageCourse = _course(roaming)
	var turns: Array[float] = []
	var facing: int = run.facing
	for tick: int in ticks_in(60.0):
		roaming.step()
		assert_true(run.x >= course.start and run.x <= course.end, "never off the course")
		if run.facing != facing:
			facing = run.facing
			turns.append(run.x)
	assert_gt(turns.size(), 1, "it turned more than once")
	for i: int in turns.size():
		var wanted: float = course.end if i % 2 == 0 else course.start
		assert_almost_eq(turns[i], wanted, 0.2, "turn %d is at an end of the course" % i)

	var plain: Expedition = _bent(0).expedition
	var ends: Expedition = _bent(1).expedition
	for stage: int in [1, 2, 3, 4, 6, 7]:
		for room: int in 2:
			var empty: bool = not ends.is_populated(stage, room)
			empty = empty and ends.side_quest_in(stage, room) == &""
			assert_true(empty, "stage %d: the entry's and the exit's rooms are empty" % stage)
		assert_false(plain.is_populated(stage, 0), "with both in the first room, it is empty")
		assert_eq(plain.side_quest_in(stage, 0), &"", "of quests too")
		var held: bool = plain.is_populated(stage, 1) or plain.side_quest_in(stage, 1) != &""
		assert_true(held, "stage %d: the room that is neither holds something" % stage)
	assert_true(ends.is_populated(GUARDIAN_STAGE, 1), "a guardian holds the exit's room")
	assert_false(ends.is_populated(GUARDIAN_STAGE, 0), "and not the entry's")


## R5: under Hold the party turns one tile of course short of the guardian's room, from
## whichever side the course brings it.
func test_r5_hold_turns_short_of_the_guardian_from_either_side() -> void:
	# (exit room, entry room, the way the party comes along the course)
	for rooms: Vector3i in [Vector3i(1, 0, 1), Vector3i(0, 1, -1)]:
		var label: String = "the guardian in room %d: " % rooms.x
		var sim: Simulation = _bent(rooms.x, rooms.y)
		var e: Expedition = sim.expedition
		var course: StageCourse = _course(sim)
		var stretch: Vector2 = course.stretch_of(rooms.x)
		var short: float = stretch.x - 1.0 if rooms.z > 0 else stretch.y + 1.0
		assert_true(course.on_ladder(short), label + "a tile short of it is on the ladder")
		sim.set_guardian_order(HOLD)
		_on_stage(sim, GUARDIAN_STAGE, GUARDIAN_STAGE + 1)
		var nearest: float = e.x
		var turned_at: float = -1.0
		for tick: int in ticks_in(40.0):
			sim.step()
			assert_null(e.battle, label + "it never fights the guardian")
			nearest = maxf(nearest, e.x) if rooms.z > 0 else minf(nearest, e.x)
			if turned_at < 0.0 and e.facing != rooms.z:
				turned_at = e.x
		assert_almost_eq(nearest, short, 0.001, label + "it comes one tile of course short")
		assert_almost_eq(turned_at, short, 0.001, label + "and turns there")
		assert_true(e.is_holding(), label + "holding")
		assert_eq(e.depth, GUARDIAN_STAGE, label + "on its stage")
		assert_true(e.is_populated(GUARDIAN_STAGE, rooms.x), label + "the guardian still waits")
