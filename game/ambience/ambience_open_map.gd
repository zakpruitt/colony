class_name AmbienceOpenMap
extends RefCounted
## Which tiles of one level's band are open, as the view draws them, and from that how much
## lamplight reaches each tile. The band is as tall as the labyrinth's stages are.

## How much light reaches each tile of the band (one pixel per tile, red channel): all of it in
## open space, less in the earth (see [constant AmbienceMood.EDGE_EXPOSURE]).
var exposure: Image

## Open tiles of the band and a one-tile border round it: 1 open, 0 earth.
var _open: PackedByteArray = []
var _top: int
var _rows: int


## Marks the open tiles of the band of [param depth] as [param view] draws them (chambers, tunnels
## and shafts, including the shaft from the level above and those of the levels either side
## reaching in; a stage shown as its own place has no shafts, only the ladders inside it), and
## from them how much light reaches each tile.
func _init(view: LabyrinthView, depth: int) -> void:
	_rows = view.labyrinth.band_height()
	_top = (depth - 1) * _rows
	var width: int = Labyrinth.LEVEL_WIDTH + 2
	_open.resize(width * (_rows + 2))
	var band := Rect2i(-1, _top - 1, width, _rows + 2)
	for rect: Rect2i in view.open_rects_near(depth):
		var overlap: Rect2i = rect.intersection(band)
		for y: int in range(overlap.position.y, overlap.end.y):
			for x: int in range(overlap.position.x, overlap.end.x):
				_open[(y - _top + 1) * width + x + 1] = 1
	exposure = Image.create_empty(Labyrinth.LEVEL_WIDTH, _rows, false, Image.FORMAT_R8)
	for y: int in _rows:
		for x: int in Labyrinth.LEVEL_WIDTH:
			var tile := Vector2i(x, _top + y)
			var value: float = AmbienceMood.EARTH_EXPOSURE
			if is_open(tile):
				value = 1.0
			elif not is_buried(tile):
				value = AmbienceMood.EDGE_EXPOSURE
			exposure.set_pixel(x, y, Color(value, 0.0, 0.0))


## The band's first world row, and how many rows it has.
func top() -> int:
	return _top


func rows() -> int:
	return _rows


## How much light reaches a world tile of this band: 1 in open space, less in the earth.
func exposure_at(tile: Vector2i) -> float:
	var local := Vector2i(tile.x, tile.y - _top)
	if local.x < 0 or local.y < 0 or local.x >= exposure.get_width():
		return AmbienceMood.EARTH_EXPOSURE
	if local.y >= exposure.get_height():
		return AmbienceMood.EARTH_EXPOSURE
	return exposure.get_pixelv(local).r


func is_open(tile: Vector2i) -> bool:
	# Columns outside the band are earth, as is the sky.
	if tile.x < 0 or tile.x >= Labyrinth.LEVEL_WIDTH or tile.y < 0:
		return false
	var row: int = tile.y - _top + 1
	if row < 0 or row >= _rows + 2:
		return false
	return _open[row * (Labyrinth.LEVEL_WIDTH + 2) + tile.x + 1] == 1


## Earth all round: not open, and no open neighbour, diagonals included.
func is_buried(tile: Vector2i) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if is_open(tile + Vector2i(dx, dy)):
				return false
	return true
