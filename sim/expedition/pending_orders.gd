class_name PendingOrders
extends RefCounted
## The orders asked of an [Expedition] by a command and not yet applied: each waits for the
## expedition's next tick, so a command given between two steps changes nothing until the
## second. Kept apart from [Expedition] so its file has room.

## The value asked for each order, by [constant PartyOrders.PACE],
## [constant PartyOrders.GUARDIANS] and [constant PartyOrders.SIDE_PATHS]; -1 when none.
var _asked: Array[int] = [-1, -1, -1]
## Whether any is asked for.
var _waiting: bool = false


## Asks for [param value] of the order [param which]; an order there is not is ignored.
func ask(which: int, value: int) -> void:
	if which >= 0 and which < _asked.size():
		_asked[which] = value
		_waiting = true


## Gives [param run] every order asked for, reporting ORDER_CHANGED for each that changes it. A
## value the order does not have, or the one it holds, changes nothing.
func apply(run: Expedition) -> void:
	if not _waiting:
		return
	var pace: int = _asked[PartyOrders.PACE]
	var guardians: int = _asked[PartyOrders.GUARDIANS]
	var side: int = _asked[PartyOrders.SIDE_PATHS]
	if pace in Expedition.Pace.values() and pace != run.pace:
		run.pace = pace as Expedition.Pace
		run._emit(SimEvent.Kind.ORDER_CHANGED, -1, PartyOrders.PACE, run.pace)
	if guardians in Expedition.GuardianOrder.values() and guardians != run.guardian_order:
		run.guardian_order = guardians as Expedition.GuardianOrder
		run._emit(SimEvent.Kind.ORDER_CHANGED, -1, PartyOrders.GUARDIANS, run.guardian_order)
	if side in Expedition.SidePaths.values() and side != run.side_paths:
		run.side_paths = side as Expedition.SidePaths
		run._emit(SimEvent.Kind.ORDER_CHANGED, -1, PartyOrders.SIDE_PATHS, run.side_paths)
	_asked.fill(-1)
	_waiting = false


## What [param run]'s orders add to its state hash: nothing while each is at its default and
## none is asked for, so a run that never gives an order hashes as one without orders. The side
## path order has a part of its own, there only while it is, or is about to be, Press on: a run
## that gives the other two hashes as it did without it.
func hash_parts(run: Expedition) -> Array:
	var parts: Array = []
	var pace: int = _asked[PartyOrders.PACE]
	var guardians: int = _asked[PartyOrders.GUARDIANS]
	var plain: bool = (
		run.pace == Expedition.Pace.STEADY
		and run.guardian_order == Expedition.GuardianOrder.CHALLENGE
	)
	if not plain or pace >= 0 or guardians >= 0:
		parts.append(["orders", run.pace, run.guardian_order, pace, guardians])
	var side: int = _asked[PartyOrders.SIDE_PATHS]
	if run.side_paths != Expedition.SidePaths.EXPLORE or side == Expedition.SidePaths.PRESS_ON:
		parts.append(["side_paths", run.side_paths, side])
	return parts
