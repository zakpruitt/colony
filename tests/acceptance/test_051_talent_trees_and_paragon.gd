extends "res://tests/support/hud_fixture.gd"
## Acceptance tests for specs/051-talent-trees-and-paragon/spec.md, one per requirement. R11
## (talents worth having) is the same check as spec 109's R9 and runs once, in test_109. Spec
## 029's tests of gold training were removed with it; the tests of the hero sheet, goals, defeat
## note and help that named training were amended to spend paragon points. R1 to R4 (the trees'
## shape, points and the rules for taking a node) moved to test_109 when the trees became three
## paths of five, and the rest were amended for them.

const SEED: int = 51
const CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]
## What spec 029 charged for training rank r + 1: base * growth ^ r, by training.
const OLD_PRICES: Dictionary = {
	"power": [40, 1.35],
	"toughness": [35, 1.35],
	"quickness": [45, 1.5],
}
# --- Helpers -------------------------------------------------------------------


## The five nodes of path [param path] of [param class_id]'s tree, in order.
func _full(class_id: StringName, path: int) -> Array[StringName]:
	return _tree(class_id).path(path).nodes.duplicate()


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


# --- R5 ------------------------------------------------------------------------


func test_r5_abilities_take_effect() -> void:
	for class_id: StringName in CLASSES:
		var hero := Hero.new(1, Content.hero_class(class_id))
		raise(hero, 30)
		assert_eq(hero.combatant().abilities.size(), 0, "%s: no nodes, no abilities" % class_id)
		for path: int in 3:
			var nodes: Array[StringName] = _full(class_id, path)
			hero.set_talents(nodes)
			# The deepest first, tier 2's left before its right (spec 109's fight order).
			var deepest_first: Array[StringName] = [
				nodes[4], nodes[3], nodes[1], nodes[2], nodes[0]
			]
			assert_eq(
				_ids(hero.combatant().abilities),
				deepest_first,
				"%s: its nodes, deepest first" % class_id
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
	for level: int in [1, 29, 30, 31, 32, 36, 60]:
		raise(mage, level)
		assert_eq(mage.paragon_points(), maxi(level - 30, 0), "level %d" % level)
	# The three stats, 3% a point, with no limit.
	raise(cleric, 30)
	var base: Combatant = cleric.combatant()
	sim.spend_paragon(cleric.id, TrainingDef.Stat.POWER)
	sim.step()
	assert_eq(cleric.paragon_rank(TrainingDef.Stat.POWER), 0, "no point, nothing spent")
	raise(cleric, 30 + 33)
	assert_eq(cleric.paragon_points(), 33)
	var ids: Array[StringName] = Content.training_ids()
	var stats: Array[TrainingDef.Stat] = [
		TrainingDef.Stat.POWER, TrainingDef.Stat.TOUGHNESS, TrainingDef.Stat.QUICKNESS
	]
	for stat: TrainingDef.Stat in stats:
		for point: int in 11:
			sim.spend_paragon(cleric.id, stat)
		sim.step()
		var events: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.PARAGON_SPENT)
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
	raise(knight, 38)
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


func test_r6_the_sheet_shows_the_points() -> void:
	var sim := Simulation.new(SEED)
	var hud: Hud = _hud_over(sim)
	var rogue: Hero = sim.party.heroes[1]
	raise(rogue, 33)
	rogue.set_talents([&"backstab", &"smoke_step"] as Array[StringName])
	hud.hero_windows.open(rogue.id, HeroWindow.Page.TALENTS)
	var sheet: HeroWindow = hud.hero_windows.window_of(rogue.id)
	hud.advance(0.1)
	# Spec 064 R7: the points read "to spend".
	assert_eq(sheet.line(&"talent_points"), "13 points to spend", "level 33 earns 15, two spent")
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
	var all: Array[StringName] = []
	for path: int in 3:
		all.append_array(_full(&"rogue", path))
	rogue.set_talents(all)
	hud.advance(0.1)
	assert_false(sheet.page_marked(HeroWindow.Page.TALENTS), "nothing more to spend")
	var row: ParagonCell = sheet.talents.paragon_cells[0]
	assert_eq(row.id, &"power", "the first cell is Power")
	# Spec 064 R9: a medallion, not ready with no point.
	assert_ne(row.medallion.state(), UiIcon.State.READY, "the medallion is not ready with no point")
	sheet.train_row(0)
	sim.step()
	assert_eq(rogue.paragon_rank(TrainingDef.Stat.POWER), 3, "and spends nothing")
	# Taking a node shows at once (back to two taken, thirteen to spend).
	rogue.set_talents([&"backstab", &"smoke_step"] as Array[StringName])
	give_rank(rogue, &"finisher")  # spec 110: the rank tier 2 needs
	sim.take_talent(rogue.id, &"finisher")
	sim.step()
	hud.advance(0.1)
	assert_eq(sheet.line(&"talent_points"), "12 points to spend", "one talent point fewer")


# --- R7 ------------------------------------------------------------------------


func test_r7_fresh_start() -> void:
	var sim := Simulation.new(SEED)
	var knight: Hero = sim.party.heroes[0]
	raise(knight, 31)
	for node: StringName in _full(&"knight", 1):
		give_rank(knight, node)  # spec 110: the rank each tier needs
		sim.take_talent(knight.id, node)
	sim.spend_paragon(knight.id, TrainingDef.Stat.TOUGHNESS)
	sim.step()
	sim.drain_events()
	assert_eq(knight.talents(), _full(&"knight", 1), "a full Berserker")
	assert_eq(Simulation.reset_price(knight), 3100, "100 gold a level")

	# Without the gold: nothing.
	sim.party.gold = 3099
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(knight.talents().size(), 5, "too poor")
	assert_eq(sim.party.gold, 3099)

	# In a fight: nothing.
	sim.party.gold = 10000
	for i: int in 3000:
		if sim.expedition.battle != null:
			break
		sim.step()
	assert_not_null(sim.expedition.battle, "a fight")
	sim.reset_talents(knight.id)
	sim.step()
	assert_eq(knight.talents().size(), 5, "not during a fight")
	while sim.expedition.battle != null:
		sim.step()
	sim.drain_events()

	# Otherwise at once.
	var gold: int = sim.party.gold
	var price: int = Simulation.reset_price(knight)
	sim.reset_talents(knight.id)
	sim.step()
	var said: Array[SimEvent] = _of_kind(sim.drain_events(), SimEvent.Kind.TALENTS_RESET)
	assert_eq(sim.party.gold, gold - price, "the price is paid")
	assert_eq(knight.talents(), [] as Array[StringName], "every node given back")
	assert_eq(knight.talent_points(), 15, "as unspent points")
	assert_eq(knight.paragon_rank(TrainingDef.Stat.TOUGHNESS), 1, "paragon points untouched")
	var earned: int = TalentRules.paragon_points_at(knight.level)
	assert_eq(knight.paragon_points(), earned - 1, "the one spent stays spent")
	assert_eq(said.size(), 1, "an event")
	if not said.is_empty():
		assert_eq(said[0].source_id, knight.id)
		assert_eq(said[0].amount, price)
	var tree: TalentTreeDef = _tree(&"knight")
	_take(sim, knight, tree.path(1).nodes[0])
	for path: int in 3:
		assert_true(knight.can_take(tree.path(path).nodes[path % 2]), "every path open again")


# --- R8 ------------------------------------------------------------------------


func test_r8_gold_training_is_gone() -> void:
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
	var levels: Array[int] = [32, 9, 1, 14]
	var talent_points: Array[int] = [15, 4, 0, 7]
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
	raise(mage, 34)
	raise(rogue, 6)
	for node: StringName in _full(&"mage", 1):
		give_rank(mage, node)  # spec 110: the rank each tier needs
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
	assert_eq(back.party.heroes[2].paragon_points(), 1, "four earned, three spent")
	var again: Array = back.to_save()["heroes"]
	var first: Array = data["heroes"]
	assert_eq(again, first, "the same again")

	# Each bad value is refused by name (paragon: level 34 allows 20, its level less 14).
	var cases: Array = [
		["heroes[2].talents[1]", "talents", ["fireball", "meteor"]],
		["heroes[2].talents[0]", "talents", ["ignite"]],
		["heroes[2].talents[2]", "talents", ["fireball", "ignite", "fireball"]],
		["heroes[2].talents[1]", "talents", ["ice_lance", "ignite"]],
		["heroes[2].talents[0]", "talents", ["backstab"]],
		["heroes[2].talents[0]", "talents", ["no_such_node"]],
		["heroes[2].talents[0]", "talents", [5]],
		["heroes[2].talents", "talents", "fireball"],
		["heroes[2].paragon.luck", "paragon", {"luck": 1}],
		["heroes[2].paragon.power", "paragon", {"power": -1}],
		["heroes[2].paragon.power", "paragon", {"power": 1.5}],
		["heroes[2].paragon", "paragon", {"power": 15, "quickness": 6}],
		["heroes[2].paragon", "paragon", {"power": 21}],
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
	greedy["heroes"][1]["talents"] = ["backstab", "mark_for_death", "finisher", "ambush"]
	var problems: PackedStringArray = Simulation.save_problems(greedy)
	assert_true(_any_names(problems, "heroes[1].talents"), "more than earned: %s" % problems)


# --- R10 -----------------------------------------------------------------------


func test_r10_auto_buy() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_buy(true)
	for hero: Hero in sim.party.heroes:
		raise(hero, 33)
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
		assert_eq(hero.talent_points(), 15, "%s: unspent" % hero.class_id)
		assert_eq(hero.paragon_points(), hero.level - 30, "%s: paragon unspent" % hero.class_id)


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
