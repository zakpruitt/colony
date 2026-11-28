class_name BattleSummons
extends RefCounted
## The rules of summons in a battle: their coming, their caps and their end. Stateless:
## everything lives on the [Combatant]s and the [Battle] passed in.
##
## A summon comes from an [AbilityEffect] that summons, beside its summoner on the heroes' side
## ([member Battle.summons]), and fights as any fighter does. Its end is never a death: no DIED,
## no passive of a kill or an ally's death, no revive, and the heroes standing are as they were.

## Why a summon ended: the amount of its SUMMON_ENDED event.
enum Ended { TIME_UP, FELL, REPLACED, FIGHT_ENDED }

## The most summons in a fight at once: one for each id they take.
const MOST: int = Battle.LAST_SUMMON_ID - Battle.FIRST_SUMMON_ID + 1


## [param summoner]'s [param ability] lands its summoning [param effect]: each of its
## [member AbilityEffect.count] summons comes in turn, the oldest of the summoner's own of that id
## replaced once it has [member AbilityEffect.summon_cap] of them, and the oldest in the fight once
## there are [constant MOST]. Each comes [member SummonDef.ahead] tiles ahead of its summoner
## toward the enemy, inside the room, with a SUMMONED event; its passives that answer a fight
## starting answer its coming.
static func summon(
	battle: Battle, summoner: Combatant, effect: AbilityEffect, ability: AbilityDef
) -> void:
	var def: SummonDef = effect.summon
	if def == null:
		return
	var lifetime: int = Combatant.seconds_to_ticks(def.seconds)
	for i: int in maxi(effect.count, 1):
		_make_room(battle, summoner, def.id, maxi(effect.summon_cap, 1))
		var made: Combatant = Combatant.from_summon(def, summoner, _free_id(battle))
		# Standing on its summoner, a push moves it toward the enemy and keeps it in the room.
		battle.push(summoner, made, def.ahead)
		made.state = Combatant.State.IDLE
		made.ready_tick = battle.tick
		made.ends_tick = battle.tick + lifetime
		made.reset_abilities()
		for own: AbilityDef in made.abilities:
			if own.is_action() and not own.ready_at_start:
				made.action_ready_tick[own.id] += battle.tick
		battle.add_summon(made)
		var came: SimEvent = battle.record(SimEvent.Kind.SUMMONED, summoner.id, made.id, lifetime)
		came.ability_id = ability.id
		BattleAbilities.fire(battle, made, AbilityDef.Trigger.FIGHT_STARTS, made)


## Ends the summons whose time is up.
static func pulse(battle: Battle) -> void:
	# The battle makes a new list as one goes, so this walk is never changed under it.
	for c: Combatant in battle.summons:
		if battle.tick >= c.ends_tick:
			end_summon(battle, c, Ended.TIME_UP)


## Ends every summon in the fight, for [param why] (an [enum Ended]).
static func end_all(battle: Battle, why: int) -> void:
	for c: Combatant in battle.summons:
		end_summon(battle, c, why)


## Ends the summon [param c] for [param why] (an [enum Ended]): its statuses, and those it put on
## anyone, end with their STATUS_ENDED events, it leaves the fight, and SUMMON_ENDED reports it.
## Nothing for one already gone.
static func end_summon(battle: Battle, c: Combatant, why: int) -> void:
	if battle.combatant(c.id) != c:
		return
	c.state = Combatant.State.DEAD
	c.target_id = -1
	c.pending_action = null
	BattleStatuses.clear(battle, c)
	BattleStatuses.clear_from(battle, c)
	battle._remove_summon(c)
	battle.record(SimEvent.Kind.SUMMON_ENDED, c.id, c.owner_id, why)


## Ends what must go for one more summon of [param id] from [param summoner]: its oldest of that id
## while it has [param cap] of them, then the oldest in the fight while there are [constant MOST].
static func _make_room(battle: Battle, summoner: Combatant, id: StringName, cap: int) -> void:
	var oldest: Combatant = null
	var held: int = cap
	while held >= cap:
		held = 0
		oldest = null
		for c: Combatant in battle.summons:
			if c.owner_id == summoner.id and c.def_id == id:
				held += 1
				if oldest == null:
					oldest = c
		if held >= cap:
			end_summon(battle, oldest, Ended.REPLACED)
	while battle.summons.size() >= MOST:
		end_summon(battle, battle.summons[0], Ended.REPLACED)


## The next id in turn that no summon in the fight holds, moving [member Battle.next_summon_id]
## past it.
static func _free_id(battle: Battle) -> int:
	for i: int in MOST:
		var id: int = battle.next_summon_id
		battle.next_summon_id = Battle.FIRST_SUMMON_ID + (id + 1 - Battle.FIRST_SUMMON_ID) % MOST
		if battle.combatant(id) == null:
			return id
	return battle.next_summon_id
