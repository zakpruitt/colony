class_name ZoneLook
extends RefCounted
## How a stage of an area looks on screen. Each area is its own place: it takes one
## of the four looks of earth, floor and light (loam, clay, stone, deep, in
## [constant LabyrinthTiles.STRATA] order) by its place in the list of areas, so the four areas
## all differ. Within an area every stage is the same place, each later one a little darker.

## How much of the ambient light each stage after the first takes away, and the most taken.
const STAGE_DIM: float = 0.02
const MOST_DIM: float = 0.2
## How the rooms of each look are cut ([RoomCut]), in [constant LabyrinthTiles.STRATA] order. A
## row is: the ceiling's reach in rows; the least and the most rows it moves between runs; the
## least and the most columns a run is wide; the columns a wall leans over; whether the corners
## are round; whether the ceiling is built (level sides, a raised middle); the chance in a
## hundred that it turns back, up for down, at a run.
const CUTS: Array[Array] = [
	# Mossy Hollow: soft and rounded.
	[2, 1, 1, 3, 5, 2, true, false, 0],
	# Claypits: broad flat steps.
	[3, 2, 3, 6, 10, 0, false, false, 0],
	# Old Crypt: built, with square walls, level runs and a raised middle.
	[1, 1, 1, 2, 5, 0, false, true, 0],
	# Ember Deep: jagged, its ceiling moving most.
	[3, 1, 3, 1, 2, 1, false, false, 50],
]

## The look's index in [constant LabyrinthTiles.STRATA].
var band: int
## The stage, 1 or more.
var stage: int


func _init(band_index: int, stage_number: int) -> void:
	band = band_index
	stage = maxi(stage_number, 1)


## The look of [param stage] of area [param area_id]; an unknown area looks like the first.
static func of(area_id: StringName, stage_number: int) -> ZoneLook:
	var index: int = maxi(Content.area_ids().find(area_id), 0)
	return ZoneLook.new(index % LabyrinthTiles.STRATA.size(), stage_number)


## The earth sheet the area is drawn with.
func stratum() -> StringName:
	return LabyrinthTiles.STRATA[band]


## The manner the area's rooms are cut in.
func cut() -> RoomCut:
	return RoomCut.new(CUTS[band])


## The palette colour the area's lamplight leans toward.
func light_hue() -> StringName:
	return AmbienceMood.LIGHT_HUE[band]


## The share of the area's ambient light this stage keeps: 1 on stage 1, a little less on each
## stage after, never below 1 - [constant MOST_DIM].
func dim() -> float:
	return 1.0 - minf(STAGE_DIM * (stage - 1), MOST_DIM)


## The light everything on this stage has with no lamp near it.
func ambient() -> Color:
	var full: Color = AmbienceMood.band_ambient(band)
	return Color(full.r * dim(), full.g * dim(), full.b * dim())
