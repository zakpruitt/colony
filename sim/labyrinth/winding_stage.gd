class_name WindingStage
extends RefCounted
## Makes one stage of a winding labyrinth ([constant Labyrinth.Shape.WINDING]): rooms on two or
## three floors of a band, joined along each floor by tunnels and from floor to floor by a
## ladder, on a route that turns round at every ladder.
##
## The route is two or three runs, each a row of rooms and tunnels on a floor of its own, laid
## out as a flat level's row is. The first run is walked one way, the next the other way, and a
## ladder stands in the columns the last room of a run shares with the first room of the next.
## A stage depends on nothing but the stream it is made from, so it lines up with no other.

## Rows of world a stage takes.
const BAND_HEIGHT: int = 32
## Rows between one floor and the next.
const FLOOR_GAP: int = 10
## Floors in the band, and the top one's row in it.
const _FLOORS: int = 3
const _TOP_FLOOR_ROW: int = 9
## Rooms on the route, and in one run of it.
const _MIN_ROOMS: int = 7
const _MAX_ROOMS: int = 10
const _RUN_MIN_ROOMS: int = 2
const _RUN_MAX_ROOMS: int = 5
## The chance, in percent, that the route has two runs and not three.
const _TWO_RUNS_PERCENT: int = 35
## Room size in tiles.
const _ROOM_MIN_WIDTH: int = 10
const _ROOM_MAX_WIDTH: int = 22
const _ROOM_MIN_HEIGHT: int = 4
const _ROOM_MAX_HEIGHT: int = 8
## Tunnel size in tiles.
const _TUNNEL_MIN_LENGTH: int = 4
const _TUNNEL_MAX_LENGTH: int = 10
const _TUNNEL_HEIGHT: int = 3
## Solid columns kept at each side of the band.
const _EDGE_MARGIN: int = 1
## Open tiles kept between a ladder or a door and the side walls of its room.
const _WALL_MARGIN: int = 2
## A ladder stands at most this many columns short of the furthest place both its rooms allow,
## so the route crosses most of the room it leaves.
const _LADDER_SLACK: int = 3
## A door stands up to this many tiles further from its room's far wall than the margin.
const _DOOR_SPREAD: int = 3


## The stage at [param depth], drawn from [param rng]: its band, rooms in route order (their
## kinds left for the caller), tunnels, ladders and course.
static func make(rng: SimRng, depth: int) -> LabyrinthLevel:
	var made := LabyrinthLevel.new()
	made.depth = depth
	var top: int = (depth - 1) * BAND_HEIGHT
	made.band = Rect2i(0, top, Labyrinth.LEVEL_WIDTH, BAND_HEIGHT)
	var counts: Array[int] = _roll_counts(rng)
	var sizes: Array[int] = _roll_sizes(rng, counts)
	var lefts: Array[int] = _place_runs(rng, counts, sizes)
	var mirrored: bool = rng.next_int(0, 1) == 1
	var climbing: bool = rng.next_int(0, 1) == 1
	var highest: int = rng.next_int(0, _FLOORS - counts.size())
	# The way each room is walked in the world: 1 right, -1 left.
	var headings: Array[int] = []
	var piece: int = 0
	for run: int in counts.size():
		var storey: int = highest + (counts.size() - 1 - run if climbing else run)
		var row: int = top + _TOP_FLOOR_ROW + storey * FLOOR_GAP
		var heading: int = 1 if run % 2 == 0 else -1
		var x: int = lefts[run]
		if heading < 0:
			x += _width(sizes, _first_piece(counts, run), _pieces(counts[run]))
		for i: int in _pieces(counts[run]):
			var size: int = sizes[piece]
			piece += 1
			var left: int = x if heading > 0 else x - size
			x += heading * size
			if mirrored:
				left = Labyrinth.LEVEL_WIDTH - left - size
			if i % 2 == 1:
				made.tunnels.append(Rect2i(left, row - _TUNNEL_HEIGHT + 1, size, _TUNNEL_HEIGHT))
				continue
			var room := LabyrinthChamber.new()
			room.index = made.chambers.size()
			var height: int = rng.next_int(_ROOM_MIN_HEIGHT, _ROOM_MAX_HEIGHT)
			room.rect = Rect2i(left, row - height + 1, size, height)
			made.chambers.append(room)
			headings.append(-heading if mirrored else heading)
	made.floor_y = made.chambers[0].floor_row()
	_lay_course(rng, made, headings)
	return made


## How many rooms each run of the route has.
static func _roll_counts(rng: SimRng) -> Array[int]:
	var runs: int = 2 if rng.next_int(1, 100) <= _TWO_RUNS_PERCENT else 3
	var rooms: int = rng.next_int(_MIN_ROOMS, _MAX_ROOMS)
	var counts: Array[int] = []
	counts.resize(runs)
	counts.fill(_RUN_MIN_ROOMS)
	for _extra: int in rooms - runs * _RUN_MIN_ROOMS:
		var open: Array[int] = []
		for run: int in runs:
			if counts[run] < _RUN_MAX_ROOMS:
				open.append(run)
		counts[open[rng.next_int(0, open.size() - 1)]] += 1
	return counts


## The pieces a run of [param rooms] rooms is made of: its rooms and the tunnels between them.
static func _pieces(rooms: int) -> int:
	return 2 * rooms - 1


## The place in the list of sizes of the first piece of run [param run].
static func _first_piece(counts: Array[int], run: int) -> int:
	var first: int = 0
	for before: int in run:
		first += _pieces(counts[before])
	return first


static func _width(sizes: Array[int], first: int, pieces: int) -> int:
	var width: int = 0
	for i: int in pieces:
		width += sizes[first + i]
	return width


## The smallest size of the piece at place [param offset] in its run: a room or a tunnel.
static func _least(offset: int) -> int:
	return _ROOM_MIN_WIDTH if offset % 2 == 0 else _TUNNEL_MIN_LENGTH


## The width of every room and the length of every tunnel, run after run in route order, cut
## down until each run fits the band and the runs can be stood over one another.
static func _roll_sizes(rng: SimRng, counts: Array[int]) -> Array[int]:
	var sizes: Array[int] = []
	for rooms: int in counts:
		for i: int in _pieces(rooms):
			if i % 2 == 0:
				sizes.append(rng.next_int(_ROOM_MIN_WIDTH, _ROOM_MAX_WIDTH))
			else:
				sizes.append(rng.next_int(_TUNNEL_MIN_LENGTH, _TUNNEL_MAX_LENGTH))
	var room: int = Labyrinth.LEVEL_WIDTH - 2 * _EDGE_MARGIN
	for run: int in counts.size():
		var first: int = _first_piece(counts, run)
		while _width(sizes, first, _pieces(counts[run])) > room:
			_shrink(rng, sizes, counts, [run], -1, -1)
	if counts.size() < 3:
		return sizes
	# The middle run stands between the far ends of the other two: both must reach it.
	var ladder_room: int = _first_piece(counts, 1) - 1
	var landing_room: int = _first_piece(counts, 2)
	while true:
		var first_run: int = _width(sizes, 0, _pieces(counts[0]))
		var middle_run: int = _width(sizes, _first_piece(counts, 1), _pieces(counts[1]))
		var last_run: int = _width(sizes, landing_room, _pieces(counts[2]))
		var reach: int = room - 2 * _shared() + sizes[ladder_room] + sizes[landing_room]
		if first_run + last_run <= reach + middle_run:
			break
		_shrink(rng, sizes, counts, [0, 2], ladder_room, landing_room)
	return sizes


## Takes a tile off one piece, chosen from those of [param runs] above their smallest size other
## than the pieces at [param kept] and [param also_kept].
static func _shrink(
	rng: SimRng, sizes: Array[int], counts: Array[int], runs: Array, kept: int, also_kept: int
) -> void:
	var open: Array[int] = []
	for run: int in runs:
		var first: int = _first_piece(counts, run)
		for i: int in _pieces(counts[run]):
			var at: int = first + i
			if sizes[at] > _least(i) and at != kept and at != also_kept:
				open.append(at)
	sizes[open[rng.next_int(0, open.size() - 1)]] -= 1


## Columns two rooms one over the other must share for a ladder to stand in both.
static func _shared() -> int:
	return 2 * _WALL_MARGIN + Labyrinth.SHAFT_WIDTH


## The left column of each run, with the first run walked rightward, the next leftward and so
## on: the last room of each over (or under) the first room of the next by enough columns for
## their ladder, and every run inside the band.
static func _place_runs(rng: SimRng, counts: Array[int], sizes: Array[int]) -> Array[int]:
	var low: int = _EDGE_MARGIN
	var high: int = Labyrinth.LEVEL_WIDTH - _EDGE_MARGIN
	var shared: int = _shared()
	var middle: int = _first_piece(counts, 1)
	var first_width: int = _width(sizes, 0, _pieces(counts[0]))
	var middle_width: int = _width(sizes, middle, _pieces(counts[1]))
	# The rooms either side of the first ladder, and the middle run's last room.
	var above: int = sizes[middle - 1]
	var below: int = sizes[middle]
	var turn: int = sizes[middle + _pieces(counts[1]) - 1]
	# The middle run's right end, where its first room stands.
	var least: int = maxi(low + middle_width, low + first_width + shared - above)
	var most: int = high
	var last: int = middle + _pieces(counts[1])
	var last_width: int = 0
	if counts.size() > 2:
		last_width = _width(sizes, last, _pieces(counts[2]))
		most = mini(most, high - last_width - shared + sizes[last] + middle_width)
	var middle_end: int = rng.next_int(least, most)
	var first_end: int = rng.next_int(
		maxi(middle_end - below + shared, low + first_width),
		mini(middle_end - shared + above, high)
	)
	var lefts: Array[int] = [first_end - first_width, middle_end - middle_width]
	if counts.size() > 2:
		var middle_left: int = lefts[1]
		lefts.append(
			rng.next_int(
				maxi(middle_left + shared - sizes[last], low),
				mini(middle_left + turn - shared, high - last_width)
			)
		)
	return lefts


## Stands a ladder between each run and the next, and lays the course: from the far wall of the
## first room through every room, tunnel and ladder to the far wall of the last, with a door a
## little inside each of those walls. [param headings] is the way each room is walked.
static func _lay_course(rng: SimRng, made: LabyrinthLevel, headings: Array[int]) -> void:
	var line := StageCourse.new()
	var rooms: Array[LabyrinthChamber] = made.chambers
	var from: Vector2i = rooms[0].floor_columns()
	line.begin(Vector2(from.x if headings[0] > 0 else from.y, rooms[0].floor_row()), 0.0)
	for room: LabyrinthChamber in rooms:
		var way: int = headings[room.index]
		var row: float = room.floor_row()
		if room.index == rooms.size() - 1:
			var columns: Vector2i = room.floor_columns()
			line.line_to(Vector2(columns.y if way > 0 else columns.x, row), room.index)
			break
		var next: LabyrinthChamber = rooms[room.index + 1]
		if next.floor_row() == room.floor_row():
			# A column is in a room up to its right wall, and in the tunnel from there.
			var wall: int = room.rect.end.x if way > 0 else room.rect.position.x
			var beyond: int = next.rect.position.x if way > 0 else next.rect.end.x
			line.line_to(Vector2(wall, row), room.index)
			line.line_to(Vector2(beyond, row))
			continue
		var ladder: Rect2i = _ladder(rng, room, next, way)
		made.ladders.append(ladder)
		var rung: float = ladder.position.x + Labyrinth.SHAFT_WIDTH / 2.0
		line.line_to(Vector2(rung, row), room.index)
		line.line_to(Vector2(rung, next.floor_row()))
	line.entry = line.start + _WALL_MARGIN + rng.next_int(0, _DOOR_SPREAD)
	line.exit = line.end - _WALL_MARGIN - rng.next_int(0, _DOOR_SPREAD)
	made.course = line


## The ladder between [param room] and [param next], one over the other: from the row under the
## upper one's floor to the lower one's floor row, inside both rooms' walls by the margin, and
## far along the way [param way] that [param room] is walked.
static func _ladder(
	rng: SimRng, room: LabyrinthChamber, next: LabyrinthChamber, way: int
) -> Rect2i:
	var low: int = maxi(room.rect.position.x, next.rect.position.x) + _WALL_MARGIN
	var high: int = mini(room.rect.end.x, next.rect.end.x) - _WALL_MARGIN - Labyrinth.SHAFT_WIDTH
	var column: int
	if way > 0:
		column = rng.next_int(maxi(low, high - _LADDER_SLACK), high)
	else:
		column = rng.next_int(low, mini(high, low + _LADDER_SLACK))
	var upper: int = mini(room.floor_row(), next.floor_row())
	var lower: int = maxi(room.floor_row(), next.floor_row())
	return Rect2i(column, upper + 1, Labyrinth.SHAFT_WIDTH, lower - upper)
