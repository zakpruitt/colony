class_name Content
extends RefCounted
## Loads and caches the definitions under res://data.
##
## Each definition is a .tres file named after its id. The folders are read
## once, on the first request.

const HEROES_DIR: String = "res://data/heroes"
const MONSTERS_DIR: String = "res://data/monsters"

static var _heroes: Dictionary[StringName, HeroClassDef] = {}
static var _monsters: Dictionary[StringName, MonsterDef] = {}
static var _loaded: bool = false


## The hero class with this id, or null if there is none.
static func hero_class(id: StringName) -> HeroClassDef:
	_load()
	return _heroes.get(id, null)


## The monster with this id, or null if there is none.
static func monster(id: StringName) -> MonsterDef:
	_load()
	return _monsters.get(id, null)


## Every hero class id, sorted.
static func hero_class_ids() -> Array[StringName]:
	_load()
	return _sorted(_heroes.keys())


## Every monster id, sorted.
static func monster_ids() -> Array[StringName]:
	_load()
	return _sorted(_monsters.keys())


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for resource: Resource in _resources_in(HEROES_DIR):
		var hero: HeroClassDef = resource as HeroClassDef
		if hero == null:
			push_error("Content: %s is not a HeroClassDef" % resource.resource_path)
			continue
		_heroes[hero.id] = hero
	for resource: Resource in _resources_in(MONSTERS_DIR):
		var def: MonsterDef = resource as MonsterDef
		if def == null:
			push_error("Content: %s is not a MonsterDef" % resource.resource_path)
			continue
		_monsters[def.id] = def


static func _resources_in(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	for file: String in ResourceLoader.list_directory(dir):
		if file.get_extension() != "tres":
			continue
		var resource: Resource = load(dir.path_join(file))
		if resource != null:
			found.append(resource)
	return found


static func _sorted(keys: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: StringName in keys:
		ids.append(key)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids
