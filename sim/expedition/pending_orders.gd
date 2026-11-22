class_name PendingOrders
extends RefCounted
## The orders asked of an [Expedition] by a command and not yet applied: each waits for the
## expedition's next tick, so a command given between two steps changes nothing until the
## second. Kept apart from [Expedition] so its file has room.

## The value asked for each order, by [constant PartyOrders.PACE] and
## [constant PartyOrders.GUARDIANS]; -1 when none.
var _asked: Array[int] = [-1, -1]


## Asks for [param value] of the order [param which]; an order there is not is ignored.
func ask(which: int, value: int) -> void:
	if which >= 0 and which < _asked.size():
		_asked[which] = value


## Gives [param run] every order asked for, reporting ORDER_CHANGED for each that changes it. A
## value the order does not have, or the one it holds, changes nothing.
func apply(run: Expedition) -> void:
	var pace: int = _asked[PartyOrders.PACE]
	var guardians: int = _asked[PartyOrders.GUARDIANS]
	if pace < 0 and guardians < 0:
		return
	if pace in Expedition.Pace.values() and pace != run.pace:
		run.pace = pace as Expedition.Pace
		run._emit(SimEvent.Kind.ORDER_CHANGED, -1, PartyOrders.PACE, run.pace)
	if guardians in Expedition.GuardianOrder.values() and guardians != run.guardian_order:
		run.guardian_order = guardians as Expedition.GuardianOrder
		run._emit(SimEvent.Kind.ORDER_CHANGED, -1, PartyOrders.GUARDIANS, run.guardian_order)
	_asked.fill(-1)


## What [param run]'s orders add to its state hash: nothing while each is at its default and
## none is asked for, so a run that never gives an order hashes as one without orders.
func hash_parts(run: Expedition) -> Array:
	var pace: int = _asked[PartyOrders.PACE]
	var guardians: int = _asked[PartyOrders.GUARDIANS]
	var plain: bool = (
		run.pace == Expedition.Pace.STEADY
		and run.guardian_order == Expedition.GuardianOrder.CHALLENGE
	)
	if plain and pace < 0 and guardians < 0:
		return []
	return [["orders", run.pace, run.guardian_order, pace, guardians]]
