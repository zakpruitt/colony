class_name AreaTravel
extends RefCounted
## The areas as the expedition keeps them: which are open, the safe and furthest stage
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
## Areas whose guardian the party has beaten at least once, by id.
var guardians_beaten: Dictionary[StringName, bool] = {}
## A destination asked for by a command, taken up once the party is free to go; &"" when none.
var pending_area: StringName = &""
var pending_stage: int = 0
## While the party is on its way: the stage asked for, and the tick it arrives on.
var stage: int = 0
var arrive_tick: int = 0
## True once a target was chosen during the journey: that target, not [member stage], is the
## target on arrival.
var target_chosen: bool = false

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


## Asks to send the party to [param stage] (1 or more) of area [param id]. Whether the area is open
## is judged now: a closed one is ignored. The party goes once it is free
## (after any fight or quest, and up from a wipe); on its way, it turns to the new destination
## and starts the journey again.
func ask(id: StringName, stage_asked: int) -> void:
	if not open.has(id):
		return
	pending_area = id
	pending_stage = maxi(stage_asked, 1)


## The first area by order: where a new game starts.
static func first_area() -> StringName:
	var ids: Array[StringName] = Content.area_ids()
	return ids[0] if not ids.is_empty() else &""


## What the streams of area [param id] are forked under: nothing for the first area, whose
## labyrinth and rolls are the seed's own, and "area/<id>/" for every other.
static func label(id: StringName) -> String:
	return "" if id == first_area() else "area/" + String(id) + "/"


## The labyrinth of area [param id], made from the first area's seed, in its shape, once and
## then kept.
func labyrinth(id: StringName) -> Labyrinth:
	if not _labyrinths.has(id):
		var first: Labyrinth = _labyrinths[first_area()]
		_labyrinths[id] = Labyrinth.new(first.seed_value, label(id), first.shape)
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
	var parts: Array = [open_ids(), kept, pending_area, pending_stage, stage, arrive_tick]
	if target_chosen:
		parts.append(true)  # only when set, to keep the hash of a run without a journey
	if not guardians_beaten.is_empty():
		# Only when one is beaten, to keep the hash of a run that beats no guardian.
		var ids: Array[StringName] = []
		for id: StringName in Content.area_ids():
			if guardians_beaten.has(id):
				ids.append(id)
		parts.append(["beaten", ids])
	return parts


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


## The target [param run] will have on arrival: one chosen on the way, or the stage asked for.
func arrival_target(run: Expedition) -> int:
	return run.target_depth if target_chosen else stage


## [param run] leaves for the destination asked for: a rest it leaves ends (REST_ENDED), and it is
## on its way from this tick, standing where it was until it arrives. The journey is a rest: fallen
## heroes stand and everyone heals as [constant JOURNEY_SECONDS] of resting would. A new
## destination asked for on the way turns it there and starts the journey again.
func depart(run: Expedition) -> void:
	if run.state == Expedition.State.RESTING:
		run._emit(SimEvent.Kind.REST_ENDED)
	if run.state != Expedition.State.JOURNEYING:
		run._rest_ticks = 0
		run._rest_start.clear()
		for hero: Hero in run._party.heroes:
			run._rest_start[hero.id] = hero.health
	run.area = pending_area
	pending_area = &""
	stage = pending_stage
	target_chosen = false
	arrive_tick = run._tick + Combatant.seconds_to_ticks(JOURNEY_SECONDS)
	run._pending_target = 0
	run.state = Expedition.State.JOURNEYING


## One tick on the way: the heroes heal as resting does, up to [constant JOURNEY_SECONDS] of it in
## all however often the journey restarts, and the party arrives when the time is up.
func journey(run: Expedition) -> void:
	if run._rest_ticks < Combatant.seconds_to_ticks(JOURNEY_SECONDS):
		run._rest_ticks += 1
		run._heal_resting()
	if run._tick >= arrive_tick:
		arrive(run)


## [param run] arrives, alive and its health unchanged, at the start of the stage asked for (or the
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
	var target: int = arrival_target(run)
	target_chosen = false
	run._set_target(target)


## Makes [param id] the area [param run] is in, with its labyrinth and stages, and its chambers
## fresh and its caches full.
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
	run._side.forget(run)
