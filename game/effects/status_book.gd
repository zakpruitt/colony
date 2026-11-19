class_name StatusBook
extends RefCounted
## The statuses on every fighter, kept from the simulation's events and in their order:
## a status is on from its STATUS_BEGAN to its STATUS_ENDED, so a frame holding both leaves
## nothing over. A fight's end, a wipe, a change of area or of stage clears the book as well, so no
## mark outlives the fight it was put on in. It reads nothing but the events, and changes nothing.
##
## As the battle does, a status put on again keeps its once-a-second clock and moves its end, and
## takes the new source and ability only when it is stronger. Its strength is worked out from its
## ability and the fighters' measures ([member power]); a shield's left is worn down by the
## blows the flagged MISSED events say it absorbed.

## How strong a status from fighter [code]source[/code] on fighter
## [code]receiver[/code] is, as a multiple of [code]scale[/code] ([enum AbilityEffect.Scale]):
## func(source: int, receiver: int, scale: int) -> float. Unset, strengths are not known.
var power: Callable

## Fighter id to status kind to what the events have said of it.
var _on: Dictionary[int, Dictionary] = {}


## Notes what [param event] says of statuses, if anything.
func observe(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.STATUS_BEGAN:
			var mine: Dictionary = _on.get(event.target_id, {})
			var old: ShownStatus = mine.get(event.status, null)
			var strength: float = _strength(event)
			if old != null:
				# Put on again: its time moves and its clock stays; a stronger one takes over.
				old.end_tick = event.tick + event.amount
				if old.weaker_than(strength):
					old.source_id = event.source_id
					old.ability_id = event.ability_id
					old.amount = strength
					old.full = strength
			else:
				var fresh := ShownStatus.new(
					event.status as AbilityEffect.Status, event.tick, event.tick + event.amount
				)
				fresh.source_id = event.source_id
				fresh.ability_id = event.ability_id
				fresh.amount = strength
				fresh.full = strength
				mine[event.status] = fresh
			_on[event.target_id] = mine
		SimEvent.Kind.MISSED:
			var shield: ShownStatus = find(event.target_id, AbilityEffect.Status.SHIELDED)
			if event.flag and shield != null and shield.amount >= 0.0:
				shield.amount = maxf(shield.amount - event.amount, 0.0)
		SimEvent.Kind.STATUS_ENDED:
			var mine: Dictionary = _on.get(event.target_id, {})
			mine.erase(event.status)
			if mine.is_empty():
				_on.erase(event.target_id)
		SimEvent.Kind.ENCOUNTER_ENDED, SimEvent.Kind.PARTY_WIPED, SimEvent.Kind.AREA_CHANGED:
			_on.clear()
		SimEvent.Kind.DEPTH_CHANGED:
			_on.clear()


## The statuses on fighter [param id], in [enum AbilityEffect.Status] order.
func statuses_of(id: int) -> Array[ShownStatus]:
	var found: Array[ShownStatus] = []
	var mine: Dictionary = _on.get(id, {})
	var kinds: Array = mine.keys()
	kinds.sort()
	for kind: int in kinds:
		var status: ShownStatus = mine[kind]
		found.append(status)
	return found


## The status [param kind] on fighter [param id], or null.
func find(id: int, kind: int) -> ShownStatus:
	var mine: Dictionary = _on.get(id, {})
	var status: ShownStatus = mine.get(kind, null)
	return status


## The share of fighter [param id]'s shield still to absorb, from 0 to 1 (1 when unknown).
func shield_left(id: int) -> float:
	var shield: ShownStatus = find(id, AbilityEffect.Status.SHIELDED)
	if shield == null or shield.full <= 0.0 or shield.amount < 0.0:
		return 1.0
	return clampf(shield.amount / shield.full, 0.0, 1.0)


## How strong the status [param event] puts on is, as [method BattleStatuses.apply] works it out
## from its ability's effect; -1 when that cannot be known.
func _strength(event: SimEvent) -> float:
	var ability: AbilityDef = Content.ability(event.ability_id)
	if ability == null:
		return -1.0
	for effect: AbilityEffect in ability.effects:
		if effect.does != AbilityEffect.Does.STATUS or effect.status != event.status:
			continue
		if not effect.status in AbilityEffect.IN_POINTS:
			return effect.amount
		if not power.is_valid():
			return -1.0
		var base: float = power.call(event.source_id, event.target_id, effect.scale)
		var amount: float = effect.amount * base
		if effect.status == AbilityEffect.Status.SHIELDED:
			amount = roundf(amount)
		return amount
	return -1.0


## Every fighter with a status on it.
func fighters() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_on.keys())
	return ids


## True while no fighter has a status.
func is_empty() -> bool:
	return _on.is_empty()
