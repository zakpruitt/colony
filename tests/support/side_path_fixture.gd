class_name SidePathFixture
extends "res://tests/support/play_fixture.gd"
## A test of a winding stage's side paths: finding one, standing a party before it, and the
## checks of how one lies in its level.

## What a side path may be: how many a level, and the sizes of its room, tunnel and ladder.
const MOST_PATHS: int = 3
const CACHE_WIDTH: Vector2i = Vector2i(8, 12)
const CACHE_HEIGHT: Vector2i = Vector2i(4, 5)
const TUNNEL_LENGTH: Vector2i = Vector2i(4, 10)
const TUNNEL_HEIGHT: int = 3
const FLOOR_GAP: int = 10
const INSET: int = 2
const GATE_CLEAR: float = 2.0
## The gates and the microskill that opens each.
const GATES: Dictionary[StringName, StringName] = {
	&"hidden_crack": &"trapspotter",
	&"locked_gate": &"lockpicker",
	&"rubble": &"strongarm",
	&"rune_seal": &"runereader",
}

var _wrong: Array[String] = []


func before_each() -> void:
	super()
	_wrong = []


func _nothing_wrong(what: String) -> void:
	assert_eq(_wrong.size(), 0, "%s:\n%s" % [what, "\n".join(_wrong.slice(0, 12))])
	_wrong = []


func _is_tunnel(path: SidePath) -> bool:
	return path.tunnel.has_area()


## The main route's room [param path] leaves from.
func _room_of(level: LabyrinthLevel, path: SidePath) -> int:
	return level.course.chamber_at(path.at)


## True if feet at [param feet], in world tiles, stand in an open rectangle of [param level],
## its side paths' among them.
func _in_the_open(level: LabyrinthLevel, feet: Vector2) -> bool:
	for rects: Array[Rect2i] in [level.open_rects(), level.side_rects()]:
		for rect: Rect2i in rects:
			if Rect2(rect).grow(0.01).has_point(feet):
				return true
	return false


## The first stage-[param stage] side path of the kind asked for ([param tunnel], or a ladder)
## over the seeds from [param from], as Vector2i(seed, place in the level's side paths).
func _find(stage: int, tunnel: bool, from: int = 1) -> Vector2i:
	for seed_value: int in range(from, from + 30):
		var level: LabyrinthLevel = winding_labyrinth(seed_value).level(stage)
		for index: int in level.side_paths.size():
			if _is_tunnel(level.side_paths[index]) == tunnel:
				return Vector2i(seed_value, index)
	fail_test("no such side path on stage %d" % stage)
	return Vector2i(1, 0)


## Stands [param sim]'s party on [param stage], [param back] tiles of the main course short of
## where side path [param index] leaves, going [param way] along the course and pacing the
## stage, the room it leaves from cleared so nothing is met there. Not [param fresh], the party
## is moved without arriving: what it was told on this stage stays told.
func _approach(
	sim: Simulation, stage: int, index: int, way: int, back: float = 1.5, fresh: bool = true
) -> SidePath:
	var e: Expedition = sim.expedition
	if fresh:
		Arrival.from_save(e, sim.tick, stage, maxi(stage, e.deepest_depth), stage, false)
	var level: LabyrinthLevel = sim.labyrinth.level(stage)
	var path: SidePath = level.side_paths[index]
	var cleared := ChamberState.new(stage)
	cleared.cleared_tick = sim.tick
	e._chambers[Vector2i(stage, _room_of(level, path))] = cleared
	var from: float = clampf(path.at - way * back, level.course.start, level.course.end)
	if fresh:
		e._place(from)
	e.x = from
	e.facing = way
	e._reset_trail()
	e._entered_key = e._key_here()
	return path


## Steps [param sim] until [param done], at most [param limit] ticks, and returns the events of
## those ticks.
func _run_until(sim: Simulation, done: Callable, limit: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for i: int in limit:
		if done.call():
			return events
		sim.step()
		events.append_array(sim.drain_events())
	if not done.call():
		fail_test("not done within %d ticks" % limit)
	return events


## The living hero of [param sim] with [param skill] and the lowest id, or -1.
func _lowest_with(sim: Simulation, skill: StringName) -> int:
	var found: int = -1
	for hero: Hero in sim.party.heroes:
		if hero.is_alive() and hero.has_microskill(skill) and (found < 0 or hero.id < found):
			found = hero.id
	return found


## Heroes that never level, so never learn a microskill.
func _keep_unskilled(sim: Simulation) -> void:
	for hero: Hero in sim.party.heroes:
		hero.xp = -10_000_000


## Everything that makes [param level]'s side paths what they are, as plain values.
func _side_signature(level: LabyrinthLevel) -> Array:
	var parts: Array = []
	for path: SidePath in level.side_paths:
		var line: StageCourse = path.course
		parts.append([String(path.gate), path.at, path.gate_at, path.tunnel, path.ladder])
		parts.append([path.room.rect, line.start, line.end, line.point_at(line.end)])
	return parts


## What is wrong with one side path of [param level], leaving room [param from].
func _check_path(
	level: LabyrinthLevel, path: SidePath, from: LabyrinthChamber, what: String
) -> void:
	var cache: LabyrinthChamber = path.room
	var rect: Rect2i = cache.rect
	if cache.kind != LabyrinthChamber.Kind.CACHE or cache.index != -1:
		_wrong.append("%s: its room is kind %d, index %d" % [what, cache.kind, cache.index])
	if level.chambers.has(cache):
		_wrong.append("%s: its room is one of the level's chambers" % what)
	if rect.size.x < CACHE_WIDTH.x or rect.size.x > CACHE_WIDTH.y:
		_wrong.append("%s: a cache room %d wide" % [what, rect.size.x])
	if rect.size.y < CACHE_HEIGHT.x or rect.size.y > CACHE_HEIGHT.y:
		_wrong.append("%s: a cache room %d tall" % [what, rect.size.y])
	if path.tunnel.has_area() == path.ladder.has_area():
		_wrong.append("%s: neither one tunnel nor one ladder" % what)
		return
	if not GATES.has(path.gate):
		_wrong.append("%s: gate %s" % [what, path.gate])
	var main: StageCourse = level.course
	var line: StageCourse = path.course
	var leaves: Vector2 = main.point_at(path.at)
	if line.start != 0.0 or not line.point_at(0.0).is_equal_approx(leaves):
		_wrong.append("%s: its course does not start where it leaves" % what)
	if not from.rect.grow(1).has_point(Vector2i(leaves.floor())) or leaves.y != from.floor_row():
		_wrong.append("%s: it leaves at %s, off room %d's floor" % [what, leaves, from.index])
	var columns: Vector2i = cache.floor_columns()
	var far: Vector2 = line.point_at(line.end)
	if far.y != cache.floor_row() or (far.x != columns.x and far.x != columns.y):
		_wrong.append("%s: its course ends at %s, not a wall of its room" % [what, far])
	var entered: bool = false
	for half: int in range(0, roundi(line.end * 2.0) + 1):
		var d: float = half / 2.0
		if line.chamber_at(d) != -1:
			_wrong.append("%s: its course is in chamber %d" % [what, line.chamber_at(d)])
			break
		if not _in_the_open(level, line.point_at(d)):
			_wrong.append("%s: %s at %s is in the earth" % [what, line.point_at(d), d])
			break
		if entered and not path.in_room(d):
			_wrong.append("%s: its course leaves the cache room again at %s" % [what, d])
			break
		entered = entered or path.in_room(d)
	if not entered or not path.in_room(line.end):
		_wrong.append("%s: its course never stands in its cache room" % what)
	var gate: Vector2 = line.point_at(path.gate_at)
	if path.gate_at < 0.0 or path.gate_at > line.end or gate.y != from.floor_row():
		_wrong.append("%s: its gate at %s is not on room %d's floor" % [what, gate, from.index])
	if path.ladder.has_area():
		_check_ladder(path, from, gate, what)
	else:
		_check_tunnel(level, path, from, gate, what)
	for ladder: Rect2i in level.ladders:
		var meets: bool = ladder.position.y - 1 == gate.y or ladder.end.y - 1 == gate.y
		var clear: bool = (
			gate.x <= ladder.position.x - GATE_CLEAR or gate.x >= ladder.end.x + GATE_CLEAR
		)
		if meets and not clear:
			_wrong.append("%s: its gate at %s is by the route's ladder %s" % [what, gate, ladder])
	for door: float in [main.entry, main.exit]:
		var doorway: Vector2 = main.point_at(door)
		if doorway.y == gate.y and absf(doorway.x - gate.x) < GATE_CLEAR:
			_wrong.append("%s: its gate at %s is by a doorway" % [what, gate])


func _check_ladder(path: SidePath, from: LabyrinthChamber, gate: Vector2, what: String) -> void:
	var ladder: Rect2i = path.ladder
	var cache: Rect2i = path.room.rect
	if ladder.size != Vector2i(Labyrinth.SHAFT_WIDTH, FLOOR_GAP):
		_wrong.append("%s: a ladder of %s" % [what, ladder.size])
	if absi(path.room.floor_row() - from.floor_row()) != FLOOR_GAP:
		_wrong.append("%s: its ladder does not go to a neighbouring floor" % what)
	for room: Rect2i in [from.rect, cache]:
		if ladder.position.x < room.position.x + INSET or ladder.end.x > room.end.x - INSET:
			_wrong.append("%s: its ladder %s is by a wall of %s" % [what, ladder, room])
	var upper: int = mini(from.floor_row(), path.room.floor_row())
	if ladder.position.y != upper + 1 or ladder.end.y != upper + FLOOR_GAP + 1:
		_wrong.append("%s: its ladder %s is not between its floors" % [what, ladder])
	var rung: float = ladder.position.x + ladder.size.x / 2.0
	if path.gate_at != 0.0 or gate != Vector2(rung, from.floor_row()):
		_wrong.append("%s: its gate at %s is not at its ladder" % [what, gate])


func _check_tunnel(
	level: LabyrinthLevel, path: SidePath, from: LabyrinthChamber, gate: Vector2, what: String
) -> void:
	var tunnel: Rect2i = path.tunnel
	var cache: Rect2i = path.room.rect
	if tunnel.size.x < TUNNEL_LENGTH.x or tunnel.size.x > TUNNEL_LENGTH.y:
		_wrong.append("%s: a tunnel %d long" % [what, tunnel.size.x])
	if tunnel.size.y != TUNNEL_HEIGHT or tunnel.end.y != from.rect.end.y:
		_wrong.append("%s: its tunnel %s is not on room %d's floor" % [what, tunnel, from.index])
	if cache.end.y != from.rect.end.y:
		_wrong.append("%s: its cache room is on another floor" % what)
	var rightward: bool = tunnel.position.x == from.rect.end.x
	var wall: int = from.rect.end.x if rightward else from.rect.position.x
	var joined: bool = tunnel.end.x == cache.position.x
	if not rightward:
		joined = tunnel.end.x == from.rect.position.x and tunnel.position.x == cache.end.x
	if not joined:
		_wrong.append("%s: its tunnel %s does not join its rooms" % [what, tunnel])
	if gate.x != wall:
		_wrong.append("%s: its gate at %s is not at its tunnel's mouth" % [what, gate])
	for other: Rect2i in level.tunnels:
		var beside: bool = other.position.x == wall or other.end.x == wall
		if beside and other.end.y == from.rect.end.y:
			_wrong.append("%s: its wall is the route's tunnel's" % what)


## The rules for a winding stage's rooms, with the side paths in: every side rectangle a tile
## inside the band, overlapping nothing but its own ladder's room, and with earth between it and
## everything it is not joined to.
func _check_earth(level: LabyrinthLevel, where: String) -> void:
	var main: Array[Rect2i] = level.open_rects()
	var inside: Rect2i = level.band.grow(-1)
	# Each side rectangle, and the rectangles it may touch.
	var mine: Array[Rect2i] = []
	var friends: Array[Array] = []
	for path: SidePath in level.side_paths:
		var from: Rect2i = level.chambers[_room_of(level, path)].rect
		var way: Rect2i = path.tunnel if path.tunnel.has_area() else path.ladder
		mine.append(path.room.rect)
		friends.append([way])
		mine.append(way)
		friends.append([from, path.room.rect])
	for i: int in mine.size():
		if not inside.encloses(mine[i]):
			_wrong.append("%s: %s is not a tile inside the band" % [where, mine[i]])
		var others: Array[Rect2i] = main.duplicate()
		for j: int in mine.size():
			if j != i:
				others.append(mine[j])
		for other: Rect2i in others:
			if friends[i].has(other):
				continue
			if mine[i].grow(1).intersects(other):
				_wrong.append("%s: no earth between %s and %s" % [where, mine[i], other])
	for path: SidePath in level.side_paths:
		if not path.ladder.has_area():
			continue
		for room: Rect2i in [level.chambers[_room_of(level, path)].rect, path.room.rect]:
			var shared: Rect2i = path.ladder.intersection(room)
			var foot: bool = path.ladder.end.y == room.end.y
			if foot and shared.size != Vector2i(path.ladder.size.x, room.size.y):
				_wrong.append("%s: ladder %s leaves room %s" % [where, path.ladder, room])
			if not foot and (shared.has_area() or path.ladder.position.y != room.end.y):
				_wrong.append("%s: ladder %s is not under room %s" % [where, path.ladder, room])
