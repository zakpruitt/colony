class_name PartyPlaces
extends RefCounted
## Where an [Expedition]'s party stands and walks to: each hero's place (its fighter's in a
## fight, on the ladder while climbing, where it fell while down, else in column behind the
## anchor, retracing the anchor's last turn) and the anchor's goal on its level. Reading changes
## nothing. Kept apart from [Expedition] so its file has room.

## Tiles between heroes walking in column.
const HERO_SPACING: float = 1.0


## Feet position, in world tiles, of hero [param hero_id], at place [param rank] in [param run]'s
## party.
static func of(run: Expedition, hero_id: int, rank: int) -> Vector2:
	var floor_y: float = run.labyrinth.level(run.depth).floor_y
	match run.state:
		Expedition.State.FIGHTING:
			var fighter: Combatant = run.battle.combatant(hero_id) if run.battle != null else null
			if fighter != null:
				return Vector2(fighter.x, floor_y)
		Expedition.State.CLIMBING:
			var lag: float = HERO_SPACING * rank * run._climb_direction
			var y: float = run._climb_y - lag
			if run._climb_direction > 0:
				y = maxf(y, run._climb_from_y)
			else:
				y = minf(y, run._climb_from_y)
			return Vector2(run.x, y)
		Expedition.State.REVIVING:
			if run._fallen.has(hero_id):
				return Vector2(run._fallen[hero_id], floor_y)
	return Vector2(_formation_x(run, rank), floor_y)


## The column [param run]'s anchor walks toward on its level: the shaft toward its target, or,
## at the target or [param holding] back from a guardian (it then hunts there as if it were the
## target), the far end of the level it faces; under Hold, never into a living guardian's chamber.
static func walk_goal(run: Expedition, holding: bool) -> float:
	var level: LabyrinthLevel = run.labyrinth.level(run.depth)
	var goal: float
	if run.depth < run.target_depth and not holding:
		goal = _shaft_middle(run, run.depth)
	elif run.depth > run.target_depth and not holding:
		goal = _shaft_middle(run, run.depth - 1)
	elif run.facing > 0:
		goal = level.chambers[level.chambers.size() - 1].floor_columns().y
	else:
		goal = level.chambers[0].floor_columns().x
	var hold: bool = run.guardian_order == Expedition.GuardianOrder.HOLD
	if hold and run._guardian_alive(run.depth):
		goal = PartyOrders.short_of(level.shaft_chamber(), run.x, goal)
	return goal


## The middle of the shaft down from [param level_depth], where a climber stands on the ladder.
static func _shaft_middle(run: Expedition, level_depth: int) -> float:
	return run.labyrinth.shaft_column(level_depth) + Labyrinth.SHAFT_WIDTH / 2.0


## The column of the hero [param rank] places behind the anchor, retracing the anchor's last turn.
static func _formation_x(run: Expedition, rank: int) -> float:
	var lag: float = HERO_SPACING * rank
	var since_turn: float = run._odometer - run._turn_odometer
	var hero_x: float = run.x - run.facing * lag
	if run._turn_facing != 0 and lag > since_turn:
		hero_x = run._turn_x - run._turn_facing * (lag - since_turn)
	var level: LabyrinthLevel = run.labyrinth.level(run.depth)
	var first: float = level.chambers[0].floor_columns().x
	var last: float = level.chambers[level.chambers.size() - 1].floor_columns().y
	return clampf(hero_x, first, last)
