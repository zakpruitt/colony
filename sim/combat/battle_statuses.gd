class_name BattleStatuses
extends RefCounted
## The rules of statuses in a battle (spec 050): putting one on, its work each second, and its
## end. Stateless: everything lives on the [Combatant]s and the [Battle] passed in.

## Statuses that do something each second.
const PULSING: Array[AbilityEffect.Status] = [
	AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING, AbilityEffect.Status.MENDING
]


## Puts the status of [param effect], from [param source]'s ability [param ability_id], on
## [param receiver]. The same status again restarts its time and keeps the stronger amount.
static func apply(
	battle: Battle,
	source: Combatant,
	receiver: Combatant,
	effect: AbilityEffect,
	ability_id: StringName
) -> void:
	var amount: float = effect.amount
	if effect.status in AbilityEffect.IN_POINTS:
		amount *= _base(effect.scale, source, receiver)
	if effect.status == AbilityEffect.Status.SHIELDED:
		amount = roundi(amount)
	var ticks: int = Combatant.seconds_to_ticks(effect.seconds)
	var fresh := CombatStatus.new(effect.status, source.id, ability_id, amount, battle.tick, ticks)
	var old: CombatStatus = receiver.status(effect.status)
	if old != null and not old.weaker_than(amount):
		fresh.amount = old.amount
		fresh.source_id = old.source_id
		fresh.ability_id = old.ability_id
	receiver.statuses[effect.status] = fresh
	var began: SimEvent = battle.record(SimEvent.Kind.STATUS_BEGAN, source.id, receiver.id, ticks)
	began.ability_id = ability_id
	began.status = effect.status


## Lets every status in the battle work and end, on its tick: damage or healing each whole
## second after it began, then its end once its time is up.
static func pulse(battle: Battle) -> void:
	for c: Combatant in battle.heroes + battle.monsters:
		if c.statuses.is_empty():
			continue
		for kind: int in c.statuses.keys():
			var status: CombatStatus = c.statuses.get(kind, null)
			if status == null or not c.is_alive():
				continue
			if kind in PULSING and battle.tick >= status.pulse_tick:
				if status.pulse_tick <= status.end_tick:
					status.pulse_tick += Simulation.TICKS_PER_SECOND
					_work(battle, c, status)
			if c.is_alive() and battle.tick >= status.end_tick and c.statuses.get(kind) == status:
				end(battle, c, kind)


## Takes the status [param kind] off [param c], with a STATUS_ENDED event.
static func end(battle: Battle, c: Combatant, kind: int) -> void:
	var status: CombatStatus = c.statuses.get(kind, null)
	if status == null:
		return
	c.statuses.erase(kind)
	var ended: SimEvent = battle.record(SimEvent.Kind.STATUS_ENDED, status.source_id, c.id)
	ended.ability_id = status.ability_id
	ended.status = kind


## Takes every status off [param c].
static func clear(battle: Battle, c: Combatant) -> void:
	for kind: int in c.statuses.keys():
		end(battle, c, kind)


static func _work(battle: Battle, bearer: Combatant, status: CombatStatus) -> void:
	var source: Combatant = battle.combatant(status.source_id)
	if status.kind == AbilityEffect.Status.MENDING:
		battle.heal(source, bearer, roundi(status.amount))
		return
	var dealt: int = maxi(1, roundi(status.amount * bearer.taken_multiplier()))
	battle.deal(source, bearer, dealt, false, Battle.Via.STATUS)


static func _base(scale: AbilityEffect.Scale, source: Combatant, receiver: Combatant) -> float:
	match scale:
		AbilityEffect.Scale.FIGHTER_DAMAGE:
			return source.damage
		AbilityEffect.Scale.FIGHTER_HEALING:
			return source.heal_power
	return receiver.max_health
