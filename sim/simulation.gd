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
const SAVE_VERSION: int = 1
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
## The heroes and their gold.
var party: Party
## Where the party is and what it is doing.
var expedition: Expedition

var _seed: int
var _tick: int = 0
var _events: Array[SimEvent] = []


func _init(seed_value: int) -> void:
	_seed = seed_value
	labyrinth = Labyrinth.new(seed_value)
	party = Party.new()
	expedition = Expedition.new(labyrinth, party, SimRng.new(seed_value).fork("expedition"))


## Advances the simulation by exactly one tick.
func step() -> void:
	_tick += 1
	expedition.step(_tick)
	_events.append_array(expedition.drain_events())


## Sets the depth the party heads for (1 or more), from the next tick.
func set_target_depth(depth: int) -> void:
	expedition.command_target_depth(depth)


## Turns auto-push (going one level deeper once the target depth is stable) on or off.
func set_auto_push(enabled: bool) -> void:
	expedition.auto_push = enabled


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
	return hash([_seed, _tick, party.hash_parts(), expedition.hash_parts()])


# --- Saving progress -----------------------------------------------------------


## The party's progress as plain values (numbers, strings, booleans, arrays and
## dictionaries), for a save file. Not the exact moment: see [method from_save].
func to_save() -> Dictionary:
	var heroes: Array = []
	for hero: Hero in party.heroes:
		heroes.append({"class": String(hero.class_id), "level": hero.level, "xp": hero.xp})
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
	var heroes: Array[Hero] = []
	var saved_heroes: Array = current["heroes"]
	for i: int in saved_heroes.size():
		var saved: Dictionary = saved_heroes[i]
		var class_text: String = saved["class"]
		var hero := Hero.new(i + 1, Content.hero_class(StringName(class_text)))
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
	return problems


## [param data] brought forward to [constant SAVE_VERSION], one version step at a
## time, as a copy. Data of an unknown or unreadable version comes back unchanged
## for [method save_problems] to refuse. A later format adds a step here.
static func upgrade_save(data: Dictionary) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	if not _is_whole(current.get("version")):
		return current
	# Each step turns version n into n + 1, e.g. `if version == 1: current = _save_1_to_2(current)`.
	return current


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
