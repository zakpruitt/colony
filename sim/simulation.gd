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
const SAVE_VERSION: int = 3
## Auto-buy buys at most one upgrade per this many seconds of game time.
const AUTO_BUY_SECONDS: float = 1.0
## The largest whole number a JSON float holds exactly (2^53).
const _LARGEST_WHOLE: int = 9_007_199_254_740_992

## Ticks stepped since the simulation was created. Read-only outside this class.
var tick: int:
	get:
		return _tick
	set(_value):
		push_error("Simulation.tick is read-only; call step() to advance it")

## The endless levels, made from the seed.
var labyrinth: Labyrinth
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
var _auto_buy: bool = false
## The switch asked for by [method set_auto_buy], applied on the next step: 1 on, 0 off, -1 none.
var _pending_auto_buy: int = -1


func _init(seed_value: int) -> void:
	_seed = seed_value
	labyrinth = Labyrinth.new(seed_value)
	party = Party.new()
	upgrades = party.upgrades
	expedition = Expedition.new(labyrinth, party, SimRng.new(seed_value).fork("expedition"))


## Advances the simulation by exactly one tick.
func step() -> void:
	_tick += 1
	if _pending_auto_buy >= 0:
		_auto_buy = _pending_auto_buy == 1
		_pending_auto_buy = -1
	_apply_buys()
	_apply_auto_buy()
	expedition.step(_tick)
	_events.append_array(expedition.drain_events())


## Sets the depth the party heads for (1 or more), from the next tick.
func set_target_depth(depth: int) -> void:
	expedition.command_target_depth(depth)


## Turns auto-push (going one level deeper once the target depth is stable) on or off.
func set_auto_push(enabled: bool) -> void:
	expedition.auto_push = enabled


## Asks to buy the next rank of upgrade [param id] at the next step. It is bought
## then if the id is known, the rank is below the maximum and the party has the
## gold; otherwise nothing happens.
func buy_upgrade(id: StringName) -> void:
	_pending_buys.append(id)


## Turns auto-buy on or off, from the next step. While on, the camp buys the cheapest
## affordable upgrade (earlier in the shop on a tie) at most once every
## [constant AUTO_BUY_SECONDS], exactly as [method buy_upgrade] would.
func set_auto_buy(enabled: bool) -> void:
	_pending_auto_buy = 1 if enabled else 0


func _apply_buys() -> void:
	var buys: Array[StringName] = _pending_buys
	_pending_buys = []
	for id: StringName in buys:
		_buy(id)


## Auto-buy looks for a purchase on the ticks that start a whole [constant AUTO_BUY_SECONDS], so
## there is never more than one in any such span, and nothing about it needs saving.
func _apply_auto_buy() -> void:
	if not _auto_buy:
		return
	var every: int = maxi(roundi(AUTO_BUY_SECONDS * TICKS_PER_SECOND), 1)
	if _tick % every != 0:
		return
	var id: StringName = upgrades.cheapest_affordable(party.gold)
	if id != &"":
		_buy(id)


## Buys the next rank of [param id] if it is known, below the maximum and affordable: takes
## the gold, raises the rank and the heroes' health, and reports
## [constant SimEvent.Kind.UPGRADE_BOUGHT].
func _buy(id: StringName) -> void:
	var price: int = upgrades.cost(id)
	if price < 0 or price > party.gold:
		return
	party.gold -= price
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
	# Without upgrades the hash is what it was before they existed.
	if upgrades.any():
		parts.append(upgrades.hash_parts())
	# Likewise auto-buy: only a simulation with it on hashes the switch.
	if _auto_buy:
		parts.append("auto_buy")
	return hash(parts)


# --- Saving progress -----------------------------------------------------------


## The party's progress as plain values (numbers, strings, booleans, arrays and
## dictionaries), for a save file. Not the exact moment: see [method from_save].
func to_save() -> Dictionary:
	var heroes: Array = []
	for hero: Hero in party.heroes:
		heroes.append({"class": String(hero.class_id), "level": hero.level, "xp": hero.xp})
	var ranks: Dictionary = {}
	for id: StringName in Content.upgrade_ids():
		ranks[String(id)] = upgrades.rank(id)
	return {
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
	}


## A simulation carrying on from saved progress, or null if [param data] has
## problems ([method save_problems] says which). Every hero stands up alive and
## full where revival would put the party: at its last stable depth, travelling,
## with every chamber freshly populated and no events pending.
static func from_save(data: Dictionary) -> Simulation:
	if not save_problems(data).is_empty():
		return null
	var current: Dictionary = upgrade_save(data)
	var sim := Simulation.new(_whole(current["seed"]))
	sim._tick = _whole(current["tick"])
	sim.party.gold = _whole(current["gold"])
	var ranks: Dictionary = current["upgrades"]
	for key: Variant in ranks:
		var id_text: String = key
		sim.upgrades.set_rank(StringName(id_text), _whole(ranks[key]))
	var heroes: Array[Hero] = []
	var saved_heroes: Array = current["heroes"]
	for i: int in saved_heroes.size():
		var saved: Dictionary = saved_heroes[i]
		var class_text: String = saved["class"]
		var hero := Hero.new(i + 1, Content.hero_class(StringName(class_text)))
		hero.upgrades = sim.upgrades
		hero.level = _whole(saved["level"])
		hero.xp = _whole(saved["xp"])
		hero.health = hero.max_health()
		heroes.append(hero)
	sim.party.heroes = heroes
	var auto_push: bool = current["auto_push"]
	var stable: int = _whole(current["last_stable_depth"])
	var deepest: int = _whole(current["deepest_depth"])
	var target: int = _whole(current["target_depth"])
	sim.expedition.arrive_from_save(sim._tick, stable, deepest, target, auto_push)
	var auto_buy_on: bool = current["auto_buy"]
	sim._auto_buy = auto_buy_on
	return sim


## Every reason [param data] cannot be loaded, one line each naming the field;
## empty when it can. Never raises an error, whatever the dictionary holds.
static func save_problems(data: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if not _is_whole(data.get("version")):
		problems.append("version: missing or not a whole number")
		return problems
	var current: Dictionary = upgrade_save(data)
	var version: int = _whole(current.get("version"))
	if version != SAVE_VERSION:
		problems.append("version: unknown version %d" % version)
		return problems
	if not _is_whole(current.get("seed")):
		problems.append("seed: missing or not a whole number")
	_check_whole(problems, current, "tick", 0)
	_check_whole(problems, current, "gold", 0)
	for field: String in ["last_stable_depth", "deepest_depth", "target_depth"]:
		_check_whole(problems, current, field, 1)
	if typeof(current.get("auto_push")) != TYPE_BOOL:
		problems.append("auto_push: missing or not true or false")
	if typeof(current.get("auto_buy")) != TYPE_BOOL:
		problems.append("auto_buy: missing or not true or false")
	var heroes: Variant = current.get("heroes")
	if not (heroes is Array) or (heroes as Array).is_empty():
		problems.append("heroes: missing, not a list or empty")
	else:
		var list: Array = heroes
		for i: int in list.size():
			_check_hero(problems, list[i], "heroes[%d]" % i)
	var stable: Variant = current.get("last_stable_depth")
	var deepest: Variant = current.get("deepest_depth")
	if _is_whole(stable) and _is_whole(deepest) and _whole(stable) > _whole(deepest):
		problems.append("last_stable_depth: deeper than deepest_depth")
	_check_upgrades(problems, current.get("upgrades"))
	return problems


## [param data] brought forward to [constant SAVE_VERSION], one version step at a
## time, as a copy. Data of an unknown or unreadable version comes back unchanged
## for [method save_problems] to refuse. A later format adds a step here.
static func upgrade_save(data: Dictionary) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	if not _is_whole(current.get("version")):
		return current
	# Each step turns version n into n + 1.
	if _whole(current["version"]) == 1:
		current = _save_1_to_2(current)
	if _whole(current["version"]) == 2:
		current = _save_2_to_3(current)
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
		if not _is_whole(rank_value):
			problems.append("%s: rank missing or not a whole number" % where)
		elif _whole(rank_value) < 0:
			problems.append("%s: rank %d is below 0" % [where, _whole(rank_value)])
		elif _whole(rank_value) > def.max_rank:
			problems.append(
				"%s: rank %d is above the maximum %d" % [where, _whole(rank_value), def.max_rank]
			)


## True for an int, or a float that is a whole number an int holds exactly.
static func _is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = value
	return is_finite(number) and number == floorf(number) and absf(number) <= _LARGEST_WHOLE


## [param value] as an int; only for values [method _is_whole] accepts.
static func _whole(value: Variant) -> int:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return int(number)
	var whole: int = value
	return whole


## Adds a problem unless [param data][[param field]] is a whole number of at least
## [param least]. The problem names the field after [param where].
static func _check_whole(
	problems: PackedStringArray, data: Dictionary, field: String, least: int, where: String = ""
) -> void:
	var value: Variant = data.get(field)
	if not _is_whole(value):
		problems.append("%s%s: missing or not a whole number" % [where, field])
	elif _whole(value) < least:
		problems.append("%s%s: below %d" % [where, field, least])


## Adds a problem for each thing wrong with one saved hero, [param where] in the list.
static func _check_hero(problems: PackedStringArray, value: Variant, where: String) -> void:
	if not (value is Dictionary):
		problems.append("%s: not a hero (class, level, xp)" % where)
		return
	var saved: Dictionary = value
	var class_text: Variant = saved.get("class")
	if typeof(class_text) != TYPE_STRING:
		problems.append("%s.class: missing or not text" % where)
	elif Content.hero_class(StringName(class_text as String)) == null:
		problems.append("%s.class: unknown hero class '%s'" % [where, class_text])
	_check_whole(problems, saved, "level", 1, where + ".")
	_check_whole(problems, saved, "xp", 0, where + ".")
