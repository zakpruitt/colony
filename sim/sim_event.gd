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
	# A command's result (spec 029), kept before ENCOUNTER_STARTED like UPGRADE_BOUGHT.
	HERO_TRAINED,
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
## with [member source_id] the guardian's combatant id. For HERO_TRAINED: the hero's new
## rank, with [member source_id] the hero's id and [member target_id] the training's
## position in [method Content.training_ids].
var amount: int = 0
## Crit for HIT; "is a heal" for PROJECTILE_LAUNCHED; "the heroes won" for ENCOUNTER_ENDED.
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
