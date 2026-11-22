class_name LadderRoute
extends RefCounted
## The way a sprite takes to its place on a stage with ladders: along its floor, and from one
## floor to another only on the ladder between them, in the ladder's column. So a hero that
## trails the party round a corner, or runs to a fight from a ladder, never crosses the earth.
##
## Places are feet in world pixels. A ladder's rectangle runs from the row under its upper floor
## to its lower floor's row, so feet on it are between its top edge and its bottom edge.


## One frame's move from [param from] toward [param goal] past [param ladders]: a share of the
## way left, at most [constant World.RUN_SPEED], as [method step] moves on one floor.
static func eased(ladders: Array[Rect2i], from: Vector2, goal: Vector2, delta: float) -> Vector2:
	if absf(goal.y - from.y) <= World.SETTLE:
		return step(from, goal, delta, false)
	# Twice along the way, corner by corner, with no list of it made: this runs for every hero
	# on every frame of a climb.
	var turns: int = 2 * ladders.size() + 1
	var left: float = 0.0
	var at: Vector2 = from
	for i: int in turns:
		var corner: Vector2 = _corner_after(ladders, at, goal)
		left += at.distance_to(corner)
		at = corner
		if at == goal:
			break
	var move: float = minf(left * (1.0 - exp(-World.FOLLOW_RATE * delta)), World.RUN_SPEED * delta)
	if left - move <= World.SETTLE:
		return goal
	at = from
	for i: int in turns:
		var corner: Vector2 = _corner_after(ladders, at, goal)
		var leg: float = at.distance_to(corner)
		if move <= leg:
			return at.move_toward(corner, move)
		move -= leg
		at = corner
		if at == goal:
			break
	return goal


## One frame's move from [param from] toward [param goal] with no ladder to mind: a share of the
## gap, at most [constant World.RUN_SPEED]. Off the floor and across, it goes one way at a time:
## across first with [param across_first] (to a shaft's ladder, then down it), down or up first
## otherwise (off the ladder, then across).
static func step(from: Vector2, goal: Vector2, delta: float, across_first: bool) -> Vector2:
	var aim: Vector2 = goal
	if absf(goal.x - from.x) > World.SETTLE and absf(goal.y - from.y) > World.SETTLE:
		aim = Vector2(goal.x, from.y) if across_first else Vector2(from.x, goal.y)
	var gap: Vector2 = aim - from
	var distance: float = gap.length()
	var move: float = minf(
		distance * (1.0 - exp(-World.FOLLOW_RATE * delta)), World.RUN_SPEED * delta
	)
	if distance - move <= World.SETTLE and aim == goal:
		return goal
	if distance <= 0.0:
		return from
	return from + gap * (move / distance)


## The next point to make for from [param at] on the way to [param goal]: the foot or head of
## the ladder that leads on, then its far end (or the goal's row on it); with no ladder that
## leads on, or on the goal's row, the goal.
static func _corner_after(ladders: Array[Rect2i], at: Vector2, goal: Vector2) -> Vector2:
	if absf(goal.y - at.y) <= World.SETTLE:
		return goal
	var ladder: Rect2i = _ladder_on(ladders, at, goal.y)
	if not ladder.has_area():
		return goal
	var rung: float = column(ladder)
	if absf(at.x - rung) > World.SETTLE:
		return Vector2(rung, at.y)
	return Vector2(rung, clampf(goal.y, ladder.position.y * World.TILE, ladder.end.y * World.TILE))


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
