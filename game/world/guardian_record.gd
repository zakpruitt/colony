class_name GuardianRecord
extends RefCounted
## Which fighters are guardians: the combatant ids of the guardians seen in a fight, kept from the
## world's events so a guardian's death and gold are known for its own after its battle is gone.
## The [World] keeps one, and the effects and the sounds read it.

var _ids: Dictionary[int, bool] = {}


## Notes the guardian of [param simulation]'s fight now, if it has one (a world made mid-fight).
func note(simulation: Simulation) -> void:
	var guardian: Combatant = CombatEffects.battle_guardian(simulation)
	if guardian != null:
		_ids[guardian.id] = true


## Takes in [param event]: a fight that starts with a guardian notes it.
func observe(event: SimEvent, simulation: Simulation) -> void:
	if event.kind == SimEvent.Kind.ENCOUNTER_STARTED:
		note(simulation)


## True for the combatant id of a guardian seen in a fight.
func has(id: int) -> bool:
	return _ids.has(id)
