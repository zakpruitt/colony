class_name BattleProjectile
extends RefCounted
## A shot or a heal in flight. It lands on [member land_tick] even if its
## source has died, and does nothing if its target died first.

var source: Combatant
var target_id: int
var land_tick: int
var is_heal: bool


func _init(source_in: Combatant, target: int, land: int, heal: bool) -> void:
	source = source_in
	target_id = target
	land_tick = land
	is_heal = heal
