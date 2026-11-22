class_name LabyrinthView
extends Node2D
## Draws the labyrinth as a cross-section of earth: solid ground with the levels' chambers,
## tunnels and shafts cut out of it, a ladder in every shaft, and the surface above depth 1.
##
## Only the levels near the focus exist as nodes (see [method set_focus]). Each built level is a
## Node2D holding four TileMapLayers, in world tile coordinates: Ground (earth or back wall),
## Edges (floor tops, ceilings, wall faces, and shade on the back wall), Corners (inner corners)
## and Ladder. The art is in [LabyrinthTiles].
##
## Zoned (as the game's world is), each stage is shown as its own place instead: only the
## focus stage is built, with earth all round it, no shafts and no ladders, and a doorway in the
## far wall where each shaft left or arrived. Its earth is its area's look ([ZoneLook]).
##
## Zoned, a winding labyrinth's stage ([constant Labyrinth.Shape.WINDING]) is cut out whole, as
## tall as [method Labyrinth.band_height]: its rooms on their floors, its tunnels, a ladder in
## each of [member LabyrinthLevel.ladders], and a doorway at its course's exit and entry.

## Emitted after the level at [param depth] has been built, so others can decorate it.
signal level_built(depth: int)
## Emitted after the level at [param depth] has been freed.
signal level_freed(depth: int)

const TILE: int = 16
## Levels this far from the focus level are built.
const BUILD_RADIUS: int = 1
## Levels further than this from the focus level are freed. More than [constant BUILD_RADIUS],
## so walking back and forth across a level boundary does not rebuild every time.
const KEEP_RADIUS: int = 2
## Rows of sky drawn above the ground line, enough to fill the screen above depth 1.
const SKY_ROWS: int = 24
## Zoned: rows of earth drawn above and below the stage, enough to fill the screen round it.
const SURROUND_ROWS: int = 8
const DOORWAY: String = "res://assets/sprites/props/doorway.png"

const _W: int = Labyrinth.LEVEL_WIDTH
const _LAYERS: Array[String] = ["Ground", "Edges", "Corners", "Ladder"]

## Set before entering the tree.
var labyrinth: Labyrinth
## Set before entering the tree: true to show each stage as its own place.
var zoned: bool = false
## Zoned: the area [member labyrinth] belongs to, which gives the stages their look.
var area: StringName = &""

var _levels: Dictionary[int, Node2D] = {}
var _surface: TileMapLayer


func _ready() -> void:
	if not zoned:
		_build_surface()


## Tells the view where the action is, in world tiles; it builds and frees levels to suit. Zoned,
## only the level the focus is on is kept.
func set_focus(world_tiles: Vector2) -> void:
	var depth: int = maxi(1, floori(world_tiles.y / _rows()) + 1)
	var keep: int = 0 if zoned else KEEP_RADIUS
	var reach: int = 0 if zoned else BUILD_RADIUS
	for built: int in _levels.keys():
		if absi(built - depth) > keep:
			_levels[built].free()
			_levels.erase(built)
			level_freed.emit(built)
	for near: int in range(maxi(1, depth - reach), depth + reach + 1):
		if not _levels.has(near):
			_levels[near] = _build_level(near)
			level_built.emit(near)


## Zoned: the look of the stage shown (the one built), or of stage 1 before any is. Null when not
## zoned.
func zone_look() -> ZoneLook:
	if not zoned:
		return null
	var stage: int = 1
	for built: int in _levels:
		stage = built
	return ZoneLook.of(area, stage)


## The look's index in [constant LabyrinthTiles.STRATA] that [param depth] is drawn with: its
## area's when zoned, by depth otherwise.
func band_of(depth: int) -> int:
	if zoned:
		return ZoneLook.of(area, depth).band
	return AmbienceMood.band(depth)


## The doorways shown on [param depth] (zoned only), in world pixels: one where the shaft from it
## left (the way on) and one where the shaft from the stage before it arrived (the way back).
## Each stands on the floor, two tiles wide, centred on the shaft's middle. On a winding stage
## they are where its course leaves and, from stage 2 on, where it arrives, each on the floor of
## the room that point is in.
func doorways(depth: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not zoned:
		return rects
	var level: LabyrinthLevel = labyrinth.level(depth)
	var size: Vector2 = Vector2(PixelSheet.load_sheet(DOORWAY).size)
	if _winding():
		var marks: Array[float] = [level.course.exit]
		if depth > 1:
			marks.append(level.course.entry)
		for mark: float in marks:
			var feet: Vector2 = level.course.point_at(mark)
			rects.append(
				Rect2(feet.x * TILE - size.x / 2.0, (feet.y + 1.0) * TILE - size.y, size.x, size.y)
			)
		return rects
	var floor_px: float = (level.floor_y + 1) * TILE
	var columns: Array[int] = [labyrinth.shaft_column(depth)]
	if depth > 1:
		columns.append(labyrinth.shaft_column(depth - 1))
	for column: int in columns:
		var middle: float = (column + Labyrinth.SHAFT_WIDTH / 2.0) * TILE
		rects.append(Rect2(middle - size.x / 2.0, floor_px - size.y, size.x, size.y))
	return rects


## The open rectangles that reach into the band of [param depth], as drawn: zoned, its chambers,
## tunnels and the ladders inside it; otherwise those of the levels either side too, shafts
## included.
func open_rects_near(depth: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if zoned:
		var level: LabyrinthLevel = labyrinth.level(depth)
		for chamber: LabyrinthChamber in level.chambers:
			rects.append(chamber.rect)
		rects.append_array(level.tunnels)
		rects.append_array(level.ladders)
		return rects
	for near: int in range(maxi(1, depth - 1), depth + 2):
		rects.append_array(labyrinth.level(near).open_rects())
	return rects


## Shows [param other] instead, when the party arrives in another area: every built level is
## freed, and the next [method set_focus] builds the new labyrinth's.
func show_labyrinth(other: Labyrinth) -> void:
	for built: int in _levels.keys():
		_levels[built].free()
		_levels.erase(built)
		level_freed.emit(built)
	labyrinth = other


## Depths currently built, ascending.
func built_depths() -> Array[int]:
	var depths: Array[int] = []
	for depth: int in _levels:
		depths.append(depth)
	depths.sort()
	return depths


## True if this world tile is open space (walkable or climbable air): inside a chamber, a
## tunnel or a shaft. The surface sky and everything outside the band's columns are not. Zoned,
## a shaft is earth; and a winding stage that is built stands alone, the rows of earth drawn
## round it being earth whatever the stages above and below hold there.
func is_open(tile: Vector2i) -> bool:
	if tile.y < 0 or tile.x < 0 or tile.x >= _W:
		return false
	if zoned and _winding():
		for rect: Rect2i in labyrinth.level(_stage_drawn_at(tile.y)).open_rects():
			if rect.has_point(tile):
				return true
		return false
	var depth: int = tile.y / _rows() + 1
	var level: LabyrinthLevel = labyrinth.level(depth)
	for rect: Rect2i in level.open_rects():
		if rect.has_point(tile):
			return not zoned or rect != level.shaft_down
	return not zoned and depth > 1 and labyrinth.level(depth - 1).shaft_down.has_point(tile)


## What is drawn at a world tile, bottom layer first, as "<sheet>/<part>" (for example
## "loam/buried_2", "loam/edge_1", "ladder/left"). Empty where nothing is built.
func visuals_at(tile: Vector2i) -> PackedStringArray:
	var layers: Array[TileMapLayer] = []
	var depth: int = _stage_drawn_at(tile.y)
	if tile.y < 0 and not _levels.has(depth):
		if _surface != null:
			layers.append(_surface)
	elif _levels.has(depth):
		for child: Node in _levels[depth].get_children():
			if child is TileMapLayer:
				layers.append(child as TileMapLayer)
	var visuals: PackedStringArray = []
	for layer: TileMapLayer in layers:
		var source_id: int = layer.get_cell_source_id(tile)
		if source_id >= 0:
			visuals.append(LabyrinthTiles.describe(source_id, layer.get_cell_atlas_coords(tile)))
	return visuals


## World pixel position of a world tile position (for placing things on the floor).
static func to_pixels(world_tiles: Vector2) -> Vector2:
	return world_tiles * TILE


## Rows of world each stage takes.
func _rows() -> int:
	return labyrinth.band_height()


func _winding() -> bool:
	return labyrinth.shape == Labyrinth.Shape.WINDING


## The stage whose drawing holds world row [param row]: the one whose band it is in, or, for a
## winding stage that is built, also the rows of earth drawn above and below it. Less than 1
## above the ground.
func _stage_drawn_at(row: int) -> int:
	if zoned and _winding():
		for built: int in _levels:
			var top: int = (built - 1) * _rows()
			if row >= top - SURROUND_ROWS and row < top + _rows() + SURROUND_ROWS:
				return built
	return floori(float(row) / _rows()) + 1


func _build_level(depth: int) -> Node2D:
	var level := Node2D.new()
	level.name = "Depth%d" % depth
	var layers: Dictionary[String, TileMapLayer] = {}
	for layer_name: String in _LAYERS:
		layers[layer_name] = _new_layer(layer_name)
		level.add_child(layers[layer_name])
	add_child(level)

	var top: int = (depth - 1) * _rows()
	var open: PackedByteArray = _open_grid(depth, top)
	var sheet: StringName = LabyrinthTiles.STRATA[band_of(depth)]
	var sheet_id: int = LabyrinthTiles.source(sheet)
	if zoned:
		_surround(layers["Ground"], sheet, top)
	for y: int in range(top, top + _rows()):
		for x: int in _W:
			var tile := Vector2i(x, y)
			var sides: int = _open_sides(open, top, x, y)
			if _is_open_in(open, top, x, y):
				layers["Ground"].set_cell(
					tile, sheet_id, LabyrinthTiles.coords(sheet, LabyrinthTiles.back_part(tile))
				)
				# Shade falls from the ceiling and the walls; the floor casts none.
				var shade: int = (LabyrinthTiles.N | LabyrinthTiles.E | LabyrinthTiles.W) & ~sides
				if shade != 0:
					layers["Edges"].set_cell(
						tile, sheet_id, LabyrinthTiles.coords(sheet, "shade_%d" % shade)
					)
				continue
			layers["Ground"].set_cell(
				tile, sheet_id, LabyrinthTiles.coords(sheet, LabyrinthTiles.buried_part(tile))
			)
			if sides != 0:
				layers["Edges"].set_cell(
					tile,
					sheet_id,
					LabyrinthTiles.coords(sheet, LabyrinthTiles.edge_part(tile, sides))
				)
			var corners: int = _open_corners(open, top, x, y, sides)
			if corners != 0:
				layers["Corners"].set_cell(
					tile, sheet_id, LabyrinthTiles.coords(sheet, "corner_%d" % corners)
				)
	if zoned:
		_place_doorways(level, depth)
		var ladders: Array[Rect2i] = labyrinth.level(depth).ladders
		_place_ladders(layers["Ladder"], ladders, top, top + _rows())
	else:
		var shafts: Array[Rect2i] = [labyrinth.level(depth).shaft_down]
		if depth > 1:
			shafts.append(labyrinth.level(depth - 1).shaft_down)
		_place_ladders(layers["Ladder"], shafts, top, top + _rows())
	return level


## Zoned: earth in the rows above and below the stage, so it stands alone in solid ground.
func _surround(layer: TileMapLayer, sheet: StringName, top: int) -> void:
	var sheet_id: int = LabyrinthTiles.source(sheet)
	var rows: Array[int] = []
	rows.assign(range(top - SURROUND_ROWS, top))
	rows.append_array(range(top + _rows(), top + _rows() + SURROUND_ROWS))
	for y: int in rows:
		for x: int in _W:
			var tile := Vector2i(x, y)
			layer.set_cell(
				tile, sheet_id, LabyrinthTiles.coords(sheet, LabyrinthTiles.buried_part(tile))
			)


## Zoned: a doorway sprite at each of [method doorways], behind everything on the stage.
func _place_doorways(level: Node2D, depth: int) -> void:
	var texture: AtlasTexture = PixelSheet.load_sheet(DOORWAY).part(&"doorway")
	var rects: Array[Rect2] = doorways(depth)
	for n: int in rects.size():
		var rect: Rect2 = rects[n]
		var door := Sprite2D.new()
		door.name = "Doorway%d" % n  # each its own name: a second "Doorway" would be renamed
		door.texture = texture
		door.centered = false
		door.position = rect.position
		level.add_child(door)


## A ladder down each of [param shafts] in the rows from [param top] to before [param end], and
## its top piece standing on the floor it goes down from, the row above the shaft.
func _place_ladders(layer: TileMapLayer, shafts: Array[Rect2i], top: int, end: int) -> void:
	var ladder_id: int = LabyrinthTiles.source(LabyrinthTiles.LADDER)
	for shaft: Rect2i in shafts:
		for y: int in range(maxi(shaft.position.y - 1, top), mini(shaft.end.y, end)):
			var prefix: String = "top_" if y < shaft.position.y else ""
			for x: int in range(shaft.position.x, shaft.end.x):
				var side: String = "left" if x == shaft.position.x else "right"
				layer.set_cell(
					Vector2i(x, y),
					ladder_id,
					LabyrinthTiles.coords(LabyrinthTiles.LADDER, prefix + side)
				)


func _build_surface() -> void:
	var surface := Node2D.new()
	surface.name = "Surface"
	add_child(surface)
	_surface = _new_layer("Sky")
	surface.add_child(_surface)
	var surface_id: int = LabyrinthTiles.source(LabyrinthTiles.SURFACE)
	var sky: Vector2i = LabyrinthTiles.coords(LabyrinthTiles.SURFACE, "sky")
	var ground: Vector2i = LabyrinthTiles.coords(LabyrinthTiles.SURFACE, "ground")
	for y: int in range(-SKY_ROWS, 0):
		for x: int in _W:
			_surface.set_cell(Vector2i(x, y), surface_id, ground if y == -1 else sky)


func _new_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = LabyrinthTiles.tile_set()
	layer.collision_enabled = false
	layer.navigation_enabled = false
	return layer


## Which tiles are open in the band of [param depth], starting at row [param top], with a
## one-tile border all round so neighbours can be read at the edges: 1 for open, 0 for earth.
func _open_grid(depth: int, top: int) -> PackedByteArray:
	var grid: PackedByteArray = []
	grid.resize((_W + 2) * (_rows() + 2))
	if zoned and _winding():
		# The stage alone: its own rooms, tunnels and ladders, whatever its neighbours hold.
		var band := Rect2i(-1, top - 1, _W + 2, _rows() + 2)
		for rect: Rect2i in labyrinth.level(depth).open_rects():
			var inside: Rect2i = rect.intersection(band)
			for y: int in range(inside.position.y, inside.end.y):
				for x: int in range(inside.position.x, inside.end.x):
					grid[(y - top + 1) * (_W + 2) + x + 1] = 1
		return grid
	for y: int in range(top - 1, top + _rows() + 1):
		for x: int in range(-1, _W + 1):
			if is_open(Vector2i(x, y)):
				grid[(y - top + 1) * (_W + 2) + x + 1] = 1
	return grid


func _is_open_in(grid: PackedByteArray, top: int, x: int, y: int) -> bool:
	return grid[(y - top + 1) * (_W + 2) + x + 1] == 1


## The sides of a tile (N, E, S, W bits) whose neighbour is open.
func _open_sides(grid: PackedByteArray, top: int, x: int, y: int) -> int:
	var sides: int = 0
	if _is_open_in(grid, top, x, y - 1):
		sides |= LabyrinthTiles.N
	if _is_open_in(grid, top, x + 1, y):
		sides |= LabyrinthTiles.E
	if _is_open_in(grid, top, x, y + 1):
		sides |= LabyrinthTiles.S
	if _is_open_in(grid, top, x - 1, y):
		sides |= LabyrinthTiles.W
	return sides


## The diagonals of an earth tile that are open while both sides next to them are earth:
## the inner corners where a floor meets a wall or a wall meets a ceiling.
func _open_corners(grid: PackedByteArray, top: int, x: int, y: int, sides: int) -> int:
	var corners: int = 0
	var n: bool = sides & LabyrinthTiles.N != 0
	var e: bool = sides & LabyrinthTiles.E != 0
	var s: bool = sides & LabyrinthTiles.S != 0
	var w: bool = sides & LabyrinthTiles.W != 0
	if not n and not e and _is_open_in(grid, top, x + 1, y - 1):
		corners |= LabyrinthTiles.NE
	if not s and not e and _is_open_in(grid, top, x + 1, y + 1):
		corners |= LabyrinthTiles.SE
	if not s and not w and _is_open_in(grid, top, x - 1, y + 1):
		corners |= LabyrinthTiles.SW
	if not n and not w and _is_open_in(grid, top, x - 1, y - 1):
		corners |= LabyrinthTiles.NW
	return corners
