extends ColonyTest
## Spec 100: on a winding, zoned stage every room is drawn cut to a shape of its own (an uneven
## ceiling, leaning walls, cut corners, each area in its manner), with room left to stand and to
## pass, the earth between places whole, and the ambience following the shape. The simulation
## does not know.

const SEEDS: int = 10
const STAGES: int = 4
const TILE: int = LabyrinthView.TILE
const WIDTH: int = Labyrinth.LEVEL_WIDTH
const N: int = LabyrinthTiles.N
const E: int = LabyrinthTiles.E
const S: int = LabyrinthTiles.S
const W: int = LabyrinthTiles.W
## R3: the rows over a floor that are always open, and R4: the most a room is ever opened to.
const STANDING_ROWS: int = 4
const MOST_ROWS: int = 8
const MOSSY: StringName = &"mossy_hollow"
const CLAY: StringName = &"claypits"
const CRYPT: StringName = &"old_crypt"
const EMBER: StringName = &"ember_deep"
const AREAS: Array[StringName] = [MOSSY, CLAY, CRYPT, EMBER]
## R1: `Simulation.state_hash()` of a winding game after 5 game minutes, by seed, recorded on
## `dev` at 0847f61.
const RECORDED_HASHES: Dictionary[int, int] = {1: 2922150097, 2: 3388009046, 3: 3466308177}
const NEAR: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]


## The winding labyrinth of [param area] for [param seed_value], as the game makes it.
func _labyrinth(seed_value: int, area: StringName) -> Labyrinth:
	return winding_labyrinth(seed_value, AreaTravel.label(area))


## Calls [param each] with (what, level, view) for stages 1 to 4 of [param seeds] seeds, each seed
## in one of the four areas in turn, the view a zoned one with that stage built.
func _every_stage(seeds: int, each: Callable) -> void:
	for seed_value: int in range(1, seeds + 1):
		var area: StringName = AREAS[seed_value % AREAS.size()]
		_stages_of(seed_value, area, each)


func _stages_of(seed_value: int, area: StringName, each: Callable) -> void:
	var labyrinth: Labyrinth = _labyrinth(seed_value, area)
	for stage: int in range(1, STAGES + 1):
		var view: LabyrinthView = zoned_view(labyrinth, stage, area)
		each.call("%s seed %d stage %d" % [area, seed_value, stage], labyrinth.level(stage), view)
		view.free()


## The rooms of [param level]: those of its route, then its side paths' cache rooms.
func _rooms(level: LabyrinthLevel) -> Array[LabyrinthChamber]:
	var rooms: Array[LabyrinthChamber] = level.chambers.duplicate()
	for path: SidePath in level.side_paths:
		rooms.append(path.room)
	return rooms


## The tunnels and ladders of [param level], its side paths' among them.
func _passages(level: LabyrinthLevel) -> Array[Rect2i]:
	var passages: Array[Rect2i] = level.tunnels + level.ladders
	for path: SidePath in level.side_paths:
		for passage: Rect2i in [path.tunnel, path.ladder]:
			if passage.has_area():
				passages.append(passage)
	return passages


## The world row of the highest open tile of [param column] over the floor of [param room], as
## [param view] answers.
func _ceiling(view: LabyrinthView, room: LabyrinthChamber, column: int) -> int:
	var row: int = room.floor_row()
	while view.is_open(Vector2i(column, row - 1)) and row > room.floor_row() - MOST_ROWS * 2:
		row -= 1
	return row


## The ceiling of every column of [param room], left to right, as [param view] answers.
func _profile(view: LabyrinthView, room: LabyrinthChamber) -> PackedInt32Array:
	var rows: PackedInt32Array = []
	for x: int in range(room.rect.position.x, room.rect.end.x):
		rows.append(_ceiling(view, room, x))
	return rows


## The same from a shape.
func _profile_of(shape: RoomShape, rect: Rect2i) -> PackedInt32Array:
	var rows: PackedInt32Array = []
	for x: int in range(rect.position.x, rect.end.x):
		rows.append(shape.ceiling_row(x))
	return rows


## True if [param rows] is the whole rectangle and nothing more: a box.
func _is_box(rows: PackedInt32Array, rect: Rect2i) -> bool:
	for row: int in rows:
		if row != rect.position.y:
			return false
	return true


## The part named [param kind] ("edge", "shade") drawn at [param tile]: its mask, or 0.
func _mask(view: LabyrinthView, tile: Vector2i, kind: String) -> int:
	for visual: String in view.visuals_at(tile):
		var part: String = visual.get_slice("/", 1)
		if part.begins_with(kind + "_"):
			return int(part.get_slice("_", 1))
	return 0


## The sides (N, E, S, W bits) of [param tile] whose neighbour is open in [param view].
func _open_sides(view: LabyrinthView, tile: Vector2i) -> int:
	var sides: int = 0
	if view.is_open(tile + Vector2i.UP):
		sides |= N
	if view.is_open(tile + Vector2i.RIGHT):
		sides |= E
	if view.is_open(tile + Vector2i.DOWN):
		sides |= S
	if view.is_open(tile + Vector2i.LEFT):
		sides |= W
	return sides


## An ambience over [param view], as the world makes it.
func _dress(view: LabyrinthView) -> Ambience:
	var ambience := Ambience.new()
	add_child_autofree(ambience)
	ambience.set_process(false)
	ambience.setup(view)
	return ambience


## The room of [param level] whose columns and floor hold the pixel rectangle [param at].
func _room_holding(level: LabyrinthLevel, at: Rect2) -> LabyrinthChamber:
	var column: int = floori(at.get_center().x / TILE)
	var best: LabyrinthChamber = null
	for room: LabyrinthChamber in _rooms(level):
		if column < room.rect.position.x or column >= room.rect.end.x:
			continue
		var floor_px: float = room.rect.end.y * TILE
		if at.position.y >= floor_px or at.position.y < floor_px - (MOST_ROWS + 1) * TILE:
			continue
		best = room
	return best


# --- R1 ------------------------------------------------------------------------


func test_r1_the_simulation_is_as_it_was() -> void:
	for seed_value: int in RECORDED_HASHES:
		var sim: Simulation = winding_simulation(seed_value)
		run_ticks(sim, ticks_in(300.0))
		assert_eq(
			sim.state_hash(),
			RECORDED_HASHES[seed_value],
			"seed %d: the state after 5 minutes hashes as it did" % seed_value
		)


# --- R2 ------------------------------------------------------------------------


func test_r2_rooms_are_not_boxes() -> void:
	for area: StringName in AREAS:
		var seen: Array[int] = [0, 0, 0]  # rooms; of more than one height; with earth in the rect
		for seed_value: int in range(1, 4):
			_stages_of(
				seed_value,
				area,
				func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
					for room: LabyrinthChamber in _rooms(level):
						var heights: Dictionary[int, bool] = {}
						var earth: int = 0
						for row: int in _profile(view, room):
							heights[row] = true
							earth += maxi(row - room.rect.position.y, 0)
						seen[0] += 1
						seen[1] += 1 if heights.size() > 1 else 0
						seen[2] += 1 if earth > 0 else 0
					var bare: int = 0
					var unshaded: int = 0
					var band: Rect2i = level.band
					for y: int in range(band.position.y, band.end.y):
						for x: int in WIDTH:
							var tile := Vector2i(x, y)
							var sides: int = _open_sides(view, tile)
							if view.is_open(tile):
								var shade: int = (N | E | W) & ~sides
								unshaded += 1 if _mask(view, tile, "shade") != shade else 0
							elif _mask(view, tile, "edge") != sides:
								bare += 1
					assert_eq(bare, 0, "%s: an edge on every earth tile beside an open one" % what)
					assert_eq(unshaded, 0, "%s: shade under every ceiling and by every wall" % what)
			)
		assert_gt(seen[0], 60, "%s: rooms were looked at" % area)
		assert_gt(seen[1] * 2, seen[0], "%s: most rooms have a ceiling of several heights" % area)
		assert_gt(seen[2] * 2, seen[0], "%s: most rooms leave some of their rectangle earth" % area)

	# A view that is not zoned, and a flat one, draw their boxes.
	var plain := LabyrinthView.new()
	plain.labyrinth = winding_labyrinth(1)
	add_child_autofree(plain)
	assert_null(plain.shapes(1), "a view that is not zoned cuts no shapes")
	var flat_labyrinth := Labyrinth.new(1)
	var flat := LabyrinthView.new()
	flat.labyrinth = flat_labyrinth
	flat.zoned = true
	add_child_autofree(flat)
	flat.set_focus(Vector2(0.0, flat_labyrinth.level(1).floor_y))
	assert_null(flat.shapes(1), "a flat stage cuts no shapes")
	for room: LabyrinthChamber in flat_labyrinth.level(1).chambers:
		assert_true(_is_box(_profile(flat, room), room.rect), "a flat stage's room is its box")
		assert_false(flat.is_open(room.rect.position + Vector2i.UP), "and nothing over it")


# --- R3 ------------------------------------------------------------------------


func test_r3_there_is_room_to_stand_and_to_pass() -> void:
	var checked: Dictionary[String, int] = {"ladder": 0, "mouth": 0, "door": 0}
	_every_stage(
		SEEDS,
		func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
			var shut: Array[String] = []
			for room: LabyrinthChamber in _rooms(level):
				var rect: Rect2i = room.rect
				var floor_row: int = room.floor_row()
				var where: String = "%s room %d at %s" % [what, room.index, rect.position]
				for x: int in range(rect.position.x, rect.end.x):
					for y: int in range(
						floor_row - mini(STANDING_ROWS, rect.size.y) + 1, rect.end.y
					):
						if not view.is_open(Vector2i(x, y)):
							shut.append("%s: (%d, %d) of its lowest rows" % [where, x, y])
				for passage: Rect2i in _passages(level):
					var in_columns: bool = (
						passage.position.x >= rect.position.x and passage.end.x <= rect.end.x
					)
					var leaves: bool = passage.position.y - 1 == floor_row
					var lands: bool = passage.end.y - 1 == floor_row
					if passage.size.x == Labyrinth.SHAFT_WIDTH and in_columns and (leaves or lands):
						checked["ladder"] += 1
						for x: int in range(passage.position.x, passage.end.x):
							for y: int in range(rect.position.y, rect.end.y):
								if not view.is_open(Vector2i(x, y)):
									shut.append("%s: (%d, %d) of a ladder's column" % [where, x, y])
					var beside: int = -1
					if passage.end.y == rect.end.y and passage.position.x == rect.end.x:
						beside = rect.end.x - 1
					elif passage.end.y == rect.end.y and passage.end.x == rect.position.x:
						beside = rect.position.x
					if beside >= 0:
						checked["mouth"] += 1
						for y: int in range(passage.position.y - 1, rect.end.y):
							var tile := Vector2i(beside, y)
							if rect.has_point(tile) and not view.is_open(tile):
								shut.append("%s: %s by a tunnel's mouth" % [where, tile])
				var pixels := Rect2(rect.position * TILE, rect.size * TILE)
				for door: Rect2 in view.doorways(level.depth):
					if not pixels.intersects(door):
						continue
					checked["door"] += 1
					var top: int = floori(door.position.y / TILE) - 1
					for x: int in range(floori(door.position.x / TILE), ceili(door.end.x / TILE)):
						for y: int in range(maxi(top, rect.position.y), rect.end.y):
							if not view.is_open(Vector2i(x, y)):
								shut.append("%s: (%d, %d) over a doorway" % [where, x, y])
			assert_eq(shut, [] as Array[String], "%s: room to stand and to pass" % what)
	)
	for kind: String in checked:
		assert_gt(checked[kind], 0, "a %s was checked" % kind)

	# Nothing that stands on a floor is taller than the rows kept open over it.
	var tallest: int = 0
	var tallest_sheet: String = ""
	for folder: String in ["res://assets/sprites/heroes/", "res://assets/sprites/monsters/"]:
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with(".png"):
				continue
			var height: int = PixelSheet.load_sheet(folder + file).size.y
			if height > tallest:
				tallest = height
				tallest_sheet = file
	assert_gt(tallest, 0, "sheets were measured")
	assert_lte(
		tallest,
		STANDING_ROWS * TILE,
		"the tallest sheet (%s) stands under the rows" % tallest_sheet
	)


# --- R4 ------------------------------------------------------------------------


func test_r4_shapes_join_nothing() -> void:
	var raised: Array[int] = [0]
	_every_stage(
		SEEDS,
		func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
			var band: Rect2i = level.band
			var rooms: Array[LabyrinthChamber] = _rooms(level)
			var passages: Array[Rect2i] = _passages(level)
			# Every open tile is a passage's, or a room's: in its columns, on or over its floor and
			# no more than 8 rows over it.
			var holder: Dictionary[Vector2i, int] = {}
			var open: Array[Vector2i] = []
			var stray: Array[Vector2i] = []
			for y: int in range(band.position.y - 1, band.end.y + 1):
				for x: int in range(-1, WIDTH + 1):
					var tile := Vector2i(x, y)
					if not view.is_open(tile):
						continue
					open.append(tile)
					var held: bool = false
					for passage: Rect2i in passages:
						held = held or passage.has_point(tile)
					for i: int in rooms.size():
						var rect: Rect2i = rooms[i].rect
						var reach := Rect2i(
							rect.position.x, rect.end.y - MOST_ROWS, rect.size.x, MOST_ROWS
						)
						if reach.has_point(tile) and (rect.has_point(tile) or not held):
							holder[tile] = i
							held = true
							raised[0] += 1 if tile.y < rect.position.y else 0
					if not held:
						stray.append(tile)
			assert_eq(
				stray, [] as Array[Vector2i], "%s: nothing open outside a room's reach" % what
			)
			# A room's tiles are beside or diagonal to no open tile but its own and those of the
			# passages its rectangle touches.
			var joined: Array[String] = []
			for tile: Vector2i in holder:
				var room: LabyrinthChamber = rooms[holder[tile]]
				for step: Vector2i in NEAR:
					var beside: Vector2i = tile + step
					if not view.is_open(beside) or holder.get(beside, -1) == holder[tile]:
						continue
					var known: bool = false
					for passage: Rect2i in passages:
						if passage.has_point(beside) and room.rect.grow(1).intersects(passage):
							known = true
					if not known:
						joined.append("%s by %s" % [tile, beside])
			assert_eq(joined, [] as Array[String], "%s: a shape joins nothing new" % what)
			# And the stage is still one place: every open tile is reached from the first room.
			var reached: Dictionary[Vector2i, bool] = {}
			var frontier: Array[Vector2i] = [
				Vector2i(rooms[0].rect.position.x, rooms[0].floor_row())
			]
			reached[frontier[0]] = true
			while not frontier.is_empty():
				var at: Vector2i = frontier.pop_back()
				for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var next: Vector2i = at + step
					if view.is_open(next) and not reached.has(next):
						reached[next] = true
						frontier.append(next)
			assert_eq(reached.size(), open.size(), "%s: every open tile is reached" % what)
	)
	assert_gt(raised[0], 0, "rooms were opened above their rectangles")


# --- R5 ------------------------------------------------------------------------


func test_r5_each_area_is_cut_its_own_way() -> void:
	# The same 20 rooms, cut in each area's manner.
	var labyrinth: Labyrinth = winding_labyrinth(1)
	var step: Dictionary[StringName, float] = {}
	var run: Dictionary[StringName, float] = {}
	var cut_corners: Dictionary[StringName, int] = {}
	var corners: int = 0
	for area: StringName in AREAS:
		var moved: int = 0
		var pairs: int = 0
		var runs: int = 0
		var columns: int = 0
		var cut: int = 0
		var rooms: int = 0
		corners = 0
		for stage: int in range(1, STAGES + 1):
			var level: LabyrinthLevel = labyrinth.level(stage)
			for room: LabyrinthChamber in _rooms(level):
				if rooms == 20:
					break
				rooms += 1
				var shape: RoomShape = RoomShape.of(
					labyrinth, level, room, ZoneLook.of(area, stage)
				)
				var rows: PackedInt32Array = _profile_of(shape, room.rect)
				runs += 1
				columns += rows.size()
				for i: int in range(1, rows.size()):
					moved += absi(rows[i] - rows[i - 1])
					pairs += 1
					runs += 1 if rows[i] != rows[i - 1] else 0
				corners += 2
				cut += 1 if rows[0] > rows[1] else 0
				cut += 1 if rows[rows.size() - 1] > rows[rows.size() - 2] else 0
		assert_eq(rooms, 20, "%s: 20 rooms were cut" % area)
		step[area] = float(moved) / pairs
		run[area] = float(columns) / runs
		cut_corners[area] = cut
	gut.p("mean step %s, mean run %s, cut corners %s of %d" % [step, run, cut_corners, corners])
	for area: StringName in AREAS:
		if area != EMBER:
			assert_gt(
				step[EMBER], step[area], "the Ember Deep's ceiling moves more than %s's" % area
			)
		if area != CRYPT:
			assert_lt(
				step[CRYPT], step[area], "the Old Crypt's ceiling moves less than %s's" % area
			)
		if area != CLAY:
			assert_gt(run[CLAY], run[area], "the Claypits' runs are wider than %s's" % area)
	assert_gte(cut_corners[MOSSY], corners - 2, "Mossy Hollow's corners are cut")
	assert_eq(cut_corners[CRYPT], 0, "the Old Crypt's corners are square")

	# And the table says so.
	var cuts: Dictionary[StringName, RoomCut] = {}
	for area: StringName in AREAS:
		cuts[area] = ZoneLook.of(area, 1).cut()
	assert_true(cuts[MOSSY].round_corners, "the table: Mossy Hollow's corners are round")
	assert_false(cuts[CRYPT].round_corners, "the table: the Old Crypt's are square")
	assert_eq(cuts[CRYPT].lean, 0, "the table: the Old Crypt's walls are upright")
	assert_true(cuts[CRYPT].raised_middle, "the table: the Old Crypt has a raised middle")
	for area: StringName in AREAS:
		if area != CLAY:
			assert_gt(
				cuts[CLAY].run.x, cuts[area].run.y, "the table: the Claypits' runs are widest"
			)
		if area != EMBER:
			var more: bool = (
				cuts[EMBER].step.y * cuts[area].run.x > cuts[area].step.y * cuts[EMBER].run.x
			)
			assert_true(more, "the table: the Ember Deep moves more a column than %s" % area)


# --- R6 ------------------------------------------------------------------------


func test_r6_a_shape_is_the_same_every_time() -> void:
	var differing: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var area: StringName = AREAS[seed_value % AREAS.size()]
		var what: String = "%s seed %d" % [area, seed_value]
		var labyrinth: Labyrinth = _labyrinth(seed_value, area)
		var view: LabyrinthView = zoned_view(labyrinth, 2, area)
		var second: LabyrinthView = zoned_view(_labyrinth(seed_value, area), 2, area)
		var level: LabyrinthLevel = labyrinth.level(2)
		var first_open: Array[Vector2i] = []
		var second_open: Array[Vector2i] = []
		var again_open: Array[Vector2i] = []
		var band: Rect2i = level.band
		for pass_number: int in 2:
			for y: int in range(band.position.y, band.end.y):
				for x: int in WIDTH:
					var tile := Vector2i(x, y)
					if pass_number == 0 and view.is_open(tile):
						first_open.append(tile)
					if pass_number == 0 and second.is_open(tile):
						second_open.append(tile)
					if pass_number == 1 and view.is_open(tile):
						again_open.append(tile)
			if pass_number == 0:
				# Built again: shown another labyrinth, then this one.
				view.show_labyrinth(_labyrinth(seed_value + 100, area))
				view.set_focus(Vector2(0.0, level.floor_y))
				view.show_labyrinth(labyrinth)
				view.set_focus(Vector2(0.0, level.floor_y))
		assert_gt(first_open.size(), 0, "%s: the stage has open tiles" % what)
		assert_eq(second_open, first_open, "%s: a second view opens the same tiles" % what)
		assert_eq(again_open, first_open, "%s: built again, the same tiles" % what)
		view.free()
		second.free()

		# The first two rooms of one size on a stage of this seed.
		var found: bool = false
		for stage: int in range(1, 60):
			var shapes: StageShapes = StageShapes.of(labyrinth, stage, ZoneLook.of(area, stage))
			var by_size: Dictionary[Vector2i, PackedInt32Array] = {}
			for room: LabyrinthChamber in _rooms(labyrinth.level(stage)):
				var rows: PackedInt32Array = _profile_of(shapes.shape_of(room), room.rect)
				for i: int in rows.size():
					rows[i] -= room.rect.position.y
				if by_size.has(room.rect.size):
					found = true
					differing += 1 if by_size[room.rect.size] != rows else 0
					break
				by_size[room.rect.size] = rows
			if found:
				break
		assert_true(found, "%s: two rooms of one size were found" % what)
	assert_gte(differing, 8, "two rooms of one size differ on at least 8 of %d seeds" % SEEDS)


# --- R7 ------------------------------------------------------------------------


func test_r7_the_ambience_follows_the_shape() -> void:
	var seen: Dictionary[String, int] = {"torch": 0, "hung": 0, "moved": 0, "earth": 0}
	_every_stage(
		SEEDS,
		func(what: String, level: LabyrinthLevel, view: LabyrinthView) -> void:
			var ambience: Ambience = _dress(view)
			var dressed: AmbienceLevel = ambience.level(level.depth)
			var wrong: Array[String] = []
			for torch: AmbienceProp in dressed.torches + dressed.cache_torches:
				seen["torch"] += 1
				var flame := Vector2i((torch.light.position / TILE).floor())
				if not view.is_open(flame):
					wrong.append("the flame at %s is in earth" % flame)
				for step: Vector2i in NEAR:
					if not view.is_open(flame + step):
						wrong.append("earth at %s by the flame at %s" % [flame + step, flame])
			for prop: AmbienceProp in (
				dressed.torches + dressed.cache_torches + dressed.props + dressed.cache_props
			):
				# What sinks into the ragged ceiling or the floor's crust is not counted.
				var body: Rect2 = prop.rect
				if prop.anchor == AmbienceProp.Anchor.CEILING:
					body = body.grow_side(SIDE_TOP, -2.0)
				elif prop.name == &"puddle":
					body = body.grow_side(SIDE_BOTTOM, -2.0)
				for y: int in range(floori(body.position.y / TILE), ceili(body.end.y / TILE)):
					for x: int in range(floori(body.position.x / TILE), ceili(body.end.x / TILE)):
						if not view.is_open(Vector2i(x, y)):
							wrong.append("the %s at %s lies in earth" % [prop.name, prop.rect])
				if prop.anchor != AmbienceProp.Anchor.CEILING:
					continue
				seen["hung"] += 1
				var room: LabyrinthChamber = _room_holding(level, prop.rect)
				if room == null:
					wrong.append("the %s at %s hangs in no room" % [prop.name, prop.rect])
					continue
				var column: int = floori(prop.rect.get_center().x / TILE)
				var ceiling: int = _ceiling(view, room, column)
				if prop.rect.position.y != ceiling * TILE - 2.0:
					wrong.append("the %s at %s is not on its ceiling" % [prop.name, prop.rect])
				seen["moved"] += 1 if ceiling != room.rect.position.y else 0
			for from: Vector2 in dressed.drip_points():
				var tile := Vector2i((from / TILE).floor())
				if not view.is_open(tile) or view.is_open(tile + Vector2i.UP):
					wrong.append("a drip falls from %s, which is no ceiling" % from)
			var unlit: int = 0
			var lit_earth: int = 0
			for room: LabyrinthChamber in _rooms(level):
				var bounds: Rect2i = view.shapes(level.depth).shape_of(room).bounds()
				for y: int in range(bounds.position.y, bounds.end.y):
					for x: int in range(bounds.position.x, bounds.end.x):
						var tile := Vector2i(x, y)
						var exposure: float = dressed.exposure_at(tile)
						if view.is_open(tile):
							unlit += 1 if exposure < 0.99 else 0
						elif room.rect.has_point(tile):
							seen["earth"] += 1
							lit_earth += 1 if exposure > AmbienceMood.EDGE_EXPOSURE + 0.01 else 0
			assert_eq(wrong, [] as Array[String], "%s: everything is placed by the shape" % what)
			assert_eq(unlit, 0, "%s: the light reaches every open tile of a room" % what)
			assert_eq(lit_earth, 0, "%s: a tile of a rectangle left as earth is buried" % what)
			# Half a minute of motion: no ember and no dust is in earth.
			var buried_motes: int = 0
			for i: int in 300:
				ambience.advance(0.1)
				for mote: AmbienceMote in dressed.motes:
					if mote.kind != &"ember" and mote.kind != &"dust":
						continue
					if not view.is_open(Vector2i((mote.position / TILE).floor())):
						buried_motes += 1
			assert_eq(buried_motes, 0, "%s: no ember and no dust drifts into earth" % what)
	)
	assert_gt(seen["torch"], 0, "torches were checked")
	assert_gt(seen["hung"], 0, "ceiling props were checked")
	assert_gt(seen["moved"], 0, "a ceiling prop hangs from a ceiling that is not its rectangle's")
	assert_gt(seen["earth"], 0, "tiles of rectangles left as earth were checked")


# --- R8 ------------------------------------------------------------------------


func test_r8_small_rooms_have_shapes() -> void:
	for area: StringName in AREAS:
		var rooms: int = 0
		var boxes: int = 0
		var small: int = 0
		var small_boxes: int = 0
		for seed_value: int in range(1, SEEDS + 1):
			var labyrinth: Labyrinth = _labyrinth(seed_value, area)
			for stage: int in range(1, STAGES + 1):
				var level: LabyrinthLevel = labyrinth.level(stage)
				var shapes: StageShapes = StageShapes.of(labyrinth, stage, ZoneLook.of(area, stage))
				for room: LabyrinthChamber in _rooms(level):
					var box: bool = _is_box(
						_profile_of(shapes.shape_of(room), room.rect), room.rect
					)
					rooms += 1
					boxes += 1 if box else 0
					if room.rect.size.y == STANDING_ROWS or room.rect.size.x <= 10:
						small += 1
						small_boxes += 1 if box else 0
		assert_gt(small, 20, "%s: small rooms were looked at" % area)
		assert_lte(boxes * 10, rooms, "%s: at most 1 room in 10 is its rectangle" % area)
		assert_lte(small_boxes * 10, small, "%s: at most 1 small room in 10 is" % area)
