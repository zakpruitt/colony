class_name AmbienceRoom
extends RefCounted
## One room of a level while [AmbienceLevel] dresses it: its floor and its ceiling as drawn, the
## columns it keeps clear, the lists its props join, and numbers rolled from the level's seed, the
## same every build.

const TILE: int = LabyrinthView.TILE

## The room: a chamber of the route, or a side path's cache room.
var chamber: LabyrinthChamber
## The look's index in [constant LabyrinthTiles.STRATA] the room is drawn with.
var band: int
## The floor line, in world pixels.
var floor_px: float
## The columns kept clear for a ladder or a doorway, and those of them where the floor is whole
## (see [AmbienceClearings]).
var clear: Dictionary[int, bool] = {}
var closed: Dictionary[int, bool] = {}
## The torches placed so far, and the list this room's props join: the level's own lists.
var torches: Array[AmbienceProp] = []
var props: Array[AmbienceProp] = []
## What stands in the room that no decoration may meet, in world pixels (see
## [AmbienceClearings]), and where its own torches and props begin in the lists above.
var kept: Array[Rect2] = []
var first_torch: int = 0
var first_prop: int = 0
## The level's lists of what throws embers and of what gleams.
var emitters: Array[AmbienceProp] = []
var gleams: Array[AmbienceProp] = []

var _seed: int
## The level's rooms as drawn, or null where each is drawn as its rectangle.
var _shapes: StageShapes
var _map: AmbienceOpenMap


func _init(
	room: LabyrinthChamber, look: int, level_seed: int, shapes: StageShapes, map: AmbienceOpenMap
) -> void:
	chamber = room
	band = look
	floor_px = (room.floor_row() + 1) * TILE
	_seed = level_seed
	_shapes = shapes
	_map = map


## A number from the level's seed, [param salt] and a position: the same every build.
func roll(salt: int, a: int, b: int = 0) -> int:
	return AmbienceLevel.mix(AmbienceLevel.mix(AmbienceLevel.mix(_seed, salt), a), b)


## The world row of the highest open tile of [param column] as the room is drawn.
func ceiling_row(column: int) -> int:
	if _shapes == null:
		return chamber.rect.position.y
	return _shapes.shape_of(chamber).ceiling_row(column)


## The ceiling line, in world pixels, over [param column] as the room is drawn.
func ceiling_px(column: int) -> float:
	return ceiling_row(column) * TILE


## True if this world tile is open as the level is drawn.
func is_open(tile: Vector2i) -> bool:
	return _map.is_open(tile)


## Whether [param x] or a column next to it is kept clear.
func near_clear(x: int) -> bool:
	return clear.has(x - 1) or clear.has(x) or clear.has(x + 1)


## Whether [param x] or a column next to it is kept clear over a whole floor.
func near_closed(x: int) -> bool:
	return closed.has(x - 1) or closed.has(x) or closed.has(x + 1)


## The world row of the highest open tile over the floor in [param column], whatever opened it:
## over a ladder it is higher than the room's own ceiling.
func open_top(column: int) -> int:
	var row: int = chamber.floor_row()
	var highest: int = row - RoomShape.MOST_ROWS * 2
	while row > highest and is_open(Vector2i(column, row - 1)):
		row -= 1
	return row


## The columns under a dip of the ceiling that holds [param column], as (first, last): a level
## run lower than the ceiling either side of it, between the walls' columns. (-1, -1) if
## [param column] is under none.
func dip_at(column: int) -> Vector2i:
	var from: int = chamber.rect.position.x + 1
	var to: int = chamber.rect.end.x - 2
	if column < from or column > to:
		return Vector2i(-1, -1)
	var row: int = open_top(column)
	var first: int = column
	var last: int = column
	while first > from and open_top(first - 1) == row:
		first -= 1
	while last < to and open_top(last + 1) == row:
		last += 1
	if open_top(first - 1) < row and open_top(last + 1) < row:
		return Vector2i(first, last)
	return Vector2i(-1, -1)
