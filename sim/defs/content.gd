class_name Content
extends RefCounted
## Loads and caches the definitions under res://data.
##
## Each definition is a .tres file named after its id. The folders are read
## once, on the first request.

const _HEROES_DIR: String = "res://data/heroes"
const _MONSTERS_DIR: String = "res://data/monsters"
const _UPGRADES_DIR: String = "res://data/upgrades"
const _TRAINING_DIR: String = "res://data/training"
const _MICROSKILLS_DIR: String = "res://data/microskills"
const _SIDE_QUESTS_DIR: String = "res://data/sidequests"
const _AREAS_DIR: String = "res://data/areas"
const ABILITIES_DIR: String = "res://data/abilities"
const _TALENTS_DIR: String = "res://data/talents"
const _RESOURCES_DIR: String = "res://data/resources"

static var _heroes: Dictionary[StringName, HeroClassDef] = {}
static var _monsters: Dictionary[StringName, MonsterDef] = {}
static var _upgrades: Dictionary[StringName, UpgradeDef] = {}
static var _upgrade_ids: Array[StringName] = []
static var _training: Dictionary[StringName, TrainingDef] = {}
static var _training_ids: Array[StringName] = []
static var _microskills: Dictionary[StringName, MicroskillDef] = {}
static var _side_quests: Dictionary[StringName, SideQuestDef] = {}
static var _areas: Dictionary[StringName, AreaDef] = {}
static var _area_ids: Array[StringName] = []
static var _abilities: Dictionary[StringName, AbilityDef] = {}
static var _talent_trees: Dictionary[StringName, TalentTreeDef] = {}
static var _resources: Dictionary[StringName, ResourceDef] = {}
static var _resource_ids: Array[StringName] = []
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


## The camp upgrade with this id, or null if there is none.
static func upgrade(id: StringName) -> UpgradeDef:
	_load()
	return _upgrades.get(id, null)


## Every camp upgrade id, in shop order (by [member UpgradeDef.order], then id).
static func upgrade_ids() -> Array[StringName]:
	_load()
	return _upgrade_ids.duplicate()


## The hero training with this id (spec 029), or null if there is none.
static func training(id: StringName) -> TrainingDef:
	_load()
	return _training.get(id, null)


## Every training id, in sheet order (by [member TrainingDef.order], then id).
static func training_ids() -> Array[StringName]:
	_load()
	return _training_ids.duplicate()


## The microskill with this id, or null if there is none.
static func microskill(id: StringName) -> MicroskillDef:
	_load()
	return _microskills.get(id, null)


## Every microskill id, sorted.
static func microskill_ids() -> Array[StringName]:
	_load()
	return _sorted(_microskills.keys())


## The side quest with this id, or null if there is none.
static func side_quest(id: StringName) -> SideQuestDef:
	_load()
	return _side_quests.get(id, null)


## Every side quest id, sorted.
static func side_quest_ids() -> Array[StringName]:
	_load()
	return _sorted(_side_quests.keys())


## The area with this id (spec 049), or null if there is none.
static func area(id: StringName) -> AreaDef:
	_load()
	return _areas.get(id, null)


## Every area id, by [member AreaDef.order], then id.
static func area_ids() -> Array[StringName]:
	_load()
	return _area_ids.duplicate()


## The ability with this id (spec 050), or null if there is none.
static func ability(id: StringName) -> AbilityDef:
	_load()
	return _abilities.get(id, null)


## Every ability id, sorted.
static func ability_ids() -> Array[StringName]:
	_load()
	return _sorted(_abilities.keys())


## The talent tree of hero class [param class_id] (spec 051), or null if it has none.
static func talent_tree(class_id: StringName) -> TalentTreeDef:
	_load()
	return _talent_trees.get(class_id, null)


## The resource with this id (spec 052), or null if there is none.
static func resource_def(id: StringName) -> ResourceDef:
	_load()
	return _resources.get(id, null)


## Every resource id, in the order of the areas that give them, then by id.
static func resource_ids() -> Array[StringName]:
	_load()
	return _resource_ids.duplicate()


## The first area, in area order, that gives resource [param id]; &"" when none does.
static func area_of_resource(id: StringName) -> StringName:
	for area_id: StringName in area_ids():
		if _areas[area_id].resource == id:
			return area_id
	return &""


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for resource: Resource in _resources_in(_HEROES_DIR):
		var hero: HeroClassDef = resource as HeroClassDef
		if hero == null:
			push_error("Content: %s is not a HeroClassDef" % resource.resource_path)
			continue
		_heroes[hero.id] = hero
	for resource: Resource in _resources_in(_MONSTERS_DIR):
		var def: MonsterDef = resource as MonsterDef
		if def == null:
			push_error("Content: %s is not a MonsterDef" % resource.resource_path)
			continue
		_monsters[def.id] = def
	for resource: Resource in _resources_in(_UPGRADES_DIR):
		var upgrade_def: UpgradeDef = resource as UpgradeDef
		if upgrade_def == null:
			push_error("Content: %s is not an UpgradeDef" % resource.resource_path)
			continue
		_upgrades[upgrade_def.id] = upgrade_def
	_upgrade_ids = _sorted(_upgrades.keys())
	for resource: Resource in _resources_in(_MICROSKILLS_DIR):
		var skill: MicroskillDef = resource as MicroskillDef
		if skill == null:
			push_error("Content: %s is not a MicroskillDef" % resource.resource_path)
			continue
		_microskills[skill.id] = skill
	for resource: Resource in _resources_in(_SIDE_QUESTS_DIR):
		var quest: SideQuestDef = resource as SideQuestDef
		if quest == null:
			push_error("Content: %s is not a SideQuestDef" % resource.resource_path)
			continue
		_side_quests[quest.id] = quest
	_upgrade_ids.sort_custom(_before_in_shop)
	for resource: Resource in _resources_in(_TRAINING_DIR):
		var training_def: TrainingDef = resource as TrainingDef
		if training_def == null:
			push_error("Content: %s is not a TrainingDef" % resource.resource_path)
			continue
		_training[training_def.id] = training_def
	_training_ids = _sorted(_training.keys())
	_training_ids.sort_custom(_before_on_sheet)
	for resource: Resource in _resources_in(_AREAS_DIR):
		var area_def: AreaDef = resource as AreaDef
		if area_def == null:
			push_error("Content: %s is not an AreaDef" % resource.resource_path)
			continue
		_areas[area_def.id] = area_def
	_area_ids = _sorted(_areas.keys())
	_area_ids.sort_custom(_before_in_order)
	for resource: Resource in _resources_in(ABILITIES_DIR):
		var ability_def: AbilityDef = resource as AbilityDef
		if ability_def == null:
			push_error("Content: %s is not an AbilityDef" % resource.resource_path)
			continue
		_abilities[ability_def.id] = ability_def
	for resource: Resource in _resources_in(_TALENTS_DIR):
		var tree: TalentTreeDef = resource as TalentTreeDef
		if tree == null:
			push_error("Content: %s is not a TalentTreeDef" % resource.resource_path)
			continue
		var known: TalentTreeDef = _talent_trees.get(tree.class_id, null)
		if known != null:
			# One tree a class; the second is refused here and by its own validate().
			push_error(
				(
					"Content: %s is a second tree for %s, after %s"
					% [tree.resource_path, tree.class_id, known.resource_path]
				)
			)
			continue
		_talent_trees[tree.class_id] = tree
	for resource: Resource in _resources_in(_RESOURCES_DIR):
		var resource_made: ResourceDef = resource as ResourceDef
		if resource_made == null:
			push_error("Content: %s is not a ResourceDef" % resource.resource_path)
			continue
		_resources[resource_made.id] = resource_made
	_resource_ids = _sorted(_resources.keys())
	_resource_ids.sort_custom(_before_by_area)


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


static func _before_in_shop(a: StringName, b: StringName) -> bool:
	var first: UpgradeDef = _upgrades[a]
	var second: UpgradeDef = _upgrades[b]
	if first.order != second.order:
		return first.order < second.order
	return String(a) < String(b)


static func _before_on_sheet(a: StringName, b: StringName) -> bool:
	var first: TrainingDef = _training[a]
	var second: TrainingDef = _training[b]
	if first.order != second.order:
		return first.order < second.order
	return String(a) < String(b)


static func _before_by_area(a: StringName, b: StringName) -> bool:
	var first: int = _area_order_of(a)
	var second: int = _area_order_of(b)
	if first != second:
		return first < second
	return String(a) < String(b)


## The order of the first area giving resource [param id]; a large number when none does.
static func _area_order_of(id: StringName) -> int:
	var best: int = 1 << 30
	for area_def: AreaDef in _areas.values():
		if area_def.resource == id:
			best = mini(best, area_def.order)
	return best


static func _before_in_order(a: StringName, b: StringName) -> bool:
	var first: AreaDef = _areas[a]
	var second: AreaDef = _areas[b]
	if first.order != second.order:
		return first.order < second.order
	return String(a) < String(b)
