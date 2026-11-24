class_name AmbienceClearings
extends RefCounted
## The columns of each chamber of one level that its decoration keeps clear: where a ladder
## passes and where a doorway stands.
##
## On a flat level every chamber keeps the same columns clear, those of the shaft down and of the
## shaft from above, as both cross its one floor. On a winding level each room keeps clear only
## the ladders that meet it (through its floor, or down to it from the floor above), a side
## path's ladder among them, the column by the mouth of a side tunnel that leaves it, and the
## doorways that stand in it: a ladder two floors away takes nothing from it. A side path's
## cache room keeps clear its own ladder, the column by its tunnel's mouth and the columns its
## cache stands in.
##
## And what stands in each room that no decoration may meet ([method standing],
## [method cache_standing]): those columns for the room's whole height, the mouths of its
## tunnels, a side path's gate, its cache, and the place a quest's prop takes.

const TILE: int = LabyrinthView.TILE

var _level: LabyrinthLevel

## By chamber index: the columns kept clear, and those of them nothing opens the floor in (a
## ladder that comes down to this floor, a doorway).
var _clear: Dictionary[int, Dictionary] = {}
var _closed: Dictionary[int, Dictionary] = {}
## The same for each side path's cache room, by the path's place in the level's list.
var _cache_clear: Array[Dictionary] = []
var _cache_closed: Array[Dictionary] = []


func _init(view: LabyrinthView, depth: int) -> void:
	var level: LabyrinthLevel = view.labyrinth.level(depth)
	_level = level
	if view.labyrinth.shape == Labyrinth.Shape.WINDING:
		_note_winding(view, level)
		return
	var clear: Dictionary[int, bool] = {}
	var closed: Dictionary[int, bool] = {}
	_note(clear, level.shaft_down.position.x, level.shaft_down.end.x)
	if depth > 1:
		var above: Rect2i = view.labyrinth.level(depth - 1).shaft_down
		_note(clear, above.position.x, above.end.x)
		_note(closed, above.position.x, above.end.x)
	for chamber: LabyrinthChamber in level.chambers:
		_clear[chamber.index] = clear
		_closed[chamber.index] = closed


## The columns of chamber [param chamber_index] to keep clear.
func columns(chamber_index: int) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var kept: Dictionary = _clear.get(chamber_index, {})
	found.assign(kept)
	return found


## Those of [method columns] where the chamber's floor is whole.
func closed_columns(chamber_index: int) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var kept: Dictionary = _closed.get(chamber_index, {})
	found.assign(kept)
	return found


## The columns of the cache room of the side path at [param place] to keep clear.
func cache_columns(place: int) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	if place >= 0 and place < _cache_clear.size():
		found.assign(_cache_clear[place])
	return found


## Those of [method cache_columns] where the cache room's floor is whole.
func cache_closed_columns(place: int) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	if place >= 0 and place < _cache_closed.size():
		found.assign(_cache_closed[place])
	return found


## What stands in [param room], a chamber of the route, that no decoration may meet, in world
## pixels.
func standing(room: LabyrinthChamber) -> Array[Rect2]:
	var found: Array[Rect2] = _in_room(room, columns(room.index))
	var spot: Vector2 = _middle(room)
	for path: String in QuestProps.SHEETS.values():
		found.append(_stood(PixelSheet.load_sheet(path), spot))
	return found


## The same for the cache room of the side path at [param place].
func cache_standing(place: int) -> Array[Rect2]:
	var room: LabyrinthChamber = _level.side_paths[place].room
	var found: Array[Rect2] = _in_room(room, cache_columns(place))
	found.append(_stood(SideProps.sheet_of(SideProps.CACHE), _middle(room)))
	return found


## The middle of the floor of [param room], where a quest's prop or a cache stands.
static func _middle(room: LabyrinthChamber) -> Vector2:
	var middle: float = floorf((room.rect.position.x + room.rect.end.x) / 2.0)
	return Vector2(middle * TILE, room.rect.end.y * TILE)


## The rectangle a sprite of [param sheet] covers standing at [param feet], as the world's props
## are stood; nothing if it has no sheet.
static func _stood(sheet: PixelSheet, feet: Vector2) -> Rect2:
	if sheet == null:
		return Rect2(feet, Vector2.ZERO)
	return Rect2(feet - Vector2(sheet.pivot) - Vector2(0, 1), Vector2(sheet.size))


## For [param room]: each of [param clear] (its columns kept clear) for its whole height, the
## column beside each tunnel's mouth for the mouth's height and a row over it, and the gates
## that stand in it.
func _in_room(room: LabyrinthChamber, clear: Dictionary[int, bool]) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var rect: Rect2i = room.rect
	var floor_px: float = rect.end.y * TILE
	var top: float = minf(rect.position.y, rect.end.y - RoomShape.MOST_ROWS) * TILE
	for column: int in clear:
		found.append(Rect2(column * TILE, top, TILE, floor_px - top))
	var tunnels: Array[Rect2i] = _level.tunnels.duplicate()
	var pixels := Rect2(rect.position * TILE, rect.size * TILE)
	for path: SidePath in _level.side_paths:
		tunnels.append(path.tunnel)
		var feet: Vector2 = path.course.point_at(path.gate_at)
		var gate: Rect2 = _stood(SideProps.sheet_of(path.gate), (feet + Vector2(0, 1)) * TILE)
		if gate.has_area() and pixels.intersects(gate):
			found.append(gate)
	for tunnel: Rect2i in tunnels:
		if not tunnel.has_area() or tunnel.end.y != rect.end.y:
			continue
		var beside: int = -1
		if tunnel.position.x == rect.end.x:
			beside = rect.end.x - 1
		elif tunnel.end.x == rect.position.x:
			beside = rect.position.x
		if beside >= 0:
			var mouth: float = (tunnel.position.y - 1) * TILE
			found.append(Rect2(beside * TILE, mouth, TILE, floor_px - mouth))
	return found


func _note_caches(level: LabyrinthLevel) -> void:
	for path: SidePath in level.side_paths:
		var rect: Rect2i = path.room.rect
		var clear: Dictionary[int, bool] = {}
		var closed: Dictionary[int, bool] = {}
		# The cache stands on the room's middle, a column either side of it.
		var middle: int = floori((rect.position.x + rect.end.x) / 2.0)
		_note(clear, middle - 1, middle + 1)
		_note(closed, middle - 1, middle + 1)
		if path.ladder.has_area():
			_note(clear, path.ladder.position.x, path.ladder.end.x)
			if path.ladder.end.y - 1 == path.room.floor_row():
				_note(closed, path.ladder.position.x, path.ladder.end.x)
		elif path.tunnel.end.x == rect.position.x:
			_note(clear, rect.position.x, rect.position.x + 1)
			_note(closed, rect.position.x, rect.position.x + 1)
		else:
			_note(clear, rect.end.x - 1, rect.end.x)
			_note(closed, rect.end.x - 1, rect.end.x)
		_cache_clear.append(clear)
		_cache_closed.append(closed)


func _note_winding(view: LabyrinthView, level: LabyrinthLevel) -> void:
	_note_caches(level)
	var ladders: Array[Rect2i] = level.ladders + level.side_ladders()
	for room: LabyrinthChamber in level.chambers:
		var clear: Dictionary[int, bool] = {}
		var closed: Dictionary[int, bool] = {}
		for path: SidePath in level.side_paths:
			# The column by the mouth of a side tunnel that leaves this room.
			if not path.tunnel.has_area() or path.tunnel.end.y != room.rect.end.y:
				continue
			if path.tunnel.position.x == room.rect.end.x:
				_note(clear, room.rect.end.x - 1, room.rect.end.x)
				_note(closed, room.rect.end.x - 1, room.rect.end.x)
			elif path.tunnel.end.x == room.rect.position.x:
				_note(clear, room.rect.position.x, room.rect.position.x + 1)
				_note(closed, room.rect.position.x, room.rect.position.x + 1)
		for ladder: Rect2i in ladders:
			if ladder.position.x < room.rect.position.x or ladder.end.x > room.rect.end.x:
				continue
			if ladder.position.y - 1 == room.floor_row():
				_note(clear, ladder.position.x, ladder.end.x)
			elif ladder.end.y - 1 == room.floor_row():
				_note(clear, ladder.position.x, ladder.end.x)
				_note(closed, ladder.position.x, ladder.end.x)
		var pixels := Rect2(room.rect.position * TILE, room.rect.size * TILE)
		for door: Rect2 in view.doorways(level.depth):
			if not pixels.intersects(door):
				continue
			var from: int = floori(door.position.x / TILE)
			var to: int = ceili(door.end.x / TILE)
			_note(clear, from, to)
			_note(closed, from, to)
		_clear[room.index] = clear
		_closed[room.index] = closed


static func _note(into: Dictionary[int, bool], from: int, to: int) -> void:
	for x: int in range(from, to):
		into[x] = true
