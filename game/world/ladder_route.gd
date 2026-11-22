class_name LadderRoute
extends RefCounted
## The way a sprite takes to its place on a stage with ladders: along its floor, and from one
## floor to another only on the ladder between them, in the ladder's column. So a hero that
## trails the party round a corner, or runs to a fight from a ladder, never crosses the earth.
##
## Places are feet in world pixels. A ladder's rectangle runs from the row under its upper floor
## to its lower floor's row, so feet on it are between its top edge and its bottom edge.


## One frame's move from [param from] toward [param goal] past [param ladders]: a share of the
## way left, at most [constant World.RUN_SPEED], as [method World._eased] moves on one floor.
static func eased(ladders: Array[Rect2i], from: Vector2, goal: Vector2, delta: float) -> Vector2:
	if absf(goal.y - from.y) <= World.SETTLE:
		return World._eased(from, goal, delta, false)
	var way: PackedVector2Array = corners(ladders, from, goal)
	var left: float = 0.0
	var at: Vector2 = from
	for corner: Vector2 in way:
		left += at.distance_to(corner)
		at = corner
	var step: float = minf(left * (1.0 - exp(-World.FOLLOW_RATE * delta)), World.RUN_SPEED * delta)
	if left - step <= World.SETTLE:
		return goal
	at = from
	for corner: Vector2 in way:
		var leg: float = at.distance_to(corner)
		if step <= leg:
			return at.move_toward(corner, step)
		step -= leg
		at = corner
	return goal


## The points to pass through from [param from] to [param goal], the goal last: to the foot or
## head of each ladder on the way, then along it. With no ladder that leads on, straight there.
static func corners(ladders: Array[Rect2i], from: Vector2, goal: Vector2) -> PackedVector2Array:
	var way := PackedVector2Array()
	var at: Vector2 = from
	for i: int in ladders.size():
		if absf(goal.y - at.y) <= World.SETTLE:
			break
		var ladder: Rect2i = _ladder_on(ladders, at, goal.y)
		if not ladder.has_area():
			break
		var rung: float = column(ladder)
		if absf(at.x - rung) > World.SETTLE:
			at = Vector2(rung, at.y)
			way.append(at)
		var top: float = ladder.position.y * World.TILE
		var bottom: float = ladder.end.y * World.TILE
		at = Vector2(rung, clampf(goal.y, top, bottom))
		way.append(at)
	way.append(goal)
	return way


## The pixel column feet keep to on [param ladder]: its middle, where the course runs.
static func column(ladder: Rect2i) -> float:
	return (ladder.position.x + ladder.size.x / 2.0) * World.TILE


## The ladder of [param ladders] that feet at [param at] can take toward the row [param goal_y]:
## one they stand at the head or foot of, or on, that goes on that way; the nearest of several.
## A rectangle with no area when there is none.
static func _ladder_on(ladders: Array[Rect2i], at: Vector2, goal_y: float) -> Rect2i:
	var best := Rect2i()
	var nearest: float = INF
	for ladder: Rect2i in ladders:
		var top: float = ladder.position.y * World.TILE
		var bottom: float = ladder.end.y * World.TILE
		if at.y < top - World.SETTLE or at.y > bottom + World.SETTLE:
			continue
		var leads_on: bool = bottom > at.y + World.SETTLE
		if goal_y < at.y:
			leads_on = top < at.y - World.SETTLE
		var apart: float = absf(column(ladder) - at.x)
		if leads_on and apart < nearest:
			nearest = apart
			best = ladder
	return best
