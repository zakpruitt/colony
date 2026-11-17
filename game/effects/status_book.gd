class_name StatusBook
extends RefCounted
## The statuses on every fighter (spec 056), kept from the simulation's events and in their order:
## a status is on from its STATUS_BEGAN to its STATUS_ENDED, so a frame holding both leaves
## nothing over. A fight's end, a wipe or a change of area clears the book as well, so no mark
## outlives the fight it was put on in. It reads nothing but the events, and changes nothing.

## Fighter id to status kind to what the events have said of it.
var _on: Dictionary[int, Dictionary] = {}


## Notes what [param event] says of statuses, if anything.
func observe(event: SimEvent) -> void:
	match event.kind:
		SimEvent.Kind.STATUS_BEGAN:
			var mine: Dictionary = _on.get(event.target_id, {})
			var old: ShownStatus = mine.get(event.status, null)
			if old != null:
				# Put on again: its time moves, its once-a-second clock and its source stay.
				old.end_tick = event.tick + event.amount
			else:
				var fresh := ShownStatus.new(
					event.status as AbilityEffect.Status, event.tick, event.tick + event.amount
				)
				fresh.source_id = event.source_id
				fresh.ability_id = event.ability_id
				mine[event.status] = fresh
			_on[event.target_id] = mine
		SimEvent.Kind.STATUS_ENDED:
			var mine: Dictionary = _on.get(event.target_id, {})
			mine.erase(event.status)
			if mine.is_empty():
				_on.erase(event.target_id)
		SimEvent.Kind.ENCOUNTER_ENDED, SimEvent.Kind.PARTY_WIPED, SimEvent.Kind.AREA_CHANGED:
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


## Every fighter with a status on it.
func fighters() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_on.keys())
	return ids


## True while no fighter has a status.
func is_empty() -> bool:
	return _on.is_empty()
