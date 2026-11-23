class_name NumberPlace
extends RefCounted
## Where a damage or heal number starts over its target, so that its whole path stays clear of
## the numbers already showing (and on screen, when its target is): the first of a list of
## steps from its place whose path clashes with none. [CombatEffects] makes the number and asks.

## The steps tried, in order: each is STEP pixels across and RISE pixels up from the number's
## place over the target, and a number drifts the way its step leans.
const SPOTS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(2, 0),
	Vector2i(-2, 0),
	Vector2i(1, 2),
	Vector2i(-1, 2),
	Vector2i(3, 1),
	Vector2i(-3, 1),
	Vector2i(0, 3),
	Vector2i(2, 3),
	Vector2i(-2, 3),
	Vector2i(4, 0),
	Vector2i(-4, 0),
	Vector2i(3, 3),
	Vector2i(-3, 3),
	Vector2i(0, -1),
	Vector2i(2, -1),
	Vector2i(-2, -1),
	Vector2i(5, 2),
	Vector2i(-5, 2),
	Vector2i(1, 4),
	Vector2i(-1, 4),
	Vector2i(4, 4),
	Vector2i(-4, 4),
	Vector2i(6, 0),
	Vector2i(-6, 0),
	Vector2i(0, 5),
	Vector2i(3, 5),
	Vector2i(-3, 5),
]
const STEP: float = 8.0
const RISE: float = 9.0
## Two numbers clash when their boxes share more than this share of the smaller box.
const OVERLAP: float = 0.25
## Seconds between the points of a path checked for clashes.
const PATH_STEP: float = 1.0 / 60.0
## Pixels kept clear between a number and the edge of the screen (a crit's shake fits inside).
const SCREEN_MARGIN: float = 4.0


## Starts [param number] (not yet shown) at the first step from [param base] whose path is clear
## of the numbers in [param showing], moving up at [param leap] and sideways at [param drift] the
## way its step leans ([param lean] for a step straight up). While [param target] (the target's
## feet) is in [param view] (the part of the world on screen), the path is kept inside it too.
## False when no step is clear: the number is then not to be shown.
static func place(
	number: FxText,
	base: Vector2,
	leap: float,
	drift: float,
	lean: float,
	target: Vector2,
	view: Rect2,
	showing: Array[FxText]
) -> bool:
	var inside: Rect2 = view.grow(-SCREEN_MARGIN)
	var keep_on_screen: bool = inside.has_point(target)
	var best_clash: float = INF
	var best_at: Vector2 = base
	var best_velocity := Vector2(drift * lean, -leap)
	# The paths of the numbers showing do not depend on the spot tried: worked out once.
	var paths: Array[Array] = []
	var bounds: Array[Rect2] = []
	for other: FxText in showing:
		if other == number or (other.kind != &"damage" and other.kind != &"heal"):
			continue
		var boxes: Array[Rect2] = []
		var t: float = 0.0
		while t < number.life and other.age + t < other.life:
			boxes.append(other.rect_at(other.age + t))
			t += PATH_STEP
		if not boxes.is_empty():
			paths.append(boxes)
			bounds.append(_bounds(boxes))
	for spot: Vector2i in SPOTS:
		var side: float = signf(spot.x) if spot.x != 0 else lean
		number.velocity = Vector2(drift * side, -leap)
		number.start(base + Vector2(spot.x * STEP, -spot.y * RISE))
		if keep_on_screen:
			number.start(number.position + _shift_inside(number, inside))
		var clash: float = _clash(_path(number), paths, bounds)
		if clash < best_clash:
			best_clash = clash
			best_at = number.position
			best_velocity = number.velocity
		if clash <= 0.0:
			break
	if best_clash > 0.0:
		return false
	number.velocity = best_velocity
	number.start(best_at)
	return true


## How badly the path [param mine] crosses [param paths] (each another number's boxes at the same
## moments, with its [param bounds]): the most any of its boxes shares with theirs at the same
## moment beyond OVERLAP, as a share; 0 when clear.
static func _clash(mine: Array[Rect2], paths: Array[Array], bounds: Array[Rect2]) -> float:
	var worst: float = 0.0
	var mine_bounds: Rect2 = _bounds(mine)
	for k: int in paths.size():
		if not mine_bounds.intersects(bounds[k]):
			continue  # no box of one can share anything with a box of the other
		var theirs: Array = paths[k]
		for i: int in mini(mine.size(), theirs.size()):
			var my_box: Rect2 = mine[i]
			var their_box: Rect2 = theirs[i]
			var smaller: float = minf(my_box.get_area(), their_box.get_area())
			if smaller > 0.0:
				var shared: float = my_box.intersection(their_box).get_area()
				worst = maxf(worst, shared / smaller - OVERLAP)
	return maxf(worst, 0.0)


## The boxes of [param number] from its start, PATH_STEP seconds apart, for its whole life.
static func _path(number: FxText) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	var t: float = 0.0
	while t < number.life:
		boxes.append(number.rect_at(t))
		t += PATH_STEP
	return boxes


## The smallest box holding every box of [param boxes] (not empty).
static func _bounds(boxes: Array[Rect2]) -> Rect2:
	var all: Rect2 = boxes[0]
	for one: Rect2 in boxes:
		all = all.merge(one)
	return all


## The move that keeps every box on the path of [param number] inside [param view].
static func _shift_inside(number: FxText, view: Rect2) -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var t: float = 0.0
	while t <= number.life:
		var box: Rect2 = number.rect_at(t)
		low = low.min(box.position)
		high = high.max(box.end)
		t += PATH_STEP
	var shift := Vector2.ZERO
	if low.x < view.position.x:
		shift.x = view.position.x - low.x
	elif high.x > view.end.x:
		shift.x = view.end.x - high.x
	if low.y < view.position.y:
		shift.y = view.position.y - low.y
	elif high.y > view.end.y:
		shift.y = view.end.y - high.y
	return shift.round()
