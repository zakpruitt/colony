class_name HeroClassDef
extends ContentDef
## A hero class: the numbers a level-1 hero of this class fights with, and how
## they grow per level. One .tres file per class under res://data/heroes.

enum Role { TANK, MELEE, RANGED, HEALER }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var max_health: int
@export var damage: int
@export var armor: int
@export var attack_interval: float  # seconds between strikes
@export var windup: float  # seconds before a strike lands or launches
@export var attack_range: float  # tiles
@export var move_speed: float  # tiles per second
@export var crit_chance: float  # 0 to 1
@export var heal_power: int  # 0 for classes that do not heal
@export var health_per_level: int
@export var damage_per_level: int
## The microskills this class learns, and (same length) the hero level each is learned at.
@export var microskills: Array[StringName] = []
@export var microskill_levels: Array[int] = []
## A class not in [constant Party.STARTING_CLASSES] is recruited: its artifact, found in a cache,
## brings its hero to camp, and its request (gold, and optionally a count of one resource) is
## the price that recruits it. A starting class leaves all of these at their defaults.
@export var artifact_name: String = ""
## A picture id; &"" for the shared placeholder.
@export var artifact_picture: StringName = &""
## The chance, per cache opened, that the artifact is in it: above 0 and at most 1.
@export var artifact_chance: float = 0.0
@export var recruit_gold: int = 0
## A [ResourceDef] id, or &"" for none.
@export var recruit_resource: StringName = &""
@export var recruit_resource_count: int = 0
## The class whose pictures and sheet this class's heroes are drawn with until it has its own;
## &"" for its own.
@export var looks_like: StringName = &""


## The class this class's heroes are drawn as: [member looks_like], or its own id.
func look() -> StringName:
	return id if looks_like == &"" else looks_like


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the class is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.combat_problems(
		id, display_name, max_health, damage, attack_interval, attack_range, move_speed, crit_chance
	)
	if role == Role.HEALER and heal_power < 1:
		problems.append("heal_power %d is below 1 for a HEALER" % heal_power)
	if microskills.size() != microskill_levels.size():
		problems.append(
			(
				"microskills has %d entries but microskill_levels has %d"
				% [microskills.size(), microskill_levels.size()]
			)
		)
	for i: int in mini(microskills.size(), microskill_levels.size()):
		if Content.microskill(microskills[i]) == null:
			problems.append("microskill %s does not exist" % microskills[i])
		if microskill_levels[i] < 1:
			problems.append(
				"microskill %s level %d is below 1" % [microskills[i], microskill_levels[i]]
			)
	_check_look(problems)
	if not Party.STARTING_CLASSES.has(id):
		_check_request(problems)
	return problems


## A look must be a class that is drawn as itself.
func _check_look(problems: PackedStringArray) -> void:
	if looks_like == &"":
		return
	var other: HeroClassDef = Content.hero_class(looks_like)
	if other == null:
		problems.append("looks_like: %s is not a hero class" % looks_like)
	elif other.looks_like != &"":
		problems.append("looks_like: %s itself looks like %s" % [looks_like, other.looks_like])


## The artifact and the request of a class that is recruited.
func _check_request(problems: PackedStringArray) -> void:
	if artifact_name.is_empty():
		problems.append("artifact_name: empty for a class that is recruited")
	if artifact_chance <= 0.0 or artifact_chance > 1.0:
		problems.append("artifact_chance: %s is not above 0 and at most 1" % artifact_chance)
	if recruit_gold < 1:
		problems.append("recruit_gold: %d is below 1" % recruit_gold)
	if recruit_resource != &"" and Content.resource_def(recruit_resource) == null:
		problems.append("recruit_resource: %s is not a resource" % recruit_resource)
	if recruit_resource_count < 0:
		problems.append("recruit_resource_count: %d is below 0" % recruit_resource_count)
	elif recruit_resource == &"" and recruit_resource_count > 0:
		problems.append("recruit_resource_count: %d of no resource" % recruit_resource_count)
	elif recruit_resource != &"" and recruit_resource_count == 0:
		problems.append("recruit_resource_count: 0 of %s" % recruit_resource)
