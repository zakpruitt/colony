extends GutTest
## Acceptance tests for specs/029-hero-training/spec.md, one per requirement. Nothing here reads or
## writes a save file: saves are dictionaries passed through JSON in memory.

## Each training: [id, name, stat, per-rank bonus, maximum rank], in sheet order.
const TRAININGS: Array = [
	[&"power", "Power", TrainingDef.Stat.POWER, 0.05, 20],
	[&"toughness", "Toughness", TrainingDef.Stat.TOUGHNESS, 0.05, 20],
	[&"quickness", "Quickness", TrainingDef.Stat.QUICKNESS, 0.03, 10],
]
## State hashes of an untouched simulation every 1500 ticks up to 20 minutes, recorded on dev
## before this spec changed any sim code: first on f2aab10, then again on 9a496cf (spec 025's
## side quests change the game) with this spec's sim code set aside.
## Re-recorded by spec 036, whose opening (stability, respawn and XP) is quicker.
const RECORDED_HASHES: Dictionary = {
	7:
	[
		2084462142,
		1561799888,
		3430649855,
		3211837043,
		4285711305,
		628014606,
		3523731703,
		1401816699,
	],
	29:
	[
		2137347314,
		1257746763,
		1616045309,
		257261949,
		388501477,
		1050815822,
		1209199514,
		2783104606,
	],
}
const SEED: int = 29
const HOUR_TICKS: int = 36_000
const SCREEN: Vector2 = Vector2(640, 360)
const TOP_BAND: float = 28.0
## Pixels kept clear just above the party frames (spec 027's ticker).
const TICKER_STRIP: float = 12.0
const POWER: StringName = &"power"
const TOUGHNESS: StringName = &"toughness"
const QUICKNESS: StringName = &"quickness"
const BLADES: StringName = &"sharp_blades"
const ARMOR: StringName = &"stout_armor"
const EPSILON: float = 0.0001

var _sim: Simulation
var _world: World
var _effects: CombatEffects
var _hud: Hud

# --- Helpers -------------------------------------------------------------------


func after_each() -> void:
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


func _events_of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(parsed is Dictionary, "the save survives JSON")
	return parsed as Dictionary


func _any_names(problems: PackedStringArray, words: Array[String]) -> bool:
	for problem: String in problems:
		var all: bool = true
		for word: String in words:
			all = all and problem.contains(word)
		if all:
			return true
	return false


## Steps [param sim] until [param done] holds (at most [param limit] ticks); false if it never did.
func _step_until(sim: Simulation, done: Callable, limit: int = 20_000) -> bool:
	for i: int in limit:
		if done.call():
			return true
		sim.step()
	return done.call()


## A HUD on [param simulation], with a world and effects, none of them processing by themselves.
func _make_hud(simulation: Simulation) -> Hud:
	_sim = simulation
	_world = World.new()
	_world.simulation = simulation
	add_child_autofree(_world)
	_world.set_process(false)
	_effects = CombatEffects.new()
	add_child_autofree(_effects)
	_effects.setup(_world, simulation)
	_effects.set_process(false)
	var made := Hud.new()
	add_child_autofree(made)
	made.set_process(false)
	made.setup(simulation, _world, _effects)
	made.advance(0.0)
	_hud = made
	return made


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


## Steps the simulation once and lets the world report its events, as a frame would.
func _frame() -> void:
	_sim.step()
	_world.sync(0.016)
	_hud.advance(0.016)


## The training row of the open sheet for [param id], or null.
func _row(id: StringName) -> HeroSheet.TrainingRow:
	return _hud.hero_sheet.training_row(StringName("training_" + String(id)))


## The fighter a hero's own numbers make, untouched by any battle.
func _base(hero: Hero) -> Combatant:
	return Combatant.from_hero(hero.def(), hero.level, hero.id)


static func _percent(multiplier: float) -> String:
	return "(+%d%%)" % roundi((multiplier - 1.0) * 100.0)


# --- R1 ------------------------------------------------------------------------


func test_r1_trainings_are_valid() -> void:
	var ids: Array[StringName] = Content.training_ids()
	assert_eq(ids.size(), TRAININGS.size(), "three trainings: %s" % [ids])
	for i: int in TRAININGS.size():
		var row: Array = TRAININGS[i]
		var id: StringName = row[0]
		var def: TrainingDef = Content.training(id)
		assert_not_null(def, "%s loads" % id)
		if def == null:
			continue
		assert_eq(def.validate(), PackedStringArray(), "%s is valid" % id)
		assert_eq(def.id, id)
		assert_eq(def.display_name, row[1] as String, "%s name" % id)
		assert_false(def.description.is_empty(), "%s says what it does" % id)
		assert_eq(def.stat, row[2] as TrainingDef.Stat, "%s stat" % id)
		assert_almost_eq(def.per_rank, row[3] as float, EPSILON, "%s bonus per rank" % id)
		assert_eq(def.max_rank, row[4] as int, "%s maximum rank" % id)
		if i < ids.size():
			assert_eq(ids[i], id, "training_ids() in sheet order")
		assert_gte(def.base_cost, 1, "%s has a base cost" % id)
		assert_gt(def.cost_growth, 1.0, "%s has a growth factor" % id)
		# The price of a hero's next rank depends on that hero's rank alone.
		var hero := Hero.new(1, Content.hero_class(&"knight"))
		var last: int = 0
		for rank: int in def.max_rank:
			hero.set_training_rank(id, rank)
			var expected: int = roundi(def.base_cost * pow(def.cost_growth, rank))
			assert_eq(hero.training_cost(id), expected, "%s rank %d" % [id, rank])
			assert_gt(hero.training_cost(id), last, "%s rank %d costs more" % [id, rank])
			last = hero.training_cost(id)
		hero.set_training_rank(id, def.max_rank)
		assert_eq(hero.training_rank(id), def.max_rank)
		assert_eq(hero.training_cost(id), 0, "%s has no price at the maximum" % id)
		hero.set_training_rank(id, 3)
		var stat: TrainingDef.Stat = row[2]
		assert_almost_eq(
			hero.training_multiplier(stat), 1.0 + 3.0 * def.per_rank, EPSILON, "ranks add up"
		)
	assert_null(Content.training(&"agility"), "an unknown id is null")
	assert_eq(Hero.new(1, Content.hero_class(&"knight")).training_cost(&"agility"), 0)


# --- R2 ------------------------------------------------------------------------


func test_r2_training_is_per_hero() -> void:
	var sim := Simulation.new(5)
	var rogue: Hero = sim.party.heroes[1]
	var price: int = rogue.training_cost(POWER)
	sim.party.gold = price + 7
	sim.train_hero(rogue.id, POWER)
	assert_eq(rogue.training_rank(POWER), 0, "nothing until the next step")
	assert_eq(sim.party.gold, price + 7)
	sim.step()
	assert_eq(rogue.training_rank(POWER), 1, "trained at the next step")
	assert_eq(sim.party.gold, 7, "the gold is taken")
	var trained: Array[SimEvent] = _events_of(sim.drain_events(), SimEvent.Kind.HERO_TRAINED)
	assert_eq(trained.size(), 1, "one event")
	if trained.size() == 1:
		assert_eq(trained[0].source_id, rogue.id, "source: the hero")
		assert_eq(trained[0].target_id, Content.training_ids().find(POWER), "target: the training")
		assert_eq(trained[0].amount, 1, "amount: the new rank")
		assert_eq(trained[0].tick, sim.tick)
	for hero: Hero in sim.party.heroes:
		if hero != rogue:
			for id: StringName in Content.training_ids():
				assert_eq(hero.training_rank(id), 0, "hero %d unchanged" % hero.id)
	assert_eq(sim.party.heroes[0].training_cost(POWER), price, "another hero's price is its own")
	assert_gt(rogue.training_cost(POWER), price, "the trained hero's next rank costs more")

	# Without the gold, at the maximum, or for nobody or nothing: nothing happens.
	sim.train_hero(rogue.id, TOUGHNESS)
	sim.step()
	assert_eq(rogue.training_rank(TOUGHNESS), 0, "7 gold trains nothing")
	assert_eq(sim.party.gold, 7, "no gold lost")
	rogue.set_training_rank(QUICKNESS, 10)
	sim.party.gold = 1_000_000
	sim.train_hero(rogue.id, QUICKNESS)
	sim.train_hero(99, POWER)
	sim.train_hero(rogue.id, &"agility")
	sim.step()
	assert_eq(rogue.training_rank(QUICKNESS), 10, "no rank past the maximum")
	assert_eq(sim.party.gold, 1_000_000, "no gold lost")
	assert_true(_events_of(sim.drain_events(), SimEvent.Kind.HERO_TRAINED).is_empty(), "no event")

	# Two commands with gold for two train twice, in order.
	var other := Simulation.new(5)
	var mage: Hero = other.party.heroes[2]
	var first: int = mage.training_cost(TOUGHNESS)
	other.party.gold = first + roundi(first * Content.training(TOUGHNESS).cost_growth)
	other.train_hero(mage.id, TOUGHNESS)
	other.train_hero(mage.id, TOUGHNESS)
	other.train_hero(mage.id, TOUGHNESS)
	other.step()
	assert_eq(mage.training_rank(TOUGHNESS), 2, "two bought")
	assert_eq(other.party.gold, 0, "paid for two")
	var events: Array[SimEvent] = _events_of(other.drain_events(), SimEvent.Kind.HERO_TRAINED)
	assert_eq(events.size(), 2, "two events")
	assert_engine_error_count(0)
	assert_push_error_count(0)


# --- R3 ------------------------------------------------------------------------


func _check_numbers(hero: Hero, fighter: Combatant, upgrades: Upgrades, when: String) -> void:
	var base: Combatant = _base(hero)
	var power: float = (
		upgrades.multiplier(UpgradeDef.Stat.DAMAGE)
		* hero.training_multiplier(TrainingDef.Stat.POWER)
	)
	var health: float = (
		upgrades.multiplier(UpgradeDef.Stat.HEALTH)
		* hero.training_multiplier(TrainingDef.Stat.TOUGHNESS)
	)
	var quick: float = hero.training_multiplier(TrainingDef.Stat.QUICKNESS)
	var what: String = "%s %s" % [hero.class_id, when]
	assert_eq(fighter.damage, roundi(base.damage * power), "%s damage" % what)
	assert_eq(fighter.heal_power, roundi(base.heal_power * power), "%s healing" % what)
	assert_eq(fighter.max_health, roundi(base.max_health * health), "%s maximum health" % what)
	assert_eq(hero.max_health(), roundi(base.max_health * health), "%s hero's maximum" % what)
	var interval: int = Combatant.seconds_to_ticks(hero.def().attack_interval / quick)
	assert_eq(fighter.attack_interval_ticks, interval, "%s attack speed" % what)


func test_r3_stacks_with_upgrades() -> void:
	var sim := Simulation.new(9)
	sim.upgrades.set_rank(BLADES, 4)  # +20%
	sim.upgrades.set_rank(ARMOR, 6)  # +30%
	var cleric: Hero = sim.party.heroes[3]
	var rogue: Hero = sim.party.heroes[1]
	cleric.set_training_rank(POWER, 3)  # +15%
	cleric.set_training_rank(TOUGHNESS, 4)  # +20%
	cleric.set_training_rank(QUICKNESS, 10)  # +30%
	rogue.set_training_rank(POWER, 7)  # +35%
	for hero: Hero in sim.party.heroes:
		hero.health = hero.max_health()
		_check_numbers(hero, hero.combatant(), sim.upgrades, "out of a fight")
	assert_gt(cleric.combatant().heal_power, roundi(_base(cleric).heal_power * 1.2), "trained")
	assert_lt(
		cleric.combatant().attack_interval_ticks,
		_base(cleric).attack_interval_ticks,
		"quicker: fewer ticks between attacks"
	)
	assert_true(_step_until(sim, func() -> bool: return sim.expedition.battle != null), "a fight")
	var battle: Battle = sim.expedition.battle
	if battle == null:
		return
	for hero: Hero in sim.party.heroes:
		_check_numbers(hero, battle.combatant(hero.id), sim.upgrades, "in a fight")

	# Toughness raises maximum health at once and leaves health as it is, in a fight...
	var knight: Hero = sim.party.heroes[0]
	var fighter: Combatant = battle.combatant(knight.id)
	fighter.health = fighter.max_health - 30
	var health: int = fighter.health
	var maximum: int = fighter.max_health
	sim.party.gold = 1_000_000
	sim.train_hero(knight.id, TOUGHNESS)
	sim.train_hero(knight.id, POWER)
	sim.step()
	assert_eq(knight.training_rank(TOUGHNESS), 1, "trained mid-fight")
	assert_gt(fighter.max_health, maximum, "the fighter's maximum rose at once")
	assert_eq(fighter.max_health, knight.max_health(), "to the hero's")
	assert_true(fighter.health <= health, "and its health was not raised: %d" % fighter.health)
	_check_numbers(knight, fighter, sim.upgrades, "trained mid-fight")

	# ... and out of one.
	var walker := Simulation.new(9)
	var mage: Hero = walker.party.heroes[2]
	mage.health = 40
	var before: int = mage.max_health()
	walker.party.gold = 1_000_000
	walker.train_hero(mage.id, TOUGHNESS)
	walker.step()
	assert_eq(mage.max_health(), roundi(_base(mage).max_health * 1.05), "maximum +5%")
	assert_gt(mage.max_health(), before)
	assert_eq(mage.health, 40, "health untouched")
	assert_engine_error_count(0)
	assert_push_error_count(0)


# --- R4 ------------------------------------------------------------------------


func test_r4_saved() -> void:
	var sim := Simulation.new(21)
	for i: int in 600:
		sim.step()
	sim.party.heroes[0].set_training_rank(TOUGHNESS, 4)
	sim.party.heroes[1].set_training_rank(POWER, 20)
	sim.party.heroes[3].set_training_rank(QUICKNESS, 7)
	var data: Dictionary = _through_json(sim.to_save())
	var version: int = data["version"]
	assert_eq(version, Simulation.SAVE_VERSION, "the version rose by one (5 since spec 035)")
	assert_eq(Simulation.SAVE_VERSION, 5)
	var loaded: Simulation = Simulation.from_save(data)
	assert_not_null(loaded, "loads: %s" % Simulation.save_problems(data))
	if loaded == null:
		return
	for i: int in sim.party.heroes.size():
		var hero: Hero = sim.party.heroes[i]
		var back: Hero = loaded.party.heroes[i]
		for id: StringName in Content.training_ids():
			assert_eq(back.training_rank(id), hero.training_rank(id), "hero %d %s" % [i, id])
		assert_eq(back.max_health(), hero.max_health(), "hero %d's toughness comes back" % i)
		assert_eq(back.health, back.max_health(), "standing at full")

	# A version 3 save loads with every rank 0, through the upgrade step.
	var old: Dictionary = data.duplicate(true)
	old["version"] = 3
	for saved: Dictionary in old["heroes"]:
		saved.erase("training")
	var upgraded: Dictionary = Simulation.upgrade_save(old)
	var upgraded_version: int = upgraded["version"]
	assert_eq(upgraded_version, Simulation.SAVE_VERSION, "through the upgrade steps")
	var from_old: Simulation = Simulation.from_save(old)
	assert_not_null(from_old, "version 3 loads: %s" % Simulation.save_problems(old))
	if from_old != null:
		for hero: Hero in from_old.party.heroes:
			for id: StringName in Content.training_ids():
				assert_eq(hero.training_rank(id), 0, "hero %d %s at zero" % [hero.id, id])

	# Bad values are refused by name.
	var cases: Array = [
		[1, "power", -1],
		[1, "power", 21],
		[2, "quickness", 11],
		[0, "toughness", 1.5],
		[3, "toughness", "lots"],
		[2, "agility", 1],
	]
	for entry: Array in cases:
		var bad: Dictionary = data.duplicate(true)
		var hero_data: Dictionary = (bad["heroes"] as Array)[entry[0]]
		var ranks: Dictionary = hero_data["training"]
		ranks[entry[1]] = entry[2]
		var problems: PackedStringArray = Simulation.save_problems(bad)
		var where: String = "heroes[%d].training" % entry[0]
		var words: Array[String] = [where, entry[1] as String]
		assert_true(_any_names(problems, words), "%s refused by name: %s" % [entry, problems])
		assert_null(Simulation.from_save(bad), "%s not loaded" % [entry])
	for bad_value: Variant in [null, "lots", [1, 2], 3]:
		var bad: Dictionary = data.duplicate(true)
		var hero_data: Dictionary = (bad["heroes"] as Array)[2]
		if bad_value == null:
			hero_data.erase("training")
		else:
			hero_data["training"] = bad_value
		var problems: PackedStringArray = Simulation.save_problems(bad)
		var words: Array[String] = ["heroes[2].training"]
		assert_true(_any_names(problems, words), "%s refused by name: %s" % [bad_value, problems])
		assert_null(Simulation.from_save(bad))
	assert_engine_error_count(0)
	assert_push_error_count(0)


# --- R5 ------------------------------------------------------------------------


func test_r5_untrained_changes_nothing() -> void:
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
	# A trained hero is part of the state.
	var plain := Simulation.new(7)
	var trained := Simulation.new(7)
	trained.party.heroes[0].set_training_rank(POWER, 1)
	assert_ne(trained.state_hash(), plain.state_hash(), "training changes the hash")


# --- R6 ------------------------------------------------------------------------


func test_r6_training_section() -> void:
	_make_hud(Simulation.new(SEED))
	var sheet: HeroSheet = _hud.hero_sheet
	var rogue: Hero = _sim.party.heroes[1]
	sheet.open(rogue.id)
	sheet.open_page(HeroSheet.Page.TRAINING)  # spec 034: the rows are on the Training tab
	assert_eq(sheet.training_rows.size(), 3, "a row per training")
	var power: HeroSheet.TrainingRow = _row(POWER)
	var toughness: HeroSheet.TrainingRow = _row(TOUGHNESS)
	var quickness: HeroSheet.TrainingRow = _row(QUICKNESS)
	assert_not_null(power, "a power row")
	assert_not_null(quickness, "a quickness row")
	if power == null or toughness == null or quickness == null:
		return
	var power_price: int = rogue.training_cost(POWER)
	var quick_price: int = rogue.training_cost(QUICKNESS)
	assert_lt(power_price, quick_price, "the test needs power cheaper than quickness")
	_sim.party.gold = power_price
	rogue.set_training_rank(TOUGHNESS, 20)
	_hud.advance(0.016)
	assert_eq(sheet.line(&"training_power"), "Power 0/20 +0%% %d" % power_price, "power's row")
	assert_eq(sheet.line(&"training_toughness"), "Toughness 20/20 +100% MAX", "at the maximum")
	assert_eq(
		sheet.line(&"training_quickness"), "Quickness 0/10 +0%% %d" % quick_price, "quickness's row"
	)
	assert_eq(power.price_colour(), ShopRow.PRICE_AFFORDABLE, "affordable: yellow, as the shop's")
	assert_eq(quickness.price_colour(), ShopRow.PRICE_TOO_DEAR, "too dear: dim red")
	assert_true(quickness.buy_button.disabled, "and not pressable")
	assert_true(toughness.max_label.is_visible_in_tree(), "MAX shows at the top rank")
	assert_false(toughness.buy_button.is_visible_in_tree(), "with no button")
	assert_true(power.buy_button.is_visible_in_tree(), "the button shows below it")
	for row: HeroSheet.TrainingRow in sheet.training_rows:
		assert_true(row.is_visible_in_tree(), "%s row shows" % row.id)
		var below: float = sheet.get_global_rect().position.y + HeroSheet.STATS_Y
		assert_gt(row.get_global_rect().position.y, below, "%s row under the stats" % row.id)

	# The button trains; the row flashes; gold and stats follow.
	_sim.party.gold = 10_000
	# Gold set directly is counted up like coins: let the count catch up first.
	_hud.advance(Hud.GOLD_CATCH_UP_SECONDS + 0.1)
	assert_eq(_hud.shown_gold(), 10_000, "the count shows the gold")
	var damage: int = rogue.combatant().damage
	assert_eq(power.flash(), 0.0, "no flash at rest")
	power.buy_button.pressed.emit()
	assert_eq(rogue.training_rank(POWER), 0, "the command waits for the step")
	_frame()
	assert_eq(rogue.training_rank(POWER), 1, "the button trained the shown hero")
	assert_eq(_sim.party.gold, 10_000 - power_price, "for its price")
	assert_eq(_hud.shown_gold(), _sim.party.gold, "the gold count drops at once")
	assert_gt(power.flash(), 0.0, "the row flashes")
	assert_eq(quickness.flash(), 0.0, "only that row")
	assert_eq(sheet.line(&"training_power"), "Power 1/20 +5%% %d" % rogue.training_cost(POWER))
	var trained: int = rogue.combatant().damage
	assert_eq(trained, roundi(_base(rogue).damage * 1.05), "the hero hits harder")
	assert_gte(trained, damage)
	assert_eq(sheet.line(&"stat_damage"), "Damage %d (+5%%)" % trained, "the stat shows it")
	_hud.advance(1.0)
	assert_eq(power.flash(), 0.0, "the flash is brief")

	# The keys train the shown hero, 1 to 3 in row order.
	var health: int = rogue.max_health()
	rogue.set_training_rank(TOUGHNESS, 0)
	var gold: int = _sim.party.gold
	var tough_price: int = rogue.training_cost(TOUGHNESS)
	_key(KEY_2)
	_frame()
	assert_eq(rogue.training_rank(TOUGHNESS), 1, "2 trains toughness")
	assert_eq(_sim.party.gold, gold - tough_price)
	assert_gt(toughness.flash(), 0.0, "and its row flashes")
	assert_eq(
		sheet.line(&"stat_health"), "Health %d (+5%%)" % rogue.max_health(), "health shows it"
	)
	assert_lt(rogue.max_health(), health, "from rank 0 again")
	_key(KEY_3)
	_frame()
	assert_eq(rogue.training_rank(QUICKNESS), 1, "3 trains quickness")
	assert_string_contains(sheet.line(&"stat_attack_speed"), "(+3%)", "attack speed shows it")
	_key(KEY_1)
	_frame()
	assert_eq(rogue.training_rank(POWER), 2, "1 trains power")
	for hero: Hero in _sim.party.heroes:
		if hero != rogue:
			assert_false(hero.is_trained(), "hero %d untouched" % hero.id)

	# A training of another hero does not flash this hero's rows.
	_hud.advance(1.0)
	_sim.train_hero(_sim.party.heroes[0].id, POWER)
	_frame()
	assert_eq(power.flash(), 0.0, "another hero's training flashes nothing here")

	# Unaffordable: the button and the key send nothing.
	_sim.party.gold = 0
	_hud.advance(0.016)
	assert_true(power.buy_button.disabled, "unaffordable")
	power.buy_button.pressed.emit()
	_key(KEY_1)
	_sim.party.gold = 100_000
	_sim.step()
	assert_eq(rogue.training_rank(POWER), 2, "a disabled button and its key send nothing")


# --- R7 ------------------------------------------------------------------------


func test_r7_bonus_is_visible() -> void:
	_make_hud(Simulation.new(SEED))
	var sheet: HeroSheet = _hud.hero_sheet
	_sim.upgrades.set_rank(BLADES, 2)  # +10%
	_sim.upgrades.set_rank(ARMOR, 2)  # +10%
	var cleric: Hero = _sim.party.heroes[3]
	cleric.set_training_rank(POWER, 2)  # +10%
	cleric.set_training_rank(TOUGHNESS, 4)  # +20%
	cleric.set_training_rank(QUICKNESS, 5)  # +15%
	sheet.open(cleric.id)
	_hud.advance(0.016)
	var fighter: Combatant = cleric.combatant()
	assert_eq(sheet.line(&"stat_damage"), "Damage %d (+21%%)" % fighter.damage, "1.1 x 1.1")
	assert_eq(sheet.line(&"stat_healing"), "Healing %d (+21%%)" % fighter.heal_power)
	assert_eq(sheet.line(&"stat_health"), "Health %d (+32%%)" % cleric.max_health(), "1.1 x 1.2")
	var speed: float = 1.15 / cleric.def().attack_interval
	assert_eq(sheet.line(&"stat_attack_speed"), "Attack speed %.1f/s (+15%%)" % speed)
	for key: StringName in [&"stat_damage", &"stat_healing", &"stat_health", &"stat_attack_speed"]:
		assert_eq(sheet.bonus_colour(key), Palette.color(&"green"), "%s bonus in green" % key)
	assert_false(sheet.line(&"stat_armor").contains("+"), "armor has no bonus")

	# Another hero shows the upgrades alone.
	var knight: Hero = _sim.party.heroes[0]
	sheet.open(knight.id)
	_hud.advance(0.016)
	assert_eq(sheet.line(&"stat_damage"), "Damage %d (+10%%)" % knight.combatant().damage)
	assert_false(sheet.line(&"stat_attack_speed").contains("+"), "untrained: no speed bonus")


# --- R8 ------------------------------------------------------------------------


func _collect(node: Node, into: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Label or child is HudButton:
			into.append(child)
		_collect(child, into)


func test_r8_sheet_still_fits() -> void:
	_make_hud(Simulation.new(SEED))
	var sheet: HeroSheet = _hud.hero_sheet
	sheet.open_page(HeroSheet.Page.TRAINING)  # spec 034: the rows are on the Training tab
	_sim.party.gold = 1_000_000_000
	for id: StringName in [BLADES, ARMOR]:
		_sim.upgrades.set_rank(id, 20)
	for i: int in _sim.party.heroes.size():
		var hero: Hero = _sim.party.heroes[i]
		hero.gain_xp(Hero.xp_for_level(99))
		# A mix of maxed rows and long prices.
		hero.set_training_rank(Content.training_ids()[i % 3], 99)
		hero.set_training_rank(POWER, 19 - i)
	var frames_top: float = SCREEN.y
	for frame: HeroFrame in _hud.frames:
		frames_top = minf(frames_top, frame.get_global_rect().position.y)
	for hero: Hero in _sim.party.heroes:
		sheet.open(hero.id)
		_hud.advance(0.5)
		var rect: Rect2 = sheet.get_global_rect()
		var what: String = "%s %s" % [hero.class_id, rect]
		assert_gte(rect.position.y, TOP_BAND, "%s: below the top band" % what)
		assert_lte(rect.end.y, frames_top - TICKER_STRIP, "%s: 12 px above the frames" % what)
		assert_gte(rect.position.x, 0.0, "%s: on screen" % what)
		assert_lte(rect.end.x, SCREEN.x, "%s: on screen" % what)
		var controls: Array[Control] = []
		_collect(sheet, controls)
		var shown: Array[Control] = []
		for control: Control in controls:
			var label: Label = control as Label
			if control.is_visible_in_tree() and (label == null or not label.text.is_empty()):
				shown.append(control)
		var in_rows: int = 0
		for control: Control in shown:
			var where: String = (
				"%s %s %s" % [hero.class_id, _text(control), control.get_global_rect()]
			)
			assert_true(rect.encloses(control.get_global_rect()), "%s inside the sheet" % where)
			if control is Label:
				var font_size: int = control.get_theme_font_size(&"font_size")
				assert_eq(
					font_size % PixelText.SIZE, 0, "%s: the pixel font at a whole size" % where
				)
			for row: HeroSheet.TrainingRow in sheet.training_rows:
				if row.is_ancestor_of(control):
					in_rows += 1
			for other: Control in shown:
				if (
					other != control
					and other.get_global_rect().intersects(control.get_global_rect())
				):
					fail_test("%s overlaps %s" % [where, _text(other)])
		assert_gte(in_rows, 3 * 5, "%s: every training row's text and button shows" % what)


func _text(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is HudButton:
		return "[%s]" % (control as HudButton).text
	return control.name


# --- R9 ------------------------------------------------------------------------


func test_r9_number_keys() -> void:
	_make_hud(Simulation.new(SEED))
	var sheet: HeroSheet = _hud.hero_sheet
	var rogue: Hero = _sim.party.heroes[1]
	_sim.party.gold = 100_000

	_hud.shop.open()
	_hud.advance(0.016)
	_key(KEY_1)
	_frame()
	var first: StringName = Content.upgrade_ids()[0]
	assert_eq(_sim.upgrades.rank(first), 1, "1 with the shop open buys")
	for hero: Hero in _sim.party.heroes:
		assert_false(hero.is_trained(), "and trains nobody")

	sheet.open(rogue.id)
	sheet.open_page(HeroSheet.Page.TRAINING)  # spec 034: 1 to 3 train on the Training tab
	assert_false(_hud.shop.is_open(), "the sheet and the shop are never open together")
	_hud.advance(0.016)
	_key(KEY_1)
	_frame()
	assert_eq(rogue.training_rank(POWER), 1, "1 with the sheet open trains")
	assert_eq(_sim.upgrades.rank(first), 1, "and buys nothing")
	_key(KEY_4)
	_key(KEY_5)
	_frame()
	for id: StringName in Content.upgrade_ids():
		if id != first:
			assert_eq(_sim.upgrades.rank(id), 0, "%s not bought from the sheet" % id)
	_hud.shop.open()
	assert_false(sheet.is_open(), "opening the shop closes the sheet")

	_hud.shop.close()
	sheet.close()
	var gold: int = _sim.party.gold
	_key(KEY_1)
	_key(KEY_2)
	_key(KEY_3)
	_frame()
	assert_eq(_sim.party.gold, gold, "with neither open, the keys do nothing")
	assert_eq(_sim.upgrades.rank(first), 1)
	assert_eq(rogue.training_rank(POWER), 1)


# --- R10 -----------------------------------------------------------------------


func test_r10_auto_buy_leaves_training() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_buy(true)
	var trained: int = 0
	for i: int in 6000:
		sim.party.gold = 1_000_000
		sim.step()
		trained += _events_of(sim.drain_events(), SimEvent.Kind.HERO_TRAINED).size()
	assert_true(sim.auto_buy, "auto-buy was on")
	assert_true(sim.upgrades.any(), "and bought upgrades")
	assert_eq(trained, 0, "no training event")
	for hero: Hero in sim.party.heroes:
		assert_false(hero.is_trained(), "hero %d untrained" % hero.id)


# --- R11 -----------------------------------------------------------------------


func test_r11_it_is_sensible() -> void:
	var cheapest: int = -1
	for id: StringName in Content.upgrade_ids():
		var first_rank: int = Content.upgrade(id).cost_at(0)
		if cheapest < 0 or first_rank < cheapest:
			cheapest = first_rank
	for id: StringName in Content.training_ids():
		var price: int = Content.training(id).cost_at(0)
		assert_between(price, cheapest, 2 * cheapest, "%s first rank against %d" % [id, cheapest])

	var sim := Simulation.new(SEED)
	sim.expedition.stable_seconds = 120.0
	var rogue: Hero = sim.party.heroes[1]
	for i: int in HOUR_TICKS:
		var price: int = rogue.training_cost(POWER)
		if price > 0 and price <= sim.party.gold:
			sim.train_hero(rogue.id, POWER)
		sim.step()
		sim.drain_events()
	var twin := Hero.new(rogue.id, rogue.def())
	twin.upgrades = sim.upgrades
	twin.level = rogue.level
	var trained: int = rogue.combatant().damage
	var plain: int = twin.combatant().damage
	gut.p(
		(
			"an hour: rogue level %d, power rank %d, %d damage against %d untrained"
			% [rogue.level, rogue.training_rank(POWER), trained, plain]
		)
	)
	assert_gte(
		float(trained), 1.25 * plain, "at least 25%% more per hit: %d vs %d" % [trained, plain]
	)
