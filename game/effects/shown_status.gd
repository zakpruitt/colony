class_name ShownStatus
extends RefCounted
## One status on one fighter as the events have told it: what it is, who put it there
## with which ability, and the ticks it began, first works and ends on. Kept by a [StatusBook].

var kind: AbilityEffect.Status
## The fighter who put it there, and the ability.
var source_id: int = -1
var ability_id: StringName = &""
## The simulation tick of its first STATUS_BEGAN, and the tick its time is up on.
var begin_tick: int = 0
var end_tick: int = 0
## How strong it is, as the battle measures it (points, a multiplier or a chance), worked out from
## its ability; -1 when that cannot be known. A shield's amount is what it has left after the
## blows the events say it absorbed, and [member full] what it held when put on.
var amount: float = -1.0
var full: float = -1.0


func _init(kind_in: AbilityEffect.Status, begin: int, end: int) -> void:
	kind = kind_in
	begin_tick = begin
	end_tick = end


## True if a status that works each second does so on [param tick]: a whole number of seconds
## after it began, while it lasts (as [method BattleStatuses.pulse] works it).
func pulses_on(tick: int) -> bool:
	var since: int = tick - begin_tick
	var each: int = Simulation.TICKS_PER_SECOND
	return since >= each and since % each == 0 and tick <= end_tick


## True if a status of the same kind with [param other] amount is stronger, as
## [method CombatStatus.weaker_than] has it; false when either strength is unknown.
func weaker_than(other: float) -> bool:
	if amount < 0.0 or other < 0.0:
		return false
	if kind in [AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED]:
		return other < amount
	return other > amount


## The name the screen gives a status: "Burning", "Shielded".
static func status_name(status: int) -> String:
	return str(AbilityEffect.Status.keys()[status]).capitalize()
