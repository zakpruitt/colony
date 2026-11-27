class_name TalentSave
extends RefCounted
## How each hero's talents and paragon points are saved, checked and brought forward from
## versions 6 and 9, kept apart from [Simulation] as [AreaSave] is.
##
## A saved hero carries "talents" (its nodes, in the order taken), "used" (its actions, least
## recently used first: [member Hero.used]) and "paragon" (a dictionary of [TrainingDef] id to the
## points spent in that stat). Unspent points are not saved: they are
## what the hero's level earns less what it spent.

## What a version 6 save's gold training cost, by training id: [base cost, growth per rank, maximum
## rank]. Only a version 6 save needs them, to give the gold back.
const _OLD_TRAINING_PRICES: Dictionary[String, Array] = {
	"power": [40, 1.35, 20],
	"toughness": [35, 1.35, 20],
	"quickness": [45, 1.5, 10],
}
## A saved hero's paragon points spent may reach its level less this: the most any version of the
## game has let a hero earn, so a save from a version that gave paragon sooner still loads.
const _PARAGON_SAVED_AFTER: int = 14


## Writes [param hero]'s talents and paragon points into its saved dictionary [param saved].
static func write(hero: Hero, saved: Dictionary) -> void:
	var talents: Array = []
	for node: StringName in hero.talents():
		talents.append(String(node))
	var paragon: Dictionary = {}
	for training_id: StringName in Content.training_ids():
		var stat: TrainingDef.Stat = Content.training(training_id).stat
		paragon[String(training_id)] = hero.paragon_rank(stat)
	saved["talents"] = talents
	saved["used"] = Array(hero.used.map(func(id: StringName) -> String: return String(id)))
	saved["paragon"] = paragon


## Gives [param hero] the talents and paragon points of its saved dictionary [param saved],
## which [method check] has passed.
static func read(hero: Hero, saved: Dictionary) -> void:
	var taken: Array[StringName] = []
	for node: Variant in saved["talents"] as Array:
		taken.append(StringName(node as String))
	hero.set_talents(taken)
	var order: Array[StringName] = []
	for id: Variant in saved["used"] as Array:
		order.append(StringName(id as String))
	hero.used.assign(order)
	var paragon: Dictionary = saved["paragon"]
	for key: Variant in paragon:
		var stat: TrainingDef.Stat = Content.training(StringName(key as String)).stat
		hero.set_paragon_rank(stat, SaveChecks.whole(paragon[key]))


## Adds a problem, naming the field after [param where], for each thing wrong with the talents
## and paragon points of one saved hero [param saved] of class [param class_def] (null if the
## class is unknown) and level [param level] (0 if unreadable).
static func check(
	problems: PackedStringArray,
	saved: Dictionary,
	class_def: HeroClassDef,
	level: int,
	where: String
) -> void:
	if saved.has("training"):
		problems.append("%s.training: a rank that cannot be given back as gold" % where)
	_check_talents(problems, saved.get("talents"), class_def, level, where + ".talents")
	_check_used(problems, saved.get("used"), saved.get("talents"), where + ".used")
	_check_paragon(problems, saved.get("paragon"), level, where + ".paragon")


## Version 6 had gold training: version 7 drops each hero's ranks, gives back the gold they cost
## and gives each hero no talents and no paragon points spent, so every point its level earned
## is unspent. A hero whose training cannot be read keeps it, for [method check] to refuse.
static func upgrade_6_to_7(data: Dictionary) -> Dictionary:
	data["version"] = 7
	var refund: int = 0
	var heroes: Variant = data.get("heroes")
	if heroes is Array:
		for saved: Variant in heroes as Array:
			if not (saved is Dictionary):
				continue
			var hero: Dictionary = saved
			var paid: int = _paid_for(hero.get("training"))
			if paid < 0:
				continue
			refund += paid
			hero.erase("training")
			hero["talents"] = []
			hero["paragon"] = {}
	if SaveChecks.is_whole(data.get("gold")):
		data["gold"] = SaveChecks.whole(data["gold"]) + refund
	return data


## Version 9 had a trunk and two paths: version 10 gives every hero its talents back, no nodes
## and every point its level earned unspent, and keeps its paragon points.
static func upgrade_9_to_10(data: Dictionary) -> Dictionary:
	data["version"] = 10
	var heroes: Variant = data.get("heroes")
	if heroes is Array:
		for saved: Variant in heroes as Array:
			if saved is Dictionary:
				(saved as Dictionary)["talents"] = []
				(saved as Dictionary)["used"] = []
	return data


## The gold a version 6 save paid for the ranks in [param training], or -1 if they cannot be read.
static func _paid_for(training: Variant) -> int:
	if not (training is Dictionary):
		return -1
	var ranks: Dictionary = training
	var paid: int = 0
	for key: Variant in ranks:
		if typeof(key) != TYPE_STRING or not _OLD_TRAINING_PRICES.has(key as String):
			return -1
		if not SaveChecks.is_whole(ranks[key]):
			return -1
		var price: Array = _OLD_TRAINING_PRICES[key as String]
		var rank: int = SaveChecks.whole(ranks[key])
		var top: int = price[2]
		if rank < 0 or rank > top:
			return -1
		for bought: int in rank:
			var base: int = price[0]
			var growth: float = price[1]
			paid += roundi(base * pow(growth, bought))
	return paid


static func _check_talents(
	problems: PackedStringArray, value: Variant, class_def: HeroClassDef, level: int, where: String
) -> void:
	if not (value is Array):
		problems.append("%s: missing or not a list of nodes" % where)
		return
	var taken: Array[StringName] = []
	for i: int in (value as Array).size():
		var node: Variant = (value as Array)[i]
		if typeof(node) != TYPE_STRING:
			problems.append("%s[%d]: not a node id" % [where, i])
			return
		taken.append(StringName(node as String))
	if class_def == null:
		return
	var tree: TalentTreeDef = Content.talent_tree(class_def.id)
	if tree == null:
		if not taken.is_empty():
			problems.append("%s: the %s class has no talent tree" % [where, class_def.id])
		return
	var order: String = tree.order_problem(taken)
	if not order.is_empty():
		problems.append(where + order)
	elif level > 0 and taken.size() > TalentRules.talent_points_at(level):
		problems.append(
			(
				"%s: %d nodes taken, but level %d earns %d talent points"
				% [where, taken.size(), level, TalentRules.talent_points_at(level)]
			)
		)


static func _check_used(
	problems: PackedStringArray, value: Variant, talents: Variant, where: String
) -> void:
	if not (value is Array):
		problems.append("%s: missing or not a list of ability ids" % where)
		return
	var nodes: Array = talents if talents is Array else []
	var seen: Dictionary[String, bool] = {}
	for i: int in (value as Array).size():
		var id: Variant = (value as Array)[i]
		if typeof(id) != TYPE_STRING or not nodes.has(id):
			problems.append("%s[%d]: not one of the hero's nodes" % [where, i])
		elif seen.has(id as String):
			problems.append("%s[%d]: '%s' is in it twice" % [where, i, id])
		else:
			seen[id as String] = true


static func _check_paragon(
	problems: PackedStringArray, value: Variant, level: int, where: String
) -> void:
	if not (value is Dictionary):
		problems.append("%s: missing or not a dictionary of points" % where)
		return
	var points: Dictionary = value
	var spent: int = 0
	for key: Variant in points:
		if typeof(key) != TYPE_STRING:
			problems.append("%s: key %s is not a stat" % [where, str(key)])
			continue
		var field: String = "%s.%s" % [where, key]
		if Content.training(StringName(key as String)) == null:
			problems.append("%s: unknown stat '%s'" % [field, key])
			continue
		if not SaveChecks.is_whole(points[key]):
			problems.append("%s: points missing or not a whole number" % field)
		elif SaveChecks.whole(points[key]) < 0:
			problems.append("%s: points %d are below 0" % [field, SaveChecks.whole(points[key])])
		else:
			spent += SaveChecks.whole(points[key])
	var most: int = maxi(level - _PARAGON_SAVED_AFTER, 0)
	if level > 0 and spent > most:
		problems.append(
			"%s: %d points spent, but level %d allows %d paragon points" % [where, spent, level, most]
		)
