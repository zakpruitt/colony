class_name SimEvent
extends RefCounted
## One thing that happened in the simulation, for the view to show.

enum Kind {
	ATTACK_STARTED,
	PROJECTILE_LAUNCHED,
	HIT,
	HEALED,
	DIED,
	# A command's result, not the expedition's: kept before ENCOUNTER_STARTED, where
	# the kinds every expedition run produces begin (spec 005's R18 test counts on it).
	UPGRADE_BOUGHT,
	# Only a run that beats a guardian produces it, so it too sits before ENCOUNTER_STARTED.
	GUARDIAN_SLAIN,
	# Spec 025's: not every run need produce each of them, so they too sit before ENCOUNTER_STARTED.
	MICROSKILL_LEARNED,
	SIDE_QUEST_STARTED,
	SIDE_QUEST_DONE,
	SIDE_QUEST_MISSED,
	# A command's result (spec 029), kept before ENCOUNTER_STARTED like UPGRADE_BOUGHT.
	HERO_TRAINED,
	# A command's result (spec 035), kept before ENCOUNTER_STARTED like UPGRADE_BOUGHT.
	ORDER_CHANGED,
	# Spec 049's: only a run that changes area or beats an area's guardian produces them.
	AREA_CHANGED,
	AREA_OPENED,
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
## For SIDE_QUEST_STARTED and SIDE_QUEST_DONE: the work in ticks, or the gold or XP given,
## with [member source_id] the worker and [member target_id] the quest's position in
## [method Content.side_quest_ids]. For SIDE_QUEST_MISSED: the needed microskill's position,
## with [member target_id] the quest's position. For HERO_TRAINED: the hero's new rank, with
## [member source_id] the hero's id and [member target_id] the training's position in
## [method Content.training_ids]. For ORDER_CHANGED: the order's new value
## ([enum Expedition.Pace] or [enum Expedition.GuardianOrder]), with [member target_id] which order:
## [constant PartyOrders.PACE] (0) or [constant PartyOrders.GUARDIANS] (1).
## For AREA_CHANGED and AREA_OPENED: the area's position in [method Content.area_ids].
var amount: int = 0
## Crit for HIT; "is a heal" for PROJECTILE_LAUNCHED; "the heroes won" for ENCOUNTER_ENDED;
## "a hazard sprang" for SIDE_QUEST_MISSED.
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
