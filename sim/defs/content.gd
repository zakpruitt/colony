class_name Content
extends RefCounted
## Loads and caches the definitions under res://data.
##
## Each definition is a .tres file named after its id. The folders are read
## once, on the first request.

const HEROES_DIR: String = "res://data/heroes"
const MONSTERS_DIR: String = "res://data/monsters"
const UPGRADES_DIR: String = "res://data/upgrades"
const TRAINING_DIR: String = "res://data/training"
const MICROSKILLS_DIR: String = "res://data/microskills"
const SIDE_QUESTS_DIR: String = "res://data/sidequests"
const AREAS_DIR: String = "res://data/areas"
const ABILITIES_DIR: String = "res://data/abilities"
const TALENTS_DIR: String = "res://data/talents"

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
	for resource: Resource in _resources_in(UPGRADES_DIR):
		var upgrade_def: UpgradeDef = resource as UpgradeDef
		if upgrade_def == null:
			push_error("Content: %s is not an UpgradeDef" % resource.resource_path)
			continue
		_upgrades[upgrade_def.id] = upgrade_def
	_upgrade_ids = _sorted(_upgrades.keys())
	for resource: Resource in _resources_in(MICROSKILLS_DIR):
		var skill: MicroskillDef = resource as MicroskillDef
		if skill == null:
			push_error("Content: %s is not a MicroskillDef" % resource.resource_path)
			continue
		_microskills[skill.id] = skill
	for resource: Resource in _resources_in(SIDE_QUESTS_DIR):
		var quest: SideQuestDef = resource as SideQuestDef
		if quest == null:
			push_error("Content: %s is not a SideQuestDef" % resource.resource_path)
			continue
		_side_quests[quest.id] = quest
	_upgrade_ids.sort_custom(_before_in_shop)
	for resource: Resource in _resources_in(TRAINING_DIR):
		var training_def: TrainingDef = resource as TrainingDef
		if training_def == null:
			push_error("Content: %s is not a TrainingDef" % resource.resource_path)
			continue
		_training[training_def.id] = training_def
	_training_ids = _sorted(_training.keys())
	_training_ids.sort_custom(_before_on_sheet)
	for resource: Resource in _resources_in(AREAS_DIR):
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
	for resource: Resource in _resources_in(TALENTS_DIR):
		var tree: TalentTreeDef = resource as TalentTreeDef
		if tree == null:
			push_error("Content: %s is not a TalentTreeDef" % resource.resource_path)
			continue
		_talent_trees[tree.class_id] = tree


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


static func _before_in_order(a: StringName, b: StringName) -> bool:
	var first: AreaDef = _areas[a]
	var second: AreaDef = _areas[b]
	if first.order != second.order:
		return first.order < second.order
	return String(a) < String(b)
