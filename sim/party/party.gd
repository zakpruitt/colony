class_name Party
extends RefCounted
## The heroes on the expedition and the gold they carry.

## The classes a new party is made of, in formation order (tank first). Hero ids are 1, 2, ...
const STARTING_CLASSES: Array[StringName] = [&"knight", &"rogue", &"mage", &"cleric"]

var heroes: Array[Hero] = []  # in formation order: tank first
var gold: int = 0
## The camp upgrades bought, shared by every hero.
var upgrades: Upgrades = Upgrades.new()


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


## True while at least one hero is alive.
func any_alive() -> bool:
	for h: Hero in heroes:
		if h.is_alive():
			return true
	return false


## The party's state as plain values, for the simulation's state hash.
func hash_parts() -> Array:
	var parts: Array = [gold]
	for h: Hero in heroes:
		var hero_parts: Array = [h.id, h.class_id, h.level, h.xp, h.health]
		# Untrained, a hero hashes as it did before training existed (spec 029).
		if h.is_trained():
			var ranks: Array = []
			for training_id: StringName in Content.training_ids():
				ranks.append(h.training_rank(training_id))
			hero_parts.append(ranks)
		parts.append(hero_parts)
	return parts
