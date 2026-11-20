class_name AreaNews
extends RefCounted
## What the area map and its goal know of the areas, kept in the order the events happened: the
## area the events are in, the guardians beaten, the areas visited, the open
## areas still to visit, and how many areas have opened since the map was last opened. A frame
## that steps many ticks at once (4x, a hitch, a return from time away) hears its events one by
## one, so a guardian slain before a journey belongs to the area left, not the one reached.
##
## It starts from the simulation (a loaded game) and then changes only through the world's events.

## The area the events heard so far are in: AREA_CHANGED moves it.
var here: StringName = &""
## Areas whose guardian has been beaten, as heard (the map also reads the simulation).
var beaten: Dictionary[StringName, bool] = {}
## Areas the party has been in.
var visited: Dictionary[StringName, bool] = {}
## Open areas the party has never been in, in the order they opened: each is a goal.
var to_visit: Array[StringName] = []
## Areas opened since the map was last opened: the mark on the map's button. At the start, every
## open area never visited counts: it opened during time away or before a reload.
var unseen: int = 0
## True while the map is open: an area that opens then is seen as it opens.
var watching: bool = false

var _simulation: Simulation


## Starts from [param simulation] and hears [param world]'s events (none with null).
func _init(simulation: Simulation, world: World = null) -> void:
	_simulation = simulation
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	if simulation == null:
		return
	here = simulation.expedition.place
	for id: StringName in Content.area_ids():
		if id == here or simulation.area_progress(id).y > 0:
			visited[id] = true
		elif simulation.is_area_open(id):
			to_visit.append(id)
	unseen = to_visit.size()


## Takes in one event, in the order the simulation reported it.
func _on_sim_event(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.AREA_CHANGED:
			here = area_at(event.amount)
			visited[here] = true
			to_visit.erase(here)
		SimEvent.Kind.AREA_OPENED:
			var opened: StringName = area_at(event.amount)
			if not watching:
				unseen += 1
			if not visited.has(opened) and not to_visit.has(opened):
				to_visit.append(opened)
		SimEvent.Kind.GUARDIAN_SLAIN:
			var def: AreaDef = Content.area(here)
			if def != null and event.amount >= def.guardian_stage:
				beaten[here] = true


## True once area [param id]'s guardian has been beaten: heard so, or the simulation (and so the
## save) keeps it beaten.
func is_beaten(id: StringName) -> bool:
	return beaten.has(id) or (_simulation != null and _simulation.is_guardian_beaten(id))


## The map has been looked at: the mark goes.
func seen() -> void:
	unseen = 0


## A goal for each open area not yet visited: [code]Visit The Claypits[/code], done when the
## party first arrives there.
func visit_goals() -> Array[Goals.Goal]:
	var goals: Array[Goals.Goal] = []
	for id: StringName in to_visit:
		var called: String = PlaceText.area_name(id)
		var goal := Goals.Goal.new(
			"visit/%s" % id, Goals.Kind.VISIT, "Visit " + called, -1.0, "", visit_hint(called)
		)
		goal.area = id
		goal.done = "Goal: visited " + called
		goals.append(goal)
	return goals


## The visit goal's hint for the area [param called].
static func visit_hint(called: String) -> String:
	return (
		"%s is open: send the party there from the Map (%s)."
		% [called, KeyBook.label(AreaMapWindow.ID)]
	)


## The id of the area at [param index] in [method Content.area_ids], or &"".
static func area_at(index: int) -> StringName:
	var ids: Array[StringName] = Content.area_ids()
	return ids[index] if index >= 0 and index < ids.size() else &""
