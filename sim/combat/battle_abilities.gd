class_name BattleAbilities
extends RefCounted
## The rules of abilities in a battle (spec 050): which action a fighter is ready to use and
## at whom, what sets passives off, and what each effect does to whom. Stateless: everything
## lives on the [Combatant]s and the [Battle] passed in.

## How deep passives may set off passives within one moment, a guard against endless chains.
const MAX_CHAIN: int = 4


## The first of [param c]'s actions that is off cooldown, whose condition holds and which has
## someone to aim at, or null.
static func ready_action(battle: Battle, c: Combatant) -> AbilityDef:
	for ability: AbilityDef in c.abilities:
		if not ability.is_action() or battle.tick < c.action_ready_tick.get(ability.id, 0):
			continue
		if _condition_holds(battle, c, ability) and aim(battle, c, ability) != null:
			return ability
	return null


## Whom [param c]'s action [param ability] aims at now, or null.
static func aim(battle: Battle, c: Combatant, ability: AbilityDef) -> Combatant:
	if c.chasing == ability.id:
		var kept: Combatant = battle.combatant(c.target_id)
		if kept != null and kept.is_alive():
			return kept
	match ability.aim:
		AbilityDef.Aim.SELF:
			return c
		AbilityDef.Aim.WEAKEST_ALLY:
			return _weakest(battle.allies_of(c))
		AbilityDef.Aim.WEAKEST_ENEMY:
			return _weakest(battle.enemies_of(c))
		AbilityDef.Aim.FURTHEST_ENEMY:
			var furthest: Combatant = null
			var best: float = -1.0
			for enemy: Combatant in battle.enemies_of(c):
				if enemy.is_alive() and absf(enemy.x - c.x) > best:
					furthest = enemy
					best = absf(enemy.x - c.x)
			return furthest
	return battle.nearest_enemy(c)


## [param c] uses [param ability] on [param target]: an ABILITY_USED event, then each effect in
## order on everyone it lands on.
static func use(battle: Battle, c: Combatant, ability: AbilityDef, target: Combatant) -> void:
	var used: SimEvent = battle.record(SimEvent.Kind.ABILITY_USED, c.id, target.id)
	used.ability_id = ability.id
	for effect: AbilityEffect in ability.effects:
		for receiver: Combatant in _receivers(battle, c, effect, target):
			_apply(battle, c, ability, effect, receiver)


## Every fighter's passives that answer to the fight starting.
static func fight_starts(battle: Battle) -> void:
	for c: Combatant in battle.heroes + battle.monsters:
		fire(battle, c, AbilityDef.Trigger.FIGHT_STARTS, c)


## The passives set off by [param source] dealing damage to [param target], whose share of
## health was [param before]: hits and crits (by strikes and actions only, so passives never
## answer each other's damage), falling below a share, kills and allies' deaths.
static func after_damage(
	battle: Battle, source: Combatant, target: Combatant, before: float, crit: bool, via: Battle.Via
) -> void:
	if via == Battle.Via.STRIKE or via == Battle.Via.ACTION:
		fire(battle, source, AbilityDef.Trigger.LANDS_HIT, target)
		if crit:
			fire(battle, source, AbilityDef.Trigger.LANDS_CRIT, target)
		fire(battle, target, AbilityDef.Trigger.IS_HIT, source)
	if target.is_alive():
		fire(battle, target, AbilityDef.Trigger.FALLS_BELOW, target, before)
		return
	fire(battle, source, AbilityDef.Trigger.KILLS, target)
	for ally: Combatant in battle.allies_of(target):
		if ally != target:
			fire(battle, ally, AbilityDef.Trigger.ALLY_DIES, target)


## Uses each of [param owner]'s passives that answer to [param trigger], on [param target].
## [param before] is the owner's share of health before the damage, for FALLS_BELOW.
static func fire(
	battle: Battle,
	owner: Combatant,
	trigger: AbilityDef.Trigger,
	target: Combatant,
	before: float = 0.0
) -> void:
	if owner.abilities.is_empty() or not owner.is_alive() or battle.chain >= MAX_CHAIN:
		return
	for ability: AbilityDef in owner.abilities:
		if ability.is_action() or ability.trigger != trigger:
			continue
		if trigger == AbilityDef.Trigger.EVERY_NTH_STRIKE:
			if owner.strikes % maxi(ability.trigger_every, 1) != 0:
				continue
		if trigger == AbilityDef.Trigger.FALLS_BELOW:
			var share: float = ability.trigger_share
			if before < share or owner.health_fraction() >= share:
				continue
		if ability.once_per_fight and owner.spent.has(ability.id):
			continue
		if ability.chance < 1.0 and not battle.roll_chance(ability.chance):
			continue
		if ability.once_per_fight:
			owner.spent[ability.id] = true
		battle.chain += 1
		use(battle, owner, ability, target)
		battle.chain -= 1


static func _condition_holds(battle: Battle, c: Combatant, ability: AbilityDef) -> bool:
	match ability.condition:
		AbilityDef.Condition.ALLY_BELOW:
			for ally: Combatant in battle.allies_of(c):
				if ally.is_alive() and ally.health_fraction() < ability.condition_share:
					return true
			return false
		AbilityDef.Condition.SELF_BELOW:
			return c.health_fraction() < ability.condition_share
		AbilityDef.Condition.ENEMIES_AT_LEAST:
			var alive: int = 0
			for enemy: Combatant in battle.enemies_of(c):
				if enemy.is_alive():
					alive += 1
			return alive >= ability.condition_count
	return true


## The living one of [param side] with the lowest share of health, the first on a tie.
static func _weakest(side: Array[Combatant]) -> Combatant:
	var weakest: Combatant = null
	for c: Combatant in side:
		if c.is_alive() and (weakest == null or c.health_fraction() < weakest.health_fraction()):
			weakest = c
	return weakest


## Whom [param effect] lands on, in the order of their side: the living, or for a revive the
## fallen of the fighter's own side.
static func _receivers(
	battle: Battle, c: Combatant, effect: AbilityEffect, target: Combatant
) -> Array[Combatant]:
	var pool: Array[Combatant] = []
	var center: float = c.x
	match effect.lands:
		AbilityEffect.Lands.TARGET:
			pool = [target]
		AbilityEffect.Lands.SELF:
			pool = [c]
		AbilityEffect.Lands.AROUND_TARGET:
			pool = battle.allies_of(target)
			center = target.x
		AbilityEffect.Lands.ALLIES:
			pool = battle.allies_of(c)
		AbilityEffect.Lands.ENEMIES:
			pool = battle.enemies_of(c)
	var radius: float = effect.radius
	var by_place: bool = effect.lands != AbilityEffect.Lands.TARGET
	by_place = by_place and effect.lands != AbilityEffect.Lands.SELF
	by_place = by_place and (radius > 0.0 or effect.lands == AbilityEffect.Lands.AROUND_TARGET)
	var reviving: bool = effect.does == AbilityEffect.Does.REVIVE
	var found: Array[Combatant] = []
	for receiver: Combatant in pool:
		if by_place and absf(receiver.x - center) > radius + Battle.EPSILON:
			continue
		if reviving and (receiver.is_alive() or receiver.team != c.team):
			continue
		if not reviving and not receiver.is_alive():
			continue
		found.append(receiver)
	return found


static func _apply(
	battle: Battle, c: Combatant, ability: AbilityDef, effect: AbilityEffect, receiver: Combatant
) -> void:
	match effect.does:
		AbilityEffect.Does.DAMAGE:
			var amount: float = c.damage * effect.multiplier
			if receiver.health_fraction() < effect.low_health_below:
				amount *= effect.low_multiplier
			amount *= c.dealt_multiplier()
			if not effect.ignores_armor:
				amount -= receiver.armor
			amount *= receiver.taken_multiplier()
			var via: Battle.Via = Battle.Via.ACTION if ability.is_action() else Battle.Via.PASSIVE
			var dealt: int = battle.deal(c, receiver, maxi(1, roundi(amount)), false, via)
			if effect.life_steal > 0.0 and dealt > 0 and c.is_alive():
				battle.heal(c, c, roundi(dealt * effect.life_steal))
		AbilityEffect.Does.HEAL:
			var base: float = receiver.max_health
			if effect.scale == AbilityEffect.Scale.FIGHTER_HEALING:
				base = c.heal_power
			battle.heal(c, receiver, roundi(base * effect.multiplier))
		AbilityEffect.Does.PUSH:
			battle.push(c, receiver, effect.push_tiles)
		AbilityEffect.Does.REVIVE:
			battle.revive(c, receiver, effect.revive_share)
		AbilityEffect.Does.STATUS:
			BattleStatuses.apply(battle, c, receiver, effect, ability.id)
