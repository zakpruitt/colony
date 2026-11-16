class_name LabyrinthTiles
extends RefCounted
## The tile art the labyrinth view draws with: every sheet under assets/sprites/tiles/ in one
## shared TileSet, one atlas source per sheet, one tile per part. See docs/style-bible.md (Tiles).
##
## A stratum sheet (loam, clay, stone, deep) holds the earth of five levels: buried earth
## variants, back wall variants, and overlays for edges, inner corners and back-wall shade, each
## indexed by a bitmask of the four sides (see [constant N]).

const DIR: String = "res://assets/sprites/tiles/"
## Earth sheets from the surface down; each covers [constant LEVELS_PER_STRATUM] levels, and
## below the last one they repeat from the first.
const STRATA: Array[StringName] = [&"loam", &"clay", &"stone", &"deep"]
const LEVELS_PER_STRATUM: int = 5
const LADDER: StringName = &"ladder"
const SURFACE: StringName = &"surface"

## Side bits of the overlay masks: edge_<mask>_<variant>, shade_<mask>.
const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8
## Diagonal bits of the corner masks: corner_<mask>.
const NE: int = 1
const SE: int = 2
const SW: int = 4
const NW: int = 8

## Buried earth variants in each stratum sheet: buried_0 is plain, the rest carry a speck,
## a stone, a clod or a streak.
const BURIED_VARIANTS: int = 13
## How many times more often plain earth is drawn than any one featured variant, so features
## stay rare enough that no pattern lines up into a grid.
const BURIED_PLAIN_WEIGHT: int = 20
## Back wall variants: back_0 is plain, the rest carry a mark, a hole or a crack.
const BACK_VARIANTS: int = 6
## The same for the back wall.
const BACK_PLAIN_WEIGHT: int = 5
## Ragged versions of each edge overlay.
const EDGE_VARIANTS: int = 3

static var _tile_set: TileSet
static var _sheet_names: Array[StringName] = []
static var _part_names: Array[PackedStringArray] = []


## The earth sheet for a depth: loam for 1-5, clay for 6-10, stone for 11-15, deep for 16-20,
## then loam again.
static func stratum(depth: int) -> StringName:
	var band: int = (maxi(depth, 1) - 1) / LEVELS_PER_STRATUM
	return STRATA[band % STRATA.size()]


## The shared TileSet holding every tile sheet. Built once.
static func tile_set() -> TileSet:
	if _tile_set == null:
		_build()
	return _tile_set


## The atlas source id of a sheet in [method tile_set].
static func source(sheet: StringName) -> int:
	tile_set()
	return _sheet_names.find(sheet)


## The atlas coordinates of a part of a sheet, or (-1, -1) if the sheet has no such part.
static func coords(sheet: StringName, part: String) -> Vector2i:
	var id: int = source(sheet)
	if id < 0:
		return Vector2i(-1, -1)
	var index: int = _part_names[id].find(part)
	return Vector2i(index, 0) if index >= 0 else Vector2i(-1, -1)


## "<sheet>/<part>" for a cell of [method tile_set], for tests and debugging.
static func describe(source_id: int, atlas_coords: Vector2i) -> String:
	tile_set()
	if source_id < 0 or source_id >= _sheet_names.size():
		return ""
	return "%s/%s" % [_sheet_names[source_id], _part_names[source_id][atlas_coords.x]]


## A buried earth part for this world tile, the same every time it is asked.
static func buried_part(tile: Vector2i) -> String:
	return "buried_%d" % _weighted(_hash(tile), BURIED_VARIANTS, BURIED_PLAIN_WEIGHT)


## A back wall part for this world tile, the same every time it is asked.
static func back_part(tile: Vector2i) -> String:
	return "back_%d" % _weighted(_hash(tile) >> 8, BACK_VARIANTS, BACK_PLAIN_WEIGHT)


## The edge overlay for an earth tile at [param tile] whose open sides are [param sides].
static func edge_part(tile: Vector2i, sides: int) -> String:
	return "edge_%d_%d" % [sides, (_hash(tile) >> 16) % EDGE_VARIANTS]


## A variant from [param roll]: 0 with weight [param plain_weight], each other one with weight 1.
static func _weighted(roll: int, variants: int, plain_weight: int) -> int:
	var pick: int = roll % (plain_weight + variants - 1)
	return 0 if pick < plain_weight else pick - plain_weight + 1


## A well-mixed, non-negative hash of a tile position.
static func _hash(tile: Vector2i) -> int:
	var h: int = (tile.x * 73856093) ^ (tile.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


static func _build() -> void:
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(LabyrinthView.TILE, LabyrinthView.TILE)
	var sheets: Array[StringName] = STRATA.duplicate()
	sheets.append_array([LADDER, SURFACE])
	for sheet_name: StringName in sheets:
		var sheet: PixelSheet = PixelSheet.load_sheet(DIR + sheet_name + ".png")
		var atlas := TileSetAtlasSource.new()
		atlas.texture = sheet.part(StringName(sheet.part_names[0])).atlas
		atlas.texture_region_size = sheet.size
		for index: int in sheet.part_names.size():
			atlas.create_tile(Vector2i(index, 0))
		_tile_set.add_source(atlas, _sheet_names.size())
		_sheet_names.append(sheet_name)
		_part_names.append(sheet.part_names)
