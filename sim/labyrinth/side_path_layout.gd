class_name SidePathLayout
extends RefCounted
## Fits side paths ([SidePath]) round a winding stage's main route, changing nothing of it: up to
## [constant MOST], each from a room of its own that is neither the first nor the last, by the
## rules the route's own rooms keep (no overlap, earth between, inside the band's margin).
##
## A side path goes one of two ways. By a ladder of its own, from a column of the room's floor
## that the main course walks, to a cache room on the floor above or below. Or, from a room with
## a free side wall (the room at either end of a ladder of the route), along the floor from
## where the main course ends to that wall, and through a tunnel of its own to a cache room on
## the same floor.

## The most side paths a stage has.
const MOST: int = 3
## A cache room's size in tiles, least and most.
const CACHE_WIDTH: Vector2i = Vector2i(8, 12)
const CACHE_HEIGHT: Vector2i = Vector2i(4, 5)
## A side tunnel's length, least and most, and its height.
const TUNNEL_LENGTH: Vector2i = Vector2i(4, 10)
const _TUNNEL_HEIGHT: int = 3
## Open tiles kept between a side ladder and the side walls of both its rooms.
const _WALL_MARGIN: int = 2
## Tiles a gate stands clear of the columns of a ladder of the route, and of a doorway.
const GATE_CLEAR: float = 2.0
## The ways a side path may leave a room: up or down a ladder, or by a tunnel left or right.
const _UP: int = -2
const _LEFT: int = -1
const _RIGHT: int = 1
const _DOWN: int = 2


## Gives [param level], a winding stage whose route is made, as many of [constant MOST] side
## paths as fit, drawn from [param rng] alone.
static func fit(level: LabyrinthLevel, rng: SimRng) -> void:
	var gates: Array[StringName] = Content.gate_ids()
	if gates.is_empty():
		return
	var slots: Array[Vector2i] = []
	for index: int in range(1, level.chambers.size() - 1):
		for way: int in [_UP, _LEFT, _RIGHT, _DOWN]:
			slots.append(Vector2i(index, way))
	for i: int in range(slots.size() - 1, 0, -1):
		var other: int = rng.next_int(0, i)
		var held: Vector2i = slots[i]
		slots[i] = slots[other]
		slots[other] = held
	var used: Dictionary[int, bool] = {}
	for slot: Vector2i in slots:
		if level.side_paths.size() >= MOST:
			break
		if used.has(slot.x):
			continue
		var made: SidePath
		if absi(slot.y) == _DOWN:
			made = _by_ladder(level, rng, slot.x, signi(slot.y))
		else:
			made = _by_tunnel(level, rng, slot.x, slot.y)
		if made == null:
			continue
		made.gate = gates[rng.next_int(0, gates.size() - 1)]
		used[slot.x] = true
		level.side_paths.append(made)
	level.side_paths.sort_custom(func(a: SidePath, b: SidePath) -> bool: return a.at < b.at)


## A side path from room [param index] by a ladder up ([param way] -1) or down (1), or null if
## none fits: first with the cache room's size as rolled, then with the smallest.
static func _by_ladder(level: LabyrinthLevel, rng: SimRng, index: int, way: int) -> SidePath:
	var from: LabyrinthChamber = level.chambers[index]
	var row: int = from.floor_row() + way * WindingStage.FLOOR_GAP
	var storey: int = row - level.band.position.y - WindingStage._TOP_FLOOR_ROW
	if storey < 0 or storey > (WindingStage._FLOORS - 1) * WindingStage.FLOOR_GAP:
		return null
	var rolled := Vector2i(
		rng.next_int(CACHE_WIDTH.x, CACHE_WIDTH.y), rng.next_int(CACHE_HEIGHT.x, CACHE_HEIGHT.y)
	)
	var walked: Vector2 = _walked(level, index)
	for size: Vector2i in [rolled, Vector2i(CACHE_WIDTH.x, CACHE_HEIGHT.x)]:
		# Each place it fits, as Vector2i(the ladder's left column, the cache room's).
		var places: Array[Vector2i] = []
		var last: int = from.rect.end.x - _WALL_MARGIN - Labyrinth.SHAFT_WIDTH
		for column: int in range(from.rect.position.x + _WALL_MARGIN, last + 1):
			var rung: float = column + Labyrinth.SHAFT_WIDTH / 2.0
			if rung < walked.x or rung > walked.y:
				continue
			if not _gate_clear(level, Vector2(rung, from.floor_row())):
				continue
			var shaft: Rect2i = _ladder_rect(column, from.floor_row(), row)
			var least: int = column + Labyrinth.SHAFT_WIDTH + _WALL_MARGIN - size.x
			for left: int in range(least, column - _WALL_MARGIN + 1):
				var cache := Rect2i(left, row - size.y + 1, size.x, size.y)
				if _fits(level, cache, []) and _fits(level, shaft, [from.rect, cache]):
					places.append(Vector2i(column, left))
		if places.is_empty():
			continue
		var place: Vector2i = places[rng.next_int(0, places.size() - 1)]
		var made := SidePath.new()
		made.room = _cache_room(Rect2i(place.y, row - size.y + 1, size.x, size.y))
		made.ladder = _ladder_rect(place.x, from.floor_row(), row)
		var middle: float = place.x + Labyrinth.SHAFT_WIDTH / 2.0
		made.at = level.course.distance_in(index, middle)
		made.gate_at = 0.0
		var columns: Vector2i = made.room.floor_columns()
		# To the wall further from the ladder, so the party crosses the room.
		var far: float = columns.x if middle - columns.x >= columns.y - middle else columns.y
		made.course = StageCourse.new()
		made.course.begin(Vector2(middle, from.floor_row()), 0.0)
		made.course.line_to(Vector2(middle, row))
		made.course.line_to(Vector2(far, row))
		return made
	return null


## A side path from room [param index] by a tunnel through its left ([param way] -1) or right
## (1) wall, or null if that wall is taken or nothing fits: first with the sizes as rolled, then
## with the smallest.
static func _by_tunnel(level: LabyrinthLevel, rng: SimRng, index: int, way: int) -> SidePath:
	var from: LabyrinthChamber = level.chambers[index]
	var row: int = from.floor_row()
	var wall: int = from.rect.end.x if way > 0 else from.rect.position.x
	for joined: Rect2i in level.tunnels:
		var beside: bool = joined.position.x == wall or joined.end.x == wall
		if beside and joined.end.y == from.rect.end.y:
			return null
	var rolled := Vector3i(
		rng.next_int(CACHE_WIDTH.x, CACHE_WIDTH.y),
		rng.next_int(CACHE_HEIGHT.x, CACHE_HEIGHT.y),
		rng.next_int(TUNNEL_LENGTH.x, TUNNEL_LENGTH.y)
	)
	var walked: Vector2 = _walked(level, index)
	# Where the main course comes nearest that wall.
	var leaves: float = walked.y if way > 0 else walked.x
	if not _gate_clear(level, Vector2(wall, row)):
		return null
	for size: Vector3i in [rolled, Vector3i(CACHE_WIDTH.x, CACHE_HEIGHT.x, TUNNEL_LENGTH.x)]:
		var tunnel_left: int = wall if way > 0 else wall - size.z
		var tunnel := Rect2i(tunnel_left, row - _TUNNEL_HEIGHT + 1, size.z, _TUNNEL_HEIGHT)
		var cache_left: int = wall + size.z if way > 0 else wall - size.z - size.x
		var cache := Rect2i(cache_left, row - size.y + 1, size.x, size.y)
		if not _fits(level, tunnel, [from.rect]) or not _fits(level, cache, []):
			continue
		var made := SidePath.new()
		made.room = _cache_room(cache)
		made.tunnel = tunnel
		made.at = level.course.distance_in(index, leaves)
		made.gate_at = absf(wall - leaves)
		var columns: Vector2i = made.room.floor_columns()
		made.course = StageCourse.new()
		made.course.begin(Vector2(leaves, row), 0.0)
		made.course.line_to(Vector2(wall, row))
		made.course.line_to(Vector2(cache.position.x if way > 0 else cache.end.x, row))
		made.course.line_to(Vector2(columns.y if way > 0 else columns.x, row))
		return made
	return null


static func _cache_room(rect: Rect2i) -> LabyrinthChamber:
	var room := LabyrinthChamber.new()
	room.index = -1
	room.kind = LabyrinthChamber.Kind.CACHE
	room.rect = rect
	return room


## The ladder at [param column] between floor rows [param a] and [param b]: from the row under
## the upper floor to the lower floor's row.
static func _ladder_rect(column: int, a: int, b: int) -> Rect2i:
	var upper: int = mini(a, b)
	return Rect2i(column, upper + 1, Labyrinth.SHAFT_WIDTH, maxi(a, b) - upper)


## The first (x) and last (y) world column the main course walks on the floor of room
## [param index].
static func _walked(level: LabyrinthLevel, index: int) -> Vector2:
	var stretch: Vector2 = level.course.stretch_of(index)
	var first: float = level.course.point_at(stretch.x).x
	var last: float = level.course.point_at(stretch.y).x
	return Vector2(minf(first, last), maxf(first, last))


## True if a gate with its feet at [param feet] stands [constant GATE_CLEAR] tiles clear of the
## columns of every ladder of the route that meets that floor, and of the stage's doorways.
static func _gate_clear(level: LabyrinthLevel, feet: Vector2) -> bool:
	var row: int = roundi(feet.y)
	for ladder: Rect2i in level.ladders:
		if ladder.position.y - 1 != row and ladder.end.y - 1 != row:
			continue
		var before: bool = feet.x <= ladder.position.x - GATE_CLEAR
		if not before and feet.x < ladder.end.x + GATE_CLEAR:
			return false
	for door: float in [level.course.entry, level.course.exit]:
		var at: Vector2 = level.course.point_at(door)
		if is_equal_approx(at.y, feet.y) and absf(at.x - feet.x) < GATE_CLEAR:
			return false
	return true


## True if [param rect] is inside the band's margin and has earth between it and every open
## rectangle of [param level], its side paths' too, other than those of [param joined].
static func _fits(level: LabyrinthLevel, rect: Rect2i, joined: Array[Rect2i]) -> bool:
	if not level.band.grow(-1).encloses(rect):
		return false
	var grown: Rect2i = rect.grow(1)
	for others: Array[Rect2i] in [level.open_rects(), level.side_rects()]:
		for other: Rect2i in others:
			if grown.intersects(other) and not joined.has(other):
				return false
	return true
