class_name RosterSave
extends RefCounted
## The colony's heroes in the save (the bench and the artifacts found from version 12), kept apart
## from [Simulation] as [AreaSave] and [ResourceSave] are.
##
## [code]heroes[/code] lists the heroes going down in formation order and [code]bench[/code] the
## benched heroes in id order, each saved alike (class, level, XP and what [TalentSave] keeps).
## [code]artifacts[/code] lists the class ids whose artifact has been found, in
## [method Content.hero_class_ids] order. Ids are not saved: on loading, the heroes going down take
## ids 1, 2 ... in their saved order, then the benched heroes the next ids in theirs.


## The heroes of [param party] and the artifacts found, as plain values, written into
## [param data].
static func write(party: Party, data: Dictionary) -> void:
	data["heroes"] = _written(party.heroes)
	data["bench"] = _written(party.bench)
	var found: Array = []
	for class_id: StringName in party.artifacts:
		found.append(String(class_id))
	data["artifacts"] = found


## Gives [param sim] the heroes, the bench and the artifacts of [param data], already checked and
## at the current version. Every hero stands at the level its XP earns, at full health.
static func read(sim: Simulation, data: Dictionary) -> void:
	var saved_heroes: Array = data["heroes"]
	var saved_bench: Array = data["bench"]
	sim.party.heroes = _read(sim, saved_heroes, 1)
	sim.party.bench = _read(sim, saved_bench, saved_heroes.size() + 1)
	var found: Array[StringName] = []
	for id: Variant in data["artifacts"] as Array:
		found.append(StringName(id as String))
	sim.party.artifacts = found


## Adds a problem for each thing wrong with the heroes, the bench and the artifacts of
## [param data], naming the field.
static func check(problems: PackedStringArray, data: Dictionary) -> void:
	var heroes: Variant = data.get("heroes")
	var listed: Array = []
	if not (heroes is Array) or (heroes as Array).is_empty():
		problems.append("heroes: missing, not a list or empty")
	else:
		listed = heroes
		for i: int in listed.size():
			_check_hero(problems, listed[i], "heroes[%d]" % i)
		if listed.size() > Roster.FIELD_SIZE:
			problems.append(
				"heroes: %d going down, more than %d" % [listed.size(), Roster.FIELD_SIZE]
			)
	var bench: Variant = data.get("bench")
	var benched: Array = []
	if not (bench is Array):
		problems.append("bench: missing or not a list of heroes")
	else:
		benched = bench
		for i: int in benched.size():
			_check_hero(problems, benched[i], "bench[%d]" % i)
	var found: Array[StringName] = _check_artifacts(problems, data.get("artifacts"))
	var seen: Dictionary[String, bool] = {}
	_check_classes(problems, listed, "heroes", found, seen)
	_check_classes(problems, benched, "bench", found, seen)


## Version 11 had no bench: version 12 gives the colony an empty one, and no artifact found.
static func upgrade_11_to_12(data: Dictionary) -> Dictionary:
	data["version"] = 12
	data["bench"] = []
	data["artifacts"] = []
	return data


static func _written(heroes: Array[Hero]) -> Array:
	var written: Array = []
	for hero: Hero in heroes:
		var saved: Dictionary = {
			"class": String(hero.class_id),
			"level": hero.level,
			"xp": hero.xp,
		}
		TalentSave.write(hero, saved)
		written.append(saved)
	return written


## The heroes of [param saved], with ids from [param first] on, sharing [param sim]'s upgrades.
static func _read(sim: Simulation, saved: Array, first: int) -> Array[Hero]:
	var heroes: Array[Hero] = []
	for i: int in saved.size():
		var entry: Dictionary = saved[i]
		var class_text: String = entry["class"]
		var hero := Hero.new(first + i, Content.hero_class(StringName(class_text)))
		hero.upgrades = sim.upgrades
		hero.level = SaveChecks.whole(entry["level"])
		hero.xp = SaveChecks.whole(entry["xp"])
		# A saved hero's XP may pay for more levels than its saved level: take them now, silently,
		# so the hero is what its XP earns. Health is filled below.
		hero.gain_xp(0)
		TalentSave.read(hero, entry)
		hero.health = hero.max_health()
		heroes.append(hero)
	return heroes


## Adds a problem for each thing wrong with one saved hero, [param where] in its list.
static func _check_hero(problems: PackedStringArray, value: Variant, where: String) -> void:
	if not (value is Dictionary):
		problems.append("%s: not a hero (class, level, xp, talents, paragon)" % where)
		return
	var saved: Dictionary = value
	var class_text: Variant = saved.get("class")
	var class_def: HeroClassDef = null
	if typeof(class_text) != TYPE_STRING:
		problems.append("%s.class: missing or not text" % where)
	else:
		class_def = Content.hero_class(StringName(class_text as String))
		if class_def == null:
			problems.append("%s.class: unknown hero class '%s'" % [where, class_text])
	SaveChecks.check_whole(problems, saved, "level", 1, where + ".")
	SaveChecks.check_whole(problems, saved, "xp", 0, where + ".")
	var level: int = 0
	if SaveChecks.is_whole(saved.get("level")) and SaveChecks.whole(saved["level"]) >= 1:
		level = SaveChecks.whole(saved["level"])
	TalentSave.check(problems, saved, class_def, level, where)


## Adds a problem for each thing wrong with the saved [param value] of [code]artifacts[/code];
## returns the classes it holds that are good.
static func _check_artifacts(problems: PackedStringArray, value: Variant) -> Array[StringName]:
	var found: Array[StringName] = []
	if not (value is Array):
		problems.append("artifacts: missing or not a list of class ids")
		return found
	var list: Array = value
	for i: int in list.size():
		var where: String = "artifacts[%d]" % i
		var id: Variant = list[i]
		if typeof(id) != TYPE_STRING or Content.hero_class(StringName(id as String)) == null:
			problems.append("%s: '%s' is not a hero class" % [where, str(id)])
		elif Party.STARTING_CLASSES.has(StringName(id as String)):
			problems.append("%s: '%s' is a starting class" % [where, id])
		elif found.has(StringName(id as String)):
			problems.append("%s: '%s' is in it twice" % [where, id])
		else:
			found.append(StringName(id as String))
	return found


## Adds a problem for each hero of [param list] (the saved field [param field]) whose class is
## already in [param seen] or is a new class whose artifact is not in [param found]; adds each
## class it meets to [param seen].
static func _check_classes(
	problems: PackedStringArray,
	list: Array,
	field: String,
	found: Array[StringName],
	seen: Dictionary[String, bool]
) -> void:
	for i: int in list.size():
		var class_text: String = _class_text(list[i])
		if class_text.is_empty() or Content.hero_class(StringName(class_text)) == null:
			continue
		var where: String = "%s[%d].class" % [field, i]
		if seen.has(class_text):
			problems.append("%s: a second %s in the colony" % [where, class_text])
		seen[class_text] = true
		var class_id := StringName(class_text)
		if not Party.STARTING_CLASSES.has(class_id) and not found.has(class_id):
			problems.append("%s: '%s' joined, but its artifact is not found" % [where, class_text])


## The class one saved hero names, or "" if it names none.
static func _class_text(entry: Variant) -> String:
	if not (entry is Dictionary):
		return ""
	var class_text: Variant = (entry as Dictionary).get("class")
	return class_text as String if typeof(class_text) == TYPE_STRING else ""
