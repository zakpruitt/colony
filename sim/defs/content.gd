class_name Content
extends RefCounted
## Loads and caches the definitions under res://data.
##
## Each kind of content is a row of [constant KINDS]: its folder, its definition class, the
## property a definition is found by and how its ids are listed. The folders are read once, on the
## first request, and each kind's id list is built then and never changes: callers get the same
## read-only array every time, and copy it to change it.

## How a kind's ids are listed: by id; by the definitions' [code]order[/code], then id; or by the
## order of the first area that gives each (resources), then id.
enum Order { BY_ID, BY_ORDER, BY_AREA }
## The kinds, each the index of its row in [constant KINDS].
enum Kind {
	HEROES,
	MONSTERS,
	UPGRADES,
	TRAINING,
	MICROSKILLS,
	SIDE_QUESTS,
	AREAS,
	ABILITIES,
	TALENTS,
	RESOURCES,
}

const DATA_DIR: String = "res://data"
const ABILITIES_DIR: String = "res://data/abilities"

## One row a kind, in [enum Kind] order. [code]key[/code] is the property a definition is found
## by; a second definition with a key already taken is refused, so a class has one talent tree.
## Areas come before resources, whose order they decide.
const KINDS: Array[Dictionary] = [
	{
		"folder": "heroes",
		"def": preload("res://sim/defs/hero_class_def.gd"),
		"key": &"id",
		"order": Order.BY_ID
	},
	{
		"folder": "monsters",
		"def": preload("res://sim/defs/monster_def.gd"),
		"key": &"id",
		"order": Order.BY_ID
	},
	{
		"folder": "upgrades",
		"def": preload("res://sim/defs/upgrade_def.gd"),
		"key": &"id",
		"order": Order.BY_ORDER
	},
	{
		"folder": "training",
		"def": preload("res://sim/defs/training_def.gd"),
		"key": &"id",
		"order": Order.BY_ORDER
	},
	{
		"folder": "microskills",
		"def": preload("res://sim/defs/microskill_def.gd"),
		"key": &"id",
		"order": Order.BY_ID
	},
	{
		"folder": "sidequests",
		"def": preload("res://sim/defs/side_quest_def.gd"),
		"key": &"id",
		"order": Order.BY_ID
	},
	{
		"folder": "areas",
		"def": preload("res://sim/defs/area_def.gd"),
		"key": &"id",
		"order": Order.BY_ORDER
	},
	{
		"folder": "abilities",
		"def": preload("res://sim/defs/ability_def.gd"),
		"key": &"id",
		"order": Order.BY_ID
	},
	{
		"folder": "talents",
		"def": preload("res://sim/defs/talent_tree_def.gd"),
		"key": &"class_id",
		"order": Order.BY_ID
	},
	{
		"folder": "resources",
		"def": preload("res://sim/defs/resource_def.gd"),
		"key": &"id",
		"order": Order.BY_AREA
	},
]

## Per kind, its definitions by key.
static var _defs: Array[Dictionary] = []
## Per kind, its keys in list order: a read-only Array[StringName].
static var _ids: Array[Array] = []
static var _loaded: bool = false


## The hero class with this id, or null if there is none.
static func hero_class(id: StringName) -> HeroClassDef:
	return _find(Kind.HEROES, id)


## The monster with this id, or null if there is none.
static func monster(id: StringName) -> MonsterDef:
	return _find(Kind.MONSTERS, id)


## Every hero class id, sorted.
static func hero_class_ids() -> Array[StringName]:
	return _ids_of(Kind.HEROES)


## Every monster id, sorted.
static func monster_ids() -> Array[StringName]:
	return _ids_of(Kind.MONSTERS)


## The camp upgrade with this id, or null if there is none.
static func upgrade(id: StringName) -> UpgradeDef:
	return _find(Kind.UPGRADES, id)


## Every camp upgrade id, in shop order (by [member UpgradeDef.order], then id).
static func upgrade_ids() -> Array[StringName]:
	return _ids_of(Kind.UPGRADES)


## The paragon stat with this id, or null if there is none.
static func training(id: StringName) -> TrainingDef:
	return _find(Kind.TRAINING, id)


## Every training id, in sheet order (by [member TrainingDef.order], then id).
static func training_ids() -> Array[StringName]:
	return _ids_of(Kind.TRAINING)


## The microskill with this id, or null if there is none.
static func microskill(id: StringName) -> MicroskillDef:
	return _find(Kind.MICROSKILLS, id)


## Every microskill id, sorted.
static func microskill_ids() -> Array[StringName]:
	return _ids_of(Kind.MICROSKILLS)


## The side quest with this id, or null if there is none.
static func side_quest(id: StringName) -> SideQuestDef:
	return _find(Kind.SIDE_QUESTS, id)


## Every side quest id, sorted.
static func side_quest_ids() -> Array[StringName]:
	return _ids_of(Kind.SIDE_QUESTS)


## The area with this id, or null if there is none.
static func area(id: StringName) -> AreaDef:
	return _find(Kind.AREAS, id)


## Every area id, by [member AreaDef.order], then id.
static func area_ids() -> Array[StringName]:
	return _ids_of(Kind.AREAS)


## The ability with this id, or null if there is none.
static func ability(id: StringName) -> AbilityDef:
	return _find(Kind.ABILITIES, id)


## Every ability id, sorted.
static func ability_ids() -> Array[StringName]:
	return _ids_of(Kind.ABILITIES)


## The talent tree of hero class [param class_id], or null if it has none.
static func talent_tree(class_id: StringName) -> TalentTreeDef:
	return _find(Kind.TALENTS, class_id)


## The resource with this id, or null if there is none.
static func resource_def(id: StringName) -> ResourceDef:
	return _find(Kind.RESOURCES, id)


## Every resource id, in the order of the areas that give them, then by id.
static func resource_ids() -> Array[StringName]:
	return _ids_of(Kind.RESOURCES)


## The first area, in area order, that gives resource [param id]; &"" when none does.
static func area_of_resource(id: StringName) -> StringName:
	for area_id: StringName in area_ids():
		if area(area_id).resource == id:
			return area_id
	return &""


## The definition of [param kind] found by [param key], or null. Asked thousands of times a
## second, so it does no more than look up.
static func _find(kind: Kind, key: StringName) -> Variant:
	if not _loaded:
		_load()
	return _defs[kind].get(key)


static func _ids_of(kind: Kind) -> Array[StringName]:
	if not _loaded:
		_load()
	return _ids[kind]


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for kind: int in KINDS.size():
		var row: Dictionary = KINDS[kind]
		var found: Dictionary = {}
		_defs.append(found)
		var def_class: Script = row["def"]
		var key_name: StringName = row["key"]
		for resource: Resource in _resources_in(DATA_DIR.path_join(row["folder"] as String)):
			if not is_instance_of(resource, def_class):
				push_error("Content: %s is not %s" % [resource.resource_path, _named(def_class)])
				continue
			var key: StringName = resource.get(key_name)
			if found.has(key):
				var known: Resource = found[key]
				push_error(
					(
						"Content: %s is a second %s for %s, after %s"
						% [
							resource.resource_path,
							def_class.get_global_name(),
							key,
							known.resource_path
						]
					)
				)
				continue
			found[key] = resource
		var ids: Array[StringName] = _listed(found, row["order"] as Order)
		ids.make_read_only()
		_ids.append(ids)


## The keys of [param found] by [param order], then by id.
static func _listed(found: Dictionary, order: Order) -> Array[StringName]:
	var rank: Dictionary[StringName, int] = {}
	for key: StringName in found:
		match order:
			Order.BY_ORDER:
				rank[key] = (found[key] as Resource).get(&"order")
			Order.BY_AREA:
				rank[key] = _area_order_of(key)
			_:
				rank[key] = 0
	var ids: Array[StringName] = []
	ids.assign(found.keys())
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			if rank[a] != rank[b]:
				return rank[a] < rank[b]
			return String(a) < String(b)
	)
	return ids


## The order of the first area giving resource [param id]; a large number when none does.
static func _area_order_of(id: StringName) -> int:
	var best: int = 1 << 30
	for area_def: AreaDef in _defs[Kind.AREAS].values():
		if area_def.resource == id:
			best = mini(best, area_def.order)
	return best


## The class name with its article: "a MonsterDef", "an AreaDef".
static func _named(def_class: Script) -> String:
	var class_text: String = def_class.get_global_name()
	return ("an " if "AEIOU".contains(class_text.left(1)) else "a ") + class_text


static func _resources_in(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	for file: String in ResourceLoader.list_directory(dir):
		if file.get_extension() != "tres":
			continue
		var resource: Resource = load(dir.path_join(file))
		if resource != null:
			found.append(resource)
	return found
