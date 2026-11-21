class_name Arrival
extends RefCounted
## Where a party arrives on a depth without climbing down to it (revived, or loaded from a save),
## and the way it then faces; and standing an expedition up from a save. Kept apart from
## [Expedition] so its file stays under gdlint's 1000 lines, and so
## [method Expedition.revival_place] and the expedition's own placing share one rule.


## Where the party arrives on [param level_depth] of [param labyrinth], as a distance along that
## stage's course: its [member StageCourse.entry].
static func column(labyrinth: Labyrinth, level_depth: int) -> float:
	return labyrinth.level(level_depth).course.entry


## The way a party placed at [param at] on [param line] faces along it (1 toward its end, -1
## toward its start): toward the way on, or, standing at the way on, back toward where a party
## arrives.
static func facing(line: StageCourse, at: float) -> int:
	var toward: float = line.entry if is_equal_approx(at, line.exit) else line.exit
	return 1 if toward >= at else -1


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
