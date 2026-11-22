class_name SidePathWalk
extends RefCounted
## An [Expedition]'s side paths: which caches are open, the party's turn off the main course to
## a gate it can open, the work on the gate, the walk to the cache room's far wall and back, and
## what the cache pays. Kept apart from [Expedition] so its file has room.
##
## On a side path the expedition's [member Expedition.x] is a distance along that path's own
## course ([method PartyPlaces.course]) and its facing 1 toward the cache room, -1 on the way
## back; the chamber the party last entered on the main course is kept, so coming back into the
## room it left starts nothing.

## The tick each cache of the area the party is in was last opened on, by Vector2i(stage, place
## in the level's side paths). One never opened has no entry.
var _opened: Dictionary[Vector2i, int] = {}
## The side paths of the party's stage whose gate has been said to be sealed since it arrived
## there. It decides only whether an event is repeated, so the state hash leaves it out.
var _said: Dictionary[int, bool] = {}
## This trip: the hero who opens the gate, whether it is open and whether the cache has paid,
## and the way along the main course the party was going.
var _opener: int = -1
var _gate_open: bool = false
var _paid: bool = false
var _back_facing: int = 1


## The tick the cache of side path [param index] on [param stage] was last opened on, or -1.
func opened_tick(stage: int, index: int) -> int:
	return _opened.get(Vector2i(stage, index), -1)


## [param run]'s party is put somewhere on a main course (arriving on a stage, revived, loaded):
## it is on no side path, and a sealed gate there is said again.
func arrived(run: Expedition) -> void:
	run.side_path = -1
	_said.clear()
	_opener = -1
	_gate_open = false
	_paid = false


## [param run]'s party comes into an area: every cache there is full.
func forget(run: Expedition) -> void:
	_opened.clear()
	arrived(run)


## One tick of travel for [param run]'s party, about to walk toward [param goal] on the main
## course. Returns true if the side paths took the tick: the party is on one, or turned onto one
## it reached within this tick's stride (its cache full and someone able to open its gate). A
## gate reached with nobody able is said once, and the party walks on.
func travel(run: Expedition, goal: float) -> bool:
	var paths: Array[SidePath] = run.labyrinth.level(run.depth).side_paths
	if run.side_path >= 0:
		_walk(run, paths[run.side_path])
		return true
	if paths.is_empty():
		return false
	var way: float = signf(goal - run.x)
	var speed: float = Expedition.PARTY_SPEED * run._upgrade(UpgradeDef.Stat.TRAVEL_SPEED)
	var stride: float = minf(speed / Simulation.TICKS_PER_SECOND, absf(goal - run.x))
	for index: int in paths.size():
		var ahead: float = (paths[index].at - run.x) * way
		if ahead < 0.0 or ahead > stride or not SidePathRules.is_full(run, run.depth, index):
			continue
		var hero: Hero = SidePathRules.opener(run, run.depth, index)
		if hero == null:
			_seal(run, index, paths[index])
			continue
		run._walk_toward(paths[index].at)
		_back_facing = int(way) if way != 0.0 else run.facing
		_opener = hero.id
		_gate_open = false
		_paid = false
		run.side_path = index
		run.x = 0.0
		run.facing = 1
		run._reset_trail()
		return true
	return false


## The gate's work is done: it stands open, and the party walks on.
func work(run: Expedition) -> void:
	var path: SidePath = run.labyrinth.level(run.depth).side_paths[run.side_path]
	var gate: int = Content.gate_ids().find(path.gate)
	run._emit(SimEvent.Kind.GATE_OPENED, run._worker, gate, run.side_path)
	_gate_open = true
	run._worker = -1
	run.state = Expedition.State.TRAVELLING


## The room [param run]'s party, on a side path, is in: the cache room once its anchor stands on
## that room's floor, else none.
func chamber(run: Expedition) -> LabyrinthChamber:
	var path: SidePath = run.labyrinth.level(run.depth).side_paths[run.side_path]
	return path.room if path.in_room(run.x) else null


## The point of the main course [param short] tiles short of where the side path [param run]'s
## party is on leaves it, on the side the party came from.
func before(run: Expedition, short: float) -> Vector2:
	var level: LabyrinthLevel = run.labyrinth.level(run.depth)
	var main: StageCourse = level.course
	var at: float = level.side_paths[run.side_path].at - _back_facing * short
	return main.point_at(clampf(at, main.start, main.end))


## What the side paths add to [param run]'s state hash: nothing until a gate is opened.
func hash_parts(run: Expedition) -> Array:
	if _opened.is_empty() and run.side_path < 0:
		return []
	var keys: Array[Vector2i] = []
	keys.assign(_opened.keys())
	keys.sort()
	var parts: Array = ["side", run.side_path, _opener, _gate_open, _paid, _back_facing]
	for key: Vector2i in keys:
		parts.append([key, _opened[key]])
	return [parts]


## One tick on [param path]: to its gate and the work on it, on to the cache room's far wall
## (the cache pays as the anchor steps onto the room's floor), and back to the main course.
func _walk(run: Expedition, path: SidePath) -> void:
	if run.facing < 0:
		run._walk_toward(0.0)
		if run.x <= Expedition._EPSILON:
			_rejoin(run, path)
		return
	if not _gate_open:
		run._walk_toward(path.gate_at)
		if absf(run.x - path.gate_at) <= Expedition._EPSILON:
			_start_work(run, path)
		return
	run._walk_toward(path.course.end)
	if not _paid and path.in_room(run.x):
		_pay(run)
	if absf(run.x - path.course.end) <= Expedition._EPSILON:
		run._turn(-1)


func _start_work(run: Expedition, path: SidePath) -> void:
	var hero: Hero = SidePathRules.opener(run, run.depth, run.side_path)
	if hero == null:
		# Nobody can any more: back the way it came.
		run._turn(-1)
		return
	var def: GateDef = Content.gate(path.gate)
	_opener = hero.id
	run.state = Expedition.State.WORKING
	run._worker = hero.id
	run._work_start = run._tick
	run._work_ticks = Combatant.seconds_to_ticks(def.work_seconds)
	var gate: int = Content.gate_ids().find(path.gate)
	run._emit(SimEvent.Kind.GATE_STARTED, hero.id, gate, run._work_ticks)


## Opens the cache of the side path [param run]'s party is on: gold for the party, XP for every
## living hero and the area's resource, and the cache is empty from this tick.
func _pay(run: Expedition) -> void:
	_paid = true
	_opened[Vector2i(run.depth, run.side_path)] = run._tick
	run._emit(SimEvent.Kind.CACHE_OPENED, _opener, -1, run.side_path)
	var base: int = SidePathRules.gold_at(run, run.depth)
	var gold: int = roundi(base * run._upgrade(UpgradeDef.Stat.GOLD))
	run._party.gold += gold
	run._emit(SimEvent.Kind.GOLD_GAINED, _opener, -1, gold)
	var xp: int = SidePathRules.xp_at(run, run.depth)
	for hero: Hero in run._party.heroes:
		if hero.is_alive():
			run._give_xp(hero, xp)
	ResourceDrops.on_cache(run, _opener, run.depth, SidePathRules.CACHE_DROPS)


## Back where the side path left the main course, going on the way the party was going.
func _rejoin(run: Expedition, path: SidePath) -> void:
	run.side_path = -1
	run.x = path.at
	run.facing = _back_facing
	run._reset_trail()
	_opener = -1
	_gate_open = false
	_paid = false


## Says, once, that nobody can open the gate of side path [param index].
func _seal(run: Expedition, index: int, path: SidePath) -> void:
	if _said.has(index):
		return
	_said[index] = true
	var def: GateDef = Content.gate(path.gate)
	var gate: int = Content.gate_ids().find(path.gate)
	var skill: int = Content.microskill_ids().find(def.microskill)
	run._emit(SimEvent.Kind.GATE_SEALED, -1, gate, skill)
