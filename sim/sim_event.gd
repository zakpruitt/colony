class_name SimEvent
extends RefCounted
## One thing that happened in the simulation, for the view to show.

enum Kind {
	ATTACK_STARTED,
	PROJECTILE_LAUNCHED,
	HIT,
	HEALED,
	DIED,
	# From here to ENCOUNTER_STARTED: kinds that not every expedition run produces (a command's
	# result, or a rarer moment).
	UPGRADE_BOUGHT,
	GUARDIAN_SLAIN,
	MICROSKILL_LEARNED,
	QUEST_STARTED,
	QUEST_DONE,
	QUEST_MISSED,
	TALENT_POINT_GAINED,
	TALENT_TAKEN,
	PARAGON_SPENT,
	TALENTS_RESET,
	ORDER_CHANGED,
	ABILITY_STARTED,
	ABILITY_USED,
	STATUS_BEGAN,
	STATUS_ENDED,
	MISSED,
	REVIVED,
	AREA_CHANGED,
	AREA_OPENED,
	RESOURCE_GAINED,
	GATE_STARTED,
	GATE_OPENED,
	GATE_SEALED,
	CACHE_OPENED,
	ENCOUNTER_STARTED,
	ENCOUNTER_ENDED,
	XP_GAINED,
	GOLD_GAINED,
	LEVEL_UP,
	REST_STARTED,
	REST_ENDED,
	DEPTH_CHANGED,
	PARTY_WIPED,
	PARTY_REVIVED,
	STABLE_DEPTH_REACHED,
	TARGET_DEPTH_CHANGED,
}

var kind: Kind
var tick: int
var source_id: int = -1
var target_id: int = -1
## Damage or healing done; flight time in ticks for PROJECTILE_LAUNCHED;
## wind-up in ticks for ATTACK_STARTED. For the expedition's events: the chamber
## index (ENCOUNTER_STARTED, ENCOUNTER_ENDED), XP or gold gained, the new level
## (LEVEL_UP), or the depth (DEPTH_CHANGED, PARTY_REVIVED, STABLE_DEPTH_REACHED,
## TARGET_DEPTH_CHANGED). For UPGRADE_BOUGHT: the new rank, with [member source_id]
## the upgrade's position in [method Content.upgrade_ids]. For GUARDIAN_SLAIN: the depth,
## with [member source_id] the guardian's combatant id.
## For MICROSKILL_LEARNED: the hero's level, with [member source_id] the hero and
## [member target_id] the microskill's position in [method Content.microskill_ids].
## For QUEST_STARTED and QUEST_DONE: the work in ticks, or the gold or XP given,
## with [member source_id] the worker and [member target_id] the quest's position in
## [method Content.quest_ids]. For QUEST_MISSED: the needed microskill's position,
## with [member target_id] the quest's position. For the talent kinds, with [member source_id] the
## hero: TALENT_POINT_GAINED: the level that earned it; TALENT_TAKEN: the talent points left, with
## [member ability_id] the node; PARAGON_SPENT: the points now in the stat, with
## [member target_id] the stat's position in [method Content.training_ids]; TALENTS_RESET: the
## gold paid. For ORDER_CHANGED: the order's new value
## ([enum Expedition.Pace] or [enum Expedition.GuardianOrder]), with [member target_id] which order:
## [constant PartyOrders.PACE] (0) or [constant PartyOrders.GUARDIANS] (1).
## For the ability kinds, with [member source_id] the fighter and [member target_id] whom it is on:
## ABILITY_STARTED: the wind-up in ticks; ABILITY_USED: 0; STATUS_BEGAN: how many ticks it lasts;
## STATUS_ENDED: 0; MISSED: the damage absorbed by a shield (0 for a miss);
## REVIVED: the health it stands up with.
## For AREA_CHANGED and AREA_OPENED: the area's position in [method Content.area_ids].
## For RESOURCE_GAINED: how many, with [member target_id] the resource's position in
## [method Content.resource_ids] and [member source_id] the monster that dropped it, or the hero
## who finished a quest or opened a cache's gate.
## For the side path kinds: GATE_STARTED: the work in ticks, with [member source_id] the worker and
## [member target_id] the gate's position in [method Content.gate_ids]; GATE_OPENED: the side
## path's place in [member LabyrinthLevel.side_paths], with the same source and target;
## GATE_SEALED: the needed microskill's position, with [member target_id] the gate's position;
## CACHE_OPENED: the side path's place, with [member source_id] the hero who opened its gate.
var amount: int = 0
## Crit for HIT; "is a heal" for PROJECTILE_LAUNCHED; "the heroes won" for ENCOUNTER_ENDED;
## "a hazard sprang" for QUEST_MISSED; "a shield absorbed it" for MISSED.
var flag: bool = false
## The [AbilityDef] id for ABILITY_STARTED, ABILITY_USED and STATUS_BEGAN (the ability that put
## the status there), and for STATUS_ENDED; the node for TALENT_TAKEN; empty otherwise.
var ability_id: StringName = &""
## The [enum AbilityEffect.Status] for STATUS_BEGAN and STATUS_ENDED; -1 otherwise.
var status: int = -1


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
