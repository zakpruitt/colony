class_name AbilityEffect
extends Resource
## One thing an ability does: where it lands and what it does there.
## Kept as a sub-resource of its [AbilityDef], so one ability is one .tres file.

## Where the effect lands.
enum Lands {
	TARGET,  ## the ability's target
	AROUND_TARGET,  ## everyone of the target's side within [member radius] of it, the target too
	SELF,  ## the fighter itself
	ALLIES,  ## every ally, the fighter too; within [member radius] of the fighter if above 0
	ENEMIES,  ## every enemy; within [member radius] of the fighter if above 0
	NEAREST_ENEMY,  ## the enemy nearest the fighter, as an ordinary strike would choose it
}

## What the effect does to each receiver.
enum Does { DAMAGE, HEAL, PUSH, REVIVE, STATUS, SUMMON }

## What a heal, or a status measured in points (shield, burning, bleeding, mending), is a
## multiple of.
enum Scale {
	FIGHTER_DAMAGE,  ## the fighter's damage
	FIGHTER_HEALING,  ## the fighter's healing power
	RECEIVER_MAX_HEALTH,  ## the receiver's maximum health
}

## The lasting effects an ability can leave on a fighter. Each status's [member amount] means:
## [br]- STUNNED, TAUNTING: nothing.
## [br]- SHIELDED: damage absorbed, times [member scale].
## [br]- BURNING, BLEEDING: damage each second (ignoring armor), times [member scale].
## [br]- MENDING: healing each second, times [member scale].
## [br]- HASTED (below 1), SLOWED (above 1): the time between strikes is multiplied by it.
## [br]- MIGHTY (above 1), WEAKENED (below 1): damage dealt is multiplied by it.
## [br]- MARKED (above 1): damage taken is multiplied by it.
## [br]- NIMBLE (0 to 1): the chance an ordinary strike misses.
## [br]- UNTOUCHABLE: nothing. No strike, action, passive or status damage from an enemy lands
## on it, and enemies aim at someone else while anyone else on its side stands.
## [br]- CHILLED: damage each second (ignoring armor), times [member scale]; a status of its
## own, so the view can show it apart from burning and bleeding.
enum Status {
	STUNNED,
	TAUNTING,
	SHIELDED,
	BURNING,
	BLEEDING,
	MENDING,
	HASTED,
	SLOWED,
	MIGHTY,
	WEAKENED,
	MARKED,
	NIMBLE,
	UNTOUCHABLE,
	CHILLED,
}

## Statuses that help their bearer; the others hurt it.
const _HELPFUL: Array[Status] = [
	Status.TAUNTING,
	Status.SHIELDED,
	Status.MENDING,
	Status.HASTED,
	Status.MIGHTY,
	Status.NIMBLE,
	Status.UNTOUCHABLE,
]
## Statuses whose amount is a number of points, measured by [member scale].
const IN_POINTS: Array[Status] = [
	Status.SHIELDED, Status.BURNING, Status.BLEEDING, Status.MENDING, Status.CHILLED
]

@export var lands: Lands = Lands.TARGET
## Tiles. For AROUND_TARGET, ALLIES and ENEMIES; 0 means only the target, or everyone.
@export var radius: float = 0.0
@export var does: Does = Does.DAMAGE
## DAMAGE: the multiple of the fighter's damage. HEAL: the multiple of [member scale].
@export var multiplier: float = 1.0
## DAMAGE: armor does not reduce it.
@export var ignores_armor: bool = false
## DAMAGE: the multiplier times the fighter's healing power, not its damage.
@export var damage_from_healing: bool = false
## DAMAGE: below this share of health (0 for never) the target takes [member low_multiplier] more.
@export var low_health_below: float = 0.0
@export var low_multiplier: float = 1.0
## DAMAGE: the fighter heals this share of what was dealt.
@export var life_steal: float = 0.0
## DAMAGE, on an EVERY_NTH_STRIKE or LANDS_HIT passive only: rather than a hit of its own, the
## ordinary strike that set it off is [member multiplier] times as strong, and
## [member life_steal] is a share of that whole strike. Then it never fires on a miss.
@export var on_strike: bool = false
## HEAL and the statuses in points: what [member multiplier] or [member amount] multiplies.
@export var scale: Scale = Scale.FIGHTER_HEALING
## PUSH: tiles away from the fighter.
@export var push_tiles: float = 0.0
## REVIVE: the share of maximum health the ally stands up with.
@export var revive_share: float = 0.0
## STATUS: which one, for how long, and how strong (see [enum Status]).
@export var status: Status = Status.STUNNED
@export var seconds: float = 0.0
@export var amount: float = 0.0
## SUMMON: who comes, how many come each use, and the most of it one summoner may have at once.
@export var summon: SummonDef
@export var count: int = 1
@export var summon_cap: int = 1


## True if this effect helps whoever it lands on; false if it hurts them.
func is_helpful() -> bool:
	match does:
		Does.HEAL, Does.REVIVE, Does.SUMMON:
			return true
		Does.STATUS:
			return status in _HELPFUL
	return false


## One line per problem; empty when the effect can do something.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if radius < 0.0:
		problems.append("radius %s is negative" % radius)
	match does:
		Does.DAMAGE:
			if multiplier <= 0.0:
				problems.append("damage multiplier %s is not positive" % multiplier)
			if low_health_below < 0.0 or low_health_below >= 1.0:
				problems.append("low_health_below %s is outside 0 to 1" % low_health_below)
			if low_health_below > 0.0 and low_multiplier <= 1.0:
				problems.append("low_multiplier %s adds nothing" % low_multiplier)
			if life_steal < 0.0 or life_steal > 1.0:
				problems.append("life_steal %s is outside 0 to 1" % life_steal)
			if on_strike and (low_health_below > 0.0 or ignores_armor or lands != Lands.TARGET):
				problems.append("a multiplied strike lands on its target, with no other bonus")
			if on_strike and damage_from_healing:
				problems.append("a multiplied strike cannot come from healing power")
		Does.HEAL:
			problems.append_array(_damage_only())
			if multiplier <= 0.0:
				problems.append("heal multiplier %s is not positive" % multiplier)
			if scale == Scale.FIGHTER_DAMAGE:
				problems.append("a heal is a multiple of healing power or maximum health")
		Does.PUSH:
			problems.append_array(_damage_only())
			if push_tiles <= 0.0:
				problems.append("push_tiles %s is not positive" % push_tiles)
		Does.REVIVE:
			problems.append_array(_damage_only())
			if revive_share <= 0.0 or revive_share > 1.0:
				problems.append("revive_share %s is outside 0 to 1" % revive_share)
		Does.STATUS:
			problems.append_array(_damage_only())
			problems.append_array(_status_problems())
		Does.SUMMON:
			problems.append_array(_damage_only())
			problems.append_array(_summon_problems())
	return problems


func _damage_only() -> PackedStringArray:
	if damage_from_healing:
		return PackedStringArray(["damage_from_healing is set on an effect that is not DAMAGE"])
	return PackedStringArray()


func _summon_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if summon == null:
		problems.append("a summon effect has no summon")
	else:
		for problem: String in summon.validate():
			problems.append("summon: %s" % problem)
	if count < 1:
		problems.append("count %d is below 1" % count)
	if summon_cap < 1:
		problems.append("summon_cap %d is below 1" % summon_cap)
	return problems


func _status_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var label: String = str(Status.keys()[status]).to_lower()
	if seconds <= 0.0:
		problems.append("%s lasts %s seconds" % [label, seconds])
	var fine: bool = true
	match status:
		Status.SHIELDED, Status.BURNING, Status.BLEEDING, Status.MENDING, Status.CHILLED:
			fine = amount > 0.0
		Status.MIGHTY:
			fine = amount > 1.0
		Status.SLOWED, Status.MARKED:
			fine = amount > 1.0
		Status.HASTED, Status.WEAKENED:
			fine = amount > 0.0 and amount < 1.0
		Status.NIMBLE:
			fine = amount > 0.0 and amount <= 1.0
	if not fine:
		problems.append("%s amount %s does nothing" % [label, amount])
	return problems
