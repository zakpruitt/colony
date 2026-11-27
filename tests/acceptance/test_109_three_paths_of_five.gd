extends "res://tests/acceptance/talent_tree_test_base.gd"
## Acceptance tests for specs/109-skill-paths-three-paths-of-five/spec.md, one per requirement
## (R9 has one test for the headless comparison and one per class for its paths). R8 is in
## test_109_every_ability_is_seen.gd; R11 is the amended suite; R12 is
## tools/tests/godot/test_051_sim_talents.py.

## The fighters and battles of spec 050's tests, built by its kit.
const Kit = preload("res://tests/unit/ability_kit_test_base.gd")

const SEED: int = 109
## "The paths" of the spec, by class: each path's name, its summary and its five nodes' names
## (tier 1; tier 2 left, right; tier 3; tier 4).
const PATHS: Dictionary = {
	&"knight":
	[
		[
			"Guardian",
			"holds the line and keeps the party standing",
			["Taunt", "Hold the Line", "Bottle-top Block", "Bulwark", "Rallying Cry"]
		],
		[
			"Berserker",
			"fights hurt and heals by hitting",
			["Whirlwind", "Bloodthirst", "Reckless Swing", "Rampage", "Earthshaker"]
		],
		[
			"Warlord",
			"leads the charge and calls out foes",
			["Shield Bash", "Last Stand", "War Banner", "Challenge", "Charge"]
		],
	],
	&"rogue":
	[
		[
			"Assassin",
			"bleeds, marks and finishes the weakest foe",
			["Backstab", "Mark for Death", "Finisher", "Ambush", "Killing Spree"]
		],
		[
			"Venom",
			"spreads bleeding and weakness through packs",
			["Poisoned Blades", "Fan of Knives", "Toxic Cloud", "Envenom", "Plague"]
		],
		[
			"Shadow",
			"slows, stuns and slips away from every blow",
			["Smoke Step", "Caltrops", "Dizzying Feint", "Shadowstep", "Vanish"]
		],
	],
	&"mage":
	[
		[
			"Pyromancer",
			"sets whole packs burning and drops meteors",
			["Fireball", "Ignite", "Wildfire", "Meteor", "Inferno"]
		],
		[
			"Frostbinder",
			"freezes foes in place and shields the party",
			["Ice Lance", "Frost Nova", "Frost Armor", "Deep Freeze", "Blizzard"]
		],
		[
			"Stormcaller",
			"strikes through armor and stuns whole packs",
			["Lightning Bolt", "Chain Spark", "Static Field", "Overload", "Thunderstorm"]
		],
	],
	&"cleric":
	[
		[
			"Lifebinder",
			"mends and shields the party through every hurt",
			["Prayer", "Renewal", "Blessing", "Sanctuary", "Miracle"]
		],
		[
			"Sunpriest",
			"burns and judges foes with holy light",
			["Smite", "Holy Fire", "Judgement", "Radiance", "Wrath"]
		],
		[
			"Warden",
			"hastens, shields and stands the fallen back up",
			["Battle Hymn", "Guardian Angel", "Aegis", "Hallowed Ground", "Resurrection"]
		],
	],
}
## "The new abilities" of the spec.
const NEW_ABILITIES: Array[StringName] = [
	&"earthshaker",
	&"war_banner",
	&"challenge",
	&"charge",
	&"toxic_cloud",
	&"envenom",
	&"plague",
	&"shadowstep",
	&"lightning_bolt",
	&"static_field",
	&"overload",
	&"thunderstorm",
	&"radiance",
	&"aegis",
	&"hallowed_ground",
	&"resurrection",
]
## R10: each class's three path colours.
const COLOURS: Dictionary = {
	&"knight": [&"blue", &"red", &"copper"],
	&"rogue": [&"red", &"forest", &"orchid"],
	&"mage": [&"orange", &"cyan", &"orchid"],
	&"cleric": [&"pink", &"tan", &"cyan"],
}

var _kit: Kit


func before_each() -> void:
	_kit = Kit.new()


func after_each() -> void:
	if _kit != null:
		_kit.free()
		_kit = null
	super()


# --- Helpers -------------------------------------------------------------------


func _ids(abilities: Array[AbilityDef]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for ability: AbilityDef in abilities:
		ids.append(ability.id)
	return ids


## Asks [param sim] to take [param node] for [param hero] and steps once; returns the events.
func _take(sim: Simulation, hero: Hero, node: StringName) -> Array[SimEvent]:
	sim.take_talent(hero.id, node)
	sim.step()
	return sim.drain_events()


func _refused(tree: TalentTreeDef, words: String) -> bool:
	return "\n".join(tree.validate()).contains(words)


func _any_names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.begins_with(field + ":"):
			return true
	return false


## A copy of [param class_id]'s tree whose paths are copies too, to break without harm.
func _broken(class_id: StringName) -> TalentTreeDef:
	var tree: TalentTreeDef = _tree(class_id).duplicate()
	var paths: Array[SkillPathDef] = []
	for each: SkillPathDef in _tree(class_id).paths:
		var copy: SkillPathDef = each.duplicate()
		copy.nodes = each.nodes.duplicate()  # a resource's copy shares its arrays
		paths.append(copy)
	tree.paths = paths
	return tree


# --- R1 ------------------------------------------------------------------------


func test_r1_three_paths_of_five() -> void:
	assert_eq(Content.ability_ids().size(), 60, "60 abilities under data/abilities")
	for id: StringName in Content.ability_ids():
		assert_eq(Content.ability(id).validate(), PackedStringArray(), "%s validates" % id)
	for id: StringName in NEW_ABILITIES:
		assert_not_null(Content.ability(id), "%s is under data/abilities" % id)
	var trees_of: Dictionary[StringName, int] = {}
	for class_id: StringName in CLASSES:
		var tree: TalentTreeDef = _tree(class_id)
		assert_not_null(tree, "%s has a tree" % class_id)
		if tree == null:
			continue
		assert_eq(tree.validate(), PackedStringArray(), "%s's tree validates" % class_id)
		assert_eq(tree.paths.size(), TalentTreeDef.PATH_COUNT, "%s: three paths" % class_id)
		var spec: Array = PATHS[class_id]
		for index: int in tree.paths.size():
			var each: SkillPathDef = tree.path(index)
			var wanted: Array = spec[index]
			var path_name: String = wanted[0]
			var summary: String = wanted[1]
			assert_eq(each.display_name, path_name, "%s path %d's name" % [class_id, index])
			assert_eq(each.summary, summary, "%s's summary" % path_name)
			var names: Array[String] = []
			for place: int in each.nodes.size():
				var node: StringName = each.nodes[place]
				trees_of[node] = trees_of.get(node, 0) + 1
				var ability: AbilityDef = Content.ability(node)
				names.append(ability.display_name if ability != null else "?")
				assert_eq(tree.tier_of(node), TalentTreeDef.TIERS[place], "%s's tier" % node)
				assert_eq(tree.path_of(node), index, "%s's path" % node)
			assert_eq(names, Array(wanted[2] as Array, TYPE_STRING, &"", null), path_name)
		assert_null(tree.path(3), "no fourth path")
		assert_null(tree.path(-1), "nor one before the first")
	assert_eq(TalentTreeDef.TIERS, [1, 2, 2, 3, 4] as Array[int], "one, two, one and one a tier")
	for id: StringName in Content.ability_ids():
		var trees: int = trees_of.get(id, 0)
		assert_eq(trees, 1, "%s is a node of exactly one tree" % id)

	# Each break is refused by name.
	var bad: TalentTreeDef = _broken(&"knight")
	bad.paths.pop_back()
	assert_true(_refused(bad, "2 paths, not 3"), "two paths: %s" % bad.validate())
	bad = _broken(&"knight")
	bad.paths[1].nodes = [&"whirlwind", &"bloodthirst", &"reckless_swing", &"rampage"]
	assert_true(_refused(bad, "paths[1] has 4 nodes, not 5"), "four nodes: %s" % bad.validate())
	bad = _broken(&"knight")
	bad.paths[0].display_name = ""
	assert_true(_refused(bad, "paths[0]: the path name is empty"), "no name")
	bad = _broken(&"knight")
	bad.paths[2].summary = ""
	assert_true(_refused(bad, "paths[2]: the path summary is empty"), "no summary")
	bad = _broken(&"knight")
	bad.paths[2].summary = "leads the charge, calls out foes and never once stops for breath"
	assert_true(_refused(bad, "over 60 characters"), "a long summary: %s" % bad.validate())
	bad = _broken(&"knight")
	bad.paths[1].nodes[4] = &"taunt"
	assert_true(_refused(bad, "'taunt' is in the tree twice"), "a repeat: %s" % bad.validate())
	bad = _broken(&"knight")
	bad.paths[1].nodes[4] = &"no_such_ability"
	assert_true(_refused(bad, "'no_such_ability' is not an ability"), "a missing ability")
	var charge: AbilityDef = Content.ability(&"charge")
	charge.ready_at_start = false
	var waits: bool = _refused(_tree(&"knight"), "'charge' is an action not ready")
	charge.ready_at_start = true
	assert_true(waits, "an action not ready at the start")
	assert_eq(_tree(&"knight").validate(), PackedStringArray(), "the knight's own tree is fine")

	# Each new ability has its own picture: 16x16, more than a speck, like no other.
	var others: Dictionary[String, StringName] = {}
	for id: StringName in Content.ability_ids():
		if NEW_ABILITIES.has(id) or UiIcon.picture(id) == null:
			continue
		others[Marshalls.raw_to_base64(UiIcon.picture(id).get_image().get_data())] = id
	for id: StringName in NEW_ABILITIES:
		var texture: Texture2D = UiIcon.picture(id)
		assert_not_null(texture, "%s has a picture" % id)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		assert_eq(image.get_size(), Vector2i(16, 16), "%s: 16x16" % id)
		var opaque: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gt(opaque, 40, "%s: a picture, not a speck" % id)
		var key: String = Marshalls.raw_to_base64(image.get_data())
		assert_false(others.has(key), "%s is not %s's picture" % [id, others.get(key, &"")])
		others[key] = id


# --- R2 ------------------------------------------------------------------------


func test_r2_points_from_levels() -> void:
	assert_eq(Hero.TALENT_POINTS, 15, "fifteen: every node of a tree")
	assert_eq(Hero.TALENT_EVERY, 2)
	var hero := Hero.new(1, Content.hero_class(&"knight"))
	for level: int in range(1, 41):
		raise(hero, level)
		assert_eq(hero.talent_points(), mini(floori(level / 2.0), 15), "talent points at %d" % level)
		assert_eq(hero.paragon_points(), maxi(level - 30, 0), "paragon points at level %d" % level)
	assert_eq(TalentRules.paragon_points_at(30), 0, "none at 30")
	assert_eq(TalentRules.paragon_points_at(31), 1, "paragon starts at 31")

	# Through play: an event for each point, at 2, 4 ... 30, none at odd levels or after.
	var sim := Simulation.new(SEED)
	var wanted: Dictionary[int, bool] = {}
	var told: Dictionary[int, bool] = {}
	for start: int in [1, 2, 29, 30, 31]:
		for h: Hero in sim.party.heroes:
			h.xp = Hero.xp_for_level(start + 1) - 1
			h.level = start
		var levelled: bool = false
		for i: int in 6000:
			sim.step()
			for e: SimEvent in sim.drain_events():
				if e.kind == SimEvent.Kind.LEVEL_UP:
					levelled = true
					if e.amount % 2 == 0 and e.amount <= 30:
						wanted[e.target_id * 100 + e.amount] = true
				elif e.kind == SimEvent.Kind.TALENT_POINT_GAINED:
					told[e.source_id * 100 + e.amount] = true
			if levelled:
				break
		assert_true(levelled, "a level-up from level %d" % start)
	assert_false(wanted.is_empty(), "levels that earn a point were reached")
	assert_eq(told, wanted, "one event per point, with the hero and the level, none past 30")


# --- R3 ------------------------------------------------------------------------


func test_r3_taking_a_node() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	var tree: TalentTreeDef = _tree(&"knight")
	var guardian: Array[StringName] = tree.path(0).nodes
	var berserker: Array[StringName] = tree.path(1).nodes
	var warlord: Array[StringName] = tree.path(2).nodes
	# What each node needs.
	assert_eq(tree.needs(guardian[0]), [] as Array[StringName], "tier 1 needs nothing")
	assert_eq(tree.needs(guardian[1]), [guardian[0]] as Array[StringName], "tier 2: tier 1")
	assert_eq(tree.needs(guardian[2]), [guardian[0]] as Array[StringName])
	assert_eq(tree.needs(guardian[3]), [guardian[1], guardian[2]] as Array[StringName])
	assert_eq(tree.needs(guardian[4]), [guardian[3]] as Array[StringName], "the capstone: tier 3")
	assert_eq(
		tree.open_nodes([] as Array[StringName]),
		[guardian[0], berserker[0], warlord[0]] as Array[StringName],
		"every tier 1 is open from the start"
	)

	# No point: nothing, and no event.
	var events: Array[SimEvent] = _take(sim, knight, guardian[0])
	assert_eq(knight.talents(), [] as Array[StringName], "nothing without a point")
	assert_eq(_of_kind(events, SimEvent.Kind.TALENT_TAKEN).size(), 0, "and no event")

	raise(knight, 30)
	assert_eq(knight.talent_points(), 15)
	var not_open: Array[StringName] = [&"backstab", &"no_such_node"]
	for each: Array[StringName] in [guardian, berserker, warlord]:
		not_open.append_array(each.slice(1))
	for node: StringName in not_open:
		events = _take(sim, knight, node)
		assert_eq(knight.talents(), [] as Array[StringName], "%s first is ignored" % node)
		assert_eq(_of_kind(events, SimEvent.Kind.TALENT_TAKEN).size(), 0, "and says nothing")

	# Tier 1, then its right tier-2 node alone opens tier 3; the capstone waits for tier 3.
	var order: Array[StringName] = [
		berserker[0],
		warlord[0],
		berserker[2],
		guardian[0],
		berserker[3],
		berserker[4],
		warlord[1],
		guardian[2],
		berserker[1],
		guardian[3],
		warlord[2],
		warlord[3],
		guardian[1],
		guardian[4],
		warlord[4],
	]
	var taken: Array[StringName] = []
	for node: StringName in order:
		if node == berserker[3]:
			assert_false(knight.can_take(berserker[4]), "the capstone waits for tier 3")
		assert_true(knight.can_take(node), "%s is open" % node)
		sim.take_talent(knight.id, node)  # asked twice in one step, taken once
		events = _take(sim, knight, node)
		taken.append(node)
		assert_eq(knight.talents(), taken, "taken in the order asked")
		var told: Array[SimEvent] = _of_kind(events, SimEvent.Kind.TALENT_TAKEN)
		assert_eq(told.size(), 1, "one event for %s" % node)
		if not told.is_empty():
			assert_eq(told[0].source_id, knight.id)
			assert_eq(told[0].ability_id, node)
			assert_eq(told[0].amount, 15 - taken.size(), "the points left")
		events = _take(sim, knight, node)
		assert_eq(knight.talents(), taken, "a node taken already is not taken again")
		assert_eq(_of_kind(events, SimEvent.Kind.TALENT_TAKEN).size(), 0, "and says nothing")
	assert_eq(knight.talents().size(), 15, "all fifteen held, of all three paths")
	assert_eq(knight.talent_points(), 0)
	raise(knight, 40)
	assert_eq(knight.talent_points(), 0, "no talent point after level 30")

	# Every class can hold all fifteen.
	for class_id: StringName in CLASSES:
		var hero: Hero = sim.party.heroes[CLASSES.find(class_id)]
		raise(hero, 30)
		var all: Array[StringName] = []
		for index: int in 3:
			all.append_array(_tree(class_id).path(index).nodes)
		if class_id != &"knight":
			for node: StringName in all:
				sim.take_talent(hero.id, node)
			sim.step()
		assert_eq(hero.talents().size(), 15, "%s holds fifteen" % class_id)

	# A hero with one point takes one node; then it has none.
	var fresh := Simulation.new(SEED)
	var rogue: Hero = fresh.party.heroes[1]
	raise(rogue, 2)
	_take(fresh, rogue, &"backstab")
	events = _take(fresh, rogue, &"smoke_step")
	assert_eq(rogue.talents(), [&"backstab"] as Array[StringName], "one point, one node")
	assert_eq(_of_kind(events, SimEvent.Kind.TALENT_TAKEN).size(), 0, "no point: no event")


# --- R4 ------------------------------------------------------------------------


func test_r4_fight_order() -> void:
	var knight := Hero.new(1, Content.hero_class(&"knight"))
	raise(knight, 30)
	var tree: TalentTreeDef = _tree(&"knight")
	var g: Array[StringName] = tree.path(0).nodes
	var b: Array[StringName] = tree.path(1).nodes
	var w: Array[StringName] = tree.path(2).nodes
	knight.set_talents([w[0], g[0], g[2], g[1], b[0], g[3], g[4]] as Array[StringName])
	var some: Array[StringName] = [g[4], g[3], g[1], g[2], g[0], b[0], w[0]]
	assert_eq(_ids(knight.combatant().abilities), some, "by tier, path and side")
	assert_eq(tree.fight_order(knight.talents()), some)
	var all: Array[StringName] = []
	for index: int in [2, 1, 0]:
		all.append_array(tree.path(index).nodes)
	knight.set_talents(all)
	var full: Array[StringName] = [
		g[4], b[4], w[4], g[3], b[3], w[3], g[1], g[2], b[1], b[2], w[1], w[2], g[0], b[0], w[0]
	]
	assert_eq(_ids(knight.combatant().abilities), full, "all fifteen, the capstones first")

	# A party with no nodes fights exactly as the class numbers alone, tick for tick.
	var party := Party.new()
	var made: Array[Combatant] = []
	var plain: Array[Combatant] = []
	for hero: Hero in party.heroes:
		raise(hero, 6)
		made.append(hero.combatant())
		plain.append(Combatant.from_hero(hero.def(), hero.level, hero.id))
	var lines: Array[PackedStringArray] = []
	for side: Array[Combatant] in [made, plain]:
		var monsters: Array[Combatant] = []
		for i: int in 3:
			monsters.append(Combatant.from_monster(Content.monster(&"goblin"), 6, 100 + i))
		var fight := Battle.new(side, monsters, 0.0, 12.0, true, SimRng.new(SEED))
		var text := PackedStringArray()
		while fight.result() == Battle.Result.ONGOING and fight.tick < 2000:
			fight.step()
			for e: SimEvent in fight.drain_events():
				text.append("%d %d %d %d %d" % [e.kind, e.tick, e.source_id, e.target_id, e.amount])
		lines.append(text)
	assert_gt(lines[0].size(), 10, "a real fight")
	assert_eq(lines[0], lines[1], "event for event")


# --- R5 ------------------------------------------------------------------------


func test_r5_fresh_start() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 32)
	var tree: TalentTreeDef = _tree(&"knight")
	var nodes: Array[StringName] = tree.path(1).nodes.duplicate()
	nodes.append_array(tree.path(2).nodes.slice(0, 2))
	for node: StringName in nodes:
		sim.take_talent(knight.id, node)
	sim.spend_paragon(knight.id, TrainingDef.Stat.TOUGHNESS)
	sim.step()
	sim.drain_events()
	assert_eq(knight.talents(), nodes, "seven nodes of two paths")
	assert_eq(Simulation.reset_price(knight), 3200, "100 gold a level")

	sim.party.gold = 3199
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(knight.talents().size(), 7, "too poor")
	assert_eq(sim.party.gold, 3199)
	sim.party.gold = 10_000
	for i: int in 3000:
		if sim.expedition.battle != null:
			break
		sim.step()
	assert_not_null(sim.expedition.battle, "a fight")
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(knight.talents().size(), 7, "not during a fight")
	while sim.expedition.battle != null:
		sim.step()
	sim.drain_events()

	var gold: int = sim.party.gold
	var price: int = Simulation.reset_price(knight)
	sim.reset_talents(knight.id)
	sim.step()
	var said: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.TALENTS_RESET)
	assert_eq(sim.party.gold, gold - price, "the price is paid")
	assert_eq(knight.talents(), [] as Array[StringName], "every node given back")
	assert_eq(knight.talent_points(), 15, "as unspent points")
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "paragon untouched")
	assert_eq(knight.paragon_points(), 1)
	assert_eq(said.size(), 1, "an event")
	if not said.is_empty():
		assert_eq(said[0].amount, price)
	# With no node taken: refused, and free.
	gold = sim.party.gold
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(_of_kind(sim.drain_events(), SimEvent.Kind.TALENTS_RESET).size(), 0, "no node: no")
	assert_eq(sim.party.gold, gold, "and no gold taken")


# --- R6 ------------------------------------------------------------------------


func test_r6_saves() -> void:
	assert_eq(Simulation.SAVE_VERSION, 10)
	var sim := Simulation.new(SEED)
	var mage: Hero = sim.party.heroes[2]
	var cleric: Hero = sim.party.heroes[3]
	raise(mage, 18)
	raise(cleric, 33)
	var tree: TalentTreeDef = _tree(&"mage")
	var order: Array[StringName] = [
		tree.path(2).nodes[0],
		tree.path(1).nodes[0],
		tree.path(1).nodes[2],
		tree.path(2).nodes[1],
		tree.path(1).nodes[3],
		tree.path(0).nodes[0],
	]
	for node: StringName in order:
		sim.take_talent(mage.id, node)
	sim.take_talent(cleric.id, &"smite")
	sim.spend_paragon(cleric.id, TrainingDef.Stat.QUICKNESS)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.QUICKNESS)
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.step()
	assert_eq(mage.talents(), order, "taken in that order")
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	assert_eq(version, 10, "saved at version 10")
	var saved_talents: Array = data["heroes"][2]["talents"]
	assert_eq(saved_talents, order.map(func(n: StringName) -> String: return String(n)), "order")
	var back: Simulation = Simulation.from_save(_through_json(data))
	assert_not_null(back, "loads: %s" % Simulation.save_problems(_through_json(data)))
	if back == null:
		return
	assert_eq(back.party.heroes[2].talents(), order, "the nodes, in the order taken")
	assert_eq(back.party.heroes[3].paragon_rank(TrainingDef.Stat.QUICKNESS), 2)
	assert_eq(back.party.heroes[3].paragon_rank(TrainingDef.Stat.POWER), 1)
	var resaved: Array = back.to_save()["heroes"]
	var first: Array = data["heroes"]
	assert_eq(resaved, first, "the same again")

	# A version 9 save: spec 051's talents and paragon at level 20 come back as no nodes, every
	# point unspent, its paragon kept and none left to spend.
	var old: Dictionary = data.duplicate(true)
	old["version"] = 9
	for i: int in 4:
		old["heroes"][i]["level"] = 20
		old["heroes"][i]["xp"] = Hero.xp_for_level(20)
	old["heroes"][0]["talents"] = ["shield_bash", "taunt", "bottle_top_block", "hold_the_line"]
	old["heroes"][1]["talents"] = ["backstab", "smoke_step", "finisher", "fan_of_knives"]
	old["heroes"][0]["paragon"] = {"power": 4, "toughness": 2, "quickness": 0}
	old["heroes"][3]["paragon"] = {"power": 1, "toughness": 0, "quickness": 2}
	var loaded: Simulation = Simulation.from_save(_through_json(old))
	assert_not_null(loaded, "a version 9 save loads: %s" % Simulation.save_problems(old))
	if loaded == null:
		return
	for hero: Hero in loaded.party.heroes:
		assert_eq(hero.talents(), [] as Array[StringName], "%s: no nodes" % hero.class_id)
		assert_eq(hero.talent_points(), 10, "%s: every point unspent" % hero.class_id)
		assert_eq(hero.paragon_points(), 0, "%s: no paragon point to spend" % hero.class_id)
	var knight: Hero = loaded.party.heroes[0]
	assert_eq(knight.paragon_rank(TrainingDef.Stat.POWER), 4, "paragon kept above level 30's")
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 2)
	assert_eq(loaded.party.heroes[3].paragon_rank(TrainingDef.Stat.QUICKNESS), 2)
	var again: Dictionary = _through_json(loaded.to_save())
	assert_eq(Simulation.save_problems(again), PackedStringArray(), "and saves again cleanly")

	# Each bad value is refused by name.
	var cases: Array = [
		["heroes[2].talents[2]", 2, "talents", ["fireball", "ignite", "no_such_node"]],
		["heroes[2].talents[1]", 2, "talents", ["fireball", "meteor"]],
		["heroes[2].talents[2]", 2, "talents", ["fireball", "ignite", "inferno"]],
		["heroes[2].talents[0]", 2, "talents", ["backstab"]],
		["heroes[1].talents[1]", 1, "talents", ["backstab", "backstab"]],
		["heroes[0].paragon", 0, "paragon", {"power": 5}],
	]
	for case: Array in cases:
		var bad: Dictionary = data.duplicate(true)
		bad["heroes"][case[1]]["level"] = 18
		bad["heroes"][case[1]]["xp"] = Hero.xp_for_level(18)
		bad["heroes"][case[1]][case[2]] = case[3]
		var found: PackedStringArray = Simulation.save_problems(bad)
		var field: String = case[0]
		assert_true(_any_names(found, field), "%s refused as %s: %s" % [case[3], field, found])
		assert_null(Simulation.from_save(bad))
	# Level 18 allows four paragon points, the most any version gave: that loads.
	var four: Dictionary = data.duplicate(true)
	four["heroes"][0]["level"] = 18
	four["heroes"][0]["xp"] = Hero.xp_for_level(18)
	four["heroes"][0]["paragon"] = {"power": 4}
	assert_eq(Simulation.save_problems(four), PackedStringArray(), "four at level 18 loads")
	# More nodes than the level earns.
	var greedy: Dictionary = data.duplicate(true)
	greedy["heroes"][0]["level"] = 4
	greedy["heroes"][0]["xp"] = Hero.xp_for_level(4)
	greedy["heroes"][0]["talents"] = ["taunt", "whirlwind", "shield_bash"]
	var problems: PackedStringArray = Simulation.save_problems(greedy)
	assert_true(_any_names(problems, "heroes[0].talents"), "more than earned: %s" % problems)


# --- R7 ------------------------------------------------------------------------


## The events of the tick [param id] was first used, from its ABILITY_USED on.
func _at_use(events: Array[SimEvent], id: StringName) -> Array[SimEvent]:
	return _kit._landing(events, id)


## Who [param events] put [param status] on.
func _given(events: Array[SimEvent], status: AbilityEffect.Status) -> Array[int]:
	var found: Array[int] = []
	for e: SimEvent in _kit._of(events, SimEvent.Kind.STATUS_BEGAN):
		if e.status == status:
			found.append(e.target_id)
	return found


## A hero of [param overrides] holding the real ability [param id].
func _holding(id: StringName, overrides: Dictionary = {}) -> Combatant:
	var hero: Combatant = _kit._hero(1, overrides)
	return _kit._give(hero, [Content.ability(id)])


## Dummies of ids 10 on, standing at [param places].
func _dummies(battle_monsters: Array[Combatant], places: Array) -> void:
	for i: int in places.size():
		battle_monsters[i].x = places[i]


func test_r7_new_abilities_do_what_they_say() -> void:
	for id: StringName in NEW_ABILITIES:
		assert_eq(Content.ability(id).validate(), PackedStringArray(), "%s is valid" % id)
		assert_true(Content.ability(id).description.ends_with("."), "%s: one plain line" % id)
	var hit: SimEvent.Kind = SimEvent.Kind.HIT

	# Earthshaker: every enemy takes 2x damage and is stunned.
	var monsters: Array[Combatant] = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	var battle: Battle = _kit._battle([_holding(&"earthshaker")], monsters, 16.0)
	_dummies(monsters, [3.0, 7.0, 14.0])
	var landing: Array[SimEvent] = _at_use(_kit._run(battle, 60), &"earthshaker")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [10, 11, 12], "Earthshaker: every enemy")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20, 20, 20], "for 2x")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [10, 11, 12], "all stunned")

	# War Banner: as the fight starts, every ally is hasted.
	var ally: Combatant = _kit._hero(2)
	battle = _kit._battle([_holding(&"war_banner"), ally], [_kit._dummy(10)])
	var events: Array[SimEvent] = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.HASTED), [1, 2], "War Banner: every ally")

	# Challenge: the nearest enemy is marked.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"challenge")], monsters)
	_dummies(monsters, [3.0, 9.0])
	landing = _at_use(_kit._run(battle, 20), &"challenge")
	assert_eq(_given(landing, AbilityEffect.Status.MARKED), [10], "Challenge: the nearest")

	# Charge: 2.5x on the furthest; it and the one beside it pushed and stunned, not the near one.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"charge")], monsters)
	_dummies(monsters, [3.0, 9.0, 10.0])
	landing = _at_use(_kit._run(battle, 120), &"charge")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [12], "Charge: the furthest")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [25], "for 2.5x")
	var stunned: Array[int] = _given(landing, AbilityEffect.Status.STUNNED)
	stunned.sort()
	assert_eq(stunned, [11, 12], "stuns the target and the enemy beside it")
	assert_almost_eq(monsters[0].x, 3.0, 0.001, "the far one stays")
	assert_gt(monsters[1].x, 9.0, "pushed back")
	assert_gt(monsters[2].x, 10.0, "pushed back")

	# Toxic Cloud: the nearest and the one beside it bleed and are weakened; not the far one.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"toxic_cloud")], monsters)
	_dummies(monsters, [3.0, 4.0, 12.0])
	landing = _at_use(_kit._run(battle, 20), &"toxic_cloud")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [10, 11], "Toxic Cloud: bleeding")
	assert_eq(_given(landing, AbilityEffect.Status.WEAKENED), [10, 11], "and weakened")

	# Envenom: 2x through armor, and it bleeds.
	monsters = _kit._typed([_kit._dummy(10, {"armor": 6})])
	battle = _kit._battle([_holding(&"envenom")], monsters, 4.0)
	landing = _at_use(_kit._run(battle, 40), &"envenom")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20], "Envenom: 2x, armor or not")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [10], "and it bleeds")

	# Plague: on a kill, every living enemy starts bleeding.
	monsters = _kit._typed([_kit._dummy(10, {"max_health": 1}), _kit._dummy(11), _kit._dummy(12)])
	battle = _kit._battle([_holding(&"plague")], monsters)
	_dummies(monsters, [2.0, 8.0, 12.0])
	landing = _at_use(_kit._run(battle, 60), &"plague")
	assert_eq(_given(landing, AbilityEffect.Status.BLEEDING), [11, 12], "Plague: every enemy left")

	# Shadowstep: 2x and a stun on the furthest.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"shadowstep")], monsters)
	_dummies(monsters, [3.0, 10.0])
	landing = _at_use(_kit._run(battle, 120), &"shadowstep")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [11], "Shadowstep: the furthest")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [20], "for 2x")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [11], "and stuns it")

	# Lightning Bolt: 1.8x through armor, from its reach of 7 tiles.
	monsters = _kit._typed([_kit._dummy(10, {"armor": 6})])
	var mage: Combatant = _holding(&"lightning_bolt")
	battle = _kit._battle([mage], monsters)
	_dummies(monsters, [6.0])
	landing = _at_use(_kit._run(battle, 20), &"lightning_bolt")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [18], "Lightning Bolt: 1.8x, armor or not")

	# Static Field: as the fight starts, every enemy is slowed.
	battle = _kit._battle([_holding(&"static_field")], [_kit._dummy(10), _kit._dummy(11)])
	events = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.SLOWED), [10, 11], "Static Field: every enemy")

	# Overload: every fifth ordinary strike also strikes every enemy for 0.6x.
	var striker: Combatant = _holding(&"overload")
	battle = _kit._battle([striker], [_kit._dummy(10), _kit._dummy(11)], 3.0)
	events = _kit._run(battle, 160)
	var fired: Array[SimEvent] = _kit._used(events, &"overload")
	assert_gte(striker.strikes, 10, "ten strikes or more")
	assert_eq(fired.size(), floori(striker.strikes / 5.0), "Overload: on every fifth strike")
	landing = _at_use(events, &"overload")
	var sparks: Array[SimEvent] = []
	for e: SimEvent in _kit._of(landing, hit, 1):
		if e.amount == 6:
			sparks.append(e)
	assert_eq(_kit._targets(sparks), [10, 11], "every enemy, for 0.6x")

	# Thunderstorm: with an enemy within 8 tiles, every enemy takes 1.5x and is stunned.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11)])
	battle = _kit._battle([_holding(&"thunderstorm")], monsters)
	_dummies(monsters, [5.0, 15.0])
	landing = _at_use(_kit._run(battle, 20), &"thunderstorm")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [15, 15], "Thunderstorm: 1.5x, everyone")
	assert_eq(_given(landing, AbilityEffect.Status.STUNNED), [10, 11], "all stunned")

	# Radiance: every enemy within 2 tiles takes 0.7x, and the cleric mends.
	monsters = _kit._typed([_kit._dummy(10), _kit._dummy(11), _kit._dummy(12)])
	var cleric: Combatant = _holding(&"radiance", {"heal_power": 10})
	battle = _kit._battle([cleric], monsters)
	_dummies(monsters, [5.0, 5.0, 12.0])
	landing = _at_use(_kit._run(battle, 80), &"radiance")
	assert_eq(_kit._targets(_kit._of(landing, hit, 1)), [10, 11], "Radiance: those near")
	assert_eq(_kit._amounts(_kit._of(landing, hit, 1)), [7, 7], "for 0.7x")
	assert_eq(_given(landing, AbilityEffect.Status.MENDING), [1], "and the cleric mends")

	# Aegis: the weakest ally is shielded.
	var hurt: Combatant = _kit._hero(2)
	hurt.health = 30
	battle = _kit._battle([_holding(&"aegis"), hurt, _kit._hero(3)], [_kit._dummy(10)])
	landing = _at_use(_kit._run(battle, 20), &"aegis")
	assert_eq(_given(landing, AbilityEffect.Status.SHIELDED), [2], "Aegis: the weakest ally")

	# Hallowed Ground: as the fight starts, every enemy is weakened.
	battle = _kit._battle([_holding(&"hallowed_ground")], [_kit._dummy(10), _kit._dummy(11)])
	events = _kit._run(battle, 3)
	assert_eq(_given(events, AbilityEffect.Status.WEAKENED), [10, 11], "Hallowed Ground")

	# Resurrection: when an ally dies, every fallen ally stands up at half health, once a fight.
	var priest: Combatant = _holding(&"resurrection", Kit.STILL)
	var fallen: Combatant = _kit._hero(2, Kit.STILL)
	fallen.health = 0
	var dying: Combatant = _kit._hero(3, Kit.STILL)
	dying.health = 1
	var shooter: Combatant = _kit._shooter(10, {"damage": 5})
	battle = _kit._battle([dying, fallen, priest], [shooter])
	events = _kit._run(battle, 600)
	var revived: Array[SimEvent] = _kit._of(events, SimEvent.Kind.REVIVED)
	var raised: Array[int] = _kit._targets(revived)
	raised.sort()
	assert_eq(raised, [2, 3], "Resurrection: every fallen ally stands up")
	assert_eq(_kit._used(events, &"resurrection").size(), 1, "once a fight")
	if not revived.is_empty():
		assert_eq(revived[0].amount, 50, "with 50% health")


# --- R9 ------------------------------------------------------------------------


func test_r9_worth_having() -> void:
	_check_king_sooner()


func test_r9_worth_having_knight() -> void:
	_check_paths_win(&"knight")


func test_r9_worth_having_rogue() -> void:
	_check_paths_win(&"rogue")


func test_r9_worth_having_mage() -> void:
	_check_paths_win(&"mage")


func test_r9_worth_having_cleric() -> void:
	_check_paths_win(&"cleric")


# --- R10 -----------------------------------------------------------------------


func test_r10_the_tab_three_paths_wide() -> void:
	var main: Main = _game()
	var knight: Hero = _hero(main, &"knight")
	var tree: TalentTreeDef = _tree(&"knight")
	set_level_keeping_health(knight, 2)
	knight.set_talents([] as Array[StringName])
	var shown: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var view: TalentTreeView = _view(shown)
	main.hud.advance(STEP)
	assert_eq(shown.class_label.text, "Knight", "no node, no path in the title")

	# Three columns side by side within the window's width, a banner over each, four tier rows.
	assert_eq(HeroWindow.WIDTH, 600.0)
	assert_eq(view.banners.size(), 3, "three banners")
	assert_eq(view.path_nodes.size(), 3, "three columns")
	var left: float = view.get_global_rect().position.x
	var spans: Array[Vector2] = []
	for index: int in 3:
		var banner: PathBanner = view.banners[index]
		assert_eq(banner.name_label.text, tree.path(index).display_name, "the banner's name")
		assert_eq(banner.summary_label.text.replace("\n", " "), tree.path(index).summary)
		var knight_colours: Array = COLOURS[&"knight"]
		var colour_name: StringName = knight_colours[index]
		assert_eq(banner.colour(), colour_name, "in the path's colour")
		var span := Vector2(banner.get_global_rect().position.x, banner.get_global_rect().end.x)
		var column: Array = view.path_nodes[index]
		assert_eq(column.size(), 5, "five nodes")
		for node: TalentNode in column:
			var rect: Rect2 = node.get_global_rect().merge(_text_rect(node.name_label))
			span = Vector2(minf(span.x, rect.position.x), maxf(span.y, rect.end.x))
			assert_gt(rect.position.y, banner.get_global_rect().end.y, "under its banner")
		assert_gte(span.x, left - 0.5, "path %d inside the window's width" % index)
		assert_lte(span.y, left + HeroWindow.WIDTH + 0.5, "path %d inside" % index)
		spans.append(span)
		var y: Array[float] = []
		for node: TalentNode in column:
			y.append(node.get_global_rect().position.y)
		assert_eq(y[1], y[2], "the two tier-2 nodes on one row")
		var west: TalentNode = column[1]
		var east: TalentNode = column[2]
		assert_lt(west.get_global_rect().end.x, east.get_global_rect().position.x, "side by side")
		assert_true(y[0] < y[1] and y[2] < y[3] and y[3] < y[4], "four rows, tier by tier")
		if index > 0:
			assert_lt(spans[index - 1].y, span.x, "side by side, apart")
			assert_eq(y[0], (view.path_nodes[0][0] as TalentNode).get_global_rect().position.y)
	_check_tree(shown, "fresh")

	# A line joins each node to each node that needs it.
	var joined: Dictionary[String, bool] = {}
	for join: Array in view.joins():
		var ends: Array = join[1]
		if ends.size() == 2:
			joined["%s>%s" % [(ends[0] as TalentNode).ability_id, (ends[1] as TalentNode).ability_id]] = (
				true
			)
	for index: int in 3:
		for node: StringName in tree.path(index).nodes:
			for before: StringName in tree.needs(node):
				assert_true(joined.has("%s>%s" % [before, node]), "%s joined to %s" % [before, node])

	# Three states, no closed path: tier 1 ready and pulsing, the rest not yet.
	for index: int in 3:
		for place: int in 5:
			var node: TalentNode = view.path_nodes[index][place]
			var wanted: TalentNode.State = TalentNode.State.LOCKED
			if place == 0:
				wanted = TalentNode.State.AVAILABLE
				assert_true(node.is_pulsing(), "%s pulses" % node.ability_id)
			assert_eq(node.state(), wanted, "%s" % node.ability_id)
	assert_eq(TalentNode.State.size(), 3, "taken, ready and not yet")
	assert_false(_texts(shown).has("Not chosen"), "no path is ever 'Not chosen'")

	# The cards say where each node stands.
	assert_eq(_stands(main, view, &"whirlwind"), "Click to learn")
	assert_eq(_stands(main, view, &"bloodthirst"), "Take Whirlwind first")
	assert_eq(_stands(main, view, &"rampage"), "Take Bloodthirst or Reckless Swing first")

	# A click on a node that can be taken takes it, with no question first.
	_clear_banners(main)
	_click(main, view.node(&"whirlwind").slot)
	_frame(main)
	assert_eq(knight.talents(), [&"whirlwind"] as Array[StringName], "a click takes it")
	assert_true(main.ui.moment.is_bursting(view.node(&"whirlwind").slot), "with a burst")
	assert_eq(_banner(main), "Knight learned Whirlwind", "and a banner")
	assert_eq(view.state_of(&"whirlwind"), TalentNode.State.TAKEN, "taken")
	assert_eq(_stands(main, view, &"whirlwind"), "Learned")
	assert_eq(_stands(main, view, &"bloodthirst"), "No points: the next comes at level 4")
	var said: bool = false
	for line: String in main.hud.journal.lines():
		said = said or line.ends_with("The Knight takes up the Berserker path")
	assert_true(said, "the journal: %s" % [main.hud.journal.lines()])
	main.hud.advance(STEP)
	assert_eq(shown.class_label.text, "Knight, Berserker", "the title names the path")
	assert_eq(
		HeroWindows.frame_tip(knight), "Knight, Berserker: click for details", "the frame's tip"
	)
	# The path holding most nodes names the hero; a tie goes to the earlier path.
	knight.set_talents([&"whirlwind", &"taunt"] as Array[StringName])
	main.hud.advance(STEP)
	assert_eq(shown.class_label.text, "Knight, Guardian", "a tie: the earlier path")
	knight.set_talents([&"whirlwind", &"taunt", &"bloodthirst"] as Array[StringName])
	main.hud.advance(STEP)
	assert_eq(shown.class_label.text, "Knight, Berserker", "the most nodes")

	# Each class has three path colours, none a state's.
	for class_id: StringName in CLASSES:
		for index: int in 3:
			var colour: StringName = PathColours.of(class_id, index)
			var colours: Array = COLOURS[class_id]
			var wanted_colour: StringName = colours[index]
			assert_eq(colour, wanted_colour, "%s path %d's colour" % [class_id, index])
			_check_not_a_state(colour)

	# Two windows on Talents still sit side by side at 1280x720.
	var rogue: Hero = _hero(main, &"rogue")
	main.hud.hero_windows.close_all()
	var back: HeroWindow = _open(main, knight, HeroWindow.Page.TALENTS)
	var over: HeroWindow = _open(main, rogue, HeroWindow.Page.TALENTS)
	await _frames()
	assert_false(back.get_global_rect().intersects(over.get_global_rect()), "side by side")
	assert_false(back.scrolls(), "the whole tree shows")
	_check_clear(main, back, "the knight beside the rogue")
	_check_clear(main, over, "the rogue beside the knight")
	main.free()
	# At 960x540 it fits, scrolling.
	var small: Main = _game(ROOM_SMALL)
	var front: HeroWindow = _open(small, small.simulation.party.heroes[2], HeroWindow.Page.TALENTS)
	await _frames()
	_check_fits(small, front, "960x540")
	_check_clear(small, front, "960x540")
	small.free()
