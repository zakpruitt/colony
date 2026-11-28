class_name BattleAbilities
extends RefCounted
## The rules of abilities in a battle: which action a fighter is ready to use and
## at whom, what sets passives off, and what each effect does to whom. Stateless: everything
## lives on the [Combatant]s and the [Battle] passed in.

## How deep passives may set off passives within one moment, a guard against endless chains.
const MAX_CHAIN: int = 4


## An action chosen and whom it is aimed at.
class Choice:
	extends RefCounted
	var action: AbilityDef
	var target: Combatant

	func _init(chosen: AbilityDef, aimed_at: Combatant) -> void:
		action = chosen
		target = aimed_at


## The action [param c] would use now, or null: of its actions off cooldown, whose condition holds
## and which have someone to aim at, the one ready the longest; a tie goes to the one used least
## recently ([member Combatant.used], never used first), then to the earlier in
## [member Combatant.abilities]. None until [param c] has swung once since its last action. A
## healer with an ally to heal uses none aimed at an enemy: it heals first.
static func ready_action(battle: Battle, c: Combatant) -> AbilityDef:
	var heal_first: bool = c.role == HeroClassDef.Role.HEALER and battle.hurt_ally(c) != null
	var chosen: Choice = choose(battle, c, heal_first)
	return chosen.action if chosen != null else null


## As [method ready_action], with [param heal_first] already worked out, and the action's target
## with it.
static func choose(battle: Battle, c: Combatant, heal_first: bool) -> Choice:
	if not c.swung_since_action:
		return null
	var chosen: Choice = null
	var since: int = 0
	var last: int = 0
	for ability: AbilityDef in c.abilities:
		var ready: int = c.action_ready_tick.get(ability.id, 0)
		var place: int = c.used.find(ability.id)
		if chosen != null and (ready > since or (ready == since and place >= last)):
			continue
		var target: Combatant = ready_target(battle, c, ability, heal_first)
		if target != null:
			chosen = Choice.new(ability, target)
			since = ready
			last = place
	return chosen


## Whom [param c] would use [param ability] on now, or null unless it is an action off cooldown
## with someone to aim at and its condition holds. With [param heal_first] (a healer with an
## ally to heal) an action aimed at an enemy is not ready.
static func ready_target(
	battle: Battle, c: Combatant, ability: AbilityDef, heal_first: bool
) -> Combatant:
	if not ability.is_action() or battle.tick < c.action_ready_tick.get(ability.id, 0):
		return null
	if heal_first and not ability.aims_at_ally():
		return null
	var target: Combatant = aim(battle, c, ability)
	if target != null and _condition_holds(battle, c, ability, target):
		return target
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
			return _weakest(_own_side(battle, c))
		AbilityDef.Aim.WEAKEST_ENEMY, AbilityDef.Aim.FURTHEST_ENEMY:
			return battle.best_enemy(c, ability.aim)
	return battle.nearest_enemy(c)


## [param c] uses [param ability] on [param target]: an ABILITY_USED event (unless
## [param report] is false), then each effect in order on everyone it lands on. An effect that
## multiplies a strike belongs to the strike and is not done here. Returns false, with no
## event, if no effect lands on anyone. [param chain] is how many passives deep the use is.
static func use(
	battle: Battle,
	c: Combatant,
	ability: AbilityDef,
	target: Combatant,
	report: bool = true,
	chain: int = 0
) -> bool:
	var lands: bool = false
	for effect: AbilityEffect in ability.effects:
		if not effect.on_strike and not _receivers(battle, c, effect, target).is_empty():
			lands = true
			break
	if not lands:
		return false
	if report:
		battle.record_use(c, target, ability)
	for effect: AbilityEffect in ability.effects:
		if effect.on_strike:
			continue
		var reviving: bool = effect.does == AbilityEffect.Does.REVIVE
		for receiver: Combatant in _receivers(battle, c, effect, target):
			# Worked out before any of them, so one that a passive set off by an earlier receiver
			# has killed is passed over: nothing but a revive lands on the dead.
			if receiver.is_alive() != reviving:
				_apply(battle, c, ability, effect, receiver, chain)
	return true


## The passives of [param c] that multiply the ordinary strike it is landing on [param target]
## now (see [method AbilityDef.boosts_strike]), each counted and rolled as [method fire] does.
static func strike_boosts(battle: Battle, c: Combatant, target: Combatant) -> Array[AbilityDef]:
	var boosts: Array[AbilityDef] = []
	if c.abilities.is_empty() or not target.is_alive():
		return boosts
	for ability: AbilityDef in c.abilities:
		if not ability.boosts_strike():
			continue
		var counts: bool = ability.trigger == AbilityDef.Trigger.LANDS_HIT
		counts = counts or ability.trigger == AbilityDef.Trigger.EVERY_NTH_STRIKE
		if counts and _answers(battle, c, ability, ability.trigger, 0.0):
			if ability.once_per_fight:
				c.spent[ability.id] = true
			boosts.append(ability)
	return boosts


## Every fighter's passives that answer to the fight starting.
static func fight_starts(battle: Battle) -> void:
	for c: Combatant in battle.fighters():
		fire(battle, c, AbilityDef.Trigger.FIGHT_STARTS, c)


## The passives set off by [param source] dealing damage to [param target], whose share of
## health was [param before]. Landing a hit or a crit, and being hit, answer ordinary strikes
## and actions only; falling below a share, a kill and an ally's death answer any damage, a
## passive's or a status's too, so passives can set off passives: [constant MAX_CHAIN] limits
## how deep, [param chain] being how deep the damage already is.
static func after_damage(
	battle: Battle,
	source: Combatant,
	target: Combatant,
	before: float,
	crit: bool,
	via: Battle.Via,
	chain: int
) -> void:
	if via == Battle.Via.STRIKE or via == Battle.Via.ACTION:
		fire(battle, source, AbilityDef.Trigger.LANDS_HIT, target, 0.0, chain)
		if crit:
			fire(battle, source, AbilityDef.Trigger.LANDS_CRIT, target, 0.0, chain)
		fire(battle, target, AbilityDef.Trigger.IS_HIT, source, 0.0, chain)
	if target.is_alive():
		fire(battle, target, AbilityDef.Trigger.FALLS_BELOW, target, before, chain)
		return
	if target.is_summon():
		# A summon's end is not a death: nobody killed it and no ally died.
		return
	fire(battle, source, AbilityDef.Trigger.KILLS, target, 0.0, chain)
	for ally: Combatant in battle.allies_of(target):
		if ally != target:
			fire(battle, ally, AbilityDef.Trigger.ALLY_DIES, target, 0.0, chain)


## Uses each of [param owner]'s passives that answer to [param trigger], on [param target].
## [param before] is the owner's share of health before the damage, for FALLS_BELOW. A passive
## that lands on nobody is not used, and a once-a-fight one is not spent by it. [param chain] is
## how many passives deep the moment already is: each passive used goes one deeper, and none is
## used [constant MAX_CHAIN] deep.
static func fire(
	battle: Battle,
	owner: Combatant,
	trigger: AbilityDef.Trigger,
	target: Combatant,
	before: float = 0.0,
	chain: int = 0
) -> void:
	if owner.abilities.is_empty() or not owner.is_alive() or chain >= MAX_CHAIN:
		return
	for ability: AbilityDef in owner.abilities:
		if ability.boosts_strike() or not _answers(battle, owner, ability, trigger, before):
			continue
		if use(battle, owner, ability, target, true, chain + 1) and ability.once_per_fight:
			owner.spent[ability.id] = true


## True if [param owner]'s passive [param ability] answers [param trigger] now: its count of
## strikes or share of health is right, it is not spent, and its chance came up.
static func _answers(
	battle: Battle,
	owner: Combatant,
	ability: AbilityDef,
	trigger: AbilityDef.Trigger,
	before: float
) -> bool:
	if ability.is_action() or ability.trigger != trigger:
		return false
	if trigger == AbilityDef.Trigger.EVERY_NTH_STRIKE:
		if owner.strikes % maxi(ability.trigger_every, 1) != 0:
			return false
	if trigger == AbilityDef.Trigger.FALLS_BELOW:
		var share: float = ability.trigger_share
		if before < share or owner.health_fraction() >= share:
			return false
	if ability.once_per_fight and owner.spent.has(ability.id):
		return false
	return ability.chance >= 1.0 or battle.roll_chance(ability.chance)


static func _condition_holds(
	battle: Battle, c: Combatant, ability: AbilityDef, target: Combatant
) -> bool:
	match ability.condition:
		AbilityDef.Condition.ALLY_BELOW, AbilityDef.Condition.OTHER_ALLY_BELOW:
			var others: bool = ability.condition == AbilityDef.Condition.OTHER_ALLY_BELOW
			for ally: Combatant in _own_side(battle, c):
				if others and ally == c:
					continue
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
		AbilityDef.Condition.ENEMY_WITHIN:
			for enemy: Combatant in battle.enemies_of(c):
				var near: bool = absf(enemy.x - c.x) <= ability.condition_tiles + Battle.EPSILON
				if near and enemy.is_alive() and not battle.untouchable(c, enemy):
					return true
			return false
		AbilityDef.Condition.TARGET_BELOW:
			return target.health_fraction() < ability.condition_share
	return true


## [param c]'s side without the summons: what a heal or a hurt ally is chosen from, so none is
## spent on a turret.
static func _own_side(battle: Battle, c: Combatant) -> Array[Combatant]:
	return battle.heroes if c.team == Combatant.Team.HEROES else battle.monsters


## The living one of [param side] with the lowest share of health, the first on a tie.
static func _weakest(side: Array[Combatant]) -> Combatant:
	var weakest: Combatant = null
	for c: Combatant in side:
		if c.is_alive() and (weakest == null or c.health_fraction() < weakest.health_fraction()):
			weakest = c
	return weakest


## Whom [param effect] lands on, in the order of their side: the living, or for a revive the
## fallen heroes of the fighter's own side; never, if it hurts, an enemy that is untouchable.
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
		AbilityEffect.Lands.NEAREST_ENEMY:
			var nearest: Combatant = battle.nearest_enemy(c)
			if nearest != null:
				pool = [nearest]
	var radius: float = effect.radius
	var by_place: bool = effect.lands == AbilityEffect.Lands.AROUND_TARGET
	if effect.lands in [AbilityEffect.Lands.ALLIES, AbilityEffect.Lands.ENEMIES]:
		by_place = radius > 0.0
	var reviving: bool = effect.does == AbilityEffect.Does.REVIVE
	var hurts: bool = not effect.is_helpful()
	var found: Array[Combatant] = []
	for receiver: Combatant in pool:
		if by_place and absf(receiver.x - center) > radius + Battle.EPSILON:
			continue
		if reviving and (receiver.is_alive() or receiver.team != c.team or receiver.is_summon()):
			continue
		if not reviving and not receiver.is_alive():
			continue
		if hurts and battle.untouchable(c, receiver):
			continue
		found.append(receiver)
	return found


static func _apply(
	battle: Battle,
	c: Combatant,
	ability: AbilityDef,
	effect: AbilityEffect,
	receiver: Combatant,
	chain: int
) -> void:
	match effect.does:
		AbilityEffect.Does.DAMAGE:
			var base: float = c.heal_power if effect.damage_from_healing else c.damage
			var amount: float = base * effect.multiplier
			if receiver.health_fraction() < effect.low_health_below:
				amount *= effect.low_multiplier
			amount *= c.dealt_multiplier()
			if not effect.ignores_armor:
				amount -= receiver.armor
			amount *= receiver.taken_multiplier()
			var via: Battle.Via = Battle.Via.ACTION if ability.is_action() else Battle.Via.PASSIVE
			var dealt: int = battle.deal(c, receiver, maxi(1, roundi(amount)), false, via, chain)
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
		AbilityEffect.Does.SUMMON:
			BattleSummons.summon(battle, c, effect, ability)
