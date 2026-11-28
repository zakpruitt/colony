class_name Hero
extends RefCounted
## One member of the party: its class, level, XP, the health it carries between
## fights, its talents and its paragon points. Its fighting numbers come from its
## [HeroClassDef], times the party's camp upgrades, times its paragon points; it fights with
## the abilities of its talents.

## XP per level step: reaching level n takes (n - 1) * (_XP_STEP * n - _XP_DISCOUNT) in total.
const _XP_STEP: int = 25
## XP taken off each level step: the first levels come quickly, and the late ones cost nearly
## the full step.
const _XP_DISCOUNT: int = 30
## Talent points a hero can earn: enough to take every node of its tree.
const TALENT_POINTS: int = 15
## A talent point comes at every level divisible by this.
const TALENT_EVERY: int = 2

var id: int
var class_id: StringName
var level: int = 1
var xp: int = 0
var health: int
## The party's camp upgrades, or null for none. Set by the [Party].
var upgrades: Upgrades
## This hero's actions in the order it last used them, least recent first; one never used is not
## in it. Each [method combatant] shares this very list, so a use in a fight is remembered after
## it (a tie between ready actions goes to the least recent). Change it in place, never replace it.
var used: Array[StringName] = []
## Counts every change to the nodes taken, so a view can tell its words are stale without copying
## [method talents] each frame.
var talents_changed: int = 0

var _def: HeroClassDef
## The talent tree nodes this hero has taken, in the order taken.
var _talents: Array[StringName] = []
## The paragon points this hero has spent, by [enum TrainingDef.Stat]; stats with none left out.
var _paragon: Dictionary[int, int] = {}
## The factor of each stat in [member _paragon], worked out as its points change.
var _paragon_factors: Dictionary[int, float] = {}


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
		_multiplier(UpgradeDef.Stat.HEALTH) * paragon_multiplier(TrainingDef.Stat.TOUGHNESS)
	)
	return roundi(base * bonus)


## True while health is above 0.
func is_alive() -> bool:
	return health > 0


## Total XP needed to be this level: (level - 1) * (_XP_STEP * level - _XP_DISCOUNT).
static func xp_for_level(level_number: int) -> int:
	return (level_number - 1) * (_XP_STEP * level_number - _XP_DISCOUNT)


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


## The microskills this hero has now: those of its class learned at or below its level,
## in the class's order.
func microskills() -> Array[StringName]:
	var learned: Array[StringName] = []
	for i: int in mini(_def.microskills.size(), _def.microskill_levels.size()):
		if level >= _def.microskill_levels[i]:
			learned.append(_def.microskills[i])
	return learned


## True if this hero has the microskill [param skill_id] at its level.
func has_microskill(skill_id: StringName) -> bool:
	return microskills().has(skill_id)


## A battle combatant for this hero, with the hero's id and current health, the party's
## upgrades and the hero's paragon points in its damage, healing power, maximum health and
## attack speed, and the abilities of its talents in [method TalentTreeDef.fight_order]: a fighter
## tries its actions in that order, so a capstone is not starved by tier 1 in fights of a few
## seconds.
func combatant() -> Combatant:
	var c: Combatant = Combatant.from_hero(_def, level, id)
	var power: float = (
		_multiplier(UpgradeDef.Stat.DAMAGE) * paragon_multiplier(TrainingDef.Stat.POWER)
	)
	c.damage = roundi(c.damage * power)
	c.heal_power = roundi(c.heal_power * power)
	c.max_health = max_health()
	c.health = clampi(health, 0, c.max_health)
	var quickness: float = paragon_multiplier(TrainingDef.Stat.QUICKNESS)
	if quickness != 1.0:
		c.attack_interval_ticks = Combatant.seconds_to_ticks(_def.attack_interval / quickness)
	var tree: TalentTreeDef = Content.talent_tree(class_id) if not _talents.is_empty() else null
	if tree != null:
		for ability_id: StringName in tree.fight_order(_talents):
			var ability: AbilityDef = Content.ability(ability_id)
			if ability != null:
				c.abilities.append(ability)
	c.used = used
	return c


# --- Talents and paragon -------------------------------------------------------


## The nodes this hero has taken, in the order taken.
func talents() -> Array[StringName]:
	return _talents.duplicate()


## The talent points this hero has earned and not spent.
func talent_points() -> int:
	return maxi(TalentRules.talent_points_at(level) - _talents.size(), 0)


## True if this hero has an unspent talent point and [param ability_id] is a node of its tree
## that is open now ([method TalentTreeDef.open_nodes]).
func can_take(ability_id: StringName) -> bool:
	var tree: TalentTreeDef = Content.talent_tree(class_id)
	if talent_points() <= 0 or tree == null:
		return false
	return tree.open_nodes(_talents).has(ability_id)


## Takes node [param ability_id] if [method can_take] allows it. Returns true if it did.
func take_talent(ability_id: StringName) -> bool:
	if not can_take(ability_id):
		return false
	_talents.append(ability_id)
	talents_changed += 1
	return true


## Sets this hero's nodes directly (loading a save, tests), with no checks.
func set_talents(taken: Array[StringName]) -> void:
	_talents = taken.duplicate()
	talents_changed += 1
	used.assign(used.filter(func(ability_id: StringName) -> bool: return taken.has(ability_id)))


## Gives back every node: each talent point is unspent.
func reset_talents() -> void:
	_talents.clear()
	talents_changed += 1
	used.clear()


## The paragon points this hero has earned and not spent.
func paragon_points() -> int:
	var spent: int = 0
	for stat: int in _paragon:
		spent += _paragon[stat]
	return maxi(TalentRules.paragon_points_at(level) - spent, 0)


## The paragon points this hero has put into [param stat].
func paragon_rank(stat: TrainingDef.Stat) -> int:
	return _paragon.get(stat, 0)


## Puts one unspent paragon point into [param stat]. Returns true if there was one.
func spend_paragon(stat: TrainingDef.Stat) -> bool:
	if paragon_points() <= 0 or TalentRules.stat_def(stat) == null:
		return false
	_paragon[stat] = paragon_rank(stat) + 1
	_count_paragon(stat)
	return true


## Sets the points this hero has in [param stat] directly (loading a save, tests), with no
## checks but that a rank below 1 is none.
func set_paragon_rank(stat: TrainingDef.Stat, rank: int) -> void:
	if rank <= 0:
		_paragon.erase(stat)
	else:
		_paragon[stat] = rank
	_count_paragon(stat)


## The factor this hero's paragon points in [param stat] give: 1 plus each point's
## [member TrainingDef.per_rank]; 1.0 with none.
func paragon_multiplier(stat: TrainingDef.Stat) -> float:
	return _paragon_factors.get(stat, 1.0)


## True when this hero has taken a node or spent a paragon point.
func has_grown() -> bool:
	return not _talents.is_empty() or not _paragon.is_empty()


## Works out the factor of [param stat] from its points, after they change.
func _count_paragon(stat: TrainingDef.Stat) -> void:
	var rank: int = paragon_rank(stat)
	var def_of_stat: TrainingDef = TalentRules.stat_def(stat)
	if rank == 0 or def_of_stat == null:
		_paragon_factors.erase(stat)
	else:
		_paragon_factors[stat] = 1.0 + rank * def_of_stat.per_rank


func _multiplier(stat: UpgradeDef.Stat) -> float:
	return upgrades.multiplier(stat) if upgrades != null else 1.0
