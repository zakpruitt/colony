class_name Hero
extends RefCounted
## One member of the party: its class, level, XP, the health it carries between
## fights and its own training (spec 029). Its fighting numbers come from its
## [HeroClassDef], times the party's camp upgrades, times its training.

## XP per level step: reaching level n takes XP_STEP * (n - 1) * n in total.
const XP_STEP: int = 25

var id: int
var class_id: StringName
var level: int = 1
var xp: int = 0
var health: int
## The party's camp upgrades, or null for none. Set by the [Party].
var upgrades: Upgrades

var _def: HeroClassDef
## The rank of each training this hero has bought; ranks of 0 are left out.
var _training: Dictionary[StringName, int] = {}


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
	var base: int = _def.max_health + _def.health_per_level * (level - 1)
	var bonus: float = (
		_multiplier(UpgradeDef.Stat.HEALTH) * training_multiplier(TrainingDef.Stat.TOUGHNESS)
	)
	return roundi(base * bonus)


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
		var before: int = max_health()
		level += 1
		gained += 1
		health += max_health() - before
	return gained


## A battle combatant for this hero, with the hero's id and current health, and
## the party's upgrades and the hero's training in its damage, healing power,
## maximum health and attack speed.
func combatant() -> Combatant:
	var c: Combatant = Combatant.from_hero(_def, level, id)
	var power: float = (
		_multiplier(UpgradeDef.Stat.DAMAGE) * training_multiplier(TrainingDef.Stat.POWER)
	)
	c.damage = roundi(c.damage * power)
	c.heal_power = roundi(c.heal_power * power)
	c.max_health = max_health()
	c.health = clampi(health, 0, c.max_health)
	var quickness: float = training_multiplier(TrainingDef.Stat.QUICKNESS)
	if quickness != 1.0:
		c.attack_interval_ticks = Combatant.seconds_to_ticks(_def.attack_interval / quickness)
	return c


## The rank this hero has of training [param training_id]; 0 if none or unknown.
func training_rank(training_id: StringName) -> int:
	return _training.get(training_id, 0)


## The price of this hero's next rank of [param training_id]; 0 at the maximum or unknown.
func training_cost(training_id: StringName) -> int:
	var training: TrainingDef = Content.training(training_id)
	if training == null:
		return 0
	return training.cost_at(training_rank(training_id))


## The factor this hero's training of [param stat] gives; 1.0 with no ranks.
func training_multiplier(stat: TrainingDef.Stat) -> float:
	var bonus: float = 0.0
	for training_id: StringName in _training:
		var training: TrainingDef = Content.training(training_id)
		if training != null and training.stat == stat:
			bonus += _training[training_id] * training.per_rank
	return 1.0 + bonus


## Sets this hero's rank of [param training_id] directly (training, loading a save,
## tests). Unknown ids are ignored; the rank is clamped to 0 .. the maximum.
func set_training_rank(training_id: StringName, new_rank: int) -> void:
	var training: TrainingDef = Content.training(training_id)
	if training == null:
		return
	var clamped: int = clampi(new_rank, 0, training.max_rank)
	if clamped == 0:
		_training.erase(training_id)
	else:
		_training[training_id] = clamped


## True when this hero has any rank of any training.
func is_trained() -> bool:
	return not _training.is_empty()


func _multiplier(stat: UpgradeDef.Stat) -> float:
	return upgrades.multiplier(stat) if upgrades != null else 1.0
