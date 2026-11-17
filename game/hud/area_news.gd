class_name AreaNews
extends RefCounted
## What the area map (spec 053) and its goal know of the areas, kept in the order the events
## happened (R7): the area the events are in, the guardians beaten, the areas visited, the open
## areas still to visit, and how many areas have opened since the map was last opened. A frame
## that steps many ticks at once (4x, a hitch, a return from time away) hears its events one by
## one, so a guardian slain before a journey is the old area's, not the new one's.
##
## It starts from the simulation (a loaded game) and then changes only through [method hear].

## The area the events heard so far are in: AREA_CHANGED moves it.
var here: StringName = &""
## Areas whose guardian has been beaten, as heard (the map also reads the simulation).
var beaten: Dictionary[StringName, bool] = {}
## Areas the party has been in.
var visited: Dictionary[StringName, bool] = {}
## Open areas the party has never been in, in the order they opened: each is a goal.
var to_visit: Array[StringName] = []
## Areas opened since the map was last opened: the mark on the map's button.
var unseen: int = 0

var _simulation: Simulation


func _init(simulation: Simulation) -> void:
	_simulation = simulation
	if simulation == null:
		return
	here = simulation.expedition.place
	for id: StringName in Content.area_ids():
		if id == here or simulation.area_progress(id).y > 0:
			visited[id] = true
		elif simulation.is_area_open(id):
			to_visit.append(id)


## Takes in one event, in the order the simulation reported it.
func hear(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.AREA_CHANGED:
			here = area_at(event.amount)
			visited[here] = true
			to_visit.erase(here)
		SimEvent.Kind.AREA_OPENED:
			var opened: StringName = area_at(event.amount)
			unseen += 1
			if not visited.has(opened) and not to_visit.has(opened):
				to_visit.append(opened)
		SimEvent.Kind.GUARDIAN_SLAIN:
			var def: AreaDef = Content.area(here)
			if def != null and event.amount >= def.guardian_stage:
				beaten[here] = true


## True once area [param id]'s guardian has been beaten: heard so, or the party has been past its
## stage, or an area it opens is open.
func is_beaten(id: StringName) -> bool:
	if beaten.has(id):
		return true
	var def: AreaDef = Content.area(id)
	if def == null or _simulation == null:
		return false
	if _simulation.area_progress(id).y > def.guardian_stage:
		return true
	for other: StringName in Content.area_ids():
		if Content.area(other).opened_by == id and _simulation.is_area_open(other):
			return true
	return false


## The map has been looked at: the mark goes.
func seen() -> void:
	unseen = 0


## A goal for each open area not yet visited (R6): [code]Visit The Claypits[/code], done when the
## party first arrives there.
func visit_goals() -> Array[Goals.Goal]:
	var goals: Array[Goals.Goal] = []
	for id: StringName in to_visit:
		var called: String = PlaceText.area_name(id)
		var goal := Goals.Goal.new(
			"visit/%s" % id,
			Goals.Kind.VISIT,
			"Visit " + called,
			-1.0,
			"",
			"%s is open: send the party there from the area map (W)." % called
		)
		goal.area = id
		goal.done = "Goal: visited " + called
		goals.append(goal)
	return goals


## The id of the area at [param index] in [method Content.area_ids], or &"".
static func area_at(index: int) -> StringName:
	var ids: Array[StringName] = Content.area_ids()
	return ids[index] if index >= 0 and index < ids.size() else &""
