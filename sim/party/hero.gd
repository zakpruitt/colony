class_name Hero
extends RefCounted
## One member of the party: its class, level, XP and the health it carries
## between fights. Its fighting numbers come from its [HeroClassDef].

## XP per level step: reaching level n takes XP_STEP * (n - 1) * n in total.
const XP_STEP: int = 25

var id: int
var class_id: StringName
var level: int = 1
var xp: int = 0
var health: int

var _def: HeroClassDef


## A level-1 hero of class [param class_def] at full health.
func _init(hero_id: int, class_def: HeroClassDef) -> void:
	id = hero_id
	_def = class_def
	class_id = class_def.id
	health = max_health()


## The class this hero was made from.
func def() -> HeroClassDef:
	return _def


## Health when full, at the hero's level.
func max_health() -> int:
	return _def.max_health + _def.health_per_level * (level - 1)


## True while health is above 0.
func is_alive() -> bool:
	return health > 0


## Total XP needed to be this level: 25 * (level - 1) * level.
static func xp_for_level(level_number: int) -> int:
	return XP_STEP * (level_number - 1) * level_number


## Adds XP and takes every level it pays for, healing by the health each level
## adds. Returns how many levels were gained.
func gain_xp(amount: int) -> int:
	xp += maxi(amount, 0)
	var gained: int = 0
	while xp >= xp_for_level(level + 1):
		level += 1
		gained += 1
		health += _def.health_per_level
	return gained


## A battle combatant for this hero, with the hero's id and current health.
func combatant() -> Combatant:
	var c: Combatant = Combatant.from_hero(_def, level, id)
	c.health = clampi(health, 0, c.max_health)
	return c
