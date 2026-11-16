class_name SimEvent
extends RefCounted
## One thing that happened in the simulation, for the view to show.

enum Kind { ATTACK_STARTED, PROJECTILE_LAUNCHED, HIT, HEALED, DIED }

var kind: Kind
var tick: int
var source_id: int = -1
var target_id: int = -1
## Damage or healing done; flight time in ticks for PROJECTILE_LAUNCHED.
var amount: int = 0
## Crit for HIT; "is a heal" for PROJECTILE_LAUNCHED.
var flag: bool = false


## Every argument is optional, so [code]SimEvent.new()[/code] still works.
func _init(
	kind_in: Kind = Kind.ATTACK_STARTED,
	tick_in: int = 0,
	source: int = -1,
	target: int = -1,
	amount_in: int = 0,
	flag_in: bool = false
) -> void:
	kind = kind_in
	tick = tick_in
	source_id = source
	target_id = target
	amount = amount_in
	flag = flag_in
