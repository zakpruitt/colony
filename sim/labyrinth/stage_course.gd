class_name StageCourse
extends RefCounted
## The line a party walks through one stage: feet positions in world tiles joined by straight
## runs (level along a floor, or straight up a ladder), each point at a distance from the first.
##
## Feet at column c stand on the tile from c to c + 1, so where two level runs meet the point
## belongs to the run on its right, and where a ladder meets a floor it belongs to the floor.

## Distances of the two ends of the line, of where a party from the stage before arrives, and of
## where the way on to the next stage leaves.
var start: float
var end: float
var entry: float
var exit: float

## The line's corners in order, and the distance of each; run i joins corner i to corner i + 1.
var _corners: PackedVector2Array = PackedVector2Array()
var _marks: PackedFloat64Array = PackedFloat64Array()
## Of each run: its chamber (-1 for none), the way it goes in the world (1 right, -1 left, 0 on a
## ladder), and what its distance is added to, as [code]base + way * distance[/code], to give the
## column (a level run) or the row (a ladder, whose way is then 1 down or -1 up).
var _rooms: PackedInt32Array = PackedInt32Array()
var _headings: PackedInt32Array = PackedInt32Array()
var _ways: PackedInt32Array = PackedInt32Array()
var _bases: PackedFloat64Array = PackedFloat64Array()


## Starts the line at [param at], which is at [param distance] (a flat level starts at its column).
func begin(at: Vector2, distance: float) -> void:
	_corners = PackedVector2Array([at])
	_marks = PackedFloat64Array([distance])
	_rooms.clear()
	_headings.clear()
	_ways.clear()
	_bases.clear()
	start = distance
	end = distance
	entry = distance
	exit = distance


## Runs the line on to [param at], level or straight up or down. The run is inside chamber
## [param chamber_index], or in a tunnel or on a ladder (-1).
func line_to(at: Vector2, chamber_index: int = -1) -> void:
	assert(not _corners.is_empty(), "begin the line first")
	var from: Vector2 = _corners[_corners.size() - 1]
	var level: bool = is_equal_approx(at.y, from.y)
	assert(level or is_equal_approx(at.x, from.x), "a run is level or straight up or down")
	var length: float = absf(at.x - from.x) if level else absf(at.y - from.y)
	if is_zero_approx(length):
		return
	var way: int = signi(roundi(at.x - from.x)) if level else signi(roundi(at.y - from.y))
	_rooms.append(chamber_index)
	_headings.append(way if level else 0)
	_ways.append(way)
	_bases.append((from.x if level else from.y) - way * end)
	end += length
	_corners.append(at)
	_marks.append(end)


## Feet position in world tiles at [param distance] (clamped to the line).
func point_at(distance: float) -> Vector2:
	if _rooms.is_empty():
		return _corners[0] if not _corners.is_empty() else Vector2.ZERO
	var run: int = _run_at(distance)
	var along: float = _bases[run] + _ways[run] * clampf(distance, start, end)
	if _headings[run] == 0:
		return Vector2(_corners[run].x, along)
	return Vector2(along, _corners[run].y)


## The world direction a party moving toward [member end] travels at [param distance]: 1 right,
## -1 left, 0 on a ladder.
func heading_at(distance: float) -> int:
	return 0 if _rooms.is_empty() else _headings[_run_at(distance)]


## True where the line runs up or down.
func on_ladder(distance: float) -> bool:
	return not _rooms.is_empty() and _headings[_run_at(distance)] == 0


## Index of the chamber the feet are in at [param distance], or -1.
func chamber_at(distance: float) -> int:
	return -1 if _rooms.is_empty() else _rooms[_run_at(distance)]


## The first (x) and last (y) distance at which the feet are in chamber [param chamber_index]:
## where they stand on the first and the last tile of its floor that the line crosses. Both are
## [member start] for a chamber the line does not pass.
func stretch_of(chamber_index: int) -> Vector2:
	var first: float = start
	var last: float = start
	var found: bool = false
	for run: int in _rooms.size():
		if _rooms[run] != chamber_index:
			continue
		var low: float = _marks[run]
		var high: float = _marks[run + 1]
		# A corner that belongs to the neighbouring run is one tile outside the chamber.
		if _rooms[_run_at(low)] != chamber_index:
			low = minf(low + 1.0, high)
		if _rooms[_run_at(high)] != chamber_index:
			high = maxf(high - 1.0, low)
		if not found:
			first = low
		last = high
		found = true
	return Vector2(first, last)


## The distance at which the line crosses world column [param column] on the floor of chamber
## [param chamber_index] (clamped to its stretch).
func distance_in(chamber_index: int, column: float) -> float:
	var stretch: Vector2 = stretch_of(chamber_index)
	var best: float = stretch.x
	var best_off: float = INF
	for run: int in _rooms.size():
		if _rooms[run] != chamber_index or _headings[run] == 0:
			continue
		var raw: float = (column - _bases[run]) * _ways[run]
		var held: float = clampf(raw, _marks[run], _marks[run + 1])
		if absf(raw - held) < best_off:
			best_off = absf(raw - held)
			best = held
	return clampf(best, stretch.x, stretch.y)


## The run [param distance] (clamped to the line) is on. A corner between two runs belongs to
## the floor where a ladder meets one, and otherwise to the run on its right in the world.
func _run_at(distance: float) -> int:
	var at: float = clampf(distance, start, end)
	var run: int = 0
	while run < _rooms.size() - 1 and at >= _marks[run + 1]:
		run += 1
	if run == 0 or at > _marks[run]:
		return run
	var before: int = _headings[run - 1]
	var after: int = _headings[run]
	if after == 0 or (before < 0 and after < 0):
		return run - 1 if before != 0 else run
	return run
