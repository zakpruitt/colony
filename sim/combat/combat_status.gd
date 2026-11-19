class_name CombatStatus
extends RefCounted
## A status on one fighter: what it is, who put it there, how strong it is and
## until when. Statuses live only as long as the fight.

var kind: AbilityEffect.Status
## The combatant who put it there; damage and healing it does are credited to them.
var source_id: int
## The ability that put it there.
var ability_id: StringName
## Points for SHIELDED (what is left to absorb), BURNING, BLEEDING, CHILLED, MENDING (each second);
## a multiplier or a chance for the others (see [enum AbilityEffect.Status]).
var amount: float
## The tick it ends on.
var end_tick: int
## The next tick a status that works each second does so.
var pulse_tick: int


func _init(
	kind_in: AbilityEffect.Status,
	source: int,
	ability: StringName,
	amount_in: float,
	begin_tick: int,
	ticks: int
) -> void:
	kind = kind_in
	source_id = source
	ability_id = ability
	amount = amount_in
	end_tick = begin_tick + ticks
	pulse_tick = begin_tick + Simulation.TICKS_PER_SECOND


## True if [param other] of the same kind is stronger than this one: for what makes strikes
## come sooner or deal less, a smaller amount; for the rest, a larger one.
func weaker_than(other: float) -> bool:
	if kind in [AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED]:
		return other < amount
	return other > amount
