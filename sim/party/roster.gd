class_name Roster
extends RefCounted
## The colony's commands about who is in it: recruiting a hero whose class's artifact was found,
## by paying its request, and choosing which four go down. A field of [Simulation], kept apart
## from it so it has room.
##
## The colony holds one hero of each class, since every sentence in the game names a hero by its
## class. A recruit joins the bench; a swap is made only while the party rests at camp, where
## everyone heals anyway, so a swap gives no free heal and no hero leaves part way through a fight,
## a climb, a quest, a journey or a side path it opened.

## How many heroes go down.
const FIELD_SIZE: int = 4

var _party: Party
var _expedition: Expedition
## Classes asked for by [method recruit], recruited in order on the next step.
var _recruits: Array[StringName] = []
## Swaps asked for by [method swap] and not yet made, in order: (bench id, field id).
var _swaps: Array[Vector2i] = []
## What [method apply] returns on the many steps with nothing to do: shared and read-only, so a
## quiet step allocates nothing.
var _none: Array[SimEvent] = []


func _init(party: Party, expedition: Expedition) -> void:
	_party = party
	_expedition = expedition
	_none.make_read_only()


## Asks to recruit the hero of [param class_id] on the next step. It joins the bench then if the
## class waits at camp ([method is_waiting]) and the party can pay both prices of its request,
## which are paid, with [constant SimEvent.Kind.HERO_RECRUITED]; otherwise nothing happens.
func recruit(class_id: StringName) -> void:
	_recruits.append(class_id)


## Asks for benched hero [param bench_id] to go down in place of [param field_id], on the first
## step on which the party rests at camp. Ids that are not a benched hero and one going down
## do nothing.
func swap(bench_id: int, field_id: int) -> void:
	if _is_benched(bench_id) and _is_fielded(field_id):
		_swaps.append(Vector2i(bench_id, field_id))


## The swaps asked for and not yet made, in order: (bench id, field id).
func waiting() -> Array[Vector2i]:
	return _swaps.duplicate()


## Its artifact found and no hero of it in the colony.
func is_waiting(class_id: StringName) -> bool:
	return _party.artifacts.has(class_id) and not _party.has_class(class_id)


## Waiting at camp, and both prices payable now.
func can_recruit(class_id: StringName) -> bool:
	return (
		Content.hero_class(class_id) != null
		and is_waiting(class_id)
		and lacks(class_id) == Vector2i.ZERO
	)


## What [param class_id]'s request still lacks of what the party holds now: x the gold short,
## y the resource short; 0 for a price paid in full or a resource not asked for.
func lacks(class_id: StringName) -> Vector2i:
	var def: HeroClassDef = Content.hero_class(class_id)
	if def == null:
		return Vector2i.ZERO
	var resource_short: int = 0
	if def.recruit_resource != &"":
		resource_short = def.recruit_resource_count - _party.resource(def.recruit_resource)
	return Vector2i(maxi(def.recruit_gold - _party.gold, 0), maxi(resource_short, 0))


## Whether a swap waiting names hero [param hero_id], coming down or going to camp. Reads the
## waiting swaps without copying them, for a view that asks every frame.
func swap_waits(hero_id: int) -> bool:
	for asked: Vector2i in _swaps:
		if asked.x == hero_id or asked.y == hero_id:
			return true
	return false


## The level a recruit would arrive at now: the lowest of the heroes going down.
func recruit_level() -> int:
	var lowest: int = 0
	for hero: Hero in _party.heroes:
		if lowest == 0 or hero.level < lowest:
			lowest = hero.level
	return maxi(lowest, 1)


## Every class waiting at camp, in [method Content.hero_class_ids] order.
func waiting_at_camp() -> Array[StringName]:
	var found: Array[StringName] = []
	for class_id: StringName in Content.hero_class_ids():
		if is_waiting(class_id):
			found.append(class_id)
	return found


## How many classes not in [constant Party.STARTING_CLASSES] have no artifact found yet.
func still_hidden() -> int:
	var hidden: int = 0
	for class_id: StringName in Content.hero_class_ids():
		if not Party.STARTING_CLASSES.has(class_id) and not _party.artifacts.has(class_id):
			hidden += 1
	return hidden


## Called by [method Simulation.step] after the talent commands: recruits what was asked for and,
## while the party rests, makes the swaps waiting. Returns the events, stamped [param tick]; on a
## step with nothing done, a shared read-only empty list.
func apply(tick: int) -> Array[SimEvent]:
	var resting: bool = _expedition.state == Expedition.State.RESTING
	if _recruits.is_empty() and (_swaps.is_empty() or not resting):
		return _none
	var events: Array[SimEvent] = []
	if not _recruits.is_empty():
		var asked: Array[StringName] = _recruits
		_recruits = []
		for class_id: StringName in asked:
			_recruit(class_id, tick, events)
	if _swaps.is_empty() or not resting:
		return events
	var swaps: Array[Vector2i] = _swaps
	_swaps = []
	for swap_asked: Vector2i in swaps:
		# One swapped already may have moved either hero: such a swap is dropped.
		if _is_benched(swap_asked.x) and _is_fielded(swap_asked.y):
			_field(swap_asked.x, swap_asked.y, tick, events)
	return events


func _recruit(class_id: StringName, tick: int, events: Array[SimEvent]) -> void:
	if not can_recruit(class_id):
		return
	var def: HeroClassDef = Content.hero_class(class_id)
	_party.gold -= def.recruit_gold
	if def.recruit_resource != &"":
		var held: int = _party.resource(def.recruit_resource)
		_party.set_resource(def.recruit_resource, held - def.recruit_resource_count)
	var newest: int = 0
	for hero: Hero in _party.roster():
		newest = maxi(newest, hero.id)
	var level: int = recruit_level()
	var made := Hero.new(newest + 1, def)
	made.upgrades = _party.upgrades
	made.level = level
	made.xp = Hero.xp_for_level(level)
	made.health = made.max_health()
	_party.bench.append(made)
	var place: int = Content.hero_class_ids().find(class_id)
	events.append(
		SimEvent.new(SimEvent.Kind.HERO_RECRUITED, tick, made.id, place, def.recruit_gold)
	)


## Benched hero [param bench_id] goes down at full health and [param field_id] is benched; the
## four stand by role, then by id.
func _field(bench_id: int, field_id: int, tick: int, events: Array[SimEvent]) -> void:
	var coming: Hero = _party.hero(bench_id)
	var leaving: Hero = _party.hero(field_id)
	_party.bench.erase(coming)
	_party.heroes.erase(leaving)
	coming.health = coming.max_health()
	_party.heroes.append(coming)
	_party.heroes.sort_custom(_before)
	_party.bench.append(leaving)
	_party.bench.sort_custom(func(a: Hero, b: Hero) -> bool: return a.id < b.id)
	events.append(SimEvent.new(SimEvent.Kind.HERO_FIELDED, tick, bench_id, field_id))


func _is_benched(id: int) -> bool:
	for hero: Hero in _party.bench:
		if hero.id == id:
			return true
	return false


func _is_fielded(id: int) -> bool:
	for hero: Hero in _party.heroes:
		if hero.id == id:
			return true
	return false


## The formation's order: by [enum HeroClassDef.Role], then by id.
static func _before(a: Hero, b: Hero) -> bool:
	if a.def().role != b.def().role:
		return a.def().role < b.def().role
	return a.id < b.id
