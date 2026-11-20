class_name AreaSave
extends RefCounted
## The areas in the save (from save version 6), kept apart from [Simulation] so its file stays
## a readable size.
##
## [code]area[/code] is the area the party is in (or heading to); its safe, furthest and target
## stages stay in [code]last_stable_depth[/code], [code]deepest_depth[/code] and
## [code]target_depth[/code]. [code]areas[/code] holds every other area the
## party has been in, by id, as [code]{"safe": s, "furthest": f}[/code], and
## [code]open_areas[/code] lists the open areas' ids.


## The areas of [param run] as plain values, written into [param data].
static func write(run: Expedition, data: Dictionary) -> void:
	var travel: AreaTravel = run.travel
	var here: Vector2i = travel.progress(run, run.area)
	data["area"] = String(run.area)
	data["last_stable_depth"] = here.x
	data["deepest_depth"] = maxi(here.y, here.x)
	if run.state == Expedition.State.JOURNEYING:
		data["target_depth"] = travel.arrival_target(run)
	var others: Dictionary = {}
	for id: StringName in Content.area_ids():
		var kept: Vector2i = travel.progress(run, id)
		if id != run.area and kept.y > 0:
			others[String(id)] = {"safe": kept.x, "furthest": kept.y}
	data["areas"] = others
	var open: Array = []
	for id: StringName in travel.open_ids():
		open.append(String(id))
	data["open_areas"] = open


## Stands [param sim]'s areas up from [param data], already checked and at the current version:
## call before [method Arrival.from_save].
static func read(sim: Simulation, data: Dictionary) -> void:
	var area_text: String = data["area"]
	var open: Array[StringName] = []
	for id: Variant in data["open_areas"] as Array:
		var id_text: String = id
		open.append(StringName(id_text))
	var others: Dictionary[StringName, Vector2i] = {}
	var saved: Dictionary = data["areas"]
	for key: Variant in saved:
		var id_text: String = key
		var entry: Dictionary = saved[key]
		others[StringName(id_text)] = Vector2i(
			SaveChecks.whole(entry["safe"]), SaveChecks.whole(entry["furthest"])
		)
	sim.expedition.travel.restore(sim.expedition, StringName(area_text), open, others)


## Version 5 had no areas: version 6 puts the party in the first area, with its depths as that
## area's stages, and opens each area whose way in lies above the deepest depth reached.
static func upgrade_5_to_6(data: Dictionary) -> Dictionary:
	data["version"] = 6
	data["area"] = String(AreaTravel.first_area())
	data["areas"] = {}
	var deepest: int = SaveChecks.whole(data.get("deepest_depth"))
	var open: Array = []
	for id: StringName in Content.area_ids():
		var way_in: int = _way_in(id)
		if way_in == 0 or deepest > way_in:
			open.append(String(id))
	data["open_areas"] = open
	return data


## Adds a problem for each thing wrong with the areas in [param data], naming the field.
static func check(problems: PackedStringArray, data: Dictionary) -> void:
	var open: Variant = data.get("open_areas")
	if not (open is Array):
		problems.append("open_areas: missing or not a list of area ids")
	else:
		var list: Array = open
		for i: int in list.size():
			if not _is_area(list[i]):
				problems.append("open_areas[%d]: unknown area '%s'" % [i, str(list[i])])
	var area: Variant = data.get("area")
	if not _is_area(area):
		problems.append("area: missing or not an area id")
	elif open is Array and not (open as Array).has(area):
		problems.append("area: '%s' is not open" % area)
	var others: Variant = data.get("areas")
	if not (others is Dictionary):
		problems.append("areas: missing or not a dictionary of areas")
		return
	var saved: Dictionary = others
	for key: Variant in saved:
		var where: String = "areas.%s" % str(key)
		if not _is_area(key):
			problems.append("%s: unknown area" % where)
			continue
		if _is_area(area) and str(key) == str(area):
			problems.append("%s: the area the party is in" % where)
			continue
		if not (saved[key] is Dictionary):
			problems.append("%s: not {safe, furthest}" % where)
			continue
		var entry: Dictionary = saved[key]
		SaveChecks.check_whole(problems, entry, "safe", 1, where + ".")
		SaveChecks.check_whole(problems, entry, "furthest", 1, where + ".")
		var safe: Variant = entry.get("safe")
		var furthest: Variant = entry.get("furthest")
		if SaveChecks.is_whole(safe) and SaveChecks.is_whole(furthest):
			if SaveChecks.whole(safe) > SaveChecks.whole(furthest):
				problems.append("%s.safe: beyond furthest" % where)


## True for text naming a known area.
static func _is_area(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return false
	return Content.area(StringName(str(value))) != null


## The furthest depth a version 5 save must have passed for area [param id] to be open: the
## guardian stages of the areas on the way to it, added up; 0 for an area opened by none.
static func _way_in(id: StringName) -> int:
	var total: int = 0
	var def: AreaDef = Content.area(id)
	var seen: int = 0
	while def != null and def.opened_by != &"" and seen < Content.area_ids().size():
		def = Content.area(def.opened_by)
		if def != null:
			total += def.guardian_stage
		seen += 1
	return total
