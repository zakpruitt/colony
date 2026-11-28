class_name AbilityDef
extends ContentDef
## Something a fighter does in battle beyond its ordinary strike: an action with a
## cooldown, or a passive that answers to what happens in the fight. Either has one or more
## [AbilityEffect]s, applied in order. One .tres file per ability under res://data/abilities.

enum Kind { ACTION, PASSIVE }

## Whom an action aims at.
enum Aim { NEAREST_ENEMY, WEAKEST_ENEMY, FURTHEST_ENEMY, WEAKEST_ALLY, SELF }

## What must hold for an action to be used.
enum Condition {
	NONE,
	ALLY_BELOW,  ## a living ally (the fighter too) below [member condition_share] of health
	SELF_BELOW,  ## the fighter below [member condition_share] of health
	ENEMIES_AT_LEAST,  ## at least [member condition_count] enemies alive
	## an enemy within [member condition_tiles] of the fighter; it does not walk to make it true
	ENEMY_WITHIN,
	TARGET_BELOW,  ## the one it aims at below [member condition_share] of health
	## a living ally other than the fighter below [member condition_share] of health
	OTHER_ALLY_BELOW,
}

## What sets a passive off, and what its target is.
enum Trigger {
	FIGHT_STARTS,  ## target: the fighter (an effect may land on the nearest enemy instead)
	LANDS_HIT,  ## an ordinary strike or an action's damage; target: the one struck
	LANDS_CRIT,  ## an ordinary strike that crits; target: the one struck
	KILLS,  ## target: the one killed
	IS_HIT,  ## by an ordinary strike or an action's damage; target: the striker
	FALLS_BELOW,  ## below [member trigger_share] of health; target: the fighter
	ALLY_DIES,  ## target: the fallen ally
	EVERY_NTH_STRIKE,  ## every [member trigger_every]th ordinary strike; target: the one struck
}

## The moves a fighter's body can perform for an ability, the one set that the data check and
## the view both read. Each is acted out in game/entities/character_moves.gd.
const MOVES: Array[StringName] = [
	&"leap",  ## jumps in an arc and comes down on the blow
	&"spin",  ## turns round with the weapon out
	&"dash",  ## a quick streak to the target and back
	&"heavy_swing",  ## a long draw back and a big follow-through
	&"throw",  ## the arm back over the shoulder, then a whip forward
	&"brace",  ## crouches behind the shield
	&"shout",  ## rears back and puffs up
	&"cast",  ## staff raised, lifting off the floor, then a thrust as it lands
	&"channel",  ## arms up and held, for the big spells
	&"prayer",  ## head bowed, then arms raised
	&"flourish",  ## a short hop and flick that does not stop what the fighter is doing
]
@export var id: StringName
@export var display_name: String
@export var description: String  # one line
## How the fighter's body acts it out, one of [constant MOVES]. A view hint only: no
## rule reads it and the state hash does not include it.
@export var move: StringName
@export var kind: Kind = Kind.ACTION
@export var effects: Array[AbilityEffect] = []

@export_group("Action")
@export var cooldown: float = 0.0  # seconds, from when it lands
@export var windup: float = 0.3  # seconds
@export var ready_at_start: bool = false
@export var aim: Aim = Aim.NEAREST_ENEMY
## Tiles; the fighter walks into it, as for a strike. Ignored if [member anywhere] or aimed at SELF.
@export var reach: float = 1.0
@export var anywhere: bool = false
@export var condition: Condition = Condition.NONE
@export var condition_share: float = 0.0
@export var condition_count: int = 0
@export var condition_tiles: float = 0.0

@export_group("Passive")
@export var trigger: Trigger = Trigger.FIGHT_STARTS
@export var trigger_share: float = 0.0
@export var trigger_every: int = 0
@export var chance: float = 1.0
@export var once_per_fight: bool = false


## True if this ability is an action.
func is_action() -> bool:
	return kind == Kind.ACTION


## True if this passive multiplies the ordinary strike that sets it off (see
## [member AbilityEffect.on_strike]) rather than landing a hit of its own.
func boosts_strike() -> bool:
	if is_action():
		return false
	for effect: AbilityEffect in effects:
		if effect != null and effect.does == AbilityEffect.Does.DAMAGE and effect.on_strike:
			return true
	return false


## True if this ability's target is on the fighter's own side: an action aimed at an ally or
## itself, or a passive whose target is the fighter or a fallen ally.
func aims_at_ally() -> bool:
	if is_action():
		return aim in [Aim.WEAKEST_ALLY, Aim.SELF]
	return trigger in [Trigger.FIGHT_STARTS, Trigger.FALLS_BELOW, Trigger.ALLY_DIES]


## What Content finds this definition by: its id.
func key() -> StringName:
	return id


## One line per problem; empty when the ability can do something.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(
		id, display_name, description, "description"
	)
	if String(move).is_empty():
		problems.append("move is empty")
	elif not MOVES.has(move):
		problems.append("move %s is not one of %s" % [move, MOVES])
	problems.append_array(_action_problems() if is_action() else _passive_problems())
	if effects.is_empty():
		problems.append("it has no effects")
	for i: int in effects.size():
		var effect: AbilityEffect = effects[i]
		if effect == null:
			problems.append("effects[%d] is empty" % i)
			continue
		for problem: String in effect.validate():
			problems.append("effects[%d]: %s" % [i, problem])
		if effect.on_strike and not _strikes():
			problems.append("effects[%d]: only a passive on a strike can multiply it" % i)
		var side: String = _side_problem(effect)
		if not side.is_empty():
			problems.append("effects[%d]: %s" % [i, side])
	return problems


func _action_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if cooldown < 0.0:
		problems.append("cooldown %s is negative" % cooldown)
	if windup < 0.0:
		problems.append("windup %s is negative" % windup)
	if not anywhere and aim != Aim.SELF and reach <= 0.0:
		problems.append("reach %s is not positive" % reach)
	match condition:
		Condition.ALLY_BELOW, Condition.SELF_BELOW, Condition.TARGET_BELOW, Condition.OTHER_ALLY_BELOW:
			if condition_share <= 0.0 or condition_share > 1.0:
				problems.append("condition_share %s is outside 0 to 1" % condition_share)
		Condition.ENEMIES_AT_LEAST:
			if condition_count < 1:
				problems.append("condition_count %d is below 1" % condition_count)
		Condition.ENEMY_WITHIN:
			if condition_tiles <= 0.0:
				problems.append("condition_tiles %s is not positive" % condition_tiles)
	return problems


func _passive_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if chance <= 0.0 or chance > 1.0:
		problems.append("chance %s is outside 0 to 1" % chance)
	if trigger == Trigger.FALLS_BELOW and (trigger_share <= 0.0 or trigger_share >= 1.0):
		problems.append("trigger_share %s is outside 0 to 1" % trigger_share)
	if trigger == Trigger.EVERY_NTH_STRIKE and trigger_every < 1:
		problems.append("trigger_every %d is below 1" % trigger_every)
	return problems


## Why [param effect] could never land on anyone it would make sense on, or "".
func _side_problem(effect: AbilityEffect) -> String:
	var on_target: bool = (
		effect.lands in [AbilityEffect.Lands.TARGET, AbilityEffect.Lands.AROUND_TARGET]
	)
	var target_is_dead: bool = not is_action() and trigger in [Trigger.KILLS, Trigger.ALLY_DIES]
	if effect.does == AbilityEffect.Does.SUMMON:
		# A summon appears beside its summoner, so it lands nowhere else.
		var beside: bool = effect.lands == AbilityEffect.Lands.SELF
		return "" if beside else "a summon lands on SELF, beside its summoner"
	if effect.does == AbilityEffect.Does.REVIVE:
		var fallen_ally: bool = (
			effect.lands == AbilityEffect.Lands.ALLIES
			or (on_target and not is_action() and trigger == Trigger.ALLY_DIES)
			or (effect.lands == AbilityEffect.Lands.AROUND_TARGET and aims_at_ally())
		)
		return "" if fallen_ally else "a revive that can never find a fallen ally"
	if effect.lands == AbilityEffect.Lands.TARGET and target_is_dead:
		return "it lands on a target that is already dead"
	var on_allies: bool = effect.lands in [AbilityEffect.Lands.SELF, AbilityEffect.Lands.ALLIES]
	if on_target:
		on_allies = aims_at_ally()
	if effect.is_helpful() and not on_allies:
		return "it helps the enemy"
	if not effect.is_helpful() and on_allies:
		return "it hurts the fighter's own side"
	return ""


func _strikes() -> bool:
	return not is_action() and trigger in [Trigger.EVERY_NTH_STRIKE, Trigger.LANDS_HIT]
