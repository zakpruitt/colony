class_name AmbienceSeen
extends RefCounted
## What of the stage shown the party has seen: the view's own memory, beside [AmbienceRooms].
## A place is seen if it is a lit room, a tunnel or ladder that touches a lit room (its whole
## length), or earth within [constant REACH] tiles of one of those; everything else is black.
##
## It is decided from the level's rectangles (rooms, tunnels, ladders, side paths), never from
## which tiles are open. A room drawn in a shape of its own counts as the bounds of that shape,
## so the earth over a room opened upward is seen as over any other. It keeps one small map,
## a pixel a tile, that the darkness's veil reads
## ([member texture]): how near each tile is to something seen, so the black's edge is soft. A
## place just seen comes out of the black over [constant SHOW_SECONDS], one forgotten goes back
## into it over [constant HIDE_SECONDS]; told to settle at once, neither fades. The map is
## remade only while something fades.
##
## It is off (everything seen) until [method follow] is given a level.

## How many tiles of earth round a seen place are seen: the nearest whole, the rest fading.
const REACH: int = 3
## Seconds for the black to leave a place, and to close over one.
const SHOW_SECONDS: float = 0.4
const HIDE_SECONDS: float = 0.6
const TILE: int = LabyrinthView.TILE


## One room, tunnel or ladder: the rooms that make it seen (itself, for a room), the map's
## tiles inside it, and those round it with how near each is.
class Place:
	extends RefCounted
	var rooms: PackedInt32Array = []
	var inside: PackedInt32Array = []
	var around: PackedInt32Array = []
	var nearness: PackedByteArray = []
	## How much of it is out of the black, 0 to 1, and where that is heading.
	var shown: float = 0.0
	var goal: float = 0.0


## The map: a tile a pixel, red for how near that tile is to something seen. One object for
## good; its pixels change only while a place fades.
var texture := ImageTexture.new()
## The world tile of the map's first pixel.
var origin: Vector2i = Vector2i.ZERO
## Goes up each time the map's pixels, its place or whether it is on changes.
var changes: int = 0

var _level: LabyrinthLevel
var _rooms: Array[Place] = []
var _links: Array[Place] = []
var _size: Vector2i = Vector2i.ZERO
var _bytes: PackedByteArray = []
## The map's pixels as the texture takes them: one object, filled again from the bytes.
var _map: Image
var _lit_at: int = -1
var _fading: int = 0


## True while there is a stage whose unseen places are black.
func is_on() -> bool:
	return _level != null


## How many places are coming out of the black or going into it.
func fading() -> int:
	return _fading


## Takes what is seen from [param rooms], the lit rooms of [param level] (the stage shown);
## null for a stage with nothing hidden. [param shapes] are its rooms as drawn, or null where
## they are drawn as their rectangles. [param at_once], or a level not followed before, shows
## it with no fade.
func follow(
	level: LabyrinthLevel, shapes: StageShapes, rooms: AmbienceRooms, at_once: bool
) -> void:
	var fresh: bool = level != _level
	if fresh:
		_level = level
		_survey(shapes)
	if level == null or not (fresh or at_once or _lit_at != rooms.changes):
		return
	_lit_at = rooms.changes
	var moved: bool = fresh
	_fading = 0
	for place: Place in _rooms:
		moved = _aim(place, rooms, fresh or at_once) or moved
	for place: Place in _links:
		moved = _aim(place, rooms, fresh or at_once) or moved
	if moved:
		_compose()


## Moves the fades on by [param delta] seconds. Nothing to do, and nothing done, while none runs.
func advance(delta: float) -> void:
	if _fading == 0:
		return
	_fading = 0
	for place: Place in _rooms:
		_fade(place, delta)
	for place: Place in _links:
		_fade(place, delta)
	_compose()


## How near the world pixel [param world_pixels] is to something seen, 0 (black) to 1, as the
## veil's shader reads the map: between the tiles' middles, a blend of the four round it.
func nearness_at(world_pixels: Vector2) -> float:
	if _level == null:
		return 1.0
	var point := Vector2(floorf(world_pixels.x) + 0.5, floorf(world_pixels.y) + 0.5)
	var cell: Vector2 = point / TILE - Vector2(origin)
	if cell.x < 0.0 or cell.y < 0.0 or cell.x > _size.x or cell.y > _size.y:
		return 0.0
	cell -= Vector2(0.5, 0.5)
	var low := Vector2i(cell.floor())
	var share: Vector2 = cell - Vector2(low)
	var top: float = lerpf(_byte(low.x, low.y), _byte(low.x + 1, low.y), share.x)
	var bottom: float = lerpf(_byte(low.x, low.y + 1), _byte(low.x + 1, low.y + 1), share.x)
	return lerpf(top, bottom, share.y) / 255.0


func _byte(x: int, y: int) -> float:
	return _bytes[clampi(y, 0, _size.y - 1) * _size.x + clampi(x, 0, _size.x - 1)]


## Sets where [param place] is heading by whether one of its rooms is lit, and there at once
## with [param at_once]. True if what it shows changed.
func _aim(place: Place, rooms: AmbienceRooms, at_once: bool) -> bool:
	var goal: float = 0.0
	for room: int in place.rooms:
		if rooms.is_lit(room):
			goal = 1.0
			break
	place.goal = goal
	if at_once:
		var moved: bool = place.shown != goal
		place.shown = goal
		return moved
	if place.shown != goal:
		_fading += 1
	return false


func _fade(place: Place, delta: float) -> void:
	if place.shown == place.goal:
		return
	if place.goal > place.shown:
		place.shown = minf(place.shown + delta / SHOW_SECONDS, place.goal)
	else:
		place.shown = maxf(place.shown - delta / HIDE_SECONDS, place.goal)
	if place.shown != place.goal:
		_fading += 1


## Lists the level's places and makes the map's room: the level's band and the earth round it
## that can be seen, with a tile of black beyond.
func _survey(shapes: StageShapes) -> void:
	_rooms.clear()
	_links.clear()
	_lit_at = -1
	_fading = 0
	changes += 1
	if _level == null:
		return
	var cover: Rect2i = _level.band.grow(REACH + 1)
	origin = cover.position
	_size = cover.size
	_bytes.resize(_size.x * _size.y)
	var lit_by: Dictionary[int, Rect2i] = {}
	for room: LabyrinthChamber in _level.chambers:
		lit_by[room.index] = _bounds(shapes, room)
	for at: int in _level.side_paths.size():
		lit_by[AmbienceRooms.CACHE + at] = _bounds(shapes, _level.side_paths[at].room)
	for room: int in lit_by:
		_rooms.append(_place(lit_by[room], PackedInt32Array([room])))
	var ways: Array[Rect2i] = _level.tunnels + _level.ladders
	for path: SidePath in _level.side_paths:
		ways.append(path.tunnel)
		ways.append(path.ladder)
	for way: Rect2i in ways:
		if not way.has_area():
			continue
		var touched: PackedInt32Array = []
		for room: int in lit_by:
			if way.grow(1).intersects(lit_by[room]):
				touched.append(room)
		_links.append(_place(way, touched))
	_bytes.fill(0)
	_map = Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_R8, _bytes)
	texture.set_image(_map)


## The tiles [param room] reaches as drawn: its shape's bounds, or its rectangle with no shape.
static func _bounds(shapes: StageShapes, room: LabyrinthChamber) -> Rect2i:
	var shape: RoomShape = shapes.shape_of(room) if shapes != null else null
	return shape.bounds() if shape != null else room.rect


## The place of [param rect] (world tiles), seen while one of [param rooms] is lit.
func _place(rect: Rect2i, rooms: PackedInt32Array) -> Place:
	var made := Place.new()
	made.rooms = rooms
	var reach: Rect2i = rect.grow(REACH).intersection(Rect2i(origin, _size))
	for y: int in range(reach.position.y, reach.end.y):
		for x: int in range(reach.position.x, reach.end.x):
			var cell: int = (y - origin.y) * _size.x + (x - origin.x)
			var out := Vector2(
				maxi(maxi(rect.position.x - x, x - rect.end.x + 1), 0),
				maxi(maxi(rect.position.y - y, y - rect.end.y + 1), 0)
			)
			if out == Vector2.ZERO:
				made.inside.append(cell)
				continue
			var near: float = clampf((REACH + 1.0 - out.length()) / REACH, 0.0, 1.0)
			if near > 0.0:
				made.around.append(cell)
				made.nearness.append(roundi(near * 255.0))
	return made


## Remakes the map from how much of each place is shown. The earth takes the most any place
## round it gives; a place's own tiles take only its own share, so nothing seen beside a black
## room shows into it, but for a seen ladder that runs through one.
func _compose() -> void:
	_bytes.fill(0)
	_spread(_rooms)
	_spread(_links)
	_own(_links, false)
	_own(_rooms, false)
	_own(_links, true)
	_map.set_data(_size.x, _size.y, false, Image.FORMAT_R8, _bytes)
	texture.update(_map)
	changes += 1


## Gives the earth round each of [param places] its share, where that is the most so far.
func _spread(places: Array[Place]) -> void:
	for place: Place in places:
		if place.shown <= 0.0:
			continue
		for i: int in place.around.size():
			var near: int = int(place.nearness[i] * place.shown)
			if near > _bytes[place.around[i]]:
				_bytes[place.around[i]] = near


## Gives the tiles of each of [param places] its own share; with [param most], only where that
## is more than they have.
func _own(places: Array[Place], most: bool) -> void:
	for place: Place in places:
		var own: int = int(255.0 * place.shown)
		for cell: int in place.inside:
			if not most or own > _bytes[cell]:
				_bytes[cell] = own
