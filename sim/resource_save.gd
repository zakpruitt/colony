class_name ResourceSave
extends RefCounted
## The resources and beaten guardians in the save (from save version 8), kept apart from
## [Simulation] as [AreaSave] is.
##
## [code]resources[/code] is a dictionary of [ResourceDef] id to the count the party holds (one it
## has none of may be left out), and [code]guardians_beaten[/code] lists the ids of the areas whose
## guardian the party has beaten at least once.


## The party's resources and the beaten guardians of [param sim] as plain values, written into
## [param data].
static func write(sim: Simulation, data: Dictionary) -> void:
	var held: Dictionary = {}
	for id: StringName in Content.resource_ids():
		if sim.party.resource(id) > 0:
			held[String(id)] = sim.party.resource(id)
	data["resources"] = held
	var beaten: Array = []
	for id: StringName in Content.area_ids():
		if sim.is_guardian_beaten(id):
			beaten.append(String(id))
	data["guardians_beaten"] = beaten


## Gives [param sim] the resources and beaten guardians of [param data], already checked and at
## the current version.
static func read(sim: Simulation, data: Dictionary) -> void:
	var held: Dictionary = data["resources"]
	for key: Variant in held:
		var id_text: String = key
		sim.party.set_resource(StringName(id_text), Simulation._whole(held[key]))
	for id: Variant in data["guardians_beaten"] as Array:
		var id_text: String = id
		sim.expedition.travel.guardians_beaten[StringName(id_text)] = true


## Version 7 had no resources: version 8 gives the party none, and counts an area's guardian beaten
## when an area it opens is open or the party has been beyond its stage there. Upgrade ranks stay.
static func upgrade_7_to_8(data: Dictionary) -> Dictionary:
	data["version"] = 8
	data["resources"] = {}
	var open: Array = []
	if data.get("open_areas") is Array:
		open = data["open_areas"]
	var beaten: Array = []
	for id: StringName in Content.area_ids():
		var def: AreaDef = Content.area(id)
		var opens_one: bool = false
		for other: StringName in Content.area_ids():
			if Content.area(other).opened_by == id and open.has(String(other)):
				opens_one = true
		if opens_one or _furthest(data, id) > def.guardian_stage:
			beaten.append(String(id))
	data["guardians_beaten"] = beaten
	return data


## Adds a problem for each thing wrong with the resources and beaten guardians in [param data],
## naming the field.
static func check(problems: PackedStringArray, data: Dictionary) -> void:
	var held: Variant = data.get("resources")
	if not (held is Dictionary):
		problems.append("resources: missing or not a dictionary of counts")
	else:
		var counts: Dictionary = held
		for key: Variant in counts:
			var where: String = "resources.%s" % str(key)
			if (
				typeof(key) != TYPE_STRING
				or Content.resource_def(StringName(key as String)) == null
			):
				problems.append("%s: unknown resource" % where)
				continue
			Simulation._check_whole(problems, counts, key as String, 0, "resources.")
	var beaten: Variant = data.get("guardians_beaten")
	if not (beaten is Array):
		problems.append("guardians_beaten: missing or not a list of area ids")
		return
	var list: Array = beaten
	for i: int in list.size():
		if typeof(list[i]) != TYPE_STRING or Content.area(StringName(list[i] as String)) == null:
			problems.append("guardians_beaten[%d]: unknown area '%s'" % [i, str(list[i])])


## The furthest stage a version 7 save [param data] holds for area [param id]: the party's deepest
## depth for the area it is in, the saved furthest stage for another, 0 when unknown.
static func _furthest(data: Dictionary, id: StringName) -> int:
	if str(data.get("area")) == String(id):
		var deepest: Variant = data.get("deepest_depth")
		return Simulation._whole(deepest) if Simulation._is_whole(deepest) else 0
	var others: Variant = data.get("areas")
	if not (others is Dictionary):
		return 0
	var kept: Variant = (others as Dictionary).get(String(id))
	if not (kept is Dictionary):
		return 0
	var entry: Dictionary = kept
	var furthest: Variant = entry.get("furthest")
	return Simulation._whole(furthest) if Simulation._is_whole(furthest) else 0
