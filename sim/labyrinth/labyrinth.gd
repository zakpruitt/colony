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
const FLOOR_ROW_IN_BAND: int = 11
const TUNNEL_HEIGHT: int = 3
const SHAFT_WIDTH: int = 2

## Chamber count per level.
const MIN_CHAMBERS: int = 4
const MAX_CHAMBERS: int = 6
## Chamber size in tiles.
const CHAMBER_MIN_WIDTH: int = 12
const CHAMBER_MAX_WIDTH: int = 24
const CHAMBER_MIN_HEIGHT: int = 4
const CHAMBER_MAX_HEIGHT: int = 8
## Tunnel length in tiles.
const TUNNEL_MIN_LENGTH: int = 4
const TUNNEL_MAX_LENGTH: int = 10
## Solid columns kept at each side of the band.
const EDGE_MARGIN: int = 1
## Open tiles kept between a shaft and the side walls of the chambers it passes through.
const SHAFT_MARGIN: int = 2
## Range of a left-side shaft's left column. Right-side shafts mirror it. Chosen so
## the chamber around the shaft always fits between the band edge and the shaft.
const LEFT_SHAFT_MIN: int = 11
const LEFT_SHAFT_MAX: int = 30
## Chamber kind odds, in percent, for chambers whose kind is rolled.
const PLAIN_PERCENT: int = 60
const DEN_PERCENT: int = 30

## The seed it was made from. Read-only outside the class.
var seed_value: int:
	get:
		return _seed

var _seed: int
var _root: SimRng
var _levels: Dictionary[int, LabyrinthLevel] = {}


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


## Left column of the shaft from this depth to the next. Generates nothing.
func shaft_column(depth: int) -> int:
	return _roll_shaft_column(_root.fork("shaft/%d" % depth), depth)


## A shaft column for this depth's side: the right third on odd depths, the left third on even.
func _roll_shaft_column(rng: SimRng, depth: int) -> int:
	var left: int = rng.next_int(LEFT_SHAFT_MIN, LEFT_SHAFT_MAX)
	if depth % 2 == 1:
		return LEVEL_WIDTH - SHAFT_WIDTH - left
	return left


func _generate(depth: int) -> LabyrinthLevel:
	var rng: SimRng = _root.fork("level/%d" % depth)
	var result := LabyrinthLevel.new()
	result.depth = depth
	result.floor_y = (depth - 1) * LEVEL_HEIGHT + FLOOR_ROW_IN_BAND

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
		var height: int = rng.next_int(CHAMBER_MIN_HEIGHT, CHAMBER_MAX_HEIGHT)
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
				result.floor_y - TUNNEL_HEIGHT + 1,
				spans[i].y - spans[i].x,
				TUNNEL_HEIGHT
			)
		)
	result.shaft_down = Rect2i(down, result.floor_y + 1, SHAFT_WIDTH, LEVEL_HEIGHT)
	return result


## Column spans [start, end) from left to right: chamber, tunnel, chamber, ..., chamber.
## The first chamber holds the shaft at [param left], the last the one at [param right].
func _layout_spans(rng: SimRng, left: int, right: int) -> Array[Vector2i]:
	# Where the first chamber can end and the last can start, keeping the shafts inside.
	var first_end_low: int = left + SHAFT_WIDTH + SHAFT_MARGIN
	var first_end_high: int = left - SHAFT_MARGIN + CHAMBER_MAX_WIDTH
	var last_start_low: int = right + SHAFT_WIDTH + SHAFT_MARGIN - CHAMBER_MAX_WIDTH
	var last_start_high: int = right - SHAFT_MARGIN
	var gap_low: int = last_start_low - first_end_high
	var gap_high: int = last_start_high - first_end_low

	# Chamber counts whose middle chambers and tunnels can fill some gap in range.
	var counts: Array[int] = []
	for count: int in range(MIN_CHAMBERS, MAX_CHAMBERS + 1):
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
		maxi(EDGE_MARGIN, first_end - CHAMBER_MAX_WIDTH),
		mini(left - SHAFT_MARGIN, first_end - CHAMBER_MIN_WIDTH)
	)
	var last_end: int = rng.next_int(
		maxi(right + SHAFT_WIDTH + SHAFT_MARGIN, last_start + CHAMBER_MIN_WIDTH),
		mini(LEVEL_WIDTH - EDGE_MARGIN, last_start + CHAMBER_MAX_WIDTH)
	)

	# Middle pieces alternate tunnel, chamber, ..., tunnel; grow them from their minimums.
	var sizes: Array[int] = []
	var limits: Array[int] = []
	for i: int in 2 * chamber_count - 3:
		var is_tunnel: bool = i % 2 == 0
		sizes.append(TUNNEL_MIN_LENGTH if is_tunnel else CHAMBER_MIN_WIDTH)
		limits.append(TUNNEL_MAX_LENGTH if is_tunnel else CHAMBER_MAX_WIDTH)
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
	return (chamber_count - 2) * CHAMBER_MIN_WIDTH + (chamber_count - 1) * TUNNEL_MIN_LENGTH


## Largest total width of the tunnels and middle chambers for this many chambers.
func _middle_max(chamber_count: int) -> int:
	return (chamber_count - 2) * CHAMBER_MAX_WIDTH + (chamber_count - 1) * TUNNEL_MAX_LENGTH


func _roll_kind(rng: SimRng, has_vault: bool) -> LabyrinthChamber.Kind:
	var roll: int = rng.next_int(1, 100)
	if roll <= PLAIN_PERCENT:
		return LabyrinthChamber.Kind.PLAIN
	if roll <= PLAIN_PERCENT + DEN_PERCENT:
		return LabyrinthChamber.Kind.DEN
	if has_vault:
		return LabyrinthChamber.Kind.PLAIN
	return LabyrinthChamber.Kind.VAULT
