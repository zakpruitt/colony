class_name AbilityDef
extends Resource
## Something a fighter does in battle beyond its ordinary strike (spec 050): an action with a
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
}

## What sets a passive off, and what its target is.
enum Trigger {
	FIGHT_STARTS,  ## target: the fighter
	LANDS_HIT,  ## an ordinary strike or an action's damage; target: the one struck
	LANDS_CRIT,  ## an ordinary strike that crits; target: the one struck
	KILLS,  ## target: the one killed
	IS_HIT,  ## by an ordinary strike or an action's damage; target: the striker
	FALLS_BELOW,  ## below [member trigger_share] of health; target: the fighter
	ALLY_DIES,  ## target: the fallen ally
	EVERY_NTH_STRIKE,  ## every [member trigger_every]th ordinary strike; target: the one struck
}

@export var id: StringName
@export var display_name: String
@export var description: String  # one line
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

@export_group("Passive")
@export var trigger: Trigger = Trigger.FIGHT_STARTS
@export var trigger_share: float = 0.0
@export var trigger_every: int = 0
@export var chance: float = 1.0
@export var once_per_fight: bool = false


## True if this ability is an action.
func is_action() -> bool:
	return kind == Kind.ACTION


## One line per problem; empty when the ability can do something.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if String(id).is_empty():
		problems.append("id is empty")
	if display_name.is_empty():
		problems.append("display_name is empty")
	if description.is_empty():
		problems.append("description is empty")
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
		Condition.ALLY_BELOW, Condition.SELF_BELOW:
			if condition_share <= 0.0 or condition_share > 1.0:
				problems.append("condition_share %s is outside 0 to 1" % condition_share)
		Condition.ENEMIES_AT_LEAST:
			if condition_count < 1:
				problems.append("condition_count %d is below 1" % condition_count)
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
	if effect.does == AbilityEffect.Does.REVIVE:
		var fallen_ally: bool = (
			effect.lands == AbilityEffect.Lands.ALLIES
			or (on_target and not is_action() and trigger == Trigger.ALLY_DIES)
			or (effect.lands == AbilityEffect.Lands.AROUND_TARGET and _target_is_ally())
		)
		return "" if fallen_ally else "a revive that can never find a fallen ally"
	if effect.lands == AbilityEffect.Lands.TARGET and target_is_dead:
		return "it lands on a target that is already dead"
	var on_allies: bool = effect.lands in [AbilityEffect.Lands.SELF, AbilityEffect.Lands.ALLIES]
	if on_target:
		on_allies = _target_is_ally()
	if effect.is_helpful() and not on_allies:
		return "it helps the enemy"
	if not effect.is_helpful() and on_allies:
		return "it hurts the fighter's own side"
	return ""


func _target_is_ally() -> bool:
	if is_action():
		return aim in [Aim.WEAKEST_ALLY, Aim.SELF]
	return trigger in [Trigger.FIGHT_STARTS, Trigger.FALLS_BELOW, Trigger.ALLY_DIES]
