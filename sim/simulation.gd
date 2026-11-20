class_name Simulation
extends RefCounted
## The whole game state, advanced one fixed tick at a time.
##
## Every later system lives in here. The simulation never asks what time it
## is: something outside calls [method step], and each call is one tick.

## How many ticks make one second of game time.
const TICKS_PER_SECOND: int = 10
## The length of one tick in microseconds of game time.
const TICK_USEC: int = 1_000_000 / TICKS_PER_SECOND
## The format of [method to_save]. Raising it means adding a step to [method upgrade_save].
const SAVE_VERSION: int = 8
## Auto-buy buys at most one upgrade per this many seconds of game time.
const AUTO_BUY_SECONDS: float = 1.0
## A fresh start costs this much gold per level of the hero.
const _RESET_GOLD_PER_LEVEL: int = 100
## The kinds of talent command waiting in [member _pending_talents].
const _TAKE: int = 0
const _PARAGON: int = 1
const _RESET: int = 2

## Ticks stepped since the simulation was created. Read-only outside this class.
var tick: int:
	get:
		return _tick
	set(_value):
		push_error("Simulation.tick is read-only; call step() to advance it")

## The endless levels of the area the party is in, made from the seed (each area has its own).
## Read-only.
var labyrinth: Labyrinth:
	get:
		return expedition.labyrinth
## True while the camp buys upgrades by itself. Read-only outside this class: call
## [method set_auto_buy].
var auto_buy: bool:
	get:
		return _auto_buy
	set(_value):
		push_error("Simulation.auto_buy is read-only; call set_auto_buy()")

## The heroes and their gold.
var party: Party
## Where the party is and what it is doing.
var expedition: Expedition
## The camp upgrades bought: the party's own, shared with every hero.
var upgrades: Upgrades

var _seed: int
var _tick: int = 0
var _events: Array[SimEvent] = []
## Upgrades asked for by [method buy_upgrade], bought in order on the next step.
var _pending_buys: Array[StringName] = []
## Talent commands asked for by [method take_talent], [method spend_paragon] and
## [method reset_talents], each [kind, hero id, what], applied in order on the next step.
var _pending_talents: Array[Array] = []
var _auto_buy: bool = false
## The switch asked for by [method set_auto_buy], applied on the next step: 1 on, 0 off, -1 none.
var _pending_auto_buy: int = -1


func _init(seed_value: int) -> void:
	_seed = seed_value
	party = Party.new()
	upgrades = party.upgrades
	var first := Labyrinth.new(seed_value)
	expedition = Expedition.new(first, party, SimRng.new(seed_value).fork("expedition"))


## Advances the simulation by exactly one tick.
func step() -> void:
	_tick += 1
	if _pending_auto_buy >= 0:
		_auto_buy = _pending_auto_buy == 1
		_pending_auto_buy = -1
	_apply_buys()
	_apply_talents()
	_apply_auto_buy()
	expedition.step(_tick)
	_events.append_array(expedition.drain_events())


## Sets the depth the party heads for (1 or more), from the next tick.
func set_target_depth(depth: int) -> void:
	expedition.command_target_depth(depth)


## Turns auto-push (going one level deeper once the target depth is stable) on or off.
func set_auto_push(enabled: bool) -> void:
	expedition.auto_push = enabled


## Sets the party's pace: how hurt it may be before it rests after a fight. It applies
## from the next step and reports [constant SimEvent.Kind.ORDER_CHANGED]; an unknown value is
## ignored.
func set_pace(pace: Expedition.Pace) -> void:
	expedition.command_pace(pace)


## Sets the party's guardian order: under Hold it never enters a living guardian's
## chamber. It applies from the next step and reports [constant SimEvent.Kind.ORDER_CHANGED]; an
## unknown value is ignored.
func set_guardian_order(order: Expedition.GuardianOrder) -> void:
	expedition.command_guardian_order(order)


## Sends the party to [param stage] of area [param area_id]. If the area is open, the party
## finishes any fight it is in, leaves, spends [constant AreaTravel.JOURNEY_SECONDS] on the way
## and arrives alive, its health unchanged, at the start of that stage (or of the area's safe
## stage, if the stage asked for is beyond it), with the stage asked for as its target. A command
## for an area that is not open does nothing.
func set_destination(area_id: StringName, stage: int) -> void:
	expedition.travel.ask(area_id, stage)


## True if the party may be sent to area [param area_id]: it is open from the start, or its
## opener's guardian has been beaten.
func is_area_open(area_id: StringName) -> bool:
	return expedition.travel.open.has(area_id)


## The safe stage (x) and furthest stage (y) of area [param area_id]; Vector2i(1, 0) for an area
## the party has never been in.
func area_progress(area_id: StringName) -> Vector2i:
	return expedition.travel.progress(expedition, area_id)


## True once area [param area_id]'s guardian has been beaten at least once; a save keeps it.
func is_guardian_beaten(area_id: StringName) -> bool:
	return expedition.travel.guardians_beaten.has(area_id)


## True once the party has held resource [param id] (the journal notes the first).
## It needs no saved field: a resource is only ever spent on upgrade ranks, so the party has held it
## when it holds some now or owns a rank of an upgrade that cost it.
func has_gathered(id: StringName) -> bool:
	if party.resource(id) > 0:
		return true
	for upgrade_id: StringName in Content.upgrade_ids():
		var def: UpgradeDef = Content.upgrade(upgrade_id)
		if def.resource == id and upgrades.rank(upgrade_id) > def.resource_from_rank:
			return true
	return false


## Asks to buy the next rank of upgrade [param id] at the next step. It is bought
## then if the id is known, the rank is below the maximum and the party has the
## gold and the resource it costs; otherwise nothing happens.
func buy_upgrade(id: StringName) -> void:
	_pending_buys.append(id)


## Asks hero [param hero_id] to spend a talent point on node [param ability_id] at the next step.
## It is taken then if the hero has an unspent point and the node is next in its tree
## ([method Hero.can_take]), with [constant SimEvent.Kind.TALENT_TAKEN]; the hero fights with it
## from its next fight on. Otherwise nothing happens.
func take_talent(hero_id: int, ability_id: StringName) -> void:
	_pending_talents.append([_TAKE, hero_id, ability_id])


## Asks hero [param hero_id] to put a paragon point into [param stat] at the next step.
## It goes in then if the hero has an unspent one, with [constant SimEvent.Kind.PARAGON_SPENT]; a
## hero in a fight fights on with the new numbers. Otherwise nothing happens.
func spend_paragon(hero_id: int, stat: TrainingDef.Stat) -> void:
	_pending_talents.append([_PARAGON, hero_id, stat])


## Asks for a fresh start for hero [param hero_id] at the next step: for
## [method reset_price] in gold, every node it took is given back as an unspent
## talent point and both paths are open again, with [constant SimEvent.Kind.TALENTS_RESET].
## Paragon points stay. Nothing happens during a fight, without the gold, or with no node taken.
func reset_talents(hero_id: int) -> void:
	_pending_talents.append([_RESET, hero_id, 0])


## The gold a fresh start for [param hero] costs.
static func reset_price(hero: Hero) -> int:
	return _RESET_GOLD_PER_LEVEL * hero.level


## Turns auto-buy on or off, from the next step. While on, the camp buys the cheapest
## upgrade it can pay both prices of (earlier in the shop on a tie) at most once every
## [constant AUTO_BUY_SECONDS], exactly as [method buy_upgrade] would.
func set_auto_buy(enabled: bool) -> void:
	_pending_auto_buy = 1 if enabled else 0


func _apply_buys() -> void:
	var buys: Array[StringName] = _pending_buys
	_pending_buys = []
	for id: StringName in buys:
		_buy(id)


func _apply_talents() -> void:
	var asked: Array[Array] = _pending_talents
	_pending_talents = []
	for entry: Array in asked:
		var kind: int = entry[0]
		var hero_id: int = entry[1]
		var hero: Hero = party.hero(hero_id)
		if hero == null:
			continue
		match kind:
			_TAKE:
				var ability_id: StringName = entry[2]
				_take(hero, ability_id)
			_PARAGON:
				var stat: int = entry[2]
				_paragon(hero, stat as TrainingDef.Stat)
			_RESET:
				_reset(hero)


func _take(hero: Hero, ability_id: StringName) -> void:
	if not hero.take_talent(ability_id):
		return
	var event := SimEvent.new(SimEvent.Kind.TALENT_TAKEN, _tick, hero.id, -1, hero.talent_points())
	event.ability_id = ability_id
	_events.append(event)


## Puts a paragon point of [param hero] into [param stat]. A hero in a fight fights on with the
## new numbers; more maximum health leaves the health it has as it is.
func _paragon(hero: Hero, stat: TrainingDef.Stat) -> void:
	if not hero.spend_paragon(stat):
		return
	var fight: Battle = expedition.battle
	var fighter: Combatant = fight.combatant(hero.id) if fight != null else null
	if fighter != null:
		var grown: Combatant = hero.combatant()
		fighter.max_health = grown.max_health
		fighter.damage = grown.damage
		fighter.heal_power = grown.heal_power
		fighter.attack_interval_ticks = grown.attack_interval_ticks
	var position: int = Content.training_ids().find(TalentRules.stat_def(stat).id)
	var rank: int = hero.paragon_rank(stat)
	_events.append(SimEvent.new(SimEvent.Kind.PARAGON_SPENT, _tick, hero.id, position, rank))


func _reset(hero: Hero) -> void:
	var price: int = reset_price(hero)
	if expedition.battle != null or hero.talents().is_empty() or price > party.gold:
		return
	party.gold -= price
	hero.reset_talents()
	_events.append(SimEvent.new(SimEvent.Kind.TALENTS_RESET, _tick, hero.id, -1, price))


## Auto-buy looks for a purchase on the ticks that start a whole [constant AUTO_BUY_SECONDS], so
## there is never more than one in any such span, and nothing about it needs saving.
func _apply_auto_buy() -> void:
	if not _auto_buy:
		return
	var every: int = Combatant.seconds_to_ticks(AUTO_BUY_SECONDS)
	if _tick % every != 0:
		return
	var id: StringName = upgrades.cheapest_affordable(party)
	if id != &"":
		_buy(id)


## Buys the next rank of [param id] if it is known, below the maximum and affordable: takes
## the gold and the resource, raises the rank and the heroes' health, and reports
## [constant SimEvent.Kind.UPGRADE_BOUGHT].
func _buy(id: StringName) -> void:
	if not upgrades.can_pay(id, party):
		return
	party.gold -= upgrades.cost(id)
	var resource_id: StringName = Content.upgrade(id).resource
	party.set_resource(resource_id, party.resource(resource_id) - upgrades.resource_cost(id))
	var before: Dictionary[int, int] = {}
	for hero: Hero in party.heroes:
		before[hero.id] = hero.max_health()
	upgrades.set_rank(id, upgrades.rank(id) + 1)
	_raise_health(before)
	var position: int = Content.upgrade_ids().find(id)
	var event := SimEvent.new(SimEvent.Kind.UPGRADE_BOUGHT, _tick, position, -1, upgrades.rank(id))
	_events.append(event)


## Heals every standing hero (and its fighter, mid-battle) by the maximum health
## it gained since [param before], its maximum health by hero id.
func _raise_health(before: Dictionary[int, int]) -> void:
	for hero: Hero in party.heroes:
		var gain: int = hero.max_health() - before[hero.id]
		if gain == 0:
			continue
		if hero.is_alive():
			hero.health += gain
		var fight: Battle = expedition.battle
		var fighter: Combatant = fight.combatant(hero.id) if fight != null else null
		if fighter != null:
			fighter.max_health += gain
			if fighter.is_alive():
				fighter.health += gain


## Every event since the last call, oldest first, each stamped with its tick.
func drain_events() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## Game time elapsed, in seconds.
func seconds() -> float:
	return float(_tick) / TICKS_PER_SECOND


## A number that is equal for two simulations in the same state: the seed, the
## tick, the party, the expedition and the battle in progress.
func state_hash() -> int:
	var parts: Array = [_seed, _tick, party.hash_parts(), expedition.hash_parts()]
	# Only when one is bought, to keep the hash of a run without upgrades.
	if upgrades.any():
		parts.append(upgrades.hash_parts())
	# Only when on, to keep the hash of a run without auto-buy.
	if _auto_buy:
		parts.append("auto_buy")
	return hash(parts)


# --- Saving progress -----------------------------------------------------------


## The party's progress as plain values (numbers, strings, booleans, arrays and
## dictionaries), for a save file. Not the exact moment: see [method from_save].
func to_save() -> Dictionary:
	var heroes: Array = []
	for hero: Hero in party.heroes:
		var saved_hero: Dictionary = {
			"class": String(hero.class_id),
			"level": hero.level,
			"xp": hero.xp,
		}
		TalentSave.write(hero, saved_hero)
		heroes.append(saved_hero)
	var ranks: Dictionary = {}
	for id: StringName in Content.upgrade_ids():
		ranks[String(id)] = upgrades.rank(id)
	var saved: Dictionary = {
		"version": SAVE_VERSION,
		"seed": _seed,
		"tick": _tick,
		"gold": party.gold,
		"heroes": heroes,
		"last_stable_depth": expedition.last_stable_depth,
		"deepest_depth": expedition.deepest_depth,
		"target_depth": expedition.target_depth,
		"auto_push": expedition.auto_push,
		"upgrades": ranks,
		"auto_buy": _auto_buy,
		"pace": PartyOrders.PACE_SAVED[expedition.pace],
		"guardian_order": PartyOrders.GUARDIAN_SAVED[expedition.guardian_order],
	}
	AreaSave.write(expedition, saved)
	ResourceSave.write(self, saved)
	return saved


## A simulation carrying on from saved progress, or null if [param data] has
## problems ([method save_problems] says which). Every hero stands up at the level its XP earns,
## alive and full, where revival would put the party: at its last stable depth, travelling,
## with every chamber freshly populated and no events pending.
static func from_save(data: Dictionary) -> Simulation:
	if not save_problems(data).is_empty():
		return null
	var current: Dictionary = upgrade_save(data)
	var sim := Simulation.new(SaveChecks.whole(current["seed"]))
	sim._tick = SaveChecks.whole(current["tick"])
	sim.party.gold = SaveChecks.whole(current["gold"])
	var ranks: Dictionary = current["upgrades"]
	for key: Variant in ranks:
		var id_text: String = key
		sim.upgrades.set_rank(StringName(id_text), SaveChecks.whole(ranks[key]))
	var heroes: Array[Hero] = []
	var saved_heroes: Array = current["heroes"]
	for i: int in saved_heroes.size():
		var saved: Dictionary = saved_heroes[i]
		var class_text: String = saved["class"]
		var hero := Hero.new(i + 1, Content.hero_class(StringName(class_text)))
		hero.upgrades = sim.upgrades
		hero.level = SaveChecks.whole(saved["level"])
		hero.xp = SaveChecks.whole(saved["xp"])
		# A saved hero's XP may pay for more levels than its saved level: take them now, silently,
		# so the hero is what its XP earns. Health is filled below.
		hero.gain_xp(0)
		TalentSave.read(hero, saved)
		hero.health = hero.max_health()
		heroes.append(hero)
	sim.party.heroes = heroes
	var auto_push: bool = current["auto_push"]
	var stable: int = SaveChecks.whole(current["last_stable_depth"])
	var deepest: int = SaveChecks.whole(current["deepest_depth"])
	var target: int = SaveChecks.whole(current["target_depth"])
	AreaSave.read(sim, current)
	ResourceSave.read(sim, current)
	Arrival.from_save(sim.expedition, sim._tick, stable, deepest, target, auto_push)
	var auto_buy_on: bool = current["auto_buy"]
	sim._auto_buy = auto_buy_on
	var pace_text: String = current["pace"]
	var order_text: String = current["guardian_order"]
	sim.expedition.pace = PartyOrders.PACE_SAVED.find(pace_text) as Expedition.Pace
	sim.expedition.guardian_order = (
		PartyOrders.GUARDIAN_SAVED.find(order_text) as Expedition.GuardianOrder
	)
	return sim


## Every reason [param data] cannot be loaded, one line each naming the field;
## empty when it can. Never raises an error, whatever the dictionary holds.
static func save_problems(data: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if not SaveChecks.is_whole(data.get("version")):
		problems.append("version: missing or not a whole number")
		return problems
	var current: Dictionary = upgrade_save(data)
	var version: int = SaveChecks.whole(current.get("version"))
	if version != SAVE_VERSION:
		problems.append("version: unknown version %d" % version)
		return problems
	if not SaveChecks.is_whole(current.get("seed")):
		problems.append("seed: missing or not a whole number")
	SaveChecks.check_whole(problems, current, "tick", 0)
	SaveChecks.check_whole(problems, current, "gold", 0)
	for field: String in ["last_stable_depth", "deepest_depth", "target_depth"]:
		SaveChecks.check_whole(problems, current, field, 1)
	if typeof(current.get("auto_push")) != TYPE_BOOL:
		problems.append("auto_push: missing or not true or false")
	if typeof(current.get("auto_buy")) != TYPE_BOOL:
		problems.append("auto_buy: missing or not true or false")
	_check_name(problems, current, "pace", PartyOrders.PACE_SAVED)
	_check_name(problems, current, "guardian_order", PartyOrders.GUARDIAN_SAVED)
	var heroes: Variant = current.get("heroes")
	if not (heroes is Array) or (heroes as Array).is_empty():
		problems.append("heroes: missing, not a list or empty")
	else:
		var list: Array = heroes
		for i: int in list.size():
			_check_hero(problems, list[i], "heroes[%d]" % i)
	var stable: Variant = current.get("last_stable_depth")
	var deepest: Variant = current.get("deepest_depth")
	if (
		SaveChecks.is_whole(stable)
		and SaveChecks.is_whole(deepest)
		and SaveChecks.whole(stable) > SaveChecks.whole(deepest)
	):
		problems.append("last_stable_depth: deeper than deepest_depth")
	_check_upgrades(problems, current.get("upgrades"))
	AreaSave.check(problems, current)
	ResourceSave.check(problems, current)
	return problems


## [param data] brought forward to [constant SAVE_VERSION], one version step at a
## time, as a copy. Data of an unknown or unreadable version comes back unchanged
## for [method save_problems] to refuse. A later format adds a step here.
static func upgrade_save(data: Dictionary) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	if not SaveChecks.is_whole(current.get("version")):
		return current
	# Each step turns version n into n + 1.
	if SaveChecks.whole(current["version"]) == 1:
		current = _save_1_to_2(current)
	if SaveChecks.whole(current["version"]) == 2:
		current = _save_2_to_3(current)
	if SaveChecks.whole(current["version"]) == 3:
		current = _save_3_to_4(current)
	if SaveChecks.whole(current["version"]) == 4:
		current = _save_4_to_5(current)
	if SaveChecks.whole(current["version"]) == 5:
		current = AreaSave.upgrade_5_to_6(current)
	if SaveChecks.whole(current["version"]) == 6:
		current = TalentSave.upgrade_6_to_7(current)
	if SaveChecks.whole(current["version"]) == 7:
		current = ResourceSave.upgrade_7_to_8(current)
	return current


## Version 1 had no upgrades: version 2 adds them, every rank 0.
static func _save_1_to_2(data: Dictionary) -> Dictionary:
	data["version"] = 2
	data["upgrades"] = {}
	return data


## Version 2 had no auto-buy: version 3 adds the switch, off.
static func _save_2_to_3(data: Dictionary) -> Dictionary:
	data["version"] = 3
	data["auto_buy"] = false
	return data


## Version 3 had no hero training: version 4 gives each saved hero its training, every rank 0.
## A hero that is not a dictionary is left for [method save_problems] to refuse.
static func _save_3_to_4(data: Dictionary) -> Dictionary:
	data["version"] = 4
	var heroes: Variant = data.get("heroes")
	if heroes is Array:
		for saved: Variant in heroes as Array:
			if saved is Dictionary:
				(saved as Dictionary)["training"] = {}
	return data


## Version 4 had no orders: version 5 adds them at their defaults, Steady and Challenge.
static func _save_4_to_5(data: Dictionary) -> Dictionary:
	data["version"] = 5
	data["pace"] = PartyOrders.PACE_SAVED[Expedition.Pace.STEADY]
	data["guardian_order"] = PartyOrders.GUARDIAN_SAVED[Expedition.GuardianOrder.CHALLENGE]
	return data


## Adds a problem unless [param data][[param field]] is one of [param names], naming the field.
static func _check_name(
	problems: PackedStringArray, data: Dictionary, field: String, names: Array[String]
) -> void:
	var value: Variant = data.get(field)
	if typeof(value) != TYPE_STRING or not names.has(value as String):
		problems.append(
			"%s: missing or not one of %s" % [field, ", ".join(PackedStringArray(names))]
		)


## Adds a problem for each saved upgrade rank that is not a known upgrade's
## whole rank from 0 to its maximum. Upgrades left out are rank 0.
static func _check_upgrades(problems: PackedStringArray, value: Variant) -> void:
	if not (value is Dictionary):
		problems.append("upgrades: missing or not a dictionary of ranks")
		return
	var ranks: Dictionary = value
	for key: Variant in ranks:
		if typeof(key) != TYPE_STRING:
			problems.append("upgrades: key %s is not an upgrade id" % str(key))
			continue
		var id_text: String = key
		var def: UpgradeDef = Content.upgrade(StringName(id_text))
		var where: String = "upgrades.%s" % id_text
		if def == null:
			problems.append("%s: unknown upgrade '%s'" % [where, id_text])
			continue
		var rank_value: Variant = ranks[key]
		if not SaveChecks.is_whole(rank_value):
			problems.append("%s: rank missing or not a whole number" % where)
		elif SaveChecks.whole(rank_value) < 0:
			problems.append("%s: rank %d is below 0" % [where, SaveChecks.whole(rank_value)])
		elif SaveChecks.whole(rank_value) > def.max_rank:
			problems.append(
				(
					"%s: rank %d is above the maximum %d"
					% [where, SaveChecks.whole(rank_value), def.max_rank]
				)
			)


## Adds a problem for each thing wrong with one saved hero, [param where] in the list.
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
