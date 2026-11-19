class_name Party
extends RefCounted
## The heroes on the expedition, and the gold and resources they carry.

## The classes a new party is made of, in formation order (tank first). Hero ids are 1, 2, ...
const STARTING_CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]

var heroes: Array[Hero] = []  # in formation order: tank first
var gold: int = 0
## The camp upgrades bought, shared by every hero.
var upgrades: Upgrades = Upgrades.new()

## How many of each resource the party holds, by [ResourceDef] id; none are left out at 0.
var _resources: Dictionary[StringName, int] = {}


## A party of level-1 heroes of the starting classes, at full health.
func _init() -> void:
	for i: int in STARTING_CLASSES.size():
		var def: HeroClassDef = Content.hero_class(STARTING_CLASSES[i])
		if def == null:
			push_error("Party: no hero class %s" % STARTING_CLASSES[i])
			continue
		var hero_made := Hero.new(i + 1, def)
		hero_made.upgrades = upgrades
		heroes.append(hero_made)


## The hero with this id, or null.
func hero(id: int) -> Hero:
	for h: Hero in heroes:
		if h.id == id:
			return h
	return null


## How many of resource [param id] the party holds; 0 for one it has none of, or an unknown id.
func resource(id: StringName) -> int:
	return _resources.get(id, 0)


## Sets the count of resource [param id] (gathering, paying, loading a save); never below 0.
func set_resource(id: StringName, count: int) -> void:
	if count <= 0:
		_resources.erase(id)
	else:
		_resources[id] = count


## True while the party holds any resource.
func has_resources() -> bool:
	return not _resources.is_empty()


## True while at least one hero is alive.
func any_alive() -> bool:
	for h: Hero in heroes:
		if h.is_alive():
			return true
	return false


## The living hero who would do a quest needing this microskill, or null.
## With several able, the one with the lowest id.
func hero_with_microskill(id: StringName) -> Hero:
	var found: Hero = null
	for h: Hero in heroes:
		if h.is_alive() and h.has_microskill(id) and (found == null or h.id < found.id):
			found = h
	return found


## The party's state as plain values, for the simulation's state hash.
func hash_parts() -> Array:
	var parts: Array = [gold]
	for h: Hero in heroes:
		var hero_parts: Array = [h.id, h.class_id, h.level, h.xp, h.health]
		# Only when grown, to keep the hash of a hero with no talents or paragon points.
		if h.has_grown():
			var ranks: Array = []
			for stat: int in TrainingDef.Stat.values():
				ranks.append(h.paragon_rank(stat as TrainingDef.Stat))
			hero_parts.append([h.talents(), ranks])
		parts.append(hero_parts)
	# Only when held, to keep the hash of a party with no resources.
	if has_resources():
		var held: Array = []
		for id: StringName in Content.resource_ids():
			held.append(resource(id))
		parts.append(["resources", held])
	return parts
