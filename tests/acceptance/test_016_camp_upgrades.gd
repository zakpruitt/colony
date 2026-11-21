extends ColonyTest
## Acceptance tests for specs/016-camp-upgrades/spec.md, one per requirement.
## R8 (the headless sim command) is tested in tools/tests/test_016_sim_upgrades.py.

## Each upgrade: [id, stat, per-rank bonus, maximum rank], in shop order.
const UPGRADES: Array = [
	[&"sharp_blades", UpgradeDef.Stat.DAMAGE, 0.05, 20],
	[&"stout_armor", UpgradeDef.Stat.HEALTH, 0.05, 20],
	[&"field_medicine", UpgradeDef.Stat.REST_HEALING, 0.10, 10],
	[&"quick_march", UpgradeDef.Stat.TRAVEL_SPEED, 0.04, 10],
	[&"fat_purse", UpgradeDef.Stat.GOLD, 0.05, 20],
]
## State hashes of an untouched simulation every 1500 ticks up to 20 minutes,
## recorded on dev before this spec changed any sim code. Re-recorded by spec 023, whose
## monster ids (part of the hash) come from where the monster is; the game is otherwise the same.
## Re-recorded by spec 025, whose side quests stand in for some chambers' monsters.
## Re-recorded by spec 036, whose opening (stability, respawn and XP) is quicker.
## Re-recorded by spec 052, whose hash includes the resources the party holds; the game is
## otherwise the same (test_052 R11 checks it against spec 016's hashes from before).
const RECORDED_HASHES: Dictionary = {
	3:
	[
		2088869351,
		1317287107,
		2134628266,
		1698720485,
		1954781545,
		2695845907,
		298120728,
		2082791177,
	],
	11:
	[
		4212334920,
		3973968880,
		2586099486,
		722505920,
		91127050,
		1110065276,
		2240902745,
		42202787,
	],
}
const HOUR_TICKS: int = 36_000
const EPSILON: float = 0.0001

# --- Helpers -------------------------------------------------------------------


func _events_of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


## [last stable depth, wipes] after an hour of play, buying or not.
func _hour(seed_value: int, buying: bool) -> Vector2i:
	var sim := Simulation.new(seed_value)
	sim.expedition.stable_seconds = 120.0
	var wipes: int = 0
	if buying:
		# Spec 052: ranks past 3 cost a resource from an area this run never visits. This test asks
		# whether upgrades are worth their gold, so the buyer holds plenty of every resource.
		for resource_id: StringName in Content.resource_ids():
			sim.party.set_resource(resource_id, 1_000_000)
	for i: int in HOUR_TICKS:
		if buying:
			var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party)
			if cheapest != &"":
				sim.buy_upgrade(cheapest)
		sim.step()
		wipes += _events_of(sim.drain_events(), SimEvent.Kind.PARTY_WIPED).size()
	return Vector2i(sim.expedition.last_stable_depth, wipes)


# --- Requirements --------------------------------------------------------------


func test_r1_five_upgrades_are_valid() -> void:
	var ids: Array[StringName] = Content.upgrade_ids()
	assert_eq(ids.size(), UPGRADES.size(), "five upgrades: %s" % [ids])
	var last_order: int = -1000000
	for i: int in UPGRADES.size():
		var row: Array = UPGRADES[i]
		var id: StringName = row[0]
		var def: UpgradeDef = Content.upgrade(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate(), PackedStringArray(), "%s is valid" % id)
		assert_eq(def.id, id)
		assert_false(def.display_name.is_empty(), "%s has a name" % id)
		var stat: UpgradeDef.Stat = row[1]
		assert_eq(def.stat, stat, "%s stat" % id)
		assert_almost_eq(def.per_rank, row[2] as float, EPSILON, "%s bonus per rank" % id)
		var max_rank: int = row[3]
		assert_eq(def.max_rank, max_rank, "%s maximum rank" % id)
		if i < ids.size():
			assert_eq(ids[i], id, "upgrade_ids() in shop order")
		var shop_def: UpgradeDef = Content.upgrade(ids[i]) if i < ids.size() else null
		if shop_def != null:
			assert_gt(shop_def.order, last_order, "orders rise along upgrade_ids()")
			last_order = shop_def.order
	assert_null(Content.upgrade(&"no_such_upgrade"), "an unknown id is null")
	# Bonuses add up by rank.
	var upgrades := Upgrades.new()
	upgrades.set_rank(&"sharp_blades", 3)
	assert_almost_eq(upgrades.multiplier(UpgradeDef.Stat.DAMAGE), 1.15, EPSILON, "rank 3 is +15%")


func test_r2_each_rank_costs_more() -> void:
	for row: Array in UPGRADES:
		var id: StringName = row[0]
		var def: UpgradeDef = Content.upgrade(id)
		if def == null:
			fail_test("%s missing" % id)
			continue
		assert_between(def.base_cost, 20, 60, "%s first rank" % id)
		assert_between(def.cost_growth, 1.3, 1.6, "%s growth" % id)
		var upgrades := Upgrades.new()
		var last: int = 0
		for rank: int in 6:
			upgrades.set_rank(id, rank)
			var expected: int = roundi(def.base_cost * pow(def.cost_growth, rank))
			assert_eq(upgrades.cost(id), expected, "%s rank %d" % [id, rank])
			assert_gt(upgrades.cost(id), last, "%s rank %d costs more" % [id, rank])
			last = upgrades.cost(id)
		upgrades.set_rank(id, def.max_rank)
		assert_eq(upgrades.rank(id), def.max_rank)
		assert_eq(upgrades.cost(id), -1, "%s has no price at the maximum" % id)
	assert_eq(Upgrades.new().cost(&"no_such_upgrade"), -1, "an unknown id has no price")


func test_r3_buying_is_a_command() -> void:
	var sim := Simulation.new(5)
	var price: int = sim.upgrades.cost(&"stout_armor")
	sim.party.gold = price + 7
	sim.buy_upgrade(&"stout_armor")
	assert_eq(sim.upgrades.rank(&"stout_armor"), 0, "nothing until the next step")
	assert_eq(sim.party.gold, price + 7)
	sim.step()
	assert_eq(sim.upgrades.rank(&"stout_armor"), 1, "bought at the next step")
	assert_eq(sim.party.gold, 7, "the gold is taken")
	var bought: Array[SimEvent] = _events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT)
	assert_eq(bought.size(), 1, "one event")
	if bought.size() == 1:
		assert_eq(bought[0].source_id, Content.upgrade_ids().find(&"stout_armor"))
		assert_eq(bought[0].amount, 1, "the new rank")
		assert_eq(bought[0].tick, sim.tick)

	# Unaffordable, unknown and maxed do nothing.
	sim.buy_upgrade(&"sharp_blades")
	sim.buy_upgrade(&"no_such_upgrade")
	sim.step()
	assert_eq(sim.upgrades.rank(&"sharp_blades"), 0, "7 gold buys nothing")
	assert_eq(sim.party.gold, 7, "no gold lost")
	assert_true(_events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT).is_empty())
	sim.upgrades.set_rank(&"quick_march", 10)
	sim.party.gold = 1_000_000
	sim.buy_upgrade(&"quick_march")
	sim.step()
	assert_eq(sim.upgrades.rank(&"quick_march"), 10, "no rank past the maximum")
	assert_eq(sim.party.gold, 1_000_000, "no gold lost at the maximum")
	assert_true(_events_of(sim.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT).is_empty())

	# Three commands with gold for two buy two, in order.
	var other := Simulation.new(5)
	var first: int = other.upgrades.cost(&"fat_purse")
	other.upgrades.set_rank(&"fat_purse", 1)
	var second: int = other.upgrades.cost(&"fat_purse")
	other.upgrades.set_rank(&"fat_purse", 0)
	other.party.gold = first + second + 1
	for i: int in 3:
		other.buy_upgrade(&"fat_purse")
	other.step()
	assert_eq(other.upgrades.rank(&"fat_purse"), 2, "two bought")
	assert_eq(other.party.gold, 1, "paid for two")
	var events: Array[SimEvent] = _events_of(other.drain_events(), SimEvent.Kind.UPGRADE_BOUGHT)
	assert_eq(events.size(), 2, "two events")
	if events.size() == 2:
		assert_eq(events[0].amount, 1)
		assert_eq(events[1].amount, 2)
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r4_upgrades_change_the_game() -> void:
	# Damage, healing power and maximum health, in the fighters of the first battle.
	var plain := Simulation.new(9)
	var strong := Simulation.new(9)
	strong.upgrades.set_rank(&"sharp_blades", 4)  # +20%
	strong.upgrades.set_rank(&"stout_armor", 6)  # +30%
	assert_true(step_until(plain, func() -> bool: return plain.expedition.battle != null, 20_000))
	assert_true(step_until(strong, func() -> bool: return strong.expedition.battle != null, 20_000))
	if plain.expedition.battle != null and strong.expedition.battle != null:
		for hero: Hero in plain.party.heroes:
			var a: Combatant = plain.expedition.battle.combatant(hero.id)
			var b: Combatant = strong.expedition.battle.combatant(hero.id)
			assert_eq(b.damage, roundi(a.damage * 1.2), "damage of hero %d" % hero.id)
			assert_eq(b.heal_power, roundi(a.heal_power * 1.2), "heal power of hero %d" % hero.id)
			assert_eq(b.max_health, roundi(a.max_health * 1.3), "max health of hero %d" % hero.id)
		var cleric: Combatant = strong.expedition.battle.combatant(4)
		assert_gt(cleric.heal_power, 0, "the cleric heals, so heal power is compared")

	# A health upgrade heals by the gain.
	var buyer := Simulation.new(9)
	buyer.party.gold = 10_000
	var before: Array[int] = []
	for hero: Hero in buyer.party.heroes:
		before.append(hero.max_health())
	buyer.buy_upgrade(&"stout_armor")
	buyer.step()
	for i: int in buyer.party.heroes.size():
		var hero: Hero = buyer.party.heroes[i]
		assert_eq(hero.max_health(), roundi(before[i] * 1.05), "max health +5%")
		assert_eq(hero.health, hero.max_health(), "health rose by the gain")

	# Rest healing per second, from the same rest.
	var resting_a := Simulation.new(9)
	var resting_b := Simulation.new(9)
	var is_resting: Callable = func(s: Simulation) -> bool:
		return s.expedition.state == Expedition.State.RESTING
	assert_true(step_until(resting_a, is_resting.bind(resting_a), 20_000), "the party rests")
	assert_true(step_until(resting_b, is_resting.bind(resting_b), 20_000))
	assert_eq(resting_a.tick, resting_b.tick, "the same rest")
	resting_b.upgrades.set_rank(&"field_medicine", 5)  # +50%, applies at once
	var start: Array[int] = []
	for hero: Hero in resting_a.party.heroes:
		start.append(hero.health)
	for i: int in 20:
		resting_a.step()
		resting_b.step()
	var compared: int = 0
	for i: int in start.size():
		var a_hero: Hero = resting_a.party.heroes[i]
		var b_hero: Hero = resting_b.party.heroes[i]
		var full: int = a_hero.max_health()
		var rest_seconds: float = 2.0
		var slow: int = mini(full, start[i] + floori(0.04 * full * rest_seconds + EPSILON))
		var fast: int = mini(full, start[i] + floori(0.06 * full * rest_seconds + EPSILON))
		if start[i] >= full:
			continue
		assert_eq(a_hero.health, slow, "hero %d rests at 4%% a second" % a_hero.id)
		assert_eq(b_hero.health, fast, "hero %d rests at 6%% a second" % b_hero.id)
		compared += 1
	assert_gt(compared, 0, "someone was healing")

	# Distance travelled per second, from the start.
	var walk_a := Simulation.new(9)
	var walk_b := Simulation.new(9)
	walk_b.upgrades.set_rank(&"quick_march", 5)  # +20%
	var x_a: float = walk_a.expedition.x
	var x_b: float = walk_b.expedition.x
	for i: int in 5:
		walk_a.step()
		walk_b.step()
	var walked_a: float = absf(walk_a.expedition.x - x_a)
	var walked_b: float = absf(walk_b.expedition.x - x_b)
	assert_almost_eq(walked_a, 1.5, EPSILON, "3 tiles a second")
	assert_almost_eq(walked_b, walked_a * 1.2, EPSILON, "20% faster")

	# Distance climbed per second.
	var climbed: Array[float] = []
	for rank: int in [0, 5]:
		var climber := Simulation.new(9)
		climber.upgrades.set_rank(&"quick_march", rank)
		climber.set_target_depth(2)
		var climbing: Callable = func() -> bool:
			return climber.expedition.state == Expedition.State.CLIMBING
		assert_true(step_until(climber, climbing, 20_000), "the party climbs")
		var y: float = climber.expedition.hero_position(1).y
		climber.step()
		climber.step()
		assert_eq(climber.expedition.state, Expedition.State.CLIMBING, "still climbing")
		climbed.append(absf(climber.expedition.hero_position(1).y - y))
	assert_almost_eq(climbed[0], 0.8, EPSILON, "4 tiles a second")
	assert_almost_eq(climbed[1], climbed[0] * 1.2, EPSILON, "20% faster")

	# Gold from the same kills.
	var poor := Simulation.new(9)
	var rich := Simulation.new(9)
	rich.upgrades.set_rank(&"fat_purse", 4)  # +20%
	var poor_gold: Array[int] = []
	var rich_gold: Array[int] = []
	for i: int in 6000:
		poor.step()
		rich.step()
		# Kills only: a side quest's gold is not the purse's (its source is the worker).
		for event: SimEvent in _events_of(poor.drain_events(), SimEvent.Kind.GOLD_GAINED):
			if event.source_id >= Expedition.FIRST_MONSTER_ID:
				poor_gold.append(event.amount)
		for event: SimEvent in _events_of(rich.drain_events(), SimEvent.Kind.GOLD_GAINED):
			if event.source_id >= Expedition.FIRST_MONSTER_ID:
				rich_gold.append(event.amount)
	assert_gt(poor_gold.size(), 5, "kills pay gold")
	assert_eq(rich_gold.size(), poor_gold.size(), "the same kills")
	for i: int in mini(poor_gold.size(), rich_gold.size()):
		assert_eq(rich_gold[i], roundi(poor_gold[i] * 1.2), "kill %d pays 20%% more" % i)
	assert_engine_error_count(0)
	assert_push_error_count(0)


func test_r5_no_upgrades_changes_nothing() -> void:
	for seed_value: int in RECORDED_HASHES:
		var sim := Simulation.new(seed_value)
		var hashes: Array = []
		for i: int in 12_000:
			sim.step()
			sim.drain_events()
			if sim.tick % 1500 == 0:
				hashes.append(sim.state_hash())
		var recorded: Array = RECORDED_HASHES[seed_value]
		assert_eq(hashes, recorded, "seed %d hashes as before" % seed_value)


func test_r6_upgrades_are_worth_buying() -> void:
	var better: int = 0
	var lines: PackedStringArray = []
	for seed_value: int in [1, 2, 3, 4, 5]:
		var plain: Vector2i = _hour(seed_value, false)
		var bought: Vector2i = _hour(seed_value, true)
		var wins: bool = bought.x > plain.x or (bought.x == plain.x and bought.y < plain.y)
		if wins:
			better += 1
		lines.append(
			(
				"seed %d: plain depth %d wipes %d, buying depth %d wipes %d"
				% [seed_value, plain.x, plain.y, bought.x, bought.y]
			)
		)
	gut.p("\n".join(lines))
	assert_gte(better, 4, "buying wins on 4 of 5 seeds:\n%s" % "\n".join(lines))


func test_r7_upgrades_are_saved() -> void:
	var sim := Simulation.new(21)
	for i: int in 600:
		sim.step()
	sim.upgrades.set_rank(&"stout_armor", 4)
	sim.upgrades.set_rank(&"quick_march", 10)
	var data: Dictionary = sim.to_save()
	var version: int = data["version"]
	assert_eq(version, Simulation.SAVE_VERSION, "the current save version (3 since spec 022)")
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary)
	var loaded: Simulation = Simulation.from_save(parsed as Dictionary)
	assert_not_null(loaded, "loads: %s" % Simulation.save_problems(parsed as Dictionary))
	if loaded == null:
		return
	for row: Array in UPGRADES:
		var id: StringName = row[0]
		assert_eq(loaded.upgrades.rank(id), sim.upgrades.rank(id), "%s rank" % id)
	for i: int in sim.party.heroes.size():
		var hero: Hero = loaded.party.heroes[i]
		assert_eq(hero.max_health(), sim.party.heroes[i].max_health(), "health bonus comes back")
		assert_eq(hero.health, hero.max_health(), "standing at full")
	var x: float = loaded.expedition.x
	loaded.step()
	assert_almost_eq(absf(loaded.expedition.x - x), 0.3 * 1.4, EPSILON, "travel bonus comes back")

	# A version 1 save loads with every rank 0.
	var old: Dictionary = data.duplicate(true)
	old["version"] = 1
	old.erase("upgrades")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "version 1 loads: %s" % Simulation.save_problems(old))
	if from_old != null:
		for row: Array in UPGRADES:
			assert_eq(from_old.upgrades.rank(row[0] as StringName), 0)
		assert_false(from_old.upgrades.any())
	var upgraded: int = Simulation.upgrade_save(old)["version"]
	assert_eq(upgraded, Simulation.SAVE_VERSION, "through the upgrade steps")

	# Bad ranks are refused by name; unknown extra keys are not.
	var cases: Array = [
		["stout_armor", -1],
		["stout_armor", 21],
		["field_medicine", 11],
		["golden_touch", 1],
		["sharp_blades", 1.5],
	]
	for entry: Array in cases:
		var bad: Dictionary = data.duplicate(true)
		var ranks: Dictionary = bad["upgrades"]
		ranks[entry[0]] = entry[1]
		var problems: PackedStringArray = Simulation.save_problems(bad)
		var named: bool = false
		for problem: String in problems:
			named = named or problem.contains(entry[0] as String)
		assert_true(named, "%s = %s refused by name: %s" % [entry[0], entry[1], problems])
		assert_null(Simulation.from_save(bad))
	var extra: Dictionary = data.duplicate(true)
	extra["saved_at"] = 12345
	assert_eq(Simulation.save_problems(extra), PackedStringArray(), "extra keys are tolerated")
	assert_engine_error_count(0)
	assert_push_error_count(0)
