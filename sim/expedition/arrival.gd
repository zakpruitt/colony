class_name Arrival
extends RefCounted
## Where a party arrives on a depth without climbing down to it (revived, or loaded from a save),
## and the way it then faces; and standing an expedition up from a save. Kept apart from
## [Expedition] so its file stays under gdlint's 1000 lines, and so
## [method Expedition.revival_place] and the expedition's own placing share one rule.


## The column the party arrives at on [param level_depth] of [param labyrinth]: the middle of the
## START chamber at depth 1, otherwise where the shaft from above lands.
static func column(labyrinth: Labyrinth, level_depth: int) -> float:
	if level_depth > 1:
		return labyrinth.shaft_column(level_depth - 1) + Labyrinth.SHAFT_WIDTH / 2.0
	var level: LabyrinthLevel = labyrinth.level(1)
	for room: LabyrinthChamber in level.chambers:
		if room.kind == LabyrinthChamber.Kind.START:
			var floor_span: Vector2i = room.floor_columns()
			return (floor_span.x + floor_span.y) / 2.0
	return level.chambers[0].floor_columns().x


## The way a party placed at [param at_column] faces: into the level, 1 right or -1 left.
static func facing(at_column: float) -> int:
	return 1 if at_column < Labyrinth.LEVEL_WIDTH / 2.0 else -1


## Stands [param run], a new expedition, up from saved progress at simulation tick [param tick]:
## where revival puts the party (the arrival point of [param stable], its last stable depth),
## travelling, with no events. Called once, before the first step (and after
## [method AreaTravel.restore] for a save with areas).
static func from_save(
	run: Expedition, tick: int, stable: int, deepest: int, target: int, push: bool
) -> void:
	run._tick = tick
	run.last_stable_depth = stable
	run.deepest_depth = maxi(deepest, stable)
	run.auto_push = push
	run.depth = stable
	run._place(column(run.labyrinth, run.depth))
	run._restart_depth_count(run._tick)
	run.target_depth = maxi(target, 1)
	run._timer_target = run.target_depth
	run._target_since = run._tick
	run.state = Expedition.State.TRAVELLING
