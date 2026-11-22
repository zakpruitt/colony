extends ColonyTest
## Spec 089: a second shape of stage, `Labyrinth.Shape.WINDING`: rooms on three floors joined by
## tunnels and ladders, a route that doubles back, and a crossing between stages that takes a
## fixed time and lands at a door. The game still makes the flat shape.

const WINDING: Labyrinth.Shape = Labyrinth.Shape.WINDING
const SEEDS: int = 40
const STAGES: int = 12
const TICKS: int = Simulation.TICKS_PER_SECOND
## R2's numbers, as the spec gives them.
const BAND_HEIGHT: int = 32
const FLOOR_GAP: int = 10
const ROOMS: Vector2i = Vector2i(7, 10)
const ROOM_WIDTH: Vector2i = Vector2i(10, 22)
const ROOM_HEIGHT: Vector2i = Vector2i(4, 8)
const TUNNEL_LENGTH: Vector2i = Vector2i(4, 10)
const TUNNEL_HEIGHT: int = 3
## Open tiles between a ladder or a door and its room's side walls.
const INSET: int = 2
## R4: how many times a flat stage's walk from entry to exit a winding stage's is, on average.
const LENGTH_RATIO_LOW: float = 1.8
const LENGTH_RATIO_HIGH: float = 2.6
## Mossy Hollow's guardian holds this stage.
const GUARDIAN_STAGE: int = 5
const RUN_SEEDS: Array[int] = [1, 2, 3]
const RUN_MINUTES: int = 30
## The 30 minute runs wipe the party once by hand, at this minute, if it has not fallen by itself.
const WIPE_MINUTE: int = 12


func _winding(seed_value: int, label: String = "") -> Labyrinth:
	return Labyrinth.new(seed_value, label, WINDING)


## How rooms [param index] and [param index] + 1 of [param level] are joined, as
## Vector2i(tunnels, ladders) that meet both the way R3 says.
func _joints(level: LabyrinthLevel, index: int) -> Vector2i:
	var a: Rect2i = level.chambers[index].rect
	var b: Rect2i = level.chambers[index + 1].rect
	var found := Vector2i.ZERO
	var left: Rect2i = a if a.position.x < b.position.x else b
	var right: Rect2i = b if a.position.x < b.position.x else a
	for tunnel: Rect2i in level.tunnels:
		var level_with: bool = tunnel.end.y == a.end.y and a.end.y == b.end.y
		if level_with and tunnel.position.x == left.end.x and tunnel.end.x == right.position.x:
			found.x += 1
	var upper: Rect2i = a if a.end.y < b.end.y else b
	var lower: Rect2i = b if a.end.y < b.end.y else a
	for ladder: Rect2i in level.ladders:
		var inside: bool = true
		for room: Rect2i in [a, b]:
			if ladder.position.x < room.position.x + INSET or ladder.end.x > room.end.x - INSET:
				inside = false
		var top_to_foot: bool = ladder.position.y == upper.end.y and ladder.end.y == lower.end.y
		if inside and top_to_foot and a.end.y != b.end.y:
			found.y += 1
	return found


## True if [param feet] stands on [param level]: on the floor of a room or a tunnel, or on a
## ladder.
func _standing(level: LabyrinthLevel, feet: Vector2) -> bool:
	var floors: Array[Rect2i] = []
	for room: LabyrinthChamber in level.chambers:
		floors.append(room.rect)
	floors.append_array(level.tunnels)
	for rect: Rect2i in floors:
		var on_row: bool = is_equal_approx(feet.y, rect.end.y - 1)
		if on_row and feet.x >= rect.position.x - 0.001 and feet.x <= rect.end.x + 0.001:
			return true
	for ladder: Rect2i in level.ladders:
		var in_columns: bool = feet.x >= ladder.position.x and feet.x <= ladder.end.x
		if in_columns and feet.y >= ladder.position.y - 1.001 and feet.y <= ladder.end.y - 0.999:
			return true
	return false


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


## Everything that makes [param level] what it is, as plain values.
func _signature(level: LabyrinthLevel) -> Array:
	var parts: Array = [level.depth, level.band, level.floor_y, level.tunnels, level.ladders]
	for room: LabyrinthChamber in level.chambers:
		parts.append([room.index, room.kind, room.rect])
	var line: StageCourse = level.course
	parts.append([line.start, line.end, line.entry, line.exit])
	for half: int in range(roundi(line.start * 2.0), roundi(line.end * 2.0) + 1):
		parts.append(line.point_at(half / 2.0))
	return parts


# --- R1 ------------------------------------------------------------------------


## R1: a labyrinth or a simulation made without a shape is flat.
func test_r1_a_labyrinth_is_flat_unless_asked() -> void:
	for seed_value: int in [1, 7, 23]:
		var plain := Labyrinth.new(seed_value)
		var flat := Labyrinth.new(seed_value, "", Labyrinth.Shape.FLAT)
		var sim := Simulation.new(seed_value)
		var wound: Labyrinth = _winding(seed_value)
		assert_eq(plain.shape, Labyrinth.Shape.FLAT, "a labyrinth is flat unless asked")
		assert_eq(sim.labyrinth.shape, Labyrinth.Shape.FLAT, "and so is a simulation's")
		assert_eq(plain.band_height(), Labyrinth.LEVEL_HEIGHT, "a flat stage's band")
		assert_eq(wound.shape, WINDING, "a winding one says so")
		for depth: int in range(1, STAGES + 1):
			var where: String = "seed %d stage %d" % [seed_value, depth]
			var level: LabyrinthLevel = plain.level(depth)
			assert_eq(_signature(level), _signature(flat.level(depth)), where + ": as a flat one")
			assert_eq(
				_signature(sim.labyrinth.level(depth)),
				_signature(flat.level(depth)),
				where + ": the simulation's too"
			)
			assert_eq(level.ladders.size(), 0, where + ": no ladders")
			assert_true(level.shaft_down.has_area(), where + ": a shaft down")
			assert_eq(level.open_rects().size(), 2 * level.chambers.size(), where + ": its rects")
			var top: int = (depth - 1) * Labyrinth.LEVEL_HEIGHT
			var band := Rect2i(0, top, Labyrinth.LEVEL_WIDTH, Labyrinth.LEVEL_HEIGHT)
			assert_eq(level.band, band, where + ": its band")
			assert_ne(_signature(wound.level(depth)), _signature(level), where + ": not winding")


# --- R2 ------------------------------------------------------------------------


## R2: the band, the floor rows, the counts and sizes, and the earth between the rooms.
func test_r2_rooms_stand_on_three_floors_apart() -> void:
	var wrong: Array[String] = []
	var rows_seen: Dictionary[int, bool] = {}
	var floors_seen: Dictionary[int, bool] = {}
	var counts_seen: Dictionary[int, bool] = {}
	for seed_value: int in range(1, SEEDS + 1):
		var maze: Labyrinth = _winding(seed_value)
		assert_eq(maze.band_height(), BAND_HEIGHT, "a winding stage's band is 32 rows")
		for depth: int in range(1, STAGES + 1):
			var level: LabyrinthLevel = maze.level(depth)
			var where: String = "seed %d stage %d" % [seed_value, depth]
			var band := Rect2i(0, (depth - 1) * BAND_HEIGHT, Labyrinth.LEVEL_WIDTH, BAND_HEIGHT)
			if level.band != band:
				wrong.append("%s: band %s" % [where, level.band])
			var count: int = level.chambers.size()
			counts_seen[count] = true
			if count < ROOMS.x or count > ROOMS.y:
				wrong.append("%s: %d rooms" % [where, count])
			var floors: Dictionary[int, bool] = {}
			for room: LabyrinthChamber in level.chambers:
				var rect: Rect2i = room.rect
				floors[room.floor_row() - band.position.y] = true
				if rect.size.x < ROOM_WIDTH.x or rect.size.x > ROOM_WIDTH.y:
					wrong.append("%s: room %d is %d wide" % [where, room.index, rect.size.x])
				if rect.size.y < ROOM_HEIGHT.x or rect.size.y > ROOM_HEIGHT.y:
					wrong.append("%s: room %d is %d tall" % [where, room.index, rect.size.y])
				if room.index != level.chambers.find(room):
					wrong.append("%s: room %d is not at its index" % [where, room.index])
			var rows: Array[int] = []
			rows.assign(floors.keys())
			rows.sort()
			floors_seen[rows.size()] = true
			if rows.size() < 2 or rows.size() > 3:
				wrong.append("%s: rooms on %d floors" % [where, rows.size()])
			for i: int in rows.size():
				rows_seen[rows[i]] = true
				if i > 0 and rows[i] - rows[i - 1] != FLOOR_GAP:
					wrong.append("%s: floors %s are not neighbours" % [where, rows])
			if level.floor_y != level.chambers[0].floor_row():
				wrong.append("%s: floor_y is not the first room's floor" % where)
			if level.shaft_down.has_area():
				wrong.append("%s: a shaft down" % where)
			wrong.append_array(_earth_problems(level, where))
	var all_rows: Array[int] = []
	all_rows.assign(rows_seen.keys())
	all_rows.sort()
	assert_eq(all_rows.size(), 3, "three floor rows in the band: %s" % [all_rows])
	if all_rows.size() == 3:
		assert_eq(all_rows[1] - all_rows[0], FLOOR_GAP, "10 rows apart")
		assert_eq(all_rows[2] - all_rows[1], FLOOR_GAP, "10 rows apart")
	assert_true(floors_seen.has(2) and floors_seen.has(3), "stages on 2 floors and on 3")
	for count: int in range(ROOMS.x, ROOMS.y + 1):
		assert_true(counts_seen.has(count), "a stage of %d rooms is seen" % count)
	assert_eq(wrong.size(), 0, "\n".join(wrong.slice(0, 12)))


## What is wrong with the open rectangles of [param level]: one outside the band's margin, two
## that overlap (a ladder comes down through its lower room to its floor, and through nothing
## else), or two that are not joined with no earth between them.
func _earth_problems(level: LabyrinthLevel, where: String) -> Array[String]:
	var wrong: Array[String] = []
	var rooms: int = level.chambers.size()
	var rects: Array[Rect2i] = level.open_rects()
	var expected: int = rooms + level.tunnels.size() + level.ladders.size()
	if rects.size() != expected or level.tunnels.size() + level.ladders.size() != rooms - 1:
		wrong.append("%s: %d open rectangles for %d rooms" % [where, rects.size(), rooms])
		return wrong
	# Pairs that are joined, as Vector2i(lower index, higher index) into the rectangles.
	var joined: Dictionary[Vector2i, bool] = {}
	# A ladder and the room it comes down into.
	var foot: Dictionary[Vector2i, bool] = {}
	for room: int in rooms:
		for other: int in range(rooms, rects.size()):
			var rect: Rect2i = rects[other]
			var chamber: Rect2i = rects[room]
			if other < rooms + level.tunnels.size():
				var beside: bool = (
					rect.position.x == chamber.end.x or rect.end.x == chamber.position.x
				)
				if beside and rect.end.y == chamber.end.y:
					joined[Vector2i(room, other)] = true
			elif rect.position.x >= chamber.position.x and rect.end.x <= chamber.end.x:
				if rect.position.y == chamber.end.y:
					joined[Vector2i(room, other)] = true
				elif rect.end.y == chamber.end.y:
					joined[Vector2i(room, other)] = true
					foot[Vector2i(room, other)] = true
	var inside: Rect2i = level.band.grow(-1)
	for i: int in rects.size():
		if not inside.encloses(rects[i]):
			wrong.append("%s: %s is not a tile inside the band" % [where, rects[i]])
		for j: int in range(i + 1, rects.size()):
			var pair := Vector2i(i, j)
			if foot.has(pair):
				var shared: Rect2i = rects[i].intersection(rects[j])
				if shared.size.x != rects[j].size.x or shared.size.y != rects[i].size.y:
					wrong.append("%s: ladder %s leaves room %s" % [where, rects[j], rects[i]])
			elif rects[i].intersects(rects[j]):
				wrong.append("%s: %s and %s overlap" % [where, rects[i], rects[j]])
			elif not joined.has(pair) and rects[i].grow(1).intersects(rects[j]):
				wrong.append("%s: no earth between %s and %s" % [where, rects[i], rects[j]])
	return wrong


# --- R3 ------------------------------------------------------------------------


## R3: neighbours in the route are joined by one tunnel or one ladder; every level has a ladder
## and a stretch walked right to left; some routes climb and some go down.
func test_r3_tunnels_and_ladders_join_the_route() -> void:
	var wrong: Array[String] = []
	var ups: int = 0
	var downs: int = 0
	var levels: int = 0
	for seed_value: int in range(1, 21):
		var maze: Labyrinth = _winding(seed_value)
		for depth: int in range(1, 11):
			var level: LabyrinthLevel = maze.level(depth)
			var line: StageCourse = level.course
			var where: String = "seed %d stage %d" % [seed_value, depth]
			levels += 1
			var ladders: int = 0
			var leftward: bool = false
			var climbs: Dictionary[int, bool] = {}
			for index: int in level.chambers.size() - 1:
				var a: LabyrinthChamber = level.chambers[index]
				var b: LabyrinthChamber = level.chambers[index + 1]
				var joints: Vector2i = _joints(level, index)
				if joints.x + joints.y != 1:
					wrong.append("%s: rooms %d and %d are joined by %s" % [where, index, joints])
					continue
				var stretch_a: Vector2 = line.stretch_of(index)
				var stretch_b: Vector2 = line.stretch_of(index + 1)
				var way_a: int = line.heading_at((stretch_a.x + stretch_a.y) / 2.0)
				var way_b: int = line.heading_at((stretch_b.x + stretch_b.y) / 2.0)
				leftward = leftward or way_a < 0 or way_b < 0
				if joints.x == 1:
					if a.floor_row() != b.floor_row() or way_a != way_b or way_a == 0:
						wrong.append("%s: the tunnel after room %d turns" % [where, index])
					continue
				ladders += 1
				climbs[signi(b.floor_row() - a.floor_row())] = true
				if absi(b.floor_row() - a.floor_row()) != FLOOR_GAP:
					wrong.append("%s: the ladder after room %d skips a floor" % [where, index])
				if way_a == 0 or way_a != -way_b:
					wrong.append("%s: the route does not turn at room %d's ladder" % [where, index])
			for tunnel: Rect2i in level.tunnels:
				var length: int = tunnel.size.x
				if length < TUNNEL_LENGTH.x or length > TUNNEL_LENGTH.y:
					wrong.append("%s: a tunnel %d long" % [where, length])
				if tunnel.size.y != TUNNEL_HEIGHT:
					wrong.append("%s: a tunnel %d tall" % [where, tunnel.size.y])
			for ladder: Rect2i in level.ladders:
				if ladder.size != Vector2i(Labyrinth.SHAFT_WIDTH, FLOOR_GAP):
					wrong.append("%s: a ladder of %s" % [where, ladder.size])
			if ladders < 1 or ladders != level.ladders.size():
				wrong.append("%s: %d ladders on the route" % [where, ladders])
			if not leftward:
				wrong.append("%s: no stretch walked right to left" % where)
			if climbs.size() != 1:
				wrong.append("%s: its ladders go both up and down" % where)
			ups += int(climbs.has(-1))
			downs += int(climbs.has(1))
	assert_eq(levels, 200, "200 levels")
	assert_gt(ups, 20, "the route goes up a ladder in some")
	assert_gt(downs, 20, "and down in others")
	assert_eq(wrong.size(), 0, "\n".join(wrong.slice(0, 12)))


# --- R4 ------------------------------------------------------------------------


## R4: the course runs from the far wall of the first room through every room in order to the
## far wall of the last, on open floor or a ladder all the way.
func test_r4_the_course_visits_every_room_in_order() -> void:
	var wrong: Array[String] = []
	var on_ladders: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var maze: Labyrinth = _winding(seed_value)
		for depth: int in range(1, STAGES + 1):
			var level: LabyrinthLevel = maze.level(depth)
			var line: StageCourse = level.course
			var where: String = "seed %d stage %d" % [seed_value, depth]
			var order: Array[int] = []
			for half: int in range(roundi(line.start * 2.0), roundi(line.end * 2.0) + 1):
				var d: float = half / 2.0
				var feet: Vector2 = line.point_at(d)
				var room: int = line.chamber_at(d)
				if order.is_empty() or order[-1] != room:
					order.append(room)
				on_ladders += int(line.on_ladder(d))
				if not _standing(level, feet):
					wrong.append("%s: %s at %s is in the earth" % [where, feet, d])
				elif room >= 0 and not level.chambers[room].rect.has_point(Vector2i(feet.floor())):
					wrong.append("%s: %s at %s is not in room %d" % [where, feet, d, room])
			var expected: Array[int] = []
			for index: int in level.chambers.size():
				if index > 0:
					expected.append(-1)
				expected.append(index)
			if order != expected:
				wrong.append("%s: the course visits %s" % [where, order])
			var last: int = level.chambers.size() - 1
			var ends: Array[float] = [line.start, line.end]
			var doors: Array[float] = [line.entry, line.exit]
			var rooms: Array[int] = [0, last]
			for i: int in 2:
				var columns: Vector2i = level.chambers[rooms[i]].floor_columns()
				# The wall behind a party walking in at the start, ahead of it at the end.
				var way: int = line.heading_at(doors[i]) * (1 if i == 1 else -1)
				var wall: float = columns.y if way > 0 else columns.x
				var row: float = level.chambers[rooms[i]].floor_row()
				if line.point_at(ends[i]) != Vector2(wall, row):
					wrong.append("%s: end %d is at %s" % [where, i, line.point_at(ends[i])])
				var door: Vector2 = line.point_at(doors[i])
				if line.chamber_at(doors[i]) != rooms[i] or door.y != row:
					wrong.append("%s: door %d is not in room %d" % [where, i, rooms[i]])
				if door.x - columns.x < INSET or columns.y - door.x < INSET:
					wrong.append("%s: door %d at %s is by the wall" % [where, i, door])
			if line.start > line.entry or line.entry >= line.exit or line.exit > line.end:
				wrong.append("%s: entry %s and exit %s" % [where, line.entry, line.exit])
	assert_gt(on_ladders, SEEDS * STAGES, "the courses were walked down their ladders")
	assert_eq(wrong.size(), 0, "\n".join(wrong.slice(0, 12)))


## R4: from entry to exit a winding stage is about twice a flat one.
func test_r4_a_stage_is_about_twice_as_long() -> void:
	var flat_total: float = 0.0
	var winding_total: float = 0.0
	for seed_value: int in range(1, SEEDS + 1):
		var flat := Labyrinth.new(seed_value)
		var wound: Labyrinth = _winding(seed_value)
		for depth: int in range(1, STAGES + 1):
			var straight: StageCourse = flat.level(depth).course
			var bent: StageCourse = wound.level(depth).course
			flat_total += absf(straight.exit - straight.entry)
			winding_total += absf(bent.exit - bent.entry)
	var levels: int = SEEDS * STAGES
	var flat_mean: float = flat_total / levels
	var winding_mean: float = winding_total / levels
	var ratio: float = winding_mean / flat_mean
	gut.p("flat mean %.1f, winding mean %.1f, ratio %.2f" % [flat_mean, winding_mean, ratio])
	assert_gt(flat_mean, 40.0, "a flat stage has a walk to measure against")
	assert_between(ratio, LENGTH_RATIO_LOW, LENGTH_RATIO_HIGH, "about twice as long")


# --- R5 ------------------------------------------------------------------------


## R5: a level is its seed, its area and its stage, and its kinds are rolled as a flat one's.
func test_r5_a_level_is_its_seed_area_and_stage() -> void:
	var seed_value: int = 11
	var forward: Labyrinth = _winding(seed_value)
	var backward: Labyrinth = _winding(seed_value)
	var jumping: Labyrinth = _winding(seed_value)
	var signatures: Dictionary[int, Array] = {}
	for depth: int in range(1, STAGES + 1):
		signatures[depth] = _signature(forward.level(depth))
	for depth: int in range(STAGES, 0, -1):
		assert_eq(
			_signature(backward.level(depth)), signatures[depth], "asked backward: %d" % depth
		)
	for depth: int in [7, 2, 12, 1, 9, 4]:
		assert_eq(_signature(jumping.level(depth)), signatures[depth], "asked alone: %d" % depth)
	assert_ne(signatures[1], signatures[2], "two stages differ")
	assert_ne(_signature(_winding(seed_value + 1).level(3)), signatures[3], "two seeds differ")

	var other: StringName = Content.area_ids()[1]
	var label: String = AreaTravel.label(other)
	assert_ne(label, "", "the second area has a label of its own")
	for depth: int in range(1, 5):
		var there: Array = _signature(_winding(seed_value, label).level(depth))
		assert_ne(there, signatures[depth], "two areas differ at stage %d" % depth)
		assert_eq(
			there, _signature(_winding(seed_value, label).level(depth)), "and each is its own"
		)
	var sim := Simulation.new(seed_value, WINDING)
	assert_eq(sim.labyrinth.shape, WINDING, "a winding simulation's labyrinth")
	assert_eq(_signature(sim.labyrinth.level(3)), signatures[3], "is the seed's winding one")
	var away: Labyrinth = sim.expedition.travel.labyrinth(other)
	assert_eq(away.shape, WINDING, "every area's labyrinth has the first one's shape")
	assert_eq(_signature(away.level(2)), _signature(_winding(seed_value, label).level(2)))

	var wrong: Array[String] = []
	var kinds: Dictionary[LabyrinthChamber.Kind, int] = {}
	var caches: int = 0
	for maze_seed: int in range(1, 21):
		var maze: Labyrinth = _winding(maze_seed)
		for depth: int in range(1, 11):
			var level: LabyrinthLevel = maze.level(depth)
			var where: String = "seed %d stage %d" % [maze_seed, depth]
			var vaults: int = 0
			var last: int = level.chambers.size() - 1
			for room: LabyrinthChamber in level.chambers:
				var count: int = kinds.get(room.kind, 0)
				kinds[room.kind] = count + 1
				vaults += int(room.kind == LabyrinthChamber.Kind.VAULT)
				var start: bool = depth == 1 and room.index == 0
				if (room.kind == LabyrinthChamber.Kind.START) != start:
					wrong.append("%s: room %d is of kind %d" % [where, room.index, room.kind])
				var is_end: bool = room.index == 0 or room.index == last
				if is_end and not start and room.kind != LabyrinthChamber.Kind.PLAIN:
					wrong.append("%s: end room %d is of kind %d" % [where, room.index, room.kind])
			if vaults > 1:
				wrong.append("%s: %d vaults" % [where, vaults])
			for path: SidePath in level.side_paths:
				caches += int(path.room.kind == LabyrinthChamber.Kind.CACHE)
				if path.room.kind != LabyrinthChamber.Kind.CACHE:
					wrong.append("%s: a side path's room is of kind %d" % [where, path.room.kind])
	for kind: LabyrinthChamber.Kind in LabyrinthChamber.Kind.values():
		if kind == LabyrinthChamber.Kind.CACHE:
			assert_false(kinds.has(kind), "no room of the route is a cache room")
			assert_gt(caches, 0, "the cache kind is seen on the side paths' rooms")
		else:
			assert_true(kinds.has(kind), "kind %d is seen over 200 levels" % kind)
	assert_eq(wrong.size(), 0, "\n".join(wrong.slice(0, 12)))


# --- R6 ------------------------------------------------------------------------


## Stands the party of [param sim] on [param stage], half a tile short of the door it leaves by
## to go [param direction] (1 on, -1 back), walking to it.
func _before_the_door(sim: Simulation, stage: int, direction: int) -> void:
	var e: Expedition = sim.expedition
	var line: StageCourse = sim.labyrinth.level(stage).course
	sim.set_auto_push(false)
	e.depth = stage
	e.target_depth = stage + direction
	e.facing = direction
	e.x = (line.exit if direction > 0 else line.entry) - direction * 0.5


## Where the heroes of a party stand in line behind an anchor at [param at] of [param line],
## facing [param facing] along it.
func _in_line(line: StageCourse, at: float, facing: int, heroes: int) -> Array[Vector2]:
	var places: Array[Vector2] = []
	for rank: int in heroes:
		var behind: float = at - facing * rank * PartyPlaces.HERO_SPACING
		places.append(line.point_at(clampf(behind, line.start, line.end)))
	return places


## Sends the party of a new winding simulation from [param stage] on or back ([param direction])
## with the travel upgrade at [param rank], checks the crossing as R6 says, and returns the ticks
## it was CLIMBING.
func _cross(stage: int, direction: int, rank: int) -> int:
	var sim := Simulation.new(5, WINDING)
	var e: Expedition = sim.expedition
	var what: String = "stage %d, %s, rank %d: " % [stage, "on" if direction > 0 else "back", rank]
	sim.upgrades.set_rank(&"quick_march", rank)
	_before_the_door(sim, stage, direction)
	var here: StageCourse = sim.labyrinth.level(stage).course
	var there: StageCourse = sim.labyrinth.level(stage + direction).course
	var heroes: int = sim.party.heroes.size()
	var door: float = here.exit if direction > 0 else here.entry
	var landing: float = there.entry if direction > 0 else there.exit
	var left: Array[Vector2] = _in_line(here, door, direction, heroes)
	var lands: Array[Vector2] = _in_line(there, landing, direction, heroes)
	assert_ne(left, lands, what + "the two doors are different places")
	var climbing: Callable = func() -> bool: return e.state == Expedition.State.CLIMBING
	if not step_until(sim, climbing, 20):
		return 0
	assert_almost_eq(e.x, door, 0.001, what + "it leaves from the door")
	var ticks: int = 0
	var shares: Array[float] = []
	var misplaced: int = 0
	var halves: Array[int] = [0, 0]
	while e.state == Expedition.State.CLIMBING and ticks < 200:
		var share: float = ClimbProgress.share(e)
		if not shares.is_empty() and share <= shares[-1]:
			misplaced += 1
		shares.append(share)
		var half: int = 0 if share < 0.5 else 1
		halves[half] += 1
		var places: Array[Vector2] = left if half == 0 else lands
		for i: int in heroes:
			if not _near(e.hero_position(sim.party.heroes[i].id), places[i]):
				misplaced += 1
		if not _near(PartyPlaces.anchor(e), places[0]):
			misplaced += 1
		assert_eq(ClimbProgress.stage_to(e), stage + direction, what + "where it is going")
		sim.step()
		ticks += 1
	assert_eq(shares[0], 0.0, what + "the share starts at 0")
	assert_gt(shares[-1], 0.95, what + "and runs to 1")
	assert_gt(halves[0], 10, what + "a first half was seen")
	assert_gt(halves[1], 10, what + "and a second")
	assert_eq(misplaced, 0, what + "every hero where it left from, then where it lands")
	assert_eq(e.state, Expedition.State.TRAVELLING, what + "it walks again")
	assert_eq(e.depth, stage + direction, what + "on the stage it went to")
	assert_eq(e.x, landing, what + "at that stage's door")
	assert_eq(e.facing, direction, what + "facing the stage's other door")
	assert_eq(ClimbProgress.share(e), 0.0, what + "no share once it has landed")
	for i: int in heroes:
		assert_eq(e.hero_position(sim.party.heroes[i].id), lands[i], what + "hero %d" % i)
	return ticks


## R6: a crossing takes as long as 16 rows of ladder, whatever lies between the two doors, and
## lands at the next stage's entry (or, going back, the last one's exit).
func test_r6_a_crossing_takes_a_fixed_time_and_lands_at_a_door() -> void:
	var rows: float = Labyrinth.LEVEL_HEIGHT
	var plain: float = rows / Expedition.CLIMB_SPEED * TICKS
	for stage: int in [2, 3, 7]:
		assert_almost_eq(float(_cross(stage, 1, 0)), plain, 1.0, "on from %d: 16 rows" % stage)
		assert_almost_eq(float(_cross(stage, -1, 0)), plain, 1.0, "back from %d: 16 rows" % stage)
	var rank: int = 5
	var faster: float = Content.upgrade(&"quick_march").per_rank * rank + 1.0
	assert_gt(faster, 1.1, "the travel upgrade speeds the party")
	assert_almost_eq(float(_cross(3, 1, rank)), plain / faster, 1.0, "shortened by the upgrade")
	assert_almost_eq(float(_cross(3, -1, rank)), plain / faster, 1.0, "going back too")

	# Hold, set while the party is on its way back up to a living guardian, turns it.
	var sim := Simulation.new(5, WINDING)
	var e: Expedition = sim.expedition
	var below: int = GUARDIAN_STAGE + 1
	_before_the_door(sim, below, -1)
	assert_ne(e.guardian_of(GUARDIAN_STAGE), &"", "stage %d has a guardian" % GUARDIAN_STAGE)
	var climbing: Callable = func() -> bool: return e.state == Expedition.State.CLIMBING
	step_until(sim, climbing, 20)
	run_ticks(sim, 8)
	assert_eq(ClimbProgress.stage_to(e), GUARDIAN_STAGE, "on its way back up to the guardian")
	sim.set_guardian_order(Expedition.GuardianOrder.HOLD)
	var events: Array[SimEvent] = []
	var line: StageCourse = sim.labyrinth.level(below).course
	var above: LabyrinthLevel = sim.labyrinth.level(GUARDIAN_STAGE)
	var off: int = 0
	for tick: int in 100:
		if e.state != Expedition.State.CLIMBING:
			break
		events.append_array(run_ticks(sim, 1))
		for hero: Hero in sim.party.heroes:
			var feet: Vector2 = e.hero_position(hero.id)
			if not _standing(above, feet) and not _standing(sim.labyrinth.level(below), feet):
				off += 1
	assert_eq(e.state, Expedition.State.TRAVELLING, "it came back down")
	assert_eq(e.depth, below, "to the stage it left")
	assert_eq(e.x, line.entry, "at its entry")
	assert_eq(e.facing, 1, "facing its exit")
	assert_eq(off, 0, "its heroes stood at one door or the other all the while")
	assert_eq(_of_kind(events, SimEvent.Kind.ENCOUNTER_STARTED).size(), 0, "no fight")
	assert_true(e.is_holding(), "and it is held from the guardian")
	assert_eq(e.monsters_in(GUARDIAN_STAGE, above.chambers.size() - 1).size(), 1, "who still waits")


## R6: a wiped party comes back to the entry of its safe stage, facing its exit.
func test_r6_a_wiped_party_comes_back_to_the_entry() -> void:
	var sim := Simulation.new(9, WINDING)
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	e.depth = 4
	e.target_depth = 4
	e.last_stable_depth = 2
	var deep: LabyrinthLevel = sim.labyrinth.level(4)
	e.x = deep.course.exit - 1.0
	e.facing = 1
	sim.step()
	var stood: Array[Vector2] = []
	for hero: Hero in sim.party.heroes:
		stood.append(e.hero_position(hero.id))
	_wipe(sim)
	sim.step()
	assert_eq(e.state, Expedition.State.REVIVING, "the party is down")
	run_ticks(sim, ticks_in(Expedition.REVIVE_SECONDS) - 1)
	assert_eq(e.state, Expedition.State.REVIVING, "until its time is up")
	for i: int in sim.party.heroes.size():
		var feet: Vector2 = e.hero_position(sim.party.heroes[i].id)
		assert_true(_standing(deep, feet), "hero %d lies on the stage it fell on" % i)
		assert_almost_eq(feet.x, stood[i].x, 0.5, "hero %d where it stood" % i)
	sim.step()
	var safe: LabyrinthLevel = sim.labyrinth.level(2)
	var line: StageCourse = safe.course
	assert_eq(e.state, Expedition.State.TRAVELLING, "it stands again")
	assert_eq(e.depth, 2, "on its safe stage")
	assert_eq(e.x, line.entry, "at the entry")
	assert_eq(e.facing, 1, "facing the exit")
	assert_eq(e.chamber().index, 0, "in the first room")
	var places: Array[Vector2] = _in_line(line, line.entry, 1, sim.party.heroes.size())
	for i: int in sim.party.heroes.size():
		assert_eq(e.hero_position(sim.party.heroes[i].id), places[i], "hero %d in line" % i)
	assert_eq(e.revival_place(), Vector3(line.entry, 2.0, 1.0), "as revival_place said")

	# Down while crossing: the heroes lie where they left from.
	var crossing := Simulation.new(9, WINDING)
	var c: Expedition = crossing.expedition
	_before_the_door(crossing, 3, 1)
	var climbing: Callable = func() -> bool: return c.state == Expedition.State.CLIMBING
	step_until(crossing, climbing, 20)
	run_ticks(crossing, 30)
	assert_gt(ClimbProgress.share(c), 0.5, "past half of the crossing")
	_wipe(crossing)
	crossing.step()
	assert_eq(c.state, Expedition.State.REVIVING, "down on the way")
	var left: StageCourse = crossing.labyrinth.level(3).course
	var lying: Array[Vector2] = _in_line(left, left.exit, 1, crossing.party.heroes.size())
	for i: int in crossing.party.heroes.size():
		var feet: Vector2 = c.hero_position(crossing.party.heroes[i].id)
		assert_true(_near(feet, lying[i]), "hero %d lies where it left from: %s" % [i, feet])


# --- R7 ------------------------------------------------------------------------


## Plays [param seed_value] on winding stages for [constant RUN_MINUTES], buying upgrades and
## spending talents, and returns its state hash. With [param watched] it counts what it sees
## into [param tally] and lists what broke R7 in [param wrong].
func _play(
	seed_value: int, watched: bool, tally: Dictionary[String, int], wrong: Array[String]
) -> int:
	var sim := Simulation.new(seed_value, WINDING)
	var e: Expedition = sim.expedition
	var seen: Array[int] = []
	var revived_at: float = -1.0
	var felled: bool = false
	for tick: int in RUN_MINUTES * 60 * TICKS:
		var was_climbing: bool = e.state == Expedition.State.CLIMBING
		var was_on: int = e.depth
		var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party)
		if cheapest != &"":
			sim.buy_upgrade(cheapest)
		TalentSpender.spend(sim)
		var due: bool = tick >= WIPE_MINUTE * 60 * TICKS and not felled
		if due and e.state == Expedition.State.TRAVELLING:
			felled = true
			_wipe(sim)
		sim.step()
		var events: Array[SimEvent] = sim.drain_events()
		if not watched:
			continue
		var level: LabyrinthLevel = sim.labyrinth.level(e.depth)
		var last: int = level.chambers.size() - 1
		var where: String = "seed %d tick %d stage %d" % [seed_value, sim.tick, e.depth]
		for event: SimEvent in events:
			match event.kind:
				SimEvent.Kind.DEPTH_CHANGED:
					if was_climbing and e.depth == was_on + 1:
						var route: Array[int] = []
						route.assign(range(sim.labyrinth.level(was_on).chambers.size()))
						tally["crossed"] += 1
						if seen != route:
							wrong.append("%s: stage %d was crossed by %s" % [where, was_on, seen])
					seen = []
					var waiting: Array[Combatant] = e.monsters_in(e.depth, last)
					if e.guardian_of(e.depth) != &"" and not waiting.is_empty():
						tally["guardians_waiting"] += int(_is_guardian(waiting[0]))
				SimEvent.Kind.PARTY_WIPED:
					tally["wipes"] += 1
				SimEvent.Kind.PARTY_REVIVED:
					seen = []
					revived_at = level.course.entry
					tally["revivals"] += 1
					if e.depth != e.last_stable_depth or e.x != revived_at or e.facing != 1:
						wrong.append("%s: revived at %s" % [where, e.x])
				SimEvent.Kind.ENCOUNTER_STARTED:
					tally["fights"] += 1
					if e.battle != null and _is_guardian(e.battle.monsters[0]):
						tally["guardians_met"] += 1
						if e.chamber().index != last or e.guardian_of(e.depth) == &"":
							wrong.append("%s: the guardian in room %d" % [where, e.chamber().index])
				SimEvent.Kind.SIDE_QUEST_STARTED:
					tally["quests"] += 1
					if e.chamber().kind != LabyrinthChamber.Kind.PLAIN:
						wrong.append("%s: a side quest in a room that is not plain" % where)
		if e.battle != null:
			var room: LabyrinthChamber = e.chamber()
			var columns: Vector2i = room.floor_columns()
			for hero: Hero in sim.party.heroes:
				var feet: Vector2 = e.hero_position(hero.id)
				if feet.y != room.floor_row() or feet.x < columns.x or feet.x > columns.y:
					wrong.append("%s: hero %d fights at %s" % [where, hero.id, feet])
			for monster: Combatant in e.battle.monsters:
				if monster.x < columns.x or monster.x > columns.y:
					wrong.append("%s: monster %d at %s" % [where, monster.id, monster.x])
		var away: bool = (
			e.state == Expedition.State.CLIMBING or e.state == Expedition.State.REVIVING
		)
		# A side path's cache room is beside the route, not one of its rooms.
		if e.side_path >= 0:
			if e.chamber() != null and e.chamber().index != -1:
				wrong.append("%s: on a side path in room %d" % [where, e.chamber().index])
		elif not away and e.chamber() != null and not seen.has(e.chamber().index):
			seen.append(e.chamber().index)
		if revived_at >= 0.0 and e.x > revived_at + 5.0:
			tally["went_on"] += 1
			revived_at = -1.0
		tally["furthest"] = maxi(tally["furthest"], e.depth)
	return sim.state_hash()


func _is_guardian(monster: Combatant) -> bool:
	return Content.monster(monster.def_id).guardian


## R7: a whole run plays on winding stages.
func test_r7_a_run_plays_on_winding_stages() -> void:
	var hashes: Dictionary[int, bool] = {}
	for seed_value: int in RUN_SEEDS:
		var tally: Dictionary[String, int] = {
			"crossed": 0,
			"fights": 0,
			"guardians_waiting": 0,
			"guardians_met": 0,
			"wipes": 0,
			"revivals": 0,
			"went_on": 0,
			"quests": 0,
			"furthest": 0,
		}
		var wrong: Array[String] = []
		var first: int = _play(seed_value, true, tally, wrong)
		var what: String = "seed %d: " % seed_value
		gut.p(what + str(tally))
		assert_eq(wrong.size(), 0, "\n".join(wrong.slice(0, 12)))
		assert_gt(tally["crossed"], 1, what + "stages were crossed going on, room by room")
		assert_gt(tally["fights"], 20, what + "fights were watched")
		assert_gt(
			tally["guardians_waiting"], 0, what + "the guardian stood in its stage's last room"
		)
		assert_gt(tally["guardians_met"], 0, what + "and was met there")
		assert_gt(tally["wipes"], 0, what + "the party was wiped")
		assert_eq(tally["revivals"], tally["wipes"], what + "and revived each time")
		assert_eq(tally["went_on"], tally["revivals"], what + "and went on from the entry")
		assert_gt(tally["quests"], 0, what + "side quests were met")
		assert_gte(tally["furthest"], 3, what + "it reached stage 3")
		assert_eq(_play(seed_value, false, {}, []), first, what + "the same seed, the same state")
		hashes[first] = true
	assert_eq(hashes.size(), RUN_SEEDS.size(), "and each seed its own")
