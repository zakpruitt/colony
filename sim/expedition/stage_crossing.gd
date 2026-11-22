class_name StageCrossing
extends RefCounted
## How an [Expedition]'s party changes stage: the rows it counts, where it lands, and where its
## heroes are on the way. Kept apart from [Expedition] so its file has room.
##
## In a flat labyrinth a stage's way on is a shaft straight down to the next stage: the party
## climbs its rows and keeps its place along the course. In a winding labyrinth the way on is a
## door: the crossing takes as long as [constant Labyrinth.LEVEL_HEIGHT] rows of ladder, whatever
## lies between the two stages, and the party lands at the door of the stage it goes to. Its
## heroes stand where they left from for the first half of it and where they land for the second.


## True if [param run]'s stages are joined by doors, not by shafts.
static func by_door(run: Expedition) -> bool:
	return run.labyrinth.shape == Labyrinth.Shape.WINDING


## The row [param run]'s party sets out from (x) and the row it climbs to (y), going on to the
## next stage ([param direction] 1) or back to the one before (-1). By a shaft they are the two
## floors' rows; by a door there is no ladder to measure, and each stage counts as
## [constant Labyrinth.LEVEL_HEIGHT] rows.
static func rows(run: Expedition, direction: int) -> Vector2:
	if by_door(run):
		var from: float = (run.depth - 1) * Labyrinth.LEVEL_HEIGHT
		return Vector2(from, from + direction * Labyrinth.LEVEL_HEIGHT)
	var here: StageCourse = PartyPlaces.course(run)
	var there: StageCourse = run.labyrinth.level(run.depth + direction).course
	return Vector2(
		here.point_at(here.exit if direction > 0 else here.entry).y,
		there.point_at(there.entry if direction > 0 else there.exit).y
	)


## [param run]'s party, on its way back to the stage before, turns round to the stage it left:
## as far from it as it had come.
static func turn_back(run: Expedition) -> void:
	var row: float = run._climb_y
	run.depth -= 1
	run._start_climb(1)
	run._climb_y = row
	if by_door(run):
		# It is now leaving the stage before by its way on.
		run.x = PartyPlaces.course(run).exit
		run._reset_trail()


## The distance along the course of the stage [param run]'s party is crossing to at which it
## lands: by a shaft, where it stands now; by a door, at that stage's entry (going on) or exit
## (going back).
static func landing(run: Expedition) -> float:
	if not by_door(run):
		return run.x
	var there: StageCourse = run.labyrinth.level(run.depth + run._climb_direction).course
	return there.entry if run._climb_direction > 0 else there.exit


## Feet of the hero at place [param rank] of [param run]'s party while it crosses by a door:
## where it left from, in line behind the anchor, and from half way where it lands, in line
## behind the anchor at the door it arrives by.
static func feet(run: Expedition, rank: int) -> Vector2:
	if ClimbProgress.share(run) < 0.5:
		return left_from(run, rank)
	var there: StageCourse = run.labyrinth.level(run.depth + run._climb_direction).course
	var at: float = landing(run)
	var behind: float = at - Arrival.facing(there, at) * PartyPlaces.HERO_SPACING * rank
	return there.point_at(clampf(behind, there.start, there.end))


## Feet of the hero at place [param rank] of [param run]'s party as it set out by a door.
static func left_from(run: Expedition, rank: int) -> Vector2:
	return PartyPlaces.course(run).point_at(PartyPlaces._formation_distance(run, rank))
