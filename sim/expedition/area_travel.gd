class_name AreaTravel
extends RefCounted
## The areas as the expedition keeps them (spec 049): which are open, the safe and furthest stage
## of each area the party is not in, each area's labyrinth, and a journey asked for or under way.
## Kept apart from [Expedition] so its file stays under gdlint's 1000 lines.

## Seconds the party spends on the way from one area to another.
const JOURNEY_SECONDS: float = 10.0

## Areas open to the party, by id.
var open: Dictionary[StringName, bool] = {}
## Vector2i(safe stage, furthest stage) of each area the party has been in and is not in now. The
## area it is in keeps them in [member Expedition.last_stable_depth] and
## [member Expedition.deepest_depth].
var stages: Dictionary[StringName, Vector2i] = {}
## A destination asked for by a command, taken up once the party is free to go; &"" when none.
var pending_area: StringName = &""
var pending_stage: int = 0
## While the party is on its way: the stage asked for, and the tick it arrives on.
var stage: int = 0
var arrive_tick: int = 0

var _labyrinths: Dictionary[StringName, Labyrinth] = {}


## The areas of a new game: those opened by no other are open, and [param first] is the first
## area's labyrinth.
func _init(first: Labyrinth) -> void:
	for id: StringName in Content.area_ids():
		if Content.area(id).opened_by == &"":
			open[id] = true
	var ids: Array[StringName] = Content.area_ids()
	if not ids.is_empty():
		_labyrinths[ids[0]] = first


## Asks to send the party to [param stage] (1 or more) of area [param id]: taken up, if the area is
## open then, once the party is free to go (after any fight, and up from a wipe).
func ask(id: StringName, stage_asked: int) -> void:
	pending_area = id
	pending_stage = maxi(stage_asked, 1)


## The first area by order: where a new game starts.
static func first_area() -> StringName:
	var ids: Array[StringName] = Content.area_ids()
	return ids[0] if not ids.is_empty() else &""


## What the streams of area [param id] are forked under: nothing for the first area, whose
## labyrinth and rolls are the seed's own, and "area/<id>/" for every other.
static func label(id: StringName) -> String:
	return "" if id == first_area() else "area/%s/" % id


## The labyrinth of area [param id], made from the first area's seed once and then kept.
func labyrinth(id: StringName) -> Labyrinth:
	if not _labyrinths.has(id):
		var first: Labyrinth = _labyrinths[first_area()]
		_labyrinths[id] = Labyrinth.new(first.seed_value, label(id))
	return _labyrinths[id]


## Opens every area that beating [param beaten]'s guardian opens and was not open yet; returns
## them, in area order.
func open_after(beaten: StringName) -> Array[StringName]:
	var opened: Array[StringName] = []
	for id: StringName in Content.area_ids():
		if Content.area(id).opened_by == beaten and not open.has(id):
			open[id] = true
			opened.append(id)
	return opened


## The open areas, in area order.
func open_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Content.area_ids():
		if open.has(id):
			ids.append(id)
	return ids


## The areas as plain values, for the expedition's state hash.
func hash_parts() -> Array:
	var kept: Array = []
	for id: StringName in Content.area_ids():
		if stages.has(id):
			kept.append([id, stages[id]])
	return [open_ids(), kept, pending_area, pending_stage, stage, arrive_tick]


## The safe stage (x) and furthest stage (y) of area [param id] for [param run]; Vector2i(1, 0)
## for an area the party has never been in.
func progress(run: Expedition, id: StringName) -> Vector2i:
	if id == run._here.id:
		return Vector2i(run.last_stable_depth, run.deepest_depth)
	return stages.get(id, Vector2i(1, 0))


## While [param run] is JOURNEYING, the stage it will arrive at: the stage asked for, or the
## area's safe stage if that is nearer. Otherwise its depth.
func journey_stage(run: Expedition) -> int:
	if run.state != Expedition.State.JOURNEYING:
		return run.depth
	return mini(stage, progress(run, run.area).x)


## Sets [param run]'s areas up from a save, before [method Arrival.from_save]: it is in
## [param area_id], [param opened] are open and [param others] holds the other areas' stages.
func restore(
	run: Expedition,
	area_id: StringName,
	opened: Array[StringName],
	others: Dictionary[StringName, Vector2i]
) -> void:
	for id: StringName in opened:
		open[id] = true
	stages = others.duplicate()
	_enter(run, area_id)


## [param run] leaves for the destination asked for, if it is open: abandoning any rest or work,
## it is on its way from this tick, and stands where it was until it arrives.
func depart(run: Expedition) -> void:
	var to: StringName = pending_area
	pending_area = &""
	if not open.has(to):
		return
	run.area = to
	stage = pending_stage
	arrive_tick = run._tick + Combatant.seconds_to_ticks(JOURNEY_SECONDS)
	run._pending_target = 0
	run._work_key = Vector2i(0, -1)
	run._work_quest = &""
	run._worker = -1
	run.state = Expedition.State.JOURNEYING


## [param run] arrives, alive and as hurt as it was, at the start of the stage asked for (or the
## area's safe stage, if that is nearer), with the stage asked for as its target.
func arrive(run: Expedition) -> void:
	var wanted: int = stage
	stages[run._here.id] = Vector2i(run.last_stable_depth, run.deepest_depth)
	_enter(run, run.area)
	run.depth = mini(wanted, run.last_stable_depth)
	run.deepest_depth = maxi(run.deepest_depth, run.depth)
	run._place(Arrival.column(run.labyrinth, run.depth))
	run._restart_depth_count(run._tick)
	run.state = Expedition.State.TRAVELLING
	run._emit(SimEvent.Kind.AREA_CHANGED, -1, -1, Content.area_ids().find(run.area))
	run._emit(SimEvent.Kind.DEPTH_CHANGED, -1, -1, run.depth)
	run._set_target(wanted)


## Makes [param id] the area [param run] is in, with its labyrinth and stages, and its chambers
## fresh.
func _enter(run: Expedition, id: StringName) -> void:
	run.area = id
	run._here = Content.area(id)
	run._labyrinth = labyrinth(id)
	var kept: Vector2i = stages.get(id, Vector2i(1, 1))
	stages.erase(id)
	run.last_stable_depth = maxi(kept.x, 1)
	run.deepest_depth = maxi(kept.y, run.last_stable_depth)
	run._chambers.clear()
	run._rolled.clear()
	run._fallen.clear()
