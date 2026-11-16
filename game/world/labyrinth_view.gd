class_name LabyrinthView
extends Node2D
## Draws the labyrinth as a cross-section of earth: solid ground with the levels' chambers,
## tunnels and shafts cut out of it, a ladder in every shaft, and the surface above depth 1.
##
## Only the levels near the focus exist as nodes (see [method set_focus]). Each built level is a
## Node2D holding four TileMapLayers, in world tile coordinates: Ground (earth or back wall),
## Edges (floor tops, ceilings, wall faces, and shade on the back wall), Corners (inner corners)
## and Ladder. The art is in [LabyrinthTiles].

const TILE: int = 16
## Levels this far from the focus level are built.
const BUILD_RADIUS: int = 1
## Levels further than this from the focus level are freed. More than [constant BUILD_RADIUS],
## so walking back and forth across a level boundary does not rebuild every time.
const KEEP_RADIUS: int = 2
## Rows of sky drawn above the ground line, enough to fill the screen above depth 1.
const SKY_ROWS: int = 24

const _H: int = Labyrinth.LEVEL_HEIGHT
const _W: int = Labyrinth.LEVEL_WIDTH
const _LAYERS: Array[String] = ["Ground", "Edges", "Corners", "Ladder"]

## Set before entering the tree.
var labyrinth: Labyrinth

var _levels: Dictionary[int, Node2D] = {}
var _surface: TileMapLayer


func _ready() -> void:
	_build_surface()


## Tells the view where the action is, in world tiles; it builds and frees levels to suit.
func set_focus(world_tiles: Vector2) -> void:
	var depth: int = maxi(1, floori(world_tiles.y / _H) + 1)
	for built: int in _levels.keys():
		if absi(built - depth) > KEEP_RADIUS:
			_levels[built].free()
			_levels.erase(built)
	for near: int in range(maxi(1, depth - BUILD_RADIUS), depth + BUILD_RADIUS + 1):
		if not _levels.has(near):
			_levels[near] = _build_level(near)


## Depths currently built, ascending.
func built_depths() -> Array[int]:
	var depths: Array[int] = []
	for depth: int in _levels:
		depths.append(depth)
	depths.sort()
	return depths


## True if this world tile is open space (walkable or climbable air): inside a chamber, a
## tunnel or a shaft. The surface sky and everything outside the band's columns are not.
func is_open(tile: Vector2i) -> bool:
	if tile.y < 0 or tile.x < 0 or tile.x >= _W:
		return false
	var depth: int = tile.y / _H + 1
	for rect: Rect2i in labyrinth.level(depth).open_rects():
		if rect.has_point(tile):
			return true
	return depth > 1 and labyrinth.level(depth - 1).shaft_down.has_point(tile)


## What is drawn at a world tile, bottom layer first, as "<sheet>/<part>" (for example
## "loam/buried_2", "loam/edge_1", "ladder/left"). Empty where nothing is built.
func visuals_at(tile: Vector2i) -> PackedStringArray:
	var layers: Array[TileMapLayer] = []
	if tile.y < 0:
		if _surface != null:
			layers.append(_surface)
	elif _levels.has(tile.y / _H + 1):
		for child: Node in _levels[tile.y / _H + 1].get_children():
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


func _build_level(depth: int) -> Node2D:
	var level := Node2D.new()
	level.name = "Depth%d" % depth
	var layers: Dictionary[String, TileMapLayer] = {}
	for layer_name: String in _LAYERS:
		layers[layer_name] = _new_layer(layer_name)
		level.add_child(layers[layer_name])
	add_child(level)

	var top: int = (depth - 1) * _H
	var open: PackedByteArray = _open_grid(top)
	var sheet: StringName = LabyrinthTiles.stratum(depth)
	var sheet_id: int = LabyrinthTiles.source(sheet)
	for y: int in range(top, top + _H):
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
	_place_ladders(layers["Ladder"], depth, top)
	return level


## Ladders in every shaft crossing this band, and the ladder top standing on the floor above.
func _place_ladders(layer: TileMapLayer, depth: int, top: int) -> void:
	var shafts: Array[Rect2i] = [labyrinth.level(depth).shaft_down]
	if depth > 1:
		shafts.append(labyrinth.level(depth - 1).shaft_down)
	var ladder_id: int = LabyrinthTiles.source(LabyrinthTiles.LADDER)
	for shaft: Rect2i in shafts:
		for y: int in range(maxi(shaft.position.y - 1, top), mini(shaft.end.y, top + _H)):
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


## Which tiles are open in the band starting at row [param top], with a one-tile border all
## round so neighbours can be read at the edges: 1 for open, 0 for earth.
func _open_grid(top: int) -> PackedByteArray:
	var grid: PackedByteArray = []
	grid.resize((_W + 2) * (_H + 2))
	for y: int in range(top - 1, top + _H + 1):
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
