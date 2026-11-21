extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/051-talent-trees-and-paragon/spec.md, one per requirement (R11 has
## one test for the headless comparison and one per class for its paths). Spec 029's tests of gold
## training were removed with it; the tests of the hero sheet, goals, defeat note and help that
## named training were amended to spend paragon points.

const SEED: int = 51
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
## "The trees" of the spec, by class: the trunk's names, the two paths' names, then each path's.
const TREES: Dictionary = {
	&"knight":
	[
		["Shield Bash", "Taunt", "Bottle-top Block"],
		["Guardian", "Berserker"],
		["Hold the Line", "Last Stand", "Bulwark", "Rallying Cry"],
		["Whirlwind", "Bloodthirst", "Reckless Swing", "Rampage"],
	],
	&"rogue":
	[
		["Backstab", "Smoke Step", "Finisher"],
		["Assassin", "Trickster"],
		["Poisoned Blades", "Mark for Death", "Ambush", "Killing Spree"],
		["Fan of Knives", "Caltrops", "Dizzying Feint", "Vanish"],
	],
	&"mage":
	[
		["Fireball", "Frost Nova", "Chain Spark"],
		["Pyromancer", "Frostbinder"],
		["Ignite", "Meteor", "Wildfire", "Inferno"],
		["Ice Lance", "Frost Armor", "Deep Freeze", "Blizzard"],
	],
	&"cleric":
	[
		["Prayer", "Blessing", "Smite"],
		["Lifebinder", "Sunpriest"],
		["Renewal", "Sanctuary", "Guardian Angel", "Miracle"],
		["Holy Fire", "Battle Hymn", "Judgement", "Wrath"],
	],
}
## What spec 029 charged for training rank r + 1: base * growth ^ r, by training.
const OLD_PRICES: Dictionary = {
	"power": [40, 1.35],
	"toughness": [35, 1.35],
	"quickness": [45, 1.5],
}
## R11: the fight each path must win and the bare party loses: the Old Crypt's guardian at its
## own level, against a party of level 14 (the level that fills a tree), on five battle seeds.
const PATH_FIGHT: StringName = &"bone_lord"
const PATH_FIGHT_LEVEL: int = 15
const PATH_SEEDS: int = 5
## R11: how long a headless run may take to beat the Slime King.
const KING_LIMIT_MINUTES: float = 60.0

# --- Helpers -------------------------------------------------------------------


## [param class_id]'s trunk, then path [param path] (0 or 1), as nodes in order.
func _full(class_id: StringName, path: int) -> Array[StringName]:
	var nodes: Array[StringName] = []
	nodes.append_array(_tree(class_id).trunk)
	nodes.append_array(_tree(class_id).path_nodes(path))
	return nodes


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.kind == kind:
			found.append(e)
	return found


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


## A version 6 save of a fresh party, heroes at [param levels], with spec 029's training
## [param training] for each hero (a dictionary of training id to rank).
func _version_6(levels: Array[int], training: Array[Dictionary], gold: int) -> Dictionary:
	var heroes: Array = []
	for i: int in CLASSES.size():
		(
			heroes
			. append(
				{
					"class": String(CLASSES[i]),
					"level": levels[i],
					"xp": Hero.xp_for_level(levels[i]),
					"training": training[i],
				}
			)
		)
	return {
		"version": 6,
		"seed": SEED,
		"tick": 0,
		"gold": gold,
		"heroes": heroes,
		"last_stable_depth": 1,
		"deepest_depth": 1,
		"target_depth": 1,
		"auto_push": true,
		"upgrades": {},
		"auto_buy": false,
		"pace": "steady",
		"guardian_order": "challenge",
		"area": "mossy_hollow",
		"areas": {},
		"open_areas": ["mossy_hollow"],
	}


func _any_names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.begins_with(field + ":"):
			return true
	return false


# --- R1 ------------------------------------------------------------------------


func test_r1_trees_are_content() -> void:
	assert_eq(Content.ability_ids().size(), 44, "44 abilities under data/abilities")
	for id: StringName in Content.ability_ids():
		var ability: AbilityDef = Content.ability(id)
		assert_eq(ability.validate(), PackedStringArray(), "%s validates" % id)
		assert_false(ability.description.is_empty(), "%s says what it does" % id)
		assert_true(ability.description.ends_with("."), "%s: one plain sentence or two" % id)
	var named: Dictionary[StringName, bool] = {}
	for class_id: StringName in CLASSES:
		var tree: TalentTreeDef = _tree(class_id)
		assert_not_null(tree, "%s has a tree under data/talents" % class_id)
		if tree == null:
			continue
		assert_eq(tree.validate(), PackedStringArray(), "%s's tree validates" % class_id)
		assert_eq(tree.class_id, class_id)
		var spec: Array = TREES[class_id]
		var parts: Array = [tree.trunk, tree.path_a, tree.path_b]
		var spec_parts: Array = [spec[0], spec[2], spec[3]]
		for p: int in parts.size():
			var names: Array[String] = []
			for node: StringName in parts[p]:
				named[node] = true
				var ability: AbilityDef = Content.ability(node)
				names.append(ability.display_name if ability != null else "?")
			assert_eq(
				names,
				Array(spec_parts[p] as Array, TYPE_STRING, &"", null),
				"%s, as the spec" % class_id
			)
		assert_eq(Array(tree.path_names), spec[1] as Array, "%s's path names" % class_id)
	assert_eq(named.size(), 44, "every ability is a node of one tree")

	# A tree naming a missing ability, or with a path of the wrong length, is refused.
	var bad: TalentTreeDef = _tree(&"knight").duplicate()
	bad.path_a = (
		[&"shield_bash_two", &"last_stand", &"bulwark", &"rallying_cry"] as Array[StringName]
	)
	assert_true(
		"\n".join(bad.validate()).contains("shield_bash_two"),
		"a missing ability: %s" % bad.validate()
	)
	bad = _tree(&"knight").duplicate()
	bad.path_b = [&"whirlwind", &"bloodthirst", &"reckless_swing"] as Array[StringName]
	assert_true("\n".join(bad.validate()).contains("path_b"), "a short path: %s" % bad.validate())
	bad = _tree(&"knight").duplicate()
	bad.trunk = [&"shield_bash", &"taunt"] as Array[StringName]
	assert_true("\n".join(bad.validate()).contains("trunk"), "a short trunk")
	bad = _tree(&"knight").duplicate()
	bad.path_names = ["Guardian"] as Array[String]
	assert_true("\n".join(bad.validate()).contains("path_names"), "one path name")
	# A second tree for a class that has one is refused: one tree a class.
	var second: TalentTreeDef = _tree(&"knight").duplicate()
	assert_true(
		"\n".join(second.validate()).contains("already has a tree"),
		"a second knight tree: %s" % second.validate()
	)
	assert_eq(_tree(&"knight").validate(), PackedStringArray(), "the knight's own tree is fine")
	assert_eq(Content.talent_tree(&"knight").resource_path, "res://data/talents/knight.tres")


# --- R2 ------------------------------------------------------------------------


func test_r2_points_from_levels() -> void:
	var hero := Hero.new(1, Content.hero_class(&"knight"))
	var expected: Array[int] = [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7]
	for level: int in range(1, 21):
		raise(hero, level)
		assert_eq(hero.level, level)
		assert_eq(hero.talent_points(), expected[level - 1], "level %d" % level)
	assert_eq(Hero.TALENT_POINTS, 7, "seven fill a tree: three trunk nodes and one path of four")

	# Each level-up through play says so: a talent point at 2, 4 ... 14, none at odd levels or after.
	var sim := Simulation.new(SEED)
	var wanted: Dictionary[int, bool] = {}
	var told: Dictionary[int, bool] = {}
	for start: int in [1, 2, 13, 14]:
		for h: Hero in sim.party.heroes:
			h.xp = Hero.xp_for_level(start + 1) - 1
			h.level = start
		var levelled: bool = false
		for i: int in 6000:
			sim.step()
			for e: SimEvent in sim.drain_events():
				if e.kind == SimEvent.Kind.LEVEL_UP:
					levelled = true
					var key: int = e.target_id * 100 + e.amount
					if e.amount % 2 == 0 and e.amount <= 14:
						wanted[key] = true
				elif e.kind == SimEvent.Kind.TALENT_POINT_GAINED:
					assert_true(sim.party.hero(e.source_id) != null, "names the hero")
					told[e.source_id * 100 + e.amount] = true
			if levelled:
				break
		assert_true(levelled, "a level-up from level %d" % start)
	assert_false(wanted.is_empty(), "levels that earn a point were reached")
	assert_eq(told, wanted, "one event per point, with the hero and the level")

	# Several levels in one award: one event for each point they earn, at once.
	var leap := Simulation.new(SEED)
	var rogue: Hero = leap.party.heroes[1]
	rogue.xp = Hero.xp_for_level(7) - 1
	var points: Array[int] = []
	var levels: Array[int] = []
	for i: int in 6000:
		leap.step()
		for e: SimEvent in leap.drain_events():
			if e.kind == SimEvent.Kind.LEVEL_UP and e.target_id == rogue.id:
				levels.append(e.amount)
			elif e.kind == SimEvent.Kind.TALENT_POINT_GAINED and e.source_id == rogue.id:
				points.append(e.amount)
		if not levels.is_empty():
			break
	assert_eq(levels, [2, 3, 4, 5, 6, 7] as Array[int], "one award, six levels")
	assert_eq(points, [2, 4, 6] as Array[int], "a point at 2, 4 and 6, each said once")
	assert_eq(rogue.talent_points(), 3, "three points to spend")


# --- R3 ------------------------------------------------------------------------


func test_r3_spending() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	var tree: TalentTreeDef = _tree(&"knight")
	# No point: nothing.
	assert_eq(knight.talent_points(), 0)
	assert_false(knight.can_take(tree.trunk[0]), "no point, no node")
	_take(sim, knight, tree.trunk[0])
	assert_eq(knight.talents(), [] as Array[StringName], "nothing without a point")

	raise(knight, 14)
	assert_eq(knight.talent_points(), 7)
	var illegal: Array[StringName] = [
		tree.trunk[1], tree.trunk[2], tree.path_a[0], tree.path_b[0], &"backstab", &"no_such_node"
	]
	for node: StringName in illegal:
		var events: Array[SimEvent] = _take(sim, knight, node)
		assert_eq(knight.talents(), [] as Array[StringName], "%s first is ignored" % node)
		assert_eq(_of(events, SimEvent.Kind.TALENT_TAKEN).size(), 0, "and says nothing")
	var taken: Array[StringName] = []
	for node: StringName in _full(&"knight", 0):
		assert_true(knight.can_take(node), "%s is next" % node)
		# Taking it twice in one step takes it once.
		sim.take_talent(knight.id, node)
		var events: Array[SimEvent] = _take(sim, knight, node)
		taken.append(node)
		assert_eq(knight.talents(), taken, "the legal order")
		var told: Array[SimEvent] = _of(events, SimEvent.Kind.TALENT_TAKEN)
		assert_eq(told.size(), 1, "one event for %s" % node)
		if not told.is_empty():
			assert_eq(told[0].source_id, knight.id)
			assert_eq(told[0].ability_id, node)
			assert_eq(told[0].amount, 7 - taken.size(), "the points left")
		# Nothing out of order between the legal steps.
		_take(sim, knight, tree.trunk[0])
		assert_eq(knight.talents(), taken, "a node taken already is not taken again")
	assert_eq(knight.talent_points(), 0, "the tree is full")
	raise(knight, 30)
	assert_eq(knight.talent_points(), 0, "levels after 14 bring no talent point")
	_take(sim, knight, tree.path_b[0])
	assert_eq(knight.talents(), taken, "a full tree takes nothing")
	# A hero with one point takes one node.
	var rogue: Hero = sim.party.heroes[1]
	raise(rogue, 2)
	_take(sim, rogue, &"backstab")
	_take(sim, rogue, &"smoke_step")
	assert_eq(rogue.talents(), [&"backstab"] as Array[StringName], "one point, one node")
	sim.take_talent(99, &"backstab")
	sim.step()
	var said: Array[SimEvent] = _of(sim.drain_events(), SimEvent.Kind.TALENT_TAKEN)
	assert_eq(said.size(), 0, "an unknown hero is ignored")


# --- R4 ------------------------------------------------------------------------


func test_r4_one_path() -> void:
	for class_id: StringName in CLASSES:
		for path: int in 2:
			var sim := Simulation.new(SEED)
			var hero: Hero = sim.party.heroes[CLASSES.find(class_id)]
			var tree: TalentTreeDef = _tree(class_id)
			raise(hero, 14)
			for node: StringName in tree.trunk:
				_take(sim, hero, node)
			assert_eq(hero.path(), -1, "%s: no path yet" % class_id)
			assert_true(hero.can_take(tree.path_a[0]), "%s: both paths open" % class_id)
			assert_true(hero.can_take(tree.path_b[0]), "%s: both paths open" % class_id)
			var walked: Array[StringName] = tree.path_nodes(path)
			var other: Array[StringName] = tree.path_nodes(1 - path)
			_take(sim, hero, walked[0])
			assert_eq(hero.path(), path, "%s walks path %d" % [class_id, path])
			for node: StringName in other:
				assert_false(hero.can_take(node), "%s: %s is closed" % [class_id, node])
				_take(sim, hero, node)
			assert_eq(hero.talents().size(), 4, "%s: nothing of the other path" % class_id)
			for node: StringName in walked.slice(1):
				_take(sim, hero, node)
			assert_eq(
				hero.talents(), _full(class_id, path), "%s: its own path, in order" % class_id
			)


# --- R5 ------------------------------------------------------------------------


func test_r5_abilities_take_effect() -> void:
	for class_id: StringName in CLASSES:
		var hero := Hero.new(1, Content.hero_class(class_id))
		raise(hero, 14)
		assert_eq(hero.combatant().abilities.size(), 0, "%s: no nodes, no abilities" % class_id)
		for path: int in 2:
			var nodes: Array[StringName] = _full(class_id, path)
			hero.set_talents(nodes)
			# The newest first: a deeper node is tried before the trunk (R14, so it is seen).
			var newest_first: Array[StringName] = nodes.duplicate()
			newest_first.reverse()
			assert_eq(
				_ids(hero.combatant().abilities),
				newest_first,
				"%s: its nodes, newest first" % class_id
			)
		hero.set_talents([] as Array[StringName])

	# A party with no nodes fights exactly as the class numbers alone did before talents.
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

	# From the next fight on: a node taken during a fight changes that fight in nothing.
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 2)
	var fighting: bool = false
	for i: int in 3000:
		sim.step()
		sim.drain_events()
		if sim.expedition.battle != null:
			fighting = true
			break
	assert_true(fighting, "a fight starts")
	if not fighting:
		return
	var battle: Battle = sim.expedition.battle
	sim.take_talent(knight.id, &"shield_bash")
	sim.step()
	assert_eq(knight.talents(), [&"shield_bash"] as Array[StringName], "taken mid-fight")
	assert_eq(battle.combatant(knight.id).abilities.size(), 0, "not in the fight under way")
	while sim.expedition.battle == battle:
		sim.step()
	for i: int in 6000:
		if sim.expedition.battle != null:
			break
		sim.step()
	assert_not_null(sim.expedition.battle, "a next fight")
	if sim.expedition.battle != null:
		var fighter: Combatant = sim.expedition.battle.combatant(knight.id)
		assert_eq(_ids(fighter.abilities), [&"shield_bash"] as Array[StringName], "in the next")


# --- R6 ------------------------------------------------------------------------


func test_r6_paragon() -> void:
	var sim := Simulation.new(SEED)
	var mage: Hero = sim.party.heroes[2]
	var cleric: Hero = sim.party.heroes[3]
	for level: int in [1, 13, 14, 15, 16, 20, 40]:
		raise(mage, level)
		assert_eq(mage.paragon_points(), maxi(level - 14, 0), "level %d" % level)
	# The three stats, 3% a point, with no limit.
	raise(cleric, 14)
	var base: Combatant = cleric.combatant()
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.step()
	assert_eq(cleric.paragon_rank(TrainingDef.Stat.POWER), 0, "no point, nothing spent")
	raise(cleric, 14 + 33)
	assert_eq(cleric.paragon_points(), 33)
	var ids: Array[StringName] = Content.training_ids()
	var stats: Array[TrainingDef.Stat] = [
		TrainingDef.Stat.POWER, TrainingDef.Stat.TOUGHNESS, TrainingDef.Stat.QUICKNESS
	]
	for stat: TrainingDef.Stat in stats:
		for point: int in 11:
			sim.spend_paragon(cleric.id, stat)
		sim.step()
		var events: Array[SimEvent] = _of(sim.drain_events(), SimEvent.Kind.PARAGON_SPENT)
		assert_eq(events.size(), 11, "an event a point")
		if not events.is_empty():
			assert_eq(events[10].source_id, cleric.id)
			assert_eq(events[10].amount, 11, "the points in the stat")
			assert_eq(ids[events[10].target_id], TalentRules.stat_def(stat).id, "the stat")
	assert_eq(cleric.paragon_points(), 0, "all spent")
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.step()
	assert_eq(cleric.paragon_rank(TrainingDef.Stat.POWER), 11, "none left, nothing more")
	var grown: Combatant = cleric.combatant()
	var levelled: Combatant = Combatant.from_hero(cleric.def(), cleric.level, cleric.id)
	for stat: TrainingDef.Stat in stats:
		assert_almost_eq(cleric.paragon_multiplier(stat), 1.33, 0.0001, "11 points, +33%")
	var bonus: float = cleric.paragon_multiplier(TrainingDef.Stat.POWER)
	assert_eq(grown.damage, roundi(levelled.damage * bonus), "Power: +33% damage")
	assert_eq(grown.heal_power, roundi(levelled.heal_power * bonus), "and healing")
	bonus = cleric.paragon_multiplier(TrainingDef.Stat.TOUGHNESS)
	assert_eq(grown.max_health, roundi(levelled.max_health * bonus), "Toughness: +33% health")
	bonus = cleric.paragon_multiplier(TrainingDef.Stat.QUICKNESS)
	assert_eq(
		grown.attack_interval_ticks,
		Combatant.seconds_to_ticks(cleric.def().attack_interval / bonus),
		"Quickness: 33% faster"
	)
	assert_lt(grown.attack_interval_ticks, levelled.attack_interval_ticks)
	assert_ne(base.damage, grown.damage)
	for id: StringName in ids:
		var def: TrainingDef = Content.training(id)
		assert_almost_eq(def.per_rank, 0.03, 0.0001, "%s is 3%% a point" % id)
		assert_true(def.description.begins_with("+3%"), "%s says so" % id)

	# A point spent mid-fight changes the fighter at once.
	var fresh := Simulation.new(SEED)
	var knight: Hero = fresh.party.heroes[0]
	raise(knight, 22)
	for i: int in 3000:
		if fresh.expedition.battle != null:
			break
		fresh.step()
	var battle: Battle = fresh.expedition.battle
	assert_not_null(battle, "a fight")
	if battle == null:
		return
	var fighter: Combatant = battle.combatant(knight.id)
	var damage: int = fighter.damage
	var health: int = fighter.max_health
	var interval: int = fighter.attack_interval_ticks
	fresh.spend_paragon(knight.id, TrainingDef.Stat.POWER)
	fresh.spend_paragon(knight.id, TrainingDef.Stat.TOUGHNESS)
	for point: int in 6:
		fresh.spend_paragon(knight.id, TrainingDef.Stat.QUICKNESS)
	fresh.step()
	assert_eq(fresh.expedition.battle, battle, "the same fight")
	assert_eq(fighter.damage, knight.combatant().damage, "Power: the fighter's damage now")
	assert_gt(fighter.damage, damage, "higher")
	assert_eq(fighter.max_health, knight.max_health(), "Toughness: its health now")
	assert_gt(fighter.max_health, health, "higher")
	assert_lt(fighter.attack_interval_ticks, interval, "Quickness: faster now")


## A HUD over [param sim], as spec 034's tests build it, with the UI layer over it for the hero
## windows (spec 060), for the Talents tab.
func _hud_over(sim: Simulation) -> Hud:
	return _make_hud(sim)


func after_each() -> void:
	super()
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


func test_r6_the_sheet_shows_the_points() -> void:
	var sim := Simulation.new(SEED)
	var hud: Hud = _hud_over(sim)
	var rogue: Hero = sim.party.heroes[1]
	raise(rogue, 17)
	rogue.set_talents([&"backstab", &"smoke_step"] as Array[StringName])
	hud.hero_windows.open(rogue.id, HeroWindow.Page.TALENTS)
	var sheet: HeroWindow = hud.hero_windows.window_of(rogue.id)
	hud.advance(0.1)
	# Spec 064 R7: the points read "to spend".
	assert_eq(sheet.line(&"talent_points"), "5 points to spend", "level 17 earns 7, two are spent")
	assert_eq(sheet.line(&"paragon_points"), "3 paragon points", "and three paragon points")
	assert_eq(sheet.line(&"training_power"), "Power 0 +0%", "nothing in Power yet")
	assert_true(sheet.page_marked(HeroWindow.Page.TALENTS), "the tab asks for a look")
	# A row's button (or its key) spends a point there, and the lines follow.
	sheet.train_row(0)
	sim.step()
	hud.advance(0.1)
	assert_eq(rogue.paragon_rank(TrainingDef.Stat.POWER), 1, "a point in Power")
	assert_eq(sheet.line(&"paragon_points"), "2 paragon points", "one fewer")
	assert_eq(sheet.line(&"training_power"), "Power 1 +3%", "the points and the bonus")
	sheet.train_row(0)
	sheet.train_row(0)
	sim.step()
	hud.advance(0.1)
	assert_eq(sheet.line(&"paragon_points"), "0 paragon points", "all spent")
	assert_eq(sheet.line(&"training_power"), "Power 3 +9%")
	# Spec 055: the tab's marker counts talent points too; with the tree full, nothing is left.
	rogue.set_talents(_full(&"rogue", 0))
	hud.advance(0.1)
	assert_false(sheet.page_marked(HeroWindow.Page.TALENTS), "nothing more to spend")
	var row: ParagonCell = sheet.talents.paragon_cells[0]
	assert_eq(row.id, &"power", "the first cell is Power")
	# Spec 064 R9: a medallion, not ready with no point.
	assert_ne(row.medallion.state(), UiIcon.State.READY, "the medallion is not ready with no point")
	sheet.train_row(0)
	sim.step()
	assert_eq(rogue.paragon_rank(TrainingDef.Stat.POWER), 3, "and spends nothing")
	# Taking a node shows at once (back to two taken, five to spend).
	rogue.set_talents([&"backstab", &"smoke_step"] as Array[StringName])
	sim.take_talent(rogue.id, &"finisher")
	sim.step()
	hud.advance(0.1)
	assert_eq(sheet.line(&"talent_points"), "4 points to spend", "one talent point fewer")


# --- R7 ------------------------------------------------------------------------


func test_r7_fresh_start() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 16)
	for node: StringName in _full(&"knight", 1):
		sim.take_talent(knight.id, node)
	sim.spend_paragon(knight.id, TrainingDef.Stat.TOUGHNESS)
	sim.step()
	sim.drain_events()
	assert_eq(knight.talents(), _full(&"knight", 1), "a full Berserker")
	assert_eq(Simulation.reset_price(knight), 1600, "100 gold a level")

	# Without the gold: nothing.
	sim.party.gold = 1599
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(knight.talents().size(), 7, "too poor")
	assert_eq(sim.party.gold, 1599)

	# In a fight: nothing.
	sim.party.gold = 5000
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

	# Otherwise at once.
	var gold: int = sim.party.gold
	var price: int = Simulation.reset_price(knight)
	sim.reset_talents(knight.id)
	sim.step()
	var said: Array[SimEvent] = _of(sim.drain_events(), SimEvent.Kind.TALENTS_RESET)
	assert_eq(sim.party.gold, gold - price, "the price is paid")
	assert_eq(knight.talents(), [] as Array[StringName], "every node given back")
	assert_eq(knight.talent_points(), 7, "as unspent points")
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "paragon points untouched")
	assert_eq(knight.paragon_points(), 1)
	assert_eq(said.size(), 1, "an event")
	if not said.is_empty():
		assert_eq(said[0].source_id, knight.id)
		assert_eq(said[0].amount, price)
	var tree: TalentTreeDef = _tree(&"knight")
	for node: StringName in tree.trunk:
		_take(sim, knight, node)
	assert_true(knight.can_take(tree.path_a[0]), "Guardian open again")
	assert_true(knight.can_take(tree.path_b[0]), "Berserker open again")


# --- R8 ------------------------------------------------------------------------


func test_r8_gold_training_is_gone() -> void:
	var sim := Simulation.new(SEED)
	assert_false(sim.has_method("train_hero"), "no command trains with gold")
	assert_false("HERO_TRAINED" in SimEvent.Kind.keys(), "and no event says so")
	var power: TrainingDef = Content.training(&"power")
	for field: String in ["base_cost", "cost_growth", "max_rank"]:
		assert_false(field in power, "no %s on a training" % field)

	var training: Array[Dictionary] = [
		{"power": 3, "toughness": 2, "quickness": 1}, {"power": 1}, {}, {"quickness": 4}
	]
	var paid: int = 0
	for ranks: Dictionary in training:
		for id: String in ranks:
			var price: Array = OLD_PRICES[id]
			var rank: int = ranks[id]
			for r: int in rank:
				var base: int = price[0]
				var growth: float = price[1]
				paid += roundi(base * pow(growth, r))
	assert_eq(paid, 167 + 82 + 45 + 40 + 45 + 68 + 101 + 152, "what spec 029 charged")
	var levels: Array[int] = [16, 9, 1, 14]
	var talent_points: Array[int] = [7, 4, 0, 7]
	var paragon_points: Array[int] = [2, 0, 0, 0]
	var data: Dictionary = _version_6(levels, training, 123)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_eq(Simulation.save_problems(parsed), PackedStringArray(), "a version 6 save loads")
	var loaded: Simulation = Simulation.from_save(parsed)
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.party.gold, 123 + paid, "the gold given back exactly")
	for i: int in levels.size():
		var hero: Hero = loaded.party.heroes[i]
		assert_eq(hero.talents(), [] as Array[StringName], "%s: no nodes" % hero.class_id)
		assert_eq(hero.talent_points(), talent_points[i], "%s: points unspent" % hero.class_id)
		assert_eq(hero.paragon_points(), paragon_points[i], "%s: paragon" % hero.class_id)
		for stat: int in TrainingDef.Stat.values():
			assert_eq(hero.paragon_rank(stat as TrainingDef.Stat), 0, "no ranks carried over")
		var def: HeroClassDef = hero.def()
		var health: int = def.max_health + def.health_per_level * (levels[i] - 1)
		assert_eq(hero.max_health(), health, "%s: no training in its numbers" % hero.class_id)
	var saved: Dictionary = loaded.to_save()
	var version: int = saved["version"]
	assert_eq(
		version,
		Simulation.SAVE_VERSION,
		"saved again at the current version (7 when spec 051 landed)"
	)
	for saved_hero: Dictionary in saved["heroes"]:
		assert_false(saved_hero.has("training"), "with no training")
	# A version 6 training rank that cannot be read is refused by name, not refunded.
	var broken: Dictionary = _version_6(levels, training, 0)
	broken["heroes"][1]["training"] = {"power": 99}
	assert_true(_any_names(Simulation.save_problems(broken), "heroes[1].training"), "refused")
	broken["heroes"][1]["training"] = {"luck": 1}
	assert_true(_any_names(Simulation.save_problems(broken), "heroes[1].training"), "refused")


# --- R9 ------------------------------------------------------------------------


func test_r9_saves() -> void:
	var sim := Simulation.new(SEED)
	var mage: Hero = sim.party.heroes[2]
	var rogue: Hero = sim.party.heroes[1]
	raise(mage, 18)
	raise(rogue, 6)
	for node: StringName in _full(&"mage", 1):
		sim.take_talent(mage.id, node)
	sim.take_talent(rogue.id, &"backstab")
	sim.spend_paragon(mage.id, TrainingDef.Stat.QUICKNESS)
	sim.spend_paragon(mage.id, TrainingDef.Stat.QUICKNESS)
	sim.spend_paragon(mage.id, TrainingDef.Stat.POWER)
	sim.step()
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	assert_eq(version, Simulation.SAVE_VERSION, "the current version (7 when spec 051 landed)")
	var saved_mage: Dictionary = data["heroes"][2]
	var names: Array = []
	for node: StringName in _full(&"mage", 1):
		names.append(String(node))
	var saved_talents: Array = saved_mage["talents"]
	assert_eq(saved_talents, names, "the nodes, in order, by id")
	var saved_paragon: Dictionary = saved_mage["paragon"]
	assert_eq(saved_paragon, {"power": 1, "toughness": 0, "quickness": 2}, "by stat")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var back: Simulation = Simulation.from_save(parsed)
	assert_not_null(back, "loads: %s" % Simulation.save_problems(parsed))
	if back == null:
		return
	assert_eq(back.party.heroes[2].talents(), _full(&"mage", 1), "the nodes, in order")
	assert_eq(back.party.heroes[1].talents(), [&"backstab"] as Array[StringName])
	assert_eq(back.party.heroes[1].talent_points(), 2, "unspent points from the level")
	assert_eq(back.party.heroes[2].paragon_rank(TrainingDef.Stat.QUICKNESS), 2)
	assert_eq(back.party.heroes[2].paragon_rank(TrainingDef.Stat.POWER), 1)
	assert_eq(back.party.heroes[2].paragon_points(), 1)
	var again: Array = back.to_save()["heroes"]
	var first: Array = data["heroes"]
	assert_eq(again, first, "the same again")

	# Each bad value is refused by name.
	var cases: Array = [
		["heroes[2].talents[1]", "talents", ["fireball", "chain_spark"]],
		["heroes[2].talents[3]", "talents", ["fireball", "frost_nova", "chain_spark", "meteor"]],
		[
			"heroes[2].talents[4]",
			"talents",
			["fireball", "frost_nova", "chain_spark", "ice_lance", "ignite"]
		],
		["heroes[2].talents[0]", "talents", ["backstab"]],
		["heroes[2].talents[0]", "talents", ["no_such_node"]],
		["heroes[2].talents[0]", "talents", [5]],
		["heroes[2].talents", "talents", "fireball"],
		["heroes[2].paragon.luck", "paragon", {"luck": 1}],
		["heroes[2].paragon.power", "paragon", {"power": -1}],
		["heroes[2].paragon.power", "paragon", {"power": 1.5}],
		["heroes[2].paragon", "paragon", {"power": 3, "quickness": 2}],
		["heroes[2].paragon", "paragon", []],
	]
	for case: Array in cases:
		var bad: Dictionary = data.duplicate(true)
		bad["heroes"][2][case[1]] = case[2]
		var found: PackedStringArray = Simulation.save_problems(bad)
		var field: String = case[0]
		assert_true(_any_names(found, field), "%s refused by name: %s" % [case[2], found])
		assert_null(Simulation.from_save(bad))
	# More nodes than the level earned.
	var greedy: Dictionary = data.duplicate(true)
	greedy["heroes"][1]["talents"] = ["backstab", "smoke_step", "finisher", "poisoned_blades"]
	var problems: PackedStringArray = Simulation.save_problems(greedy)
	assert_true(_any_names(problems, "heroes[1].talents"), "more than earned: %s" % problems)


# --- R10 -----------------------------------------------------------------------


func test_r10_auto_buy() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_buy(true)
	for hero: Hero in sim.party.heroes:
		raise(hero, 15)
	sim.party.gold = 1_000_000
	var bought: int = 0
	for i: int in 20 * 60 * Simulation.TICKS_PER_SECOND:
		sim.step()
		for e: SimEvent in sim.drain_events():
			if e.kind == SimEvent.Kind.UPGRADE_BOUGHT:
				bought += 1
			assert_false(
				e.kind in [SimEvent.Kind.TALENT_TAKEN, SimEvent.Kind.PARAGON_SPENT],
				"auto-buy spends no point"
			)
	assert_gt(bought, 10, "auto-buy was buying")
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.talents(), [] as Array[StringName], "%s: no node" % hero.class_id)
		assert_eq(hero.talent_points(), 7, "%s: unspent" % hero.class_id)
		assert_eq(hero.paragon_points(), hero.level - 14, "%s: paragon unspent" % hero.class_id)


# --- R11 -----------------------------------------------------------------------


## The game time of the first win over the Slime King from seed [param seed_value], or -1, and
## the wipes before it; spending as `dev.py sim --spend-talents` does if [param spending].
func _until_king(seed_value: int, spending: bool) -> Array[float]:
	var sim := Simulation.new(seed_value)
	var wipes: int = 0
	for i: int in roundi(KING_LIMIT_MINUTES * 60.0 * Simulation.TICKS_PER_SECOND):
		if spending:
			TalentSpender.spend(sim)
		var fight: Battle = sim.expedition.battle
		sim.step()
		for e: SimEvent in sim.drain_events():
			if e.kind == SimEvent.Kind.PARTY_WIPED:
				wipes += 1
			elif e.kind == SimEvent.Kind.GUARDIAN_SLAIN and fight != null:
				if fight.combatant(e.source_id).def_id == &"slime_king":
					return [sim.seconds(), float(wipes)] as Array[float]
	return [-1.0, float(wipes)] as Array[float]


func test_r11_worth_having() -> void:
	var report: PackedStringArray = []
	for seed_value: int in range(1, 6):
		var plain: Array[float] = _until_king(seed_value, false)
		var spent: Array[float] = _until_king(seed_value, true)
		var line: String = (
			"seed %d: without %.0f s, %d wipes; with %.0f s, %d wipes"
			% [seed_value, plain[0], plain[1], spent[0], spent[1]]
		)
		report.append(line)
		assert_gt(spent[0], 0.0, "with talents the King falls, " + line)
		assert_true(plain[0] < 0.0 or spent[0] < plain[0], "sooner, " + line)
		assert_lt(spent[1], plain[1], "with fewer wipes, " + line)
	gut.p("\n".join(report))


## Wins out of [constant PATH_SEEDS] for a party of level 14 against [constant PATH_FIGHT], with
## [param class_id]'s hero on path [param path] (none if [param class_id] is empty).
func _path_wins(class_id: StringName, path: int) -> int:
	var wins: int = 0
	for seed_value: int in PATH_SEEDS:
		var party := Party.new()
		var heroes: Array[Combatant] = []
		for hero: Hero in party.heroes:
			raise(hero, 14)
			if hero.class_id == class_id:
				hero.set_talents(_full(class_id, path))
			heroes.append(hero.combatant())
		var def: MonsterDef = Content.monster(PATH_FIGHT)
		var monsters: Array[Combatant] = [Combatant.from_monster(def, PATH_FIGHT_LEVEL, 100)]
		var battle := Battle.new(heroes, monsters, 0.0, 14.0, true, SimRng.new(seed_value * 7 + 1))
		while battle.result() == Battle.Result.ONGOING and battle.tick < LIMIT_TICKS_90_S:
			battle.step()
		if battle.result() == Battle.Result.HEROES_WON:
			wins += 1
	return wins


## Each path of [param class_id] wins most of a fight the bare party never wins.
func _worth_having(class_id: StringName) -> void:
	var bare: int = _path_wins(&"", -1)
	assert_eq(bare, 0, "the bare party never beats the %s in 90 s" % PATH_FIGHT)
	for path: int in 2:
		var name_text: String = _tree(class_id).path_names[path]
		var wins: int = _path_wins(class_id, path)
		gut.p("%s %s: %d of %d" % [class_id, name_text, wins, PATH_SEEDS])
		assert_gte(wins, 3, "%s wins it %d times of %d" % [name_text, wins, PATH_SEEDS])


func test_r11_worth_having_knight() -> void:
	_worth_having(&"knight")


func test_r11_worth_having_rogue() -> void:
	_worth_having(&"rogue")


func test_r11_worth_having_mage() -> void:
	_worth_having(&"mage")


func test_r11_worth_having_cleric() -> void:
	_worth_having(&"cleric")


# --- R12 -----------------------------------------------------------------------


func test_r12_deterministic() -> void:
	var runs: Array[Array] = []
	for run: int in 2:
		var sim := Simulation.new(SEED)
		var hashes: Array = []
		for i: int in 15 * 60 * Simulation.TICKS_PER_SECOND:
			TalentSpender.spend(sim)
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 == 0:
				hashes.append(sim.state_hash())
		var grown: bool = false
		for hero: Hero in sim.party.heroes:
			grown = grown or not hero.talents().is_empty()
		assert_true(grown, "the run spent points")
		hashes.append(sim.to_save())
		runs.append(hashes)
	assert_eq(runs[0], runs[1], "two runs with spending agree")

	# Spending nothing hashes as before: spec 016's recorded hashes.
	var recorded: Dictionary = (
		preload("res://tests/acceptance/test_016_camp_upgrades.gd").RECORDED_HASHES
	)
	for seed_value: int in recorded:
		var sim := Simulation.new(seed_value)
		var hashes: Array = []
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 == 0:
				hashes.append(sim.state_hash())
		assert_eq(hashes, recorded[seed_value] as Array, "seed %d hashes as before" % seed_value)


# --- R13 -----------------------------------------------------------------------


func test_r13_limit_ends_statuses() -> void:
	var sim := Simulation.new(SEED)
	for i: int in 3000:
		if sim.expedition.battle != null:
			break
		sim.step()
	var battle: Battle = sim.expedition.battle
	assert_not_null(battle, "a fight")
	if battle == null:
		return
	sim.drain_events()
	# Nobody can win: the fight runs into the 90-second limit, a monster slowed all the while.
	for c: Combatant in battle.heroes + battle.monsters:
		c.max_health = 100_000_000
		c.health = c.max_health
	var slow := AbilityEffect.new()
	slow.does = AbilityEffect.Does.STATUS
	slow.status = AbilityEffect.Status.SLOWED
	slow.seconds = 10_000.0
	slow.amount = 1.5
	var monster: Combatant = battle.monsters[0]
	BattleStatuses.apply(battle, battle.heroes[0], monster, slow, &"test_slow")
	assert_true(monster.has_status(AbilityEffect.Status.SLOWED), "slowed")
	var events: Array[SimEvent] = []
	while sim.expedition.battle == battle:
		sim.step()
		events.append_array(sim.drain_events())
	var ended: int = -1
	var lost: int = -1
	for i: int in events.size():
		var e: SimEvent = events[i]
		if e.kind == SimEvent.Kind.STATUS_ENDED and e.target_id == monster.id:
			ended = i
		if e.kind == SimEvent.Kind.ENCOUNTER_ENDED:
			lost = i
			assert_false(e.flag, "the limit is a loss")
	assert_gt(ended, -1, "the status ended with its event")
	assert_lt(ended, lost, "before the fight ended")
	for c: Combatant in battle.monsters:
		assert_true(c.statuses.is_empty(), "%d goes back to its chamber with no status" % c.id)
