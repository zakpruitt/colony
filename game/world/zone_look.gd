class_name ZoneLook
extends RefCounted
## How a stage of an area looks on screen. Each area is its own place: it takes one
## of the four looks of earth, floor and light (loam, clay, stone, deep, in
## [constant LabyrinthTiles.STRATA] order) by its place in the list of areas, so the four areas
## all differ. Within an area every stage is the same place, each later one a little darker.

## How much of the ambient light each stage after the first takes away, and the most taken.
const STAGE_DIM: float = 0.02
const MOST_DIM: float = 0.2

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
