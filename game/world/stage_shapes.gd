class_name StageShapes
extends RefCounted
## The rooms of one winding stage as drawn (a [RoomShape] each, the route's and the cache
## rooms'), and from them every open tile of the stage: the shapes, the tunnels and the ladders.

var _shapes: Dictionary[Rect2i, RoomShape] = {}
var _band: Rect2i
## One byte a tile of the band: 1 open, 0 earth.
var _open: PackedByteArray = []
var _rects: Array[Rect2i] = []


## The shapes of stage [param depth] of [param labyrinth], cut in the manner of [param look].
static func of(labyrinth: Labyrinth, depth: int, look: ZoneLook) -> StageShapes:
	var made := StageShapes.new()
	var level: LabyrinthLevel = labyrinth.level(depth)
	made._band = level.band
	made._open.resize(level.band.size.x * level.band.size.y)
	for room: LabyrinthChamber in level.chambers:
		made._shape(labyrinth, level, room, look)
	for passage: Rect2i in level.tunnels + level.ladders:
		made._cut(passage)
	for path: SidePath in level.side_paths:
		made._shape(labyrinth, level, path.room, look)
		for passage: Rect2i in [path.tunnel, path.ladder]:
			if passage.has_area():
				made._cut(passage)
	return made


## The shape of [param room], a room of the stage's route or a cache room of it; null for
## any other.
func shape_of(room: LabyrinthChamber) -> RoomShape:
	return _shapes.get(room.rect)


## True if this world tile is open on the stage as drawn.
func is_open(tile: Vector2i) -> bool:
	if not _band.has_point(tile):
		return false
	var local: Vector2i = tile - _band.position
	return _open[local.y * _band.size.x + local.x] == 1


## Rectangles that hold every open tile of the stage: each room's [method RoomShape.bounds],
## the tunnels and the ladders, the route's first and then each side path's.
func open_rects() -> Array[Rect2i]:
	return _rects.duplicate()


func _shape(
	labyrinth: Labyrinth, level: LabyrinthLevel, room: LabyrinthChamber, look: ZoneLook
) -> void:
	var shape: RoomShape = RoomShape.of(labyrinth, level, room, look)
	_shapes[room.rect] = shape
	var bounds: Rect2i = shape.bounds()
	_rects.append(bounds)
	for x: int in range(bounds.position.x, bounds.end.x):
		for y: int in range(shape.ceiling_row(x), bounds.end.y):
			_mark(Vector2i(x, y))


func _cut(passage: Rect2i) -> void:
	_rects.append(passage)
	for y: int in range(passage.position.y, passage.end.y):
		for x: int in range(passage.position.x, passage.end.x):
			_mark(Vector2i(x, y))


func _mark(tile: Vector2i) -> void:
	if _band.has_point(tile):
		var local: Vector2i = tile - _band.position
		_open[local.y * _band.size.x + local.x] = 1
