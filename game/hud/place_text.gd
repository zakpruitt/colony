class_name PlaceText
extends RefCounted
## How the screen names a place in the labyrinth: an area and a stage, "Mossy Hollow 3".


## [param stage] of area [param area_id], as the screen names it: "Mossy Hollow 3".
static func of(area_id: StringName, stage: int) -> String:
	return "%s %d" % [area_name(area_id), stage]


## Area [param area_id]'s name, "Mossy Hollow", or the id itself for an unknown area.
static func area_name(area_id: StringName) -> String:
	var def: AreaDef = Content.area(area_id)
	return def.display_name if def != null else String(area_id)


## [param stage] of the area the party of [param simulation] stands in (while it is on its way
## elsewhere, the area it is leaving).
static func here(simulation: Simulation, stage: int) -> String:
	return of(simulation.expedition.place, stage)
