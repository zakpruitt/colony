class_name RoomShape
extends RefCounted
## The tiles of one room as drawn: its rectangle with some left as earth, and what is opened
## above it.
##
## A shape is a ceiling of its own height over each column of the room, and every tile from
## there down to the floor open: the ceiling goes in level runs that step up and down, the walls
## lean in under it and the corners are cut, by the numbers of the area's [RoomCut]. It is drawing
## only. The floor is whole, and the simulation's room is still the rectangle.
##
## Whatever the cut, there is room to stand and to pass: [constant STANDING_ROWS] rows over the
## whole floor, and a ladder's columns for the rectangle's whole height. And the earth between
## places holds: nothing opens outside the room's columns, higher than [constant MOST_ROWS] over
## the floor, or beside another place the rectangle does not touch.

## Rows over a floor, the floor's own among them, open in every column: as tall as the tallest
## thing that stands on a floor, and a row more than a tunnel's mouth and a doorway.
const STANDING_ROWS: int = 4
## Rows over a floor, the floor's own among them, a shape opens at most: the tallest a room is.
const MOST_ROWS: int = 8

var _rect: Rect2i
## The world row of the highest open tile of each column of the rectangle.
var _ceilings: PackedInt32Array = []


## The shape of [param room] of [param level] in [param labyrinth], cut in the manner of
## [param look].
static func of(
	labyrinth: Labyrinth, level: LabyrinthLevel, room: LabyrinthChamber, look: ZoneLook
) -> RoomShape:
	var shape := RoomShape.new()
	var rect: Rect2i = room.rect
	shape._rect = rect
	var cut: RoomCut = look.cut()
	var label: String = "shape/%d/%d/%s" % [level.depth, room.index, rect]
	var rng: SimRng = SimRng.new(labyrinth.seed_value).fork(label)
	# Row numbers grow downward: the lowest a ceiling may be is the greatest row.
	var lowest: int = rect.end.y - mini(STANDING_ROWS, rect.size.y)
	var highest: int = rect.end.y - MOST_ROWS
	# Under a leaning wall the ceiling keeps a row over the wall's foot, so the wall has a lean.
	var deepest: int = lowest - (1 if cut.lean > 0 else 0)
	var reach: int = mini(cut.reach, deepest - highest)
	var top: int = clampi(rect.position.y - reach / 2, highest, deepest - reach)
	var rows: PackedInt32Array
	if cut.raised_middle:
		rows = _built(rng, cut, rect.size.x, top, top + reach)
	else:
		rows = _runs(rng, cut, rect.size.x, top, top + reach)
	_lean(rows, cut, lowest)
	_clear_ladders(rows, level, room, cut.lean == 0)
	_keep_earth(rows, level, room)
	shape._ceilings = rows
	return shape


## True if this world tile is open in the room as drawn.
func is_open(tile: Vector2i) -> bool:
	return tile.y < _rect.end.y and tile.y >= ceiling_row(tile.x)


## The world row of the highest open tile of [param column], or the floor row + 1 outside the
## room.
func ceiling_row(column: int) -> int:
	if column < _rect.position.x or column >= _rect.end.x:
		return _rect.end.y
	return _ceilings[column - _rect.position.x]


## The world tiles the shape reaches: the room's rectangle and whatever is opened above it.
func bounds() -> Rect2i:
	var top: int = _rect.position.y
	for row: int in _ceilings:
		top = mini(top, row)
	return Rect2i(_rect.position.x, top, _rect.size.x, _rect.end.y - top)


## A ceiling of [param width] columns in level runs between the rows [param high] and
## [param low], each run a step of the cut's size from the one before: on the same way, up or
## down, until a step would leave those rows or the cut turns it, and then back.
static func _runs(rng: SimRng, cut: RoomCut, width: int, high: int, low: int) -> PackedInt32Array:
	var rows: PackedInt32Array = []
	var row: int = rng.next_int(high, low)
	var way: int = 1 if rng.next_int(0, 1) == 1 else -1
	for run_width: int in _run_widths(rng, cut.run, width):
		if not rows.is_empty():
			var move: int = rng.next_int(cut.step.x, cut.step.y)
			if row + way * move < high or row + way * move > low:
				way = -way
			row = clampi(row + way * move, high, low)
			if rng.next_int(1, 100) <= cut.turn:
				way = -way
		for i: int in run_width:
			rows.append(row)
	return rows


## A built ceiling of [param width] columns: a level run at each side at the row [param low],
## the same width both sides, and the middle raised to [param high].
static func _built(rng: SimRng, cut: RoomCut, width: int, high: int, low: int) -> PackedInt32Array:
	var rows: PackedInt32Array = []
	var side: int = clampi(rng.next_int(cut.run.x, cut.run.y), 1, maxi((width - 2) / 2, 1))
	for x: int in width:
		rows.append(low if x < side or x >= width - side else high)
	return rows


## The widths of the runs of a ceiling [param width] columns wide, each between the least
## ([code]run.x[/code]) and the most ([code]run.y[/code]) where the room allows: the last takes
## what is left, and a room too narrow for two runs is still cut in two.
static func _run_widths(rng: SimRng, run: Vector2i, width: int) -> Array[int]:
	var widths: Array[int] = []
	var left: int = width
	while left > 0:
		var run_width: int = mini(rng.next_int(run.x, run.y), left)
		if left - run_width < run.x:
			run_width = left
			if widths.is_empty() and left > 1:
				var least: int = maxi(left * 2 / 5, 1)
				run_width = rng.next_int(least, left - least)
				widths.append(left - run_width)
		widths.append(run_width)
		left = width
		for taken: int in widths:
			left -= taken
	return widths


## Leans the walls of the ceiling [param rows] in: over the cut's lean, each column nearer a wall
## is a row lower than the one before, the wall's own column two lower where corners are round,
## and none lower than [param lowest]. A ceiling too low at a wall leans over fewer columns.
static func _lean(rows: PackedInt32Array, cut: RoomCut, lowest: int) -> void:
	var width: int = rows.size()
	for side: int in 2:
		var lean: int = mini(cut.lean, (width - 2) / 2)
		while lean > 0 and rows[_from_wall(side, lean, width)] > lowest - lean:
			lean -= 1
		for i: int in range(lean - 1, -1, -1):
			var drop: int = 2 if cut.round_corners and i == 0 else 1
			var inner: int = rows[_from_wall(side, i + 1, width)]
			rows[_from_wall(side, i, width)] = mini(lowest - i, inner + drop)


## The place in a ceiling [param width] columns wide of the column [param steps] from the left
## wall ([param side] 0) or the right (1).
static func _from_wall(side: int, steps: int, width: int) -> int:
	return steps if side == 0 else width - 1 - steps


## Opens the columns of every ladder that meets [param room], and the one either side of them,
## for the rectangle's whole height; with [param square], a wall's column too where that leaves
## it alone under a lower ceiling, so an upright wall keeps its square corner.
static func _clear_ladders(
	rows: PackedInt32Array, level: LabyrinthLevel, room: LabyrinthChamber, square: bool
) -> void:
	var rect: Rect2i = room.rect
	for ladder: Rect2i in level.ladders + level.side_ladders():
		if ladder.position.x < rect.position.x or ladder.end.x > rect.end.x:
			continue
		if ladder.position.y - 1 != room.floor_row() and ladder.end.y - 1 != room.floor_row():
			continue
		var from: int = ladder.position.x - 1
		var to: int = ladder.end.x + 1
		if square and from == rect.position.x + 1:
			from = rect.position.x
		if square and to == rect.end.x - 1:
			to = rect.end.x
		for column: int in range(from, to):
			var at: int = column - rect.position.x
			if at >= 0 and at < rows.size():
				rows[at] = mini(rows[at], rect.position.y)


## Closes again, down to the rectangle's top, every column opened above it beside or diagonal to
## where another room may be open, or a tunnel or ladder the rectangle does not touch.
static func _keep_earth(
	rows: PackedInt32Array, level: LabyrinthLevel, room: LabyrinthChamber
) -> void:
	var rect: Rect2i = room.rect
	var others: Array[Rect2i] = []
	var rooms: Array[LabyrinthChamber] = level.chambers.duplicate()
	var passages: Array[Rect2i] = level.tunnels + level.ladders
	for path: SidePath in level.side_paths:
		rooms.append(path.room)
		passages.append(path.tunnel)
		passages.append(path.ladder)
	for other: LabyrinthChamber in rooms:
		if other != room:
			var reach: Rect2i = other.rect
			others.append(
				Rect2i(reach.position.x, reach.end.y - MOST_ROWS, reach.size.x, MOST_ROWS)
			)
	for passage: Rect2i in passages:
		if passage.has_area() and not rect.grow(1).intersects(passage):
			others.append(passage)
	for at: int in rows.size():
		if rows[at] >= rect.position.y:
			continue
		var opened := Rect2i(rect.position.x + at, rows[at], 1, rect.position.y - rows[at]).grow(1)
		for other: Rect2i in others:
			if opened.intersects(other):
				rows[at] = rect.position.y
				break
