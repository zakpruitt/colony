class_name Labyrinth
extends RefCounted
## The endless stack of levels, generated lazily from a seed.
##
## Each level depends only on the seed and its depth: it draws from its own
## SimRng stream, and the shaft columns it must line up with come from their
## own per-depth streams, so depths can be asked for in any order.
##
## Layout: the chamber holding the left-third shaft is the first chamber and
## the one holding the right-third shaft is the last, so a party crosses the
## level to keep descending. The chambers and tunnels between them fill the
## gap exactly.

const LEVEL_WIDTH: int = 120
const LEVEL_HEIGHT: int = 16
const _FLOOR_ROW_IN_BAND: int = 11
const _TUNNEL_HEIGHT: int = 3
const SHAFT_WIDTH: int = 2

## Chamber count per level.
const _MIN_CHAMBERS: int = 4
const _MAX_CHAMBERS: int = 6
## Chamber size in tiles.
const _CHAMBER_MIN_WIDTH: int = 12
const _CHAMBER_MAX_WIDTH: int = 24
const _CHAMBER_MIN_HEIGHT: int = 4
const _CHAMBER_MAX_HEIGHT: int = 8
## Tunnel length in tiles.
const _TUNNEL_MIN_LENGTH: int = 4
const _TUNNEL_MAX_LENGTH: int = 10
## Solid columns kept at each side of the band.
const _EDGE_MARGIN: int = 1
## Open tiles kept between a shaft and the side walls of the chambers it passes through.
const _SHAFT_MARGIN: int = 2
## Range of a left-side shaft's left column. Right-side shafts mirror it. Chosen so
## the chamber around the shaft always fits between the band edge and the shaft.
const _LEFT_SHAFT_MIN: int = 11
const _LEFT_SHAFT_MAX: int = 30
## Chamber kind odds, in percent, for chambers whose kind is rolled.
const _PLAIN_PERCENT: int = 60
const _DEN_PERCENT: int = 30

## The seed it was made from. Read-only outside the class.
var seed_value: int:
	get:
		return _seed

var _seed: int
var _root: SimRng
var _levels: Dictionary[int, LabyrinthLevel] = {}
## Each depth's shaft column, worked out on the first request.
var _shaft_columns: Dictionary[int, int] = {}


## The levels of [param seed_value]; with an [param area_label] (an area other than the first),
## that area's own levels of the seed.
func _init(seed_in: int, area_label: String = "") -> void:
	_seed = seed_in
	_root = SimRng.new(seed_in)
	if area_label != "":
		_root = _root.fork(area_label)


## The level at this depth (1 or more). Generated once, then cached.
func level(depth: int) -> LabyrinthLevel:
	assert(depth >= 1, "depth starts at 1")
	if not _levels.has(depth):
		_levels[depth] = _generate(depth)
	return _levels[depth]


## Left column of the shaft from this depth to the next. Generates no level.
func shaft_column(depth: int) -> int:
	if not _shaft_columns.has(depth):
		_shaft_columns[depth] = _roll_shaft_column(_root.fork("shaft/%d" % depth), depth)
	return _shaft_columns[depth]


## A shaft column for this depth's side: the right third on odd depths, the left third on even.
func _roll_shaft_column(rng: SimRng, depth: int) -> int:
	var left: int = rng.next_int(_LEFT_SHAFT_MIN, _LEFT_SHAFT_MAX)
	if depth % 2 == 1:
		return LEVEL_WIDTH - SHAFT_WIDTH - left
	return left


func _generate(depth: int) -> LabyrinthLevel:
	var rng: SimRng = _root.fork("level/%d" % depth)
	var result := LabyrinthLevel.new()
	result.depth = depth
	result.floor_y = (depth - 1) * LEVEL_HEIGHT + _FLOOR_ROW_IN_BAND

	var down: int = shaft_column(depth)
	# Depth 1 has no shaft in from above; a column on the other side shapes it the same way.
	var up: int = shaft_column(depth - 1) if depth > 1 else _roll_shaft_column(rng, depth + 1)
	var left: int = mini(down, up)
	var right: int = maxi(down, up)

	var spans: Array[Vector2i] = _layout_spans(rng, left, right)
	var chamber_count: int = (spans.size() + 1) >> 1
	var shaft_index: int = 0 if down == left else chamber_count - 1
	var vaults: int = 0
	for i: int in range(0, spans.size(), 2):
		var chamber := LabyrinthChamber.new()
		chamber.index = i >> 1
		var height: int = rng.next_int(_CHAMBER_MIN_HEIGHT, _CHAMBER_MAX_HEIGHT)
		chamber.rect = Rect2i(
			spans[i].x, result.floor_y - height + 1, spans[i].y - spans[i].x, height
		)
		if depth == 1 and chamber.index == 0:
			chamber.kind = LabyrinthChamber.Kind.START
		elif chamber.index == shaft_index:
			chamber.kind = LabyrinthChamber.Kind.PLAIN
		else:
			chamber.kind = _roll_kind(rng, vaults > 0)
			if chamber.kind == LabyrinthChamber.Kind.VAULT:
				vaults += 1
		result.chambers.append(chamber)
	for i: int in range(1, spans.size(), 2):
		result.tunnels.append(
			Rect2i(
				spans[i].x,
				result.floor_y - _TUNNEL_HEIGHT + 1,
				spans[i].y - spans[i].x,
				_TUNNEL_HEIGHT
			)
		)
	result.shaft_down = Rect2i(down, result.floor_y + 1, SHAFT_WIDTH, LEVEL_HEIGHT)
	result.course = _course_of(result, up if depth > 1 else -1, down)
	return result


## The course of a level on one floor row: along it from the first chamber's first floor column
## to the last chamber's last, the distance being the column. A party arrives in the middle of
## the shaft from above at column [param up] (with none, -1, in the middle of the first
## chamber) and leaves by the middle of the shaft at column [param down].
func _course_of(made: LabyrinthLevel, up: int, down: int) -> StageCourse:
	var course := StageCourse.new()
	var row: float = made.floor_y
	var first: LabyrinthChamber = made.chambers[0]
	var last: LabyrinthChamber = made.chambers[made.chambers.size() - 1]
	course.begin(Vector2(first.floor_columns().x, row), first.floor_columns().x)
	for chamber: LabyrinthChamber in made.chambers:
		if chamber == last:
			course.line_to(Vector2(chamber.floor_columns().y, row), chamber.index)
		else:
			# A column is in a chamber up to its far wall, and in the tunnel from there.
			course.line_to(Vector2(chamber.rect.end.x, row), chamber.index)
			course.line_to(Vector2(made.chambers[chamber.index + 1].rect.position.x, row))
	var arrival: Vector2i = first.floor_columns()
	course.entry = up + SHAFT_WIDTH / 2.0 if up >= 0 else (arrival.x + arrival.y) / 2.0
	course.exit = down + SHAFT_WIDTH / 2.0
	return course


## Column spans [start, end) from left to right: chamber, tunnel, chamber, ..., chamber.
## The first chamber holds the shaft at [param left], the last the one at [param right].
func _layout_spans(rng: SimRng, left: int, right: int) -> Array[Vector2i]:
	# Where the first chamber can end and the last can start, keeping the shafts inside.
	var first_end_low: int = left + SHAFT_WIDTH + _SHAFT_MARGIN
	var first_end_high: int = left - _SHAFT_MARGIN + _CHAMBER_MAX_WIDTH
	var last_start_low: int = right + SHAFT_WIDTH + _SHAFT_MARGIN - _CHAMBER_MAX_WIDTH
	var last_start_high: int = right - _SHAFT_MARGIN
	var gap_low: int = last_start_low - first_end_high
	var gap_high: int = last_start_high - first_end_low

	# Chamber counts whose middle chambers and tunnels can fill some gap in range.
	var counts: Array[int] = []
	for count: int in range(_MIN_CHAMBERS, _MAX_CHAMBERS + 1):
		if _middle_min(count) <= gap_high and _middle_max(count) >= gap_low:
			counts.append(count)
	var chamber_count: int = counts[rng.next_int(0, counts.size() - 1)]
	var gap: int = rng.next_int(
		maxi(gap_low, _middle_min(chamber_count)), mini(gap_high, _middle_max(chamber_count))
	)

	var first_end: int = rng.next_int(
		maxi(first_end_low, last_start_low - gap), mini(first_end_high, last_start_high - gap)
	)
	var last_start: int = first_end + gap
	var first_start: int = rng.next_int(
		maxi(_EDGE_MARGIN, first_end - _CHAMBER_MAX_WIDTH),
		mini(left - _SHAFT_MARGIN, first_end - _CHAMBER_MIN_WIDTH)
	)
	var last_end: int = rng.next_int(
		maxi(right + SHAFT_WIDTH + _SHAFT_MARGIN, last_start + _CHAMBER_MIN_WIDTH),
		mini(LEVEL_WIDTH - _EDGE_MARGIN, last_start + _CHAMBER_MAX_WIDTH)
	)

	# Middle pieces alternate tunnel, chamber, ..., tunnel; grow them from their minimums.
	var sizes: Array[int] = []
	var limits: Array[int] = []
	for i: int in 2 * chamber_count - 3:
		var is_tunnel: bool = i % 2 == 0
		sizes.append(_TUNNEL_MIN_LENGTH if is_tunnel else _CHAMBER_MIN_WIDTH)
		limits.append(_TUNNEL_MAX_LENGTH if is_tunnel else _CHAMBER_MAX_WIDTH)
	for _extra: int in gap - _middle_min(chamber_count):
		var open: Array[int] = []
		for i: int in sizes.size():
			if sizes[i] < limits[i]:
				open.append(i)
		sizes[open[rng.next_int(0, open.size() - 1)]] += 1

	var spans: Array[Vector2i] = [Vector2i(first_start, first_end)]
	var x: int = first_end
	for size: int in sizes:
		spans.append(Vector2i(x, x + size))
		x += size
	spans.append(Vector2i(last_start, last_end))
	return spans


## Smallest total width of the tunnels and middle chambers for this many chambers.
func _middle_min(chamber_count: int) -> int:
	return (chamber_count - 2) * _CHAMBER_MIN_WIDTH + (chamber_count - 1) * _TUNNEL_MIN_LENGTH


## Largest total width of the tunnels and middle chambers for this many chambers.
func _middle_max(chamber_count: int) -> int:
	return (chamber_count - 2) * _CHAMBER_MAX_WIDTH + (chamber_count - 1) * _TUNNEL_MAX_LENGTH


func _roll_kind(rng: SimRng, has_vault: bool) -> LabyrinthChamber.Kind:
	var roll: int = rng.next_int(1, 100)
	if roll <= _PLAIN_PERCENT:
		return LabyrinthChamber.Kind.PLAIN
	if roll <= _PLAIN_PERCENT + _DEN_PERCENT:
		return LabyrinthChamber.Kind.DEN
	if has_vault:
		return LabyrinthChamber.Kind.PLAIN
	return LabyrinthChamber.Kind.VAULT
