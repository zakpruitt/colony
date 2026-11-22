class_name PartyPlaces
extends RefCounted
## Where an [Expedition]'s party stands and walks to, all of it asked of the stage's
## [StageCourse]: each hero's place (its fighter's in a fight, on the ladder while climbing to
## another stage or, between stages joined by doors, where [StageCrossing] puts it, where it fell
## while down, else in line behind the anchor along the course, retracing the anchor's last
## turn) and the anchor's goal. Reading changes nothing. Kept apart
## from [Expedition] so its file has room.

## Tiles of course between heroes walking in line.
const HERO_SPACING: float = 1.0


## The course of the stage [param run]'s party is on.
static func course(run: Expedition) -> StageCourse:
	return run.labyrinth.level(run.depth).course


## Feet position, in world tiles, of the party's anchor (the point the heroes line up behind).
static func anchor(run: Expedition) -> Vector2:
	var feet: Vector2 = course(run).point_at(run.x)
	if run.state == Expedition.State.CLIMBING:
		if StageCrossing.by_door(run):
			return StageCrossing.feet(run, 0)
		feet.y = run._climb_y
	return feet


## The way the party faces in the world: 1 right, -1 left (the way it last faced while on a ladder).
static func world_facing(run: Expedition) -> int:
	var line: StageCourse = course(run)
	var heading: int = line.heading_at(run.x)
	if heading == 0:
		# On a ladder: as it stepped on, coming the way it travels now.
		var behind: float = run.x
		while heading == 0 and behind > line.start and behind < line.end:
			behind = clampf(behind - run.facing * HERO_SPACING, line.start, line.end)
			heading = line.heading_at(behind)
	return run.facing * heading if heading != 0 else run.facing


## Feet position, in world tiles, of hero [param hero_id], at place [param rank] in [param run]'s
## party.
static func of(run: Expedition, hero_id: int, rank: int) -> Vector2:
	match run.state:
		Expedition.State.FIGHTING:
			var fighter: Combatant = run.battle.combatant(hero_id) if run.battle != null else null
			if fighter != null:
				return Vector2(fighter.x, _fight_row(run))
		Expedition.State.CLIMBING:
			if StageCrossing.by_door(run):
				return StageCrossing.feet(run, rank)
			var lag: float = HERO_SPACING * rank * run._climb_direction
			var y: float = run._climb_y - lag
			if run._climb_direction > 0:
				y = maxf(y, run._climb_from_y)
			else:
				y = minf(y, run._climb_from_y)
			return Vector2(course(run).point_at(run.x).x, y)
		Expedition.State.REVIVING:
			if run._fallen.has(hero_id):
				return run._fallen[hero_id]
	return course(run).point_at(_formation_distance(run, rank))


## The distance [param run]'s anchor walks toward on its stage: the way on or the way back toward
## its target, or, at the target or [param holding] back from a guardian (it then hunts there as
## if it were the target), the end of the course it faces; under Hold, never into a living
## guardian's chamber.
static func walk_goal(run: Expedition, holding: bool) -> float:
	var line: StageCourse = course(run)
	var goal: float
	if run.depth < run.target_depth and not holding:
		goal = line.exit
	elif run.depth > run.target_depth and not holding:
		goal = line.entry
	elif run.facing > 0:
		goal = line.end
	else:
		goal = line.start
	var hold: bool = run.guardian_order == Expedition.GuardianOrder.HOLD
	if hold and run._guardian_alive(run.depth):
		var guarded: Vector2 = line.stretch_of(ChamberRules.way_on_room(line))
		goal = PartyOrders.short_of_stretch(guarded, run.x, goal)
	return goal


## Where hero [param hero_id], at place [param rank], lies if the party falls now: where it
## stands, or, on the way to another stage, on the floor the party left.
static func fallen(run: Expedition, hero_id: int, rank: int) -> Vector2:
	if run.state == Expedition.State.CLIMBING and StageCrossing.by_door(run):
		return StageCrossing.left_from(run, rank)
	var feet: Vector2 = of(run, hero_id, rank)
	if run.state == Expedition.State.CLIMBING:
		feet.y = course(run).point_at(run.x).y
	return feet


## The floor row of the chamber [param run]'s fight is in; for a battle handed to it with no
## chamber (a test's, the showcase's), the row the anchor is on.
static func _fight_row(run: Expedition) -> float:
	var key: Vector2i = run._battle_key
	if key.x < 1 or key.y < 0:
		return course(run).point_at(run.x).y
	return run.labyrinth.level(key.x).chambers[key.y].floor_row()


## The course distance of the hero [param rank] places behind the anchor, retracing the anchor's
## last turn.
static func _formation_distance(run: Expedition, rank: int) -> float:
	var lag: float = HERO_SPACING * rank
	var since_turn: float = run._odometer - run._turn_odometer
	var hero_x: float = run.x - run.facing * lag
	if run._turn_facing != 0 and lag > since_turn:
		hero_x = run._turn_x - run._turn_facing * (lag - since_turn)
	var line: StageCourse = course(run)
	return clampf(hero_x, line.start, line.end)
