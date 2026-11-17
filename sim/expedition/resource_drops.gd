class_name ResourceDrops
extends RefCounted
## What the party gathers of the area's resource (spec 052): a monster killed may drop some, by its
## size, and a side quest finished pays some; the amount grows with the stage. Kept apart from
## [Expedition] so its file stays under gdlint's 1000 lines.
##
## Each kill's roll comes from its own stream, forked from the expedition's under the area's label
## and the monster's id, so a drop takes nothing from any other stream (no fight changes) and leaves
## nothing to save: the same monster always drops the same.

## The chance a monster of each [enum MonsterDef.Size] drops anything: small sometimes, large
## usually, a guardian always.
const DROP_CHANCE: Dictionary[MonsterDef.Size, float] = {
	MonsterDef.Size.SMALL: 0.3,
	MonsterDef.Size.LARGE: 0.8,
	MonsterDef.Size.BOSS: 1.0,
}
## How many a drop of each size is on stage 1.
const DROP_BASE: Dictionary[MonsterDef.Size, int] = {
	MonsterDef.Size.SMALL: 1,
	MonsterDef.Size.LARGE: 2,
	MonsterDef.Size.BOSS: 6,
}
## Each stage past the first adds this share of the stage-1 amount, so farming further pays more.
const STAGE_GROWTH: float = 0.25
## A side quest finished pays what a large monster's drop on its stage is.
const QUEST_SIZE: MonsterDef.Size = MonsterDef.Size.LARGE


## How many a drop of a monster of [param size] is on [param stage].
static func amount_at(size: MonsterDef.Size, stage: int) -> int:
	return maxi(roundi(DROP_BASE[size] * (1.0 + STAGE_GROWTH * maxi(stage - 1, 0))), 1)


## [param dead], a monster of [param def], fell in [param run]'s fight: it may drop the area's
## resource, with [constant SimEvent.Kind.RESOURCE_GAINED].
static func on_kill(run: Expedition, dead: Combatant, def: MonsterDef) -> void:
	var label: String = AreaTravel.label(run._here.id)
	var rng: SimRng = run._rng.fork(label + "resource/%d" % dead.id)
	if not rng.chance(DROP_CHANCE[def.size]):
		return
	_give(run, dead.id, amount_at(def.size, run._battle_key.x))


## The party finished a side quest on [param stage], [param worker] doing it: it pays some of the
## area's resource.
static func on_quest(run: Expedition, worker: int, stage: int) -> void:
	_give(run, worker, amount_at(QUEST_SIZE, stage))


static func _give(run: Expedition, source: int, amount: int) -> void:
	var id: StringName = run._here.resource
	var position: int = Content.resource_ids().find(id)
	if position < 0 or amount <= 0:
		return
	run._party.set_resource(id, run._party.resource(id) + amount)
	run._emit(SimEvent.Kind.RESOURCE_GAINED, source, position, amount)
